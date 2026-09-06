# elm-table

Headless table state and row-model pipeline for Elm 0.19.1. A port of
[TanStack Table](https://github.com/TanStack/table) core as pure functions.

The package renders nothing. You keep the `State`, feed it and your data
through the pipeline, and draw whatever you like from the resulting row model.

Status: in progress. See `SPEC.md` for the plan and `PORT_NOTES.md` for the
coverage table.

## Development

```
make check   # elm-format --validate, elm-review, elm-test
make test
make docs
```

Deploying the demo needs Cloudflare credentials in a local env file; copy
`.env.example` and fill it in.
