// One-off (but harmless to keep) recovery script.
//
// Six hand-written pages under content/reference/ were lost before commit
// (a .gitignore accident). The deployed site at elm-table-docs.pages.dev
// still serves the built HTML for them, so this script fetches each live
// page, extracts the rendered content out of `<article class="prose">`,
// converts it back to the Markdown shape build.ts expects (see build.ts:
// front matter with title/id, site-absolute internal links, plain tables,
// heading text with no anchor chrome), and writes content/reference/<slug>.md.
//
//   bun run scripts/recover.ts
//
// Safe to re-run: it always re-fetches and overwrites the target files.

import TurndownService from "turndown";
import { gfm } from "turndown-plugin-gfm";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join, posix } from "node:path";

const root = import.meta.dir + "/..";
const base = "https://elm-table-docs.pages.dev";

// slug -> front-matter title (matches config.json's nav label for the page,
// and the <h1> text on the live page).
const pages: { slug: string; title: string }[] = [
  { slug: "reference/table-api", title: "Table API" },
  { slug: "reference/column-api", title: "Column API" },
  { slug: "reference/row-api", title: "Row API" },
  { slug: "reference/cell-api", title: "Cell API" },
  { slug: "reference/header-api", title: "Header API" },
  { slug: "reference/features-api", title: "Features API" },
];

// Resolve a href found on `pageId`'s live page (relative to
// /<pageId>/index.html) back to the site-absolute, extension-less form the
// Markdown sources use (e.g. "/reference/module/Table#Config",
// "/guide/sorting"). External links pass through unchanged.
const toSitePath = (href: string, pageId: string): string => {
  if (/^https?:\/\//.test(href) || href.startsWith("#")) return href;
  const [path, hash] = href.split("#");
  const dir = posix.dirname(posix.join("/", pageId, "index.html"));
  let resolved = path ? posix.normalize(posix.join(dir, path)) : dir;
  resolved = resolved.replace(/\/index\.html$/, "");
  if (resolved === "") resolved = "/";
  return resolved + (hash ? `#${hash}` : "");
};

const turndown = new TurndownService({
  headingStyle: "atx",
  bulletListMarker: "-",
  codeBlockStyle: "fenced",
});
turndown.use(gfm);

for (const { slug, title } of pages) {
  const url = `${base}/${slug}/`;
  console.log(`fetching ${url}`);
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${url}: HTTP ${res.status}`);
  const html = await res.text();

  const articleMatch = /<article class="prose">([\s\S]*?)<\/article>/.exec(html);
  if (!articleMatch) throw new Error(`${slug}: no <article class="prose"> found`);
  let content = articleMatch[1];

  // The page <h1> is the layout's title chrome, not part of the Markdown
  // body (build.ts injects it separately from front matter `title:`).
  content = content.replace(/^\s*<h1>[\s\S]*?<\/h1>/, "");

  // Strip the auto-generated "#" permalink build.ts appends to every
  // heading; it is regenerated from the slugified heading text on rebuild.
  content = content.replace(/\s*<a class="anchor" href="#[^"]*" aria-hidden="true">#<\/a>/g, "");

  // Unwrap the <div class="table-wrap"> build.ts adds around every <table>.
  content = content.replace(/<div class="table-wrap">([\s\S]*?)<\/div>/g, "$1");

  // Rewrite relative hrefs back to the site-absolute form used in content/.
  content = content.replace(/href="([^"]*)"/g, (_m, href) => `href="${toSitePath(href, slug)}"`);

  // turndown-plugin-gfm's table-cell rule does not escape literal "|"
  // characters (e.g. from a union-type code span like `'start' | 'end'`),
  // which would otherwise split a GFM table row into extra columns. Escape
  // them with a placeholder before conversion and restore as "\|" after,
  // matching the convention already used in content/migrating.md.
  const PIPE = "PIPE";
  content = content.replace(/<t[dh][^>]*>[\s\S]*?<\/t[dh]>/g, (cellHtml) => cellHtml.replace(/\|/g, PIPE));

  const md = turndown.turndown(content).replaceAll(PIPE, "\\|").trim();

  const out = `---\ntitle: ${title}\nid: ${slug}\n---\n\n${md}\n`;
  const file = join(root, "content", `${slug}.md`);
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, out);
  console.log(`  wrote content/${slug}.md (${out.split("\n").length} lines)`);
}
