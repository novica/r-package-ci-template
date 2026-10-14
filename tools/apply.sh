#!/usr/bin/env bash
# Copy the CI, release and citation setup into an existing R package.
#
# Usage: tools/apply.sh [--unreleased] /path/to/package [owner/repo]
#
# --unreleased  The package has no release yet: start release-please at
#               0.0.0 and make the first release 0.1.0. Without it, the
#               version in DESCRIPTION is taken as the last release.
#
# Existing files are never overwritten; they are listed as skipped so you
# can compare them with the template by hand. owner/repo defaults to the
# package's GitHub "origin" remote.
set -euo pipefail

unreleased=false
if [ "${1:-}" = "--unreleased" ]; then unreleased=true; shift; fi

src="$(cd "$(dirname "$0")/.." && pwd)"
# pwd -W (Git Bash) gives C:/... paths, which Windows R can open when the
# path is embedded in R code below; plain pwd elsewhere.
pkg="$(cd "${1:?usage: tools/apply.sh [--unreleased] /path/to/package [owner/repo]}" && { pwd -W 2>/dev/null || pwd; })"
[ -f "$pkg/DESCRIPTION" ] || { echo "No DESCRIPTION in $pkg" >&2; exit 1; }

field() { Rscript -e "cat(read.dcf('$pkg/DESCRIPTION', fields = '$1')[[1]])"; }
package="$(field Package)"
version="$(field Version)"

repo="${2:-}"
if [ -z "$repo" ]; then
  url="$(git -C "$pkg" remote get-url origin 2>/dev/null || true)"
  repo="$(echo "$url" | sed -E 's#^(git@github.com:|https://github.com/)##; s#\.git$##')"
fi
[[ "$repo" == */* ]] || { echo "Pass owner/repo; could not read it from git." >&2; exit 1; }
owner="${repo%%/*}"
site_url="https://${owner}.github.io/${repo#*/}/"

echo "Package: $package $version, repo: $repo"

# The CI, release and citation files. The rest of the template (DESCRIPTION,
# R/, tests/, README, ...) is the skeleton for new packages.
files=(
  $(cd "$src" && find .github -type f ! -name template-ci.yml | sort)
  .gitattributes air.toml jarl.toml codecov.yml release-please-config.json
  inst/CITATION
)

copied=(); skipped=()
copy() {
  local rel="$1" dest="$pkg/$1"
  if [ -e "$dest" ]; then skipped+=("$rel"); return; fi
  mkdir -p "$(dirname "$dest")"
  sed -e "s#{{ *package *}}#$package#g" -e "s#{{ *repo *}}#$repo#g" \
      -e "s#{{ *owner *}}#$owner#g" -e "s#{{ *site_url *}}#$site_url#g" \
      -e '/# template-only$/d' "$src/$rel" > "$dest"
  copied+=("$rel")
}
for f in "${files[@]}"; do copy "$f"; done

if [ -e "$pkg/_pkgdown.yml" ] || [ -e "$pkg/pkgdown/_pkgdown.yml" ]; then
  skipped+=("_pkgdown.yml")
else
  copy _pkgdown.yml
fi

if [ -e "$pkg/.release-please-manifest.json" ]; then
  skipped+=(".release-please-manifest.json")
else
  start="$version"; $unreleased && start="0.0.0"
  printf '{\n  ".": "%s"\n}\n' "$start" > "$pkg/.release-please-manifest.json"
  copied+=(".release-please-manifest.json")
fi
if ! $unreleased && [[ " ${copied[*]} " == *" release-please-config.json "* ]]; then
  sed -i '/"release-as"/d' "$pkg/release-please-config.json"
fi

if [ -e "$pkg/CITATION.cff" ]; then
  skipped+=("CITATION.cff")
else
  Rscript "$src/tools/cff.R" "$pkg" "$repo" "$site_url"
  copied+=("CITATION.cff")
fi

touch "$pkg/.Rbuildignore"
added=0
while IFS= read -r line; do
  line="${line%$'\r'}"  # CRLF checkouts
  [ "$line" = '^tools$' ] && continue
  [ "$line" = '^LICENSE\.md$' ] && [ ! -e "$pkg/LICENSE.md" ] && continue
  if ! grep -qxF -- "$line" "$pkg/.Rbuildignore"; then
    echo "$line" >> "$pkg/.Rbuildignore"
    added=$((added + 1))
  fi
done < "$src/.Rbuildignore"

echo
echo "Copied:";  printf '  %s\n' "${copied[@]}"
if [ ${#skipped[@]} -gt 0 ]; then
  echo "Skipped (already exist, compare by hand):"; printf '  %s\n' "${skipped[@]}"
fi
echo "Added $added line(s) to .Rbuildignore."
cat <<MSG

Next steps:
  1. If _pkgdown.yml was skipped, set url: $site_url and
     development: mode: release in it.
  2. Check CITATION.cff (license, abstract) and inst/CITATION.
  3. Run air format . and jarl check . : CI fails on either.
  4. Once on CRAN, add the DOI 10.32614/CRAN.package.$package to
     inst/CITATION, CITATION.cff and the README.
  5. Set up the repository settings listed in the template README.
MSG
$unreleased && echo "  6. After the first release (0.1.0), remove \"release-as\" from release-please-config.json."
true
