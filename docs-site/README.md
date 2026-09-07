# docs-site

The documentation site for `viewengine/elm-table`, deployed to Cloudflare
Pages as <https://elm-table-docs.pages.dev>.

It mirrors the [TanStack Table docs site](https://tanstack.com/table) in
structure, page names, and section order, with every page rewritten for the
Elm API.

## Layout

```
config.json      the navigation; every page must be listed here
content/**.md    one Markdown file per page, front matter `title:` and `id:`
snippets/        an Elm application holding every code snippet shown in the docs
build.ts         Markdown -> HTML, sidebar, prev/next, generated API reference, link check
shared/          layout.html and style.css
deploy.sh        wrangler pages deploy dist --project-name elm-table-docs
```

## Commands

```
make dist     full build into dist/
make dev      same, skipping the two `elm make` runs
make serve    build, then serve dist/ on http://localhost:8099
make deploy   build, then publish to Cloudflare Pages
make clean    remove dist/ and elm-stuff/
```

`make dist` does five things in order, and fails on any of them:

1. `elm make --docs=docs.json` in the repository root.
2. `elm make src/*.elm` in `snippets/`, so every code snippet in the docs
   compiles against the real package.
3. Renders `content/**.md`, inlining snippets.
4. Generates one page per exposed module from `docs.json`, rendering every
   `@docs` entry of the module comment in the module's own order. The build
   fails if a `@docs` line names something `docs.json` does not expose, or if
   an exposed value appears in no `@docs` line.
5. Checks every internal link. A link to a page that does not exist, or to an
   anchor that page does not have, fails the build.

## Snippets

A code block in Markdown written like this:

    ```elm snippet=Sorting.elm#sortableColumns
    ```

is replaced at build time by the top-level declaration `sortableColumns` from
`snippets/src/Sorting.elm` — from its type annotation line through the end of
the declaration. Because the whole `snippets/` project is compiled first, every
such block is known to compile against the current package.

`snippets/elm.json` has `source-directories` of `["src", "../../src"]`, so the
snippets build against the working tree rather than a published version.

A plain ` ```elm ` block with no `snippet=` is allowed only for a fragment that
cannot compile on its own: a bare type signature, a record literal shown as
data, or an excerpt.

`snippets/src/Shared/People.elm` holds the fixture the snippets share. It is not
itself a snippet source.

## Adding a page

1. Add it to `config.json`, in the section and position it belongs in.
2. Write `content/<id>.md` with front matter whose `id:` matches.
3. Add any code to a module in `snippets/src/` and reference it with
   `snippet=`.
4. `make dist`.

## Writing rules

The prose follows `reports/design-rules.md` in the repository root: plain
language, no marketing, and none of the banned words listed there. Check with:

```
./banned.sh
```
