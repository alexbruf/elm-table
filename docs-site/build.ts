// Builds the elm-table documentation site into dist/.
//
//   bun run build.ts          full build
//   bun run build.ts --fast   skip `elm make` for docs.json and the snippets
//
// Pipeline:
//   1. `elm make --docs=docs.json` in the repo root (the API source of truth).
//   2. `elm make src/*.elm` in snippets/ so every code block in the docs compiles.
//   3. Markdown in content/ -> HTML, with `elm snippet=Module.elm#name` fences
//      replaced by the named top-level declaration from snippets/src/Module.elm.
//   4. One generated page per exposed module, rendered from docs.json.
//   5. Sidebar from config.json, prev/next links, per-page table of contents.
//   6. Link check: every internal href must resolve to a page and an anchor.
//
// Any failure exits non-zero.

import { $ } from "bun";
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync, rmSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { Marked } from "marked";

const root = import.meta.dir;
const repo = join(root, "..");
const dist = join(root, "dist");
const fast = process.argv.includes("--fast");

const fail = (msg: string): never => {
  console.error(`\n  build failed: ${msg}\n`);
  process.exit(1);
};

// ---------------------------------------------------------------- 1. elm make

if (!fast) {
  const docs = await $`elm make --docs=docs.json`.cwd(repo).quiet().nothrow();
  if (docs.exitCode !== 0) fail(`elm make --docs=docs.json\n${docs.stderr.toString()}`);
  console.log("  docs.json regenerated");
}

const snippetsDir = join(root, "snippets");
const snippetFiles = readdirSync(join(snippetsDir, "src")).filter((f) => f.endsWith(".elm"));
if (snippetFiles.length === 0) fail("snippets/src holds no .elm modules");

if (!fast) {
  const paths = snippetFiles.map((f) => `src/${f}`);
  const compiled = await $`elm make ${paths} --output=/dev/null`.cwd(snippetsDir).quiet().nothrow();
  if (compiled.exitCode !== 0) {
    fail(`snippets do not compile\n${compiled.stderr.toString()}${compiled.stdout.toString()}`);
  }
  console.log(`  ${snippetFiles.length} snippet modules compile`);
}

// ------------------------------------------------------- 2. snippet extraction

type DeclMap = Map<string, string>;
const snippetSource = new Map<string, DeclMap>();

const parseDecls = (source: string): DeclMap => {
  const lines = source.split("\n");
  const decls: DeclMap = new Map();
  const starts: { name: string | null; line: number }[] = [];
  for (let i = 0; i < lines.length; i++) {
    // Type, module, import and port lines end the previous declaration but are
    // not addressable by name themselves.
    if (/^(module|import|port|type|infix)\b/.test(lines[i])) {
      if (starts.length && starts[starts.length - 1].name !== null) starts.push({ name: null, line: i });
      continue;
    }
    const m = /^([a-z][A-Za-z0-9_]*)\s*(:|.*=)/.exec(lines[i]);
    if (!m) continue;
    const name = m[1];
    if (starts.length && starts[starts.length - 1].name === name) continue;
    starts.push({ name, line: i });
  }
  for (let s = 0; s < starts.length; s++) {
    const from = starts[s].line;
    let to = s + 1 < starts.length ? starts[s + 1].line : lines.length;
    // Trim trailing blank lines and any doc comment that belongs to the next decl.
    while (to > from && lines[to - 1].trim() === "") to--;
    let body = lines.slice(from, to);
    // Drop a trailing block comment (the doc comment of the next declaration).
    for (;;) {
      let end = body.length;
      while (end > 0 && body[end - 1].trim() === "") end--;
      if (end === 0 || !/-\}\s*$/.test(body[end - 1])) break;
      let open = end - 1;
      while (open >= 0 && !/^\{-/.test(body[open])) open--;
      if (open < 0) break;
      body = body.slice(0, open);
      while (body.length && body[body.length - 1].trim() === "") body.pop();
    }
    while (body.length && /^--/.test(body[body.length - 1])) {
      body.pop();
      while (body.length && body[body.length - 1].trim() === "") body.pop();
    }
    if (starts[s].name !== null) decls.set(starts[s].name!, body.join("\n"));
  }
  return decls;
};

for (const f of snippetFiles) {
  snippetSource.set(f, parseDecls(readFileSync(join(snippetsDir, "src", f), "utf8")));
}

let snippetUses = 0;
const usedDecls = new Set<string>();

const resolveSnippet = (spec: string, page: string): string => {
  const [file, name] = spec.split("#");
  if (!file || !name) fail(`${page}: malformed snippet spec "${spec}" (want Module.elm#name)`);
  const decls = snippetSource.get(file);
  if (!decls) fail(`${page}: snippet file snippets/src/${file} does not exist`);
  const body = decls!.get(name);
  if (body === undefined) {
    fail(`${page}: snippets/src/${file} has no top-level declaration "${name}"`);
  }
  snippetUses++;
  usedDecls.add(`${file}#${name}`);
  return body!;
};

// -------------------------------------------------------------- 3. site config

type NavChild = { label: string; to: string; module?: string };
type NavSection = { label: string; children: NavChild[]; generated?: string };
type SiteConfig = {
  title: string;
  tagline: string;
  examplesBase: string;
  repo: string;
  sections: NavSection[];
};

const config: SiteConfig = JSON.parse(readFileSync(join(root, "config.json"), "utf8"));
const layout = readFileSync(join(root, "shared/layout.html"), "utf8");
const css = readFileSync(join(root, "shared/style.css"), "utf8");

const flatNav: NavChild[] = config.sections.flatMap((s) => s.children);
const navIds = new Set(flatNav.map((c) => c.to));

// ------------------------------------------------------------------ 4. marked

const escapeHtml = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

const slugify = (s: string) =>
  s
    .toLowerCase()
    .replace(/<[^>]+>/g, "")
    .replace(/&[a-z]+;/g, "")
    .replace(/[^a-z0-9 _-]/g, "")
    .trim()
    .replace(/\s+/g, "-");

type Heading = { level: number; text: string; id: string };

const wrapTables = (html: string) =>
  html.replace(/<table>[\s\S]*?<\/table>/g, (t) => `<div class="table-wrap">${t}</div>`);

const renderMarkdown = (md: string, pageId: string): { html: string; headings: Heading[] } => {
  const headings: Heading[] = [];
  const seen = new Map<string, number>();
  const marked = new Marked({ gfm: true, breaks: false });
  marked.use({
    renderer: {
      heading({ tokens, depth }: any) {
        const text = this.parser.parseInline(tokens);
        let id = slugify(text);
        const n = seen.get(id) ?? 0;
        seen.set(id, n + 1);
        if (n > 0) id = `${id}-${n}`;
        if (depth >= 2 && depth <= 3) headings.push({ level: depth, text, id });
        return `<h${depth} id="${id}">${text}<a class="anchor" href="#${id}" aria-hidden="true">#</a></h${depth}>\n`;
      },
      code({ text, lang }: any) {
        const cls = lang ? ` class="language-${escapeHtml(String(lang).split(/\s+/)[0])}"` : "";
        return `<pre><code${cls}>${escapeHtml(text)}\n</code></pre>\n`;
      },
    },
  });
  const html = wrapTables(marked.parse(md, { async: false }) as string);
  return { html, headings };
};

// ------------------------------------------------------ 5. content page loader

type Page = {
  id: string;
  title: string;
  label: string;
  md: string;
  html?: string;
  headings: Heading[];
  ids: Set<string>;
};

const frontMatter = (raw: string, file: string) => {
  const m = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?/.exec(raw);
  if (!m) fail(`${file}: missing front matter`);
  const meta: Record<string, string> = {};
  for (const line of m![1].split("\n")) {
    const kv = /^([A-Za-z_]+):\s*(.*)$/.exec(line.trim());
    if (kv) meta[kv[1]] = kv[2].replace(/^["']|["']$/g, "");
  }
  return { meta, body: raw.slice(m![0].length) };
};

const pages = new Map<string, Page>();

for (const child of flatNav) {
  if (child.module) continue; // generated below
  const file = join(root, "content", `${child.to}.md`);
  if (!existsSync(file)) fail(`config.json lists "${child.to}" but content/${child.to}.md is missing`);
  const { meta, body } = frontMatter(readFileSync(file, "utf8"), `content/${child.to}.md`);
  if (!meta.title) fail(`content/${child.to}.md: front matter has no title:`);
  if (!meta.id) fail(`content/${child.to}.md: front matter has no id:`);
  if (meta.id !== child.to) {
    fail(`content/${child.to}.md: front matter id "${meta.id}" does not match config.json "${child.to}"`);
  }
  pages.set(child.to, {
    id: child.to,
    title: meta.title,
    label: child.label,
    md: body,
    headings: [],
    ids: new Set(),
  });
}

// Check for orphaned markdown files.
const walk = (dir: string, prefix = ""): string[] =>
  readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory()
      ? walk(join(dir, e.name), `${prefix}${e.name}/`)
      : e.name.endsWith(".md")
        ? [`${prefix}${e.name.replace(/\.md$/, "")}`]
        : [],
  );
for (const id of walk(join(root, "content"))) {
  if (!navIds.has(id)) fail(`content/${id}.md is not listed in config.json`);
}

// ------------------------------------------------- 6. generated module pages

type DocEntry = { kind: "union" | "alias" | "value"; name: string; signature: string; comment: string };

const docsJson = JSON.parse(readFileSync(join(repo, "docs.json"), "utf8")) as any[];

const shortenType = (t: string) =>
  t
    .replace(/\bTable\.Internal\.Types\./g, "Table.")
    .replace(/\bBasics\./g, "")
    .replace(/\bString\.String\b/g, "String")
    .replace(/\bList\.List\b/g, "List")
    .replace(/\bMaybe\.Maybe\b/g, "Maybe")
    .replace(/\bDict\.Dict\b/g, "Dict")
    .replace(/\bSet\.Set\b/g, "Set")
    .replace(/\bArray\.Array\b/g, "Array")
    .replace(/\bTime\.Posix\b/g, "Time.Posix")
    .replace(/\bPlatform\.Cmd\.Cmd\b/g, "Cmd");

const moduleEntries = (mod: any): Map<string, DocEntry> => {
  const out = new Map<string, DocEntry>();
  for (const u of mod.unions) {
    const head = [u.name, ...u.args].join(" ");
    const cases = u.cases.map(
      ([name, args]: [string, string[]]) => `${name}${args.length ? " " + args.map(shortenType).join(" ") : ""}`,
    );
    const sig = cases.length ? `type ${head}\n    = ${cases.join("\n    | ")}` : `type ${head}`;
    out.set(u.name, { kind: "union", name: u.name, signature: sig, comment: u.comment });
  }
  for (const a of mod.aliases) {
    const head = [a.name, ...a.args].join(" ");
    out.set(a.name, {
      kind: "alias",
      name: a.name,
      signature: `type alias ${head} =\n    ${shortenType(a.type).replace(/\n/g, "\n    ")}`,
      comment: a.comment,
    });
  }
  for (const v of mod.values) {
    out.set(v.name, {
      kind: "value",
      name: v.name,
      signature: `${v.name} : ${shortenType(v.type)}`,
      comment: v.comment,
    });
  }
  return out;
};

const referenceCounts: { module: string; declared: number; rendered: number }[] = [];

const renderModulePage = (child: NavChild): Page => {
  const mod = docsJson.find((m) => m.name === child.module);
  if (!mod) fail(`docs.json has no module ${child.module}`);
  const entries = moduleEntries(mod);
  const declared = entries.size;
  const rendered = new Set<string>();

  const parts: string[] = [];
  const headings: Heading[] = [];
  const anchorIds = new Set<string>();
  const seen = new Map<string, number>();

  let prose: string[] = [];
  const flushProse = () => {
    const md = prose.join("\n").trim();
    prose = [];
    if (!md) return;
    const marked = new Marked({ gfm: true });
    marked.use({
      renderer: {
        heading({ tokens, depth }: any) {
          const text = this.parser.parseInline(tokens);
          let id = slugify(text);
          const n = seen.get(id) ?? 0;
          seen.set(id, n + 1);
          if (n > 0) id = `${id}-${n}`;
          anchorIds.add(id);
          const level = Math.min(depth + 1, 4);
          if (level <= 3) headings.push({ level, text, id });
          return `<h${level} id="${id}">${text}<a class="anchor" href="#${id}" aria-hidden="true">#</a></h${level}>\n`;
        },
      },
    });
    parts.push(`<div class="module-intro">${marked.parse(md, { async: false })}</div>`);
  };

  for (const line of String(mod.comment).split("\n")) {
    const m = /^@docs\s+(.*)$/.exec(line.trim());
    if (!m) {
      prose.push(line);
      continue;
    }
    flushProse();
    for (const raw of m[1].split(",")) {
      const name = raw.trim();
      if (!name) continue;
      const entry = entries.get(name);
      if (!entry) fail(`${child.module}: module comment @docs mentions "${name}", which docs.json does not expose`);
      rendered.add(name);
      anchorIds.add(name);
      const doc = new Marked({ gfm: true }).parse(String(entry!.comment).trim(), { async: false }) as string;
      parts.push(
        `<section class="decl" id="${name}">` +
          `<h3><a class="decl-name" href="#${name}">${name}</a></h3>` +
          `<pre><code class="language-elm">${escapeHtml(entry!.signature)}</code></pre>` +
          `<div class="decl-doc">${doc}</div>` +
          `</section>`,
      );
    }
  }
  flushProse();

  const missing = [...entries.keys()].filter((k) => !rendered.has(k));
  if (missing.length) {
    fail(`${child.module}: ${missing.length} exposed values are not in any @docs line: ${missing.join(", ")}`);
  }
  referenceCounts.push({ module: child.module!, declared, rendered: rendered.size });

  const header =
    `<p class="count-note">Generated from <code>docs.json</code>. ` +
    `${rendered.size} exposed values, types, and type aliases, in the order the module exposes them.</p>`;

  return {
    id: child.to,
    title: child.module!,
    label: child.label,
    md: "",
    html: header + parts.join("\n"),
    headings,
    ids: anchorIds,
  };
};

for (const section of config.sections) {
  for (const child of section.children) {
    if (child.module) pages.set(child.to, renderModulePage(child));
  }
}

// ------------------------------------------------------------ 7. render pages

const hrefFor = (fromId: string, toId: string, hash = "") => {
  const fromDir = dirname(join("/", fromId, "index.html"));
  const target = join("/", toId, "index.html");
  let rel = relative(fromDir, target);
  if (!rel.startsWith(".")) rel = `./${rel}`;
  return rel + hash;
};

const sidebarFor = (currentId: string) =>
  config.sections
    .map(
      (s) =>
        `<h2>${s.label}</h2><ul>` +
        s.children
          .map(
            (c) =>
              `<li><a href="${hrefFor(currentId, c.to)}"${c.to === currentId ? ' class="is-current"' : ""}>${c.label}</a></li>`,
          )
          .join("") +
        `</ul>`,
    )
    .join("");

const tocFor = (page: Page) =>
  page.headings.length
    ? `<h2>On this page</h2><ul>` +
      page.headings
        .map((h) => `<li class="lvl-${h.level}"><a href="#${h.id}">${h.text}</a></li>`)
        .join("") +
      `</ul>`
    : "";

const pagerFor = (id: string) => {
  const i = flatNav.findIndex((c) => c.to === id);
  const prev = i > 0 ? flatNav[i - 1] : null;
  const next = i >= 0 && i < flatNav.length - 1 ? flatNav[i + 1] : null;
  return (
    (prev ? `<a class="prev" href="${hrefFor(id, prev.to)}"><span>Previous</span>${prev.label}</a>` : "") +
    (next ? `<a class="next" href="${hrefFor(id, next.to)}"><span>Next</span>${next.label}</a>` : "")
  );
};

// Rewrite site-absolute links (/guide/sorting, /guide/sorting#state) to relative
// ones, and collect every internal link for the checker.
const links: { from: string; to: string; hash: string }[] = [];

const rewriteLinks = (html: string, fromId: string) =>
  html.replace(/(href|src)="\/([^"#]*)(#[^"]*)?"/g, (_m, attr, path, hash) => {
    const target = path.replace(/\/$/, "");
    links.push({ from: fromId, to: target, hash: (hash ?? "").replace(/^#/, "") });
    return `${attr}="${hrefFor(fromId, target, hash ?? "")}"`;
  });

const collectIds = (html: string, into: Set<string>) => {
  for (const m of html.matchAll(/\sid="([^"]+)"/g)) into.add(m[1]);
};

rmSync(dist, { recursive: true, force: true });
mkdirSync(dist, { recursive: true });
writeFileSync(join(dist, "style.css"), css);

// First pass: markdown -> html (snippets inlined), collect anchors.
for (const page of pages.values()) {
  if (page.html !== undefined) {
    collectIds(page.html, page.ids);
    continue;
  }
  const withSnippets = page.md.replace(
    /```elm\s+snippet=([^\s`]+)\s*\n[\s\S]*?```/g,
    (_m, spec) => "```elm\n" + resolveSnippet(spec, `content/${page.id}.md`) + "\n```",
  );
  const { html, headings } = renderMarkdown(withSnippets, page.id);
  page.html = html;
  page.headings = headings;
  collectIds(html, page.ids);
}

// Second pass: layout + link rewrite.
for (const page of pages.values()) {
  const body = rewriteLinks(page.html!, page.id);
  const out = layout
    .replace(/\{\{title\}\}/g, escapeHtml(page.title))
    .replace(/\{\{cssHref\}\}/g, hrefFor(page.id, "").replace(/index\.html$/, "style.css"))
    .replace(/\{\{homeHref\}\}/g, hrefFor(page.id, "overview"))
    .replace(/\{\{examplesHref\}\}/g, hrefFor(page.id, "examples"))
    .replace(/\{\{sidebar\}\}/g, sidebarFor(page.id))
    .replace(/\{\{toc\}\}/g, tocFor(page))
    .replace(/\{\{pager\}\}/g, pagerFor(page.id))
    .replace(/\{\{content\}\}/g, body);
  const dir = join(dist, page.id);
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, "index.html"), out);
}

// Root index redirects to the overview.
writeFileSync(
  join(dist, "index.html"),
  `<!doctype html><html lang="en"><head><meta charset="utf-8">` +
    `<meta http-equiv="refresh" content="0; url=./overview/"><title>elm-table docs</title></head>` +
    `<body><p><a href="./overview/">elm-table documentation</a></p></body></html>\n`,
);

// ------------------------------------------------------------ 8. link checker

const problems: string[] = [];
for (const link of links) {
  const target = pages.get(link.to);
  if (!target) {
    problems.push(`${link.from}: link to /${link.to} — no such page`);
    continue;
  }
  if (link.hash && !target.ids.has(link.hash)) {
    problems.push(`${link.from}: link to /${link.to}#${link.hash} — no such anchor on that page`);
  }
}
// Same-page anchors.
for (const page of pages.values()) {
  for (const m of page.html!.matchAll(/href="#([^"]+)"/g)) {
    if (!page.ids.has(m[1])) problems.push(`${page.id}: link to #${m[1]} — no such anchor on this page`);
  }
}
if (problems.length) fail(`${problems.length} broken internal link(s)\n    ${problems.join("\n    ")}`);

// ------------------------------------------------------------------ 9. report

const declaredTotal = referenceCounts.reduce((a, r) => a + r.declared, 0);
const renderedTotal = referenceCounts.reduce((a, r) => a + r.rendered, 0);
const unusedDecls = [...snippetSource.entries()].flatMap(([f, d]) =>
  [...d.keys()].filter((n) => !usedDecls.has(`${f}#${n}`)).map((n) => `${f}#${n}`),
);

console.log(`  ${pages.size} pages written to dist/`);
console.log(`  ${snippetUses} snippet blocks inlined from ${usedDecls.size} declarations`);
for (const r of referenceCounts) console.log(`  reference ${r.module}: ${r.rendered}/${r.declared} entries`);
console.log(`  reference total: ${renderedTotal}/${declaredTotal} entries`);
console.log(`  ${links.length} internal links checked, 0 broken`);
if (unusedDecls.length) console.log(`  note: ${unusedDecls.length} snippet declarations are not referenced`);
