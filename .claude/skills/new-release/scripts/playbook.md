# new-release playbook


# new-release

Build, tag, and publish GitHub release with binaries.

## Prerequisites

Read project rules (`CLAUDE.md`, first found).

- Clean git state
- `gh` CLI authenticated
- `make build-all` target exists

## Input

```bash
/new-release v1.2.3
```

`$VERSION`: Version string (with or without `v` prefix).

## Workflow

```bash
INPUT=$(cat)
VERSION="${INPUT#v}"
[ -z "$VERSION" ] && read -p "Version: " VERSION

[ -n "$(git status --short)" ] && { echo "Uncommitted changes"; exit 1; }

make build-all
git tag -a "v$VERSION" -m "Release v$VERSION"
git push origin "v$VERSION"
gh release create "v$VERSION" --title "v$VERSION" --notes "Release v$VERSION" dist/agents-sync-*
```

## Exit Criteria

- [ ] Project rules read (if exists)
- [ ] Binaries in `dist/`
- [ ] Tag on origin
- [ ] Release at `https://github.com/{owner}/{repo}/releases/tag/v{version}`
