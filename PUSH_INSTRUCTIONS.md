# Push Instructions — Aftermap v0.1.0 (P1 spike)

This document is the **single source of truth** for pushing the P0/P1 spike
to GitHub. Run these steps **in order** from the repository root after
Stage 7 lands.

## What's in the bundle

- **Repo:** `zymalpha/aftermap` (private — confirm with the owner before
  marking public).
- **Branch:** `main`.
- **Head:** see `git rev-parse HEAD` at the bottom of this file. The bundle
  includes all 8 commits in the linear history from `97f64fc` (init) to
  the Stage 7 commit.
- **Bundle file:** `aftermap-p1.bundle` (single file, `git bundle create
  --all`, SHA-256 in the footer).

The bundle is verified (`git bundle verify aftermap-p1.bundle` -> `is okay`).
Bundle size and SHA-256 are in the footer for cross-checking.

## Option A — Push the bundle into a fresh clone (recommended for transfers)

Use this when handing the artifact to a partner machine, a CI seed, or a
new contributor who should not see your local branch state beyond the
spike.

```bash
# 1. Clone the bundle into a brand-new repo
git clone aftermap-p1.bundle aftermap-fresh
cd aftermap-fresh
git log --oneline          # confirm 8 commits ending in the Stage 7 head
git status                 # must be clean

# 2. Add the GitHub remote (replace owner if not zymalpha)
git remote add origin git@github.com:zymalpha/aftermap.git

# 3. Push main
git push -u origin main
```

If the GitHub repo already has commits you want to keep, replace step 3
with a force-push **only after** confirming with the repo owner:

```bash
git push -u origin main --force-with-lease
```

## Option B — Push from this working tree directly

Use this when you have credentials for `zymalpha/aftermap` already set up
on this machine.

```bash
# 1. Add the remote (idempotent)
git remote remove origin 2>/dev/null || true
git remote add origin git@github.com:zymalpha/aftermap.git

# 2. Confirm the remote points where you expect
git remote -v

# 3. Push main
git push -u origin main
```

If `git push` complains about the remote existing with conflicting
history, stop and switch to Option A — that path is safer for a first
release of a fresh repo.

## Tagging the v0.1.0 release

```bash
git tag -a aftermap-p1 -m "P0/P1 spike complete: 166 PASS / 0 FAIL (2026-07-22)"
git push origin aftermap-p1
```

The annotated tag `aftermap-p1` matches the bundle filename and gives
reviewers a stable handle.

## Post-push verification

```bash
# On a different machine, fetch the bundle again to triple-check
git clone aftermap-p1.bundle aftermap-recheck
cd aftermap-recheck
git log --oneline | head -10
bash run.sh    # or run.bat on Windows
```

Expected: `=== 完成 ===` and zero `WARN: ... exit non-zero` lines (with
Godot installed), or exactly one `WARN: Godot 未安装...` line (without
Godot).

## Rollback

If the push was wrong:

```bash
# Delete the remote tag and branch (be careful — this is destructive)
git push origin :aftermap-p1
git push origin :main
```

Then re-create from the local bundle as in Option A.

---

## Footer — bundle identity (do not edit)

| Field            | Value                                                                  |
| ---------------- | ---------------------------------------------------------------------- |
| Bundle file      | `aftermap-p1.bundle` (working-tree artifact, not tracked)              |
| Bundle size      | 221,417 bytes                                                          |
| Bundle SHA-256   | `79a1ca7882a83100d83ae0c4986acc4e28f3f70455163913b7a8c3cfdc05373f`     |
| Local HEAD       | `1e34cda010c120e38e30f7284d06d9602ca69d87`                              |
| Refs included    | `refs/heads/main`, `HEAD` (both pointing at `1e34cda`)                  |
| Commit count     | 8 (`git rev-list --count main`)                                        |