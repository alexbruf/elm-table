// Builds the examples site into dist/.
//
//   bun run build.ts            build every example listed in examples.json
//   bun run build.ts sorting    build one example by slug
//   bun run build.ts --dev      skip --optimize and terser
//
// For each example: elm make src/<Module>.elm -> dist/<slug>/elm.js, then a
// page from shared/example.html with the demo, the Elm source, and a link to
// the TanStack example it ports. dist/index.html lists every built example.

import { $ } from "bun";
import { existsSync, mkdirSync, readFileSync, writeFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

const root = import.meta.dir;
const args = process.argv.slice(2);
const dev = args.includes("--dev");
const only = args.filter((a) => !a.startsWith("--"));

const manifest = JSON.parse(readFileSync(join(root, "examples.json"), "utf8"));
const template = readFileSync(join(root, "shared/example.html"), "utf8");
const indexTemplate = readFileSync(join(root, "shared/index.html"), "utf8");
const css = readFileSync(join(root, "shared/style.css"), "utf8");
const tanstackBase = "https://github.com/TanStack/table/tree/main/";

const escapeHtml = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

const fill = (tpl: string, vars: Record<string, string>) =>
  tpl.replace(/\{\{(\w+)\}\}/g, (_, k) => vars[k] ?? "");

const terserArgs = [
  "--compress",
  "pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe",
  "--mangle",
];

type Example = { slug: string; module: string; title: string; tanstack: string; description: string; flags?: boolean };
const built: { group: string; ex: Example }[] = [];
const missing: string[] = [];
let failed = 0;

for (const group of manifest.groups) {
  for (const ex of group.examples as Example[]) {
    if (only.length && !only.includes(ex.slug)) continue;
    const src = join(root, "src", `${ex.module}.elm`);
    if (!existsSync(src)) {
      missing.push(ex.slug);
      continue;
    }
    const outDir = join(root, "dist", ex.slug);
    mkdirSync(outDir, { recursive: true });
    const js = join(outDir, "elm.js");
    const make = dev
      ? $`elm make src/${ex.module}.elm --output=${js}`.cwd(root).quiet()
      : $`elm make src/${ex.module}.elm --optimize --output=${js}`.cwd(root).quiet();
    const res = await make.nothrow();
    if (res.exitCode !== 0) {
      failed++;
      console.error(`FAILED ${ex.slug}\n${res.stderr.toString()}`);
      continue;
    }
    if (!dev) {
      await $`bunx terser ${js} ${terserArgs} --output ${js}`.cwd(root).quiet();
    }

    // Source tab: the entry module plus any modules under src/<Module>/.
    const sources: { name: string; code: string }[] = [
      { name: `${ex.module}.elm`, code: readFileSync(src, "utf8") },
    ];
    const extraDir = join(root, "src", ex.module);
    if (existsSync(extraDir)) {
      for (const f of readdirSync(extraDir).sort()) {
        if (f.endsWith(".elm")) {
          sources.push({ name: `${ex.module}/${f}`, code: readFileSync(join(extraDir, f), "utf8") });
        }
      }
    }
    const exampleCssPath = join(root, "src", `${ex.module}.css`);
    const exampleCss = existsSync(exampleCssPath) ? readFileSync(exampleCssPath, "utf8") : "";

    const sourceHtml = sources
      .map(
        (s) =>
          `<details${s === sources[0] ? " open" : ""}><summary>${escapeHtml(s.name)}</summary><pre><code>${escapeHtml(s.code)}</code></pre></details>`,
      )
      .join("\n");

    const initFlags = ex.flags ? `, flags: { now: Date.now(), seed: 42 }` : "";
    const html = fill(template, {
      title: ex.title,
      description: ex.description,
      slug: ex.slug,
      module: ex.module,
      css: css + "\n" + exampleCss,
      source: sourceHtml,
      tanstackUrl: tanstackBase + ex.tanstack,
      tanstackPath: ex.tanstack,
      initFlags,
    });
    writeFileSync(join(outDir, "index.html"), html);
    built.push({ group: group.label, ex });
    console.log(`built ${ex.slug}`);
  }
}

// Index page over everything that has a built page (not just this run).
const listing = manifest.groups
  .map((g: any) => {
    const items = (g.examples as Example[])
      .filter((ex) => existsSync(join(root, "dist", ex.slug, "index.html")))
      .map(
        (ex) =>
          `<li><a href="${ex.slug}/">${escapeHtml(ex.title)}</a><span>${escapeHtml(ex.description)}</span></li>`,
      )
      .join("\n");
    return items ? `<section><h2>${escapeHtml(g.label)}</h2><ul>${items}</ul></section>` : "";
  })
  .join("\n");
mkdirSync(join(root, "dist"), { recursive: true });
writeFileSync(join(root, "dist/index.html"), fill(indexTemplate, { css, listing }));

console.log(`\n${built.length} built, ${failed} failed, ${missing.length} not yet written${missing.length ? ": " + missing.join(", ") : ""}`);
if (failed) process.exit(1);
