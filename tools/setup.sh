#!/usr/bin/env bash
# Turn a fresh copy of this template into your package. Run it once, from
# the root of the new repository, after "Use this template".
#
# Usage: tools/setup.sh [package-name] [orcid]
#
# The package name defaults to the repository name. Author name and email
# come from `git config user.name` and `user.email`.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
[ -f tools/README-package.md ] || { echo "Already set up." >&2; exit 1; }

url="$(git remote get-url origin 2>/dev/null || true)"
repo="$(echo "$url" | sed -E 's#^(git@github.com:|https://github.com/)##; s#\.git$##')"
[[ "$repo" == */* ]] || { echo "No GitHub origin remote found." >&2; exit 1; }
owner="${repo%%/*}"
site_url="https://${owner}.github.io/${repo#*/}/"

package="${1:-${repo#*/}}"
if ! [[ "$package" =~ ^[A-Za-z][A-Za-z0-9.]*[A-Za-z0-9]$ ]]; then
  echo "\"$package\" is not a valid R package name (letters, digits and dots;" >&2
  echo "no dashes). Pass a name: tools/setup.sh mypackage" >&2
  exit 1
fi
orcid="${2:-}"

name="$(git config user.name || true)"
email="$(git config user.email || true)"
[ -n "$name" ] && [ -n "$email" ] || {
  echo "Set git config user.name and user.email first." >&2; exit 1;
}
family="${name##* }"
given="${name% *}"
[ "$given" = "$name" ] && given=""

fill() {
  sed -i -e "s#{{package}}#$package#g" -e "s#{{repo}}#$repo#g" \
    -e "s#{{owner}}#$owner#g" -e "s#{{site_url}}#$site_url#g" \
    -e "s#{{given}}#$given#g" -e "s#{{family}}#$family#g" \
    -e "s#{{email}}#$email#g" "$@"
}

mapfile -d '' files < <(git ls-files -z | grep -zv '^tools/')
for f in "${files[@]}"; do
  if grep -q '{{package}}\|{{repo}}\|{{owner}}\|{{site_url}}\|{{given}}\|{{family}}\|{{email}}' "$f"; then
    fill "$f"
  fi
done

if [ -n "$orcid" ]; then
  sed -i "s#role = c(\"aut\", \"cre\"))#role = c(\"aut\", \"cre\"),\n           comment = c(ORCID = \"$orcid\"))#" DESCRIPTION
fi

fill tools/README-package.md
mv tools/README-package.md README.md
sed -i "s/^Copyright (c) .*/Copyright (c) $(date +%Y) $package authors/" LICENSE.md
sed -i "s/^YEAR: .*/YEAR: $(date +%Y)/" LICENSE
Rscript tools/cff.R . "$repo" "$site_url"
sed -i '/# template-only$/d' .github/workflows/*.yml
rm .github/workflows/template-ci.yml
sed -i '/^\^tools\$$/d' .Rbuildignore
rm -rf tools

cat <<MSG
Set up $package ($repo).

Next steps:
  1. Write the Title and Description in DESCRIPTION, and copy them into
     title and abstract in CITATION.cff.
  2. Replace R/hello.R and its test with your own code.
  3. Commit, then set up the repository settings listed in the template
     README (ruleset on main, squash merging, Actions PR permission, Pages,
     CODECOV_TOKEN).
  4. The first release is 0.1.0. After it, remove "release-as" from
     release-please-config.json.
MSG
