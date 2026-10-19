# r-package-ci-template

CI, release and citation setup for R packages on GitHub, extracted from
[ParBayesianOptimization](https://github.com/novica/ParBayesianOptimization)
and [shinyds](https://github.com/novica/shinyds), and applied to
[ggindex](https://github.com/discindo/ggindex).

What it sets up:

- **R CMD check** on every PR and after each merge to `main` (for the
  README badge), with `--as-cran` on macOS, Windows and Ubuntu (release
  and oldrel-1), gated on [air](https://posit-dev.github.io/air/)
  formatting and [jarl](https://jarl.etiennebacher.com) linting. Only errors
  fail the check; warnings and notes show in the log. Windows skips
  vignettes, since Quarto can't load the package during `R CMD build`
  there. R-devel has no binary
  packages and compiles every dependency, so it stays out of PRs and runs
  weekly and on demand. So does a check without `Suggests` installed,
  which CRAN sometimes runs: examples and tests that use a suggested
  package must be guarded (`@examplesIf rlang::is_installed("pkg")`,
  `testthat::skip_if_not_installed("pkg")`).
- **Test coverage** to Codecov on every push to `main`.
- **pkgdown site** deployed to GitHub Pages on every push to `main`.
- **Releases with [release-please](https://github.com/googleapis/release-please)**:
  Conventional Commit PR titles become `CHANGELOG.md`, `NEWS.md`, the version
  bump in `DESCRIPTION` and `CITATION.cff`, a git tag and a GitHub release.
- **PR title check** so every squash commit is a valid Conventional Commit.
- **Citation files**: `inst/CITATION` built from `DESCRIPTION`, and
  `CITATION.cff` for GitHub's "Cite this repository" button, validated
  with [cffconvert](https://github.com/citation-file-format/cffconvert)
  whenever it changes.
- **Contributor files**: issue forms, a PR template with an AI-use
  disclosure, a contributing guide, `CODEOWNERS` and Dependabot for actions.

The repository is a minimal working package with all of this in place. Use
it as a GitHub template for a new package, or apply the CI files to an
existing one.

## Start a new package

1. Click **Use this template** → **Create a new repository**. Name the
   repository after the package (letters, digits and dots only).
2. Clone it and run the setup script once:

   ```sh
   git clone git@github.com:<you>/<package>.git
   cd <package>
   tools/setup.sh                      # or: tools/setup.sh <package> <orcid>
   ```

   It fills in the package name, repository, site URL and your name and
   email (from `git config`), adds your ORCID if given, writes
   `CITATION.cff` and `README.md`, and removes `tools/`.
3. Write the `Title` and `Description` in `DESCRIPTION` (and in
   `CITATION.cff`), replace `R/hello.R` with your code, and commit.
4. Set up the [repository settings](#repository-settings).

The package starts at version 0.0.0, and its first release is 0.1.0. After
that release, remove `"release-as"` from `release-please-config.json`.

On this template repository, the package jobs (R CMD check, coverage,
pkgdown, release-please) are skipped by lines marked `# template-only`,
since they would run against the placeholders. Instead, `template-ci.yml`
lints the workflows and runs `tools/setup.sh` on a copy, then checks the
result. `tools/setup.sh` and `tools/apply.sh` remove the marked lines and
`template-ci.yml`.

## Add to an existing package

```sh
git clone https://github.com/novica/r-package-ci-template
r-package-ci-template/tools/apply.sh path/to/package
```

`apply.sh` copies only the CI, release and citation files, never the
package skeleton. It reads the package name and version from `DESCRIPTION`
and `owner/repo` from the `origin` remote (or pass it as the second
argument), generates `CITATION.cff` from `DESCRIPTION` and adds the new
files to `.Rbuildignore`. The workflows trigger on the repository's
default branch instead of `main`. It never overwrites an existing file,
and a workflow already present as `.yaml` counts as existing; skipped
files are listed so you can compare them by hand.

The version in `DESCRIPTION` is taken as the last release. For a package
that has never been released, pass `--unreleased`: release-please then
starts at 0.0.0 and the first release is 0.1.0. After that release,
remove `"release-as"` from `release-please-config.json`.

Then, in the package:

1. If it already had `_pkgdown.yml`, set `url:` to the GitHub Pages
   address and `development: mode: release`.
2. Check `CITATION.cff` (license, abstract) and `inst/CITATION`.
3. Run `air format .` and `jarl check .`: R CMD check waits for both.
4. If a dependency is not on CRAN (for example INLA), uncomment
   `extra-repositories` in the three R workflows and add an
   `Additional_repositories:` field to `DESCRIPTION`.

## After the first CRAN release

Add the CRAN DOI (`10.32614/CRAN.package.<name>`) to `inst/CITATION`,
`CITATION.cff` and a README badge.

## Repository settings

These are not files, so the scripts can't set them:

- **Rules → Rulesets:** protect `main`. Require a pull request before
  merging, and require the **Validate PR title** status check. Don't make
  the R CMD check jobs required: they skip PRs that only touch
  documentation, and a required check that never starts blocks the merge.
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
