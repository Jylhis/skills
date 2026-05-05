# Restore from this backup

This directory was created by `scripts/install.bash` when it migrated your
existing `~/.claude/` content into the jstack repo.

## Roll back the plugins migration

```bash
rm ~/.claude/plugins
mv "$(dirname "$0")" ~/.claude/plugins
```

## Roll back individual files

For each file in this backup directory (e.g. `settings.json`, `CLAUDE.md`):

```bash
rm ~/.claude/<file>
cp -a "$(dirname "$0")/<file>" ~/.claude/<file>
```

## See also

- `nix-origins.txt` (in the backup root) records the nix-store paths that
  symlinks pointed at before they were replaced. Useful for re-enabling the
  home-manager module that previously managed those files.
