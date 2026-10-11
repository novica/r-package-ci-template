# r-package-ci-template

CI, release and citation setup for R packages on GitHub, extracted from
[ParBayesianOptimization](https://github.com/novica/ParBayesianOptimization)
and [shinyds](https://github.com/novica/shinyds).

What it sets up:

- **R CMD check** on every PR with `--as-cran` on macOS, Windows and Ubuntu
  (release and oldrel-1), gated on [air](https://posit-dev.github.io/air/)
  formatting and [jarl](https://jarl.etiennebacher.com) linting. R-devel runs
  weekly and on demand.
- **Test coverage** to Codecov on every push to `main`.
- **pkgdown site** deployed to GitHub Pages on every push to `main`.
- **Releases with [release-please](https://github.com/googleapis/release-please)**:
  Conventional Commit PR titles become `CHANGELOG.md`, `NEWS.md`, the version
  bump in `DESCRIPTION` and `CITATION.cff`, a git tag and a GitHub release.
- **PR title check** so every squash commit is a valid Conventional Commit.
- **Citation files**: `inst/CITATION` built from `DESCRIPTION`, and
  `CITATION.cff` for GitHub's "Cite this repository" button.
- **Contributor files**: issue forms, a PR template with an AI-use
  disclosure, a contributing guide, `CODEOWNERS` and Dependabot for actions.

## Use

```sh
git clone https://github.com/novica/r-package-ci-template
./r-package-ci-template/apply.sh path/to/your/package
```

`apply.sh` reads the package name and version from `DESCRIPTION` and
`owner/repo` from the `origin` remote (or pass it as the second argument).
It copies everything in [`template/`](template/), fills in the placeholders,
generates `CITATION.cff` from `DESCRIPTION` and adds the new files to
`.Rbuildignore`. It never overwrites an existing file; skipped files are
listed so you can compare them with `template/` by hand.

The files live in `template/` and are applied with `apply.sh` rather than
GitHub's "Use this template" button, because the setup usually goes into a
package that already exists, and some files (`CITATION.cff`, the manifest)
depend on its `DESCRIPTION`.

Then, in the package:

1. In `_pkgdown.yml`, set `url:` to the GitHub Pages address and
   `development: mode: release`.
2. Check `CITATION.cff` (license, abstract) and `inst/CITATION`.
3. Set `Version` in `DESCRIPTION` to the last released version, without a
   `.9000` suffix, and make sure `.release-please-manifest.json` matches.
4. If a dependency is not on CRAN (for example INLA), uncomment
   `extra-repositories` in the three R workflows and add an
   `Additional_repositories:` field to `DESCRIPTION`.
5. Once the package is on CRAN, add the CRAN DOI
   (`10.32614/CRAN.package.<name>`) to `inst/CITATION`, `CITATION.cff` and a
   README badge.

## Repository settings

These are not files, so `apply.sh` can't set them:

- **General → Pull Requests:** allow only **squash merging**, with the
  default commit message set to the PR title. release-please reads the
  squash commit subject, and `BEGIN_COMMIT_OVERRIDE` only works for
  squash merges.
- **Actions → General → Workflow permissions:** allow GitHub Actions to
  create and approve pull requests, so release-please can open its PR.
- **Pages:** set the source to **GitHub Actions**.
- **Secrets:** add `CODECOV_TOKEN` from codecov.io.

## Releasing

- Every merge to `main` updates the open release PR. Merging that PR tags
  the release and creates the GitHub release from the PR description.
- The release PR can stay open to collect fixes. Only `fix:` and `docs:`
  keep it a patch release; a `feat:` turns it into a minor release.
- To fix changelog wording after the fact, add a
  `BEGIN_COMMIT_OVERRIDE` / `END_COMMIT_OVERRIDE` block to the description
  of the merged PR. It takes effect on the next push to `main`. Overrides
  replace the whole message, so repeat `(#NN)` and `Closes #NN` if you want
  the links.
- Don't hand-edit the release PR branch: release-please rebuilds it on
  every push to `main`. If you must, do it right before merging. The one
  exception is `NEWS.md`: the workflow only adds a version section when
  it isn't there yet, so a hand-written section committed to `main`
  survives.
- Never move a published tag. If something needs fixing after a GitHub
  release, release the next patch version. CRAN doesn't need consecutive
  versions, so the patch release can go to CRAN instead.
- CRAN asks for a gap between submissions. Hold the release PR open until
  you are ready to submit, then merge it and submit from `main`.

## Why it looks like this

Things the setup gets right that were wrong at first:

- **Path filters have no stray spaces.** A pattern like `"*.json "` matches
  nothing.
- **R CMD check still runs when workflows change.** It ignores issue and PR
  templates under `.github/`, but not `.github/workflows/`, so a CI change
  is tested on its own PR.
- **pkgdown has no path filter.** `README.md` and `NEWS.md` are the home
  and news pages, so ignoring `*.md` left the site stale.
- **pkgdown builds once, in release mode.** release-please versions never
  carry `.9000`, so a separate dev build only duplicated the site at
  `/dev/`.
- **No `release: published` trigger.** Releases created with the default
  `GITHUB_TOKEN` don't trigger other workflows, so it never ran.
- **R-devel stays out of PRs.** It has no binary packages and compiles
  every dependency.
- **Windows builds without vignettes.** Quarto can't load the package
  while `R CMD build` renders vignettes on Windows; `R CMD check` still
  rebuilds them.
- **`setup-jarl` already runs `jarl check`.** Running it again in a
  separate step lints twice.
- **Concurrency on every workflow.** Checks cancel superseded runs.
  release-please queues instead of cancelling, so a run never stops
  halfway through pushing to the release PR branch.
- **Citations list authors in `DESCRIPTION` order.** Put the original
  author first; the maintainer is taken from the `cre` role wherever it
  appears. R's automatic citation lists only `aut` people, so a maintainer
  without `aut` drops out.
