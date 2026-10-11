#!/usr/bin/env bash
# Copy the CI, release and citation setup into an existing R package.
#
# Usage: ./apply.sh /path/to/package [owner/repo]
#
# Existing files are never overwritten; they are listed as skipped so you
# can compare them with template/ by hand. owner/repo defaults to the
# package's GitHub "origin" remote.
set -euo pipefail

src="$(cd "$(dirname "$0")/template" && pwd)"
pkg="$(cd "${1:?usage: apply.sh /path/to/package [owner/repo]}" && pwd)"
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

copied=(); skipped=()
while IFS= read -r -d '' f; do
  rel="${f#"$src"/}"
  dest="$pkg/$rel"
  if [ -e "$dest" ]; then
    skipped+=("$rel")
    continue
  fi
  mkdir -p "$(dirname "$dest")"
  sed -e "s#{{package}}#$package#g" -e "s#{{repo}}#$repo#g" \
      -e "s#{{owner}}#$owner#g" -e "s#{{version}}#$version#g" \
      -e "s#{{site_url}}#$site_url#g" "$f" > "$dest"
  copied+=("$rel")
done < <(find "$src" -type f -print0 | sort -z)

if [ -e "$pkg/CITATION.cff" ]; then
  skipped+=("CITATION.cff")
else
  Rscript "$(dirname "$0")/cff.R" "$pkg" "$repo" "$site_url"
  copied+=("CITATION.cff")
fi

ignore=(
  '^\.github$' '^air\.toml$' '^jarl\.toml$' '^codecov\.yml$'
  '^\.release-please-manifest\.json$' '^release-please-config\.json$'
  '^CHANGELOG\.md$' '^CITATION\.cff$' '^cran-comments\.md$'
  '^CRAN-SUBMISSION$' '^_pkgdown\.yml$' '^pkgdown$' '^docs$'
)
touch "$pkg/.Rbuildignore"
added=0
for line in "${ignore[@]}"; do
  if ! grep -qxF -- "$line" "$pkg/.Rbuildignore"; then
    echo "$line" >> "$pkg/.Rbuildignore"
    added=$((added + 1))
  fi
done

echo
echo "Copied:";  printf '  %s\n' "${copied[@]}"
if [ ${#skipped[@]} -gt 0 ]; then
  echo "Skipped (already exist, compare by hand):"; printf '  %s\n' "${skipped[@]}"
fi
echo "Added $added line(s) to .Rbuildignore."
cat <<MSG

Next steps:
  1. Set url: $site_url and development: mode: release in _pkgdown.yml.
  2. Check CITATION.cff (license, abstract) and inst/CITATION.
  3. Once on CRAN, add the DOI 10.32614/CRAN.package.$package to
     inst/CITATION, CITATION.cff and the README.
  4. On GitHub, see "Repository settings" in the template README.
MSG
