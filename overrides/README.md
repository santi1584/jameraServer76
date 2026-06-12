# Overrides

Customizations to the server live here as **full-file copies**, so the
upstream trees (`source 7.6/` and `data/`) stay pristine. The Docker build
overlays this folder on top of them right before compiling:

- `overrides/source/<path>` replaces `source 7.6/<path>` in the build
- `overrides/data/<path>` replaces `data/<path>` in the image

`ls -R overrides/` is therefore the complete list of everything customized,
and deleting a file here fully reverts that customization on the next build.

## Workflow

1. Copy the file you want to change into the matching path here, creating
   subdirectories as needed (git only tracks the top-level folders), e.g.:

   ```
   mkdir -p overrides/source
   cp "source 7.6/player.h" overrides/source/player.h
   ```

2. Edit the copy in `overrides/`, never the original.
3. Rebuild: `cd docker && ./build.sh`. The build log starts with one
   `override(source): ...` / `override(data): ...` line per active override,
   so every image documents what went into it.
4. To revert an experiment, delete the override file and rebuild.

## Seeing what you changed

```
./overrides/diff.sh
```

prints a unified diff of every override against its upstream counterpart —
the full picture of your customizations in one command. It also flags
overrides that are identical to upstream (dead weight you can delete) and
files with no upstream counterpart (new files).

## Rules and limitations

- **Once a file is overridden, treat the upstream copy as read-only.** If you
  edit the original of an overridden file, the override silently wins in the
  build and your edit never ships. `diff.sh` makes such drift visible.
- Granularity is whole files: you carry the entire file, not just your edit.
- **Adding a brand-new `.cpp` file** also requires overriding
  `source 7.6/Makefile.am` (the build only compiles files listed there).
  New headers need no Makefile change.
- The overlay happens in the Docker build only. If you build outside Docker,
  the overrides are not applied.
