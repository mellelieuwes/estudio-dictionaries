#!/bin/zsh
# Builds the Estudio JW dictionary files from Kaikki.org (Wiktextract) extracts
# and, with --publish, uploads them to this repository's release for the
# app's dictionary schema.
#
# usage: scripts/build-and-publish.sh <estudio-app-dir> <version> [--publish]
#   <estudio-app-dir>  the Estudio app folder that contains EstudioKit
#                      (estudio-dictbuild lives in EstudioKit/Sources/estudio-dictbuild)
#   <version>          data version, letters/digits/dots only, e.g. 2026.11.22
#
# Inputs are downloaded once into work/raw; delete them to fetch fresh extracts.
set -euo pipefail
cd "$(dirname "$0")/.."

app=${1:?path to the Estudio app folder (contains EstudioKit)}
version=${2:?data version, e.g. 2026.11.22}
publish=${3:-}
repo=mellelieuwes/estudio-dictionaries
schema=3
tag=schema-$schema
work=${WORK:-$PWD/work}
raw=$work/raw
built=$work/built
out=$work/release
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}

# source-target  Kaikki.org extract (the target is the Wiktionary edition's language)
inputs=(
  es-en https://kaikki.org/dictionary/Spanish/kaikki.org-dictionary-Spanish.jsonl
  es-nl https://kaikki.org/nlwiktionary/Spaans/kaikki.org-dictionary-Spaans.jsonl
  en-es https://kaikki.org/eswiktionary/Ingl%C3%A9s/kaikki.org-dictionary-Ingl%C3%A9s.jsonl
  en-nl https://kaikki.org/nlwiktionary/Engels/kaikki.org-dictionary-Engels.jsonl
  nl-en https://kaikki.org/dictionary/Dutch/kaikki.org-dictionary-Dutch.jsonl
  nl-es https://kaikki.org/eswiktionary/Neerland%C3%A9s/kaikki.org-dictionary-Neerland%C3%A9s.jsonl
)

mkdir -p "$raw"
arguments=()
for pair url in $inputs; do
  file=$raw/$pair.jsonl
  if [[ ! -s $file ]]; then
    echo "== downloading $pair"
    curl -fL --retry 3 -o "$file.part" "$url"
    mv "$file.part" "$file"
  fi
  arguments+=("${pair%-*}:${pair#*-}=$file")
done

echo "== building estudio-dictbuild"
swift build -c release --package-path "$app/EstudioKit" --product estudio-dictbuild
tool=$app/EstudioKit/.build/release/estudio-dictbuild

rm -rf "$built" "$out"
echo "== building dictionary files"
"$tool" build "$built" $arguments
echo "== packing release files"
"$tool" package "$built" "$out" "$version" "https://github.com/$repo/releases/download/$tag"
ls -l "$built" "$out"

[[ $publish == --publish ]] || { echo "== built only; add --publish to upload"; exit 0; }

notes=$work/notes.md
cat > "$notes" <<EOF
Dictionary files for Estudio JW (app dictionary schema $schema), data version $version.

The app reads \`manifest.json\` from this release and downloads only the files for the language pairs someone uses. Every file is checked against the SHA-256 checksums in the manifest before it is installed.

Contents: definitions and word forms from Wiktionary, via [Kaikki.org](https://kaikki.org/) (Wiktextract), filtered and restructured for offline lookup. License: [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), © Wiktionary contributors. See the README for the file format.

<sub>Written by an AI agent (omp · anthropic/claude-opus-5-5).</sub>
EOF

if ! gh release view "$tag" -R "$repo" >/dev/null 2>&1; then
  gh release create "$tag" -R "$repo" --title "Dictionaries for app schema $schema" --notes-file "$notes"
else
  gh release edit "$tag" -R "$repo" --notes-file "$notes"
fi
echo "== uploading files"
gh release upload "$tag" -R "$repo" --clobber "$out"/*.sqlite.xz
# The manifest goes last, so devices never see it before its files exist.
gh release upload "$tag" -R "$repo" --clobber "$out/manifest.json"
echo "== removing files of older versions"
for asset in $(gh release view "$tag" -R "$repo" --json assets -q '.assets[].name'); do
  if [[ $asset == *.sqlite.xz && $asset != *-$version.sqlite.xz ]]; then
    gh release delete-asset "$tag" "$asset" -R "$repo" -y
  fi
done
echo "== published https://github.com/$repo/releases/tag/$tag"
