#!/bin/zsh
# Builds the Estudio JW dictionary files from Kaikki.org (Wiktextract) extracts
# and, with --publish, uploads them to this repository's release for the
# app's dictionary schema.
#
# usage: scripts/build-and-publish.sh <estudio-app-dir> <version> [--add <language>] [--publish]
#   <estudio-app-dir>  the Estudio app folder that contains EstudioKit
#                      (estudio-dictbuild lives in EstudioKit/Sources/estudio-dictbuild)
#   <version>          data version, letters/digits/dots only, e.g. 2026.11.22
#   --add <language>   build only the inputs involving <language> (e.g. de) and publish
#                      forms-<language> plus its pair files, merged into the published
#                      manifest: every other file and its download URL stay unchanged,
#                      so no device downloads its existing files again.
#
# Inputs are downloaded once into work/raw; delete them to fetch fresh extracts.
set -euo pipefail
cd "$(dirname "$0")/.."

app=${1:?path to the Estudio app folder (contains EstudioKit)}
version=${2:?data version, e.g. 2026.11.22}
shift 2
add= publish=
while (( $# )); do
  case $1 in
    --add) add=${2:?language after --add}; shift 2 ;;
    --publish) publish=1; shift ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done
repo=mellelieuwes/estudio-dictionaries
schema=3
tag=schema-$schema
work=${WORK:-$PWD/work}
raw=$work/raw
built=$work/built
out=$work/release
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}

# source-target  use  Kaikki.org extract (the target is the Wiktionary edition's language)
# use: "forms" imports definitions and word forms; "definitions" imports definitions and
# form descriptions only, for editions whose forms of foreign words are unreliable.
# A language's forms file comes from its "forms" inputs (the English Wiktionary).
inputs=(
  es-en forms        https://kaikki.org/dictionary/Spanish/kaikki.org-dictionary-Spanish.jsonl
  es-nl forms        https://kaikki.org/nlwiktionary/Spaans/kaikki.org-dictionary-Spaans.jsonl
  en-es forms        https://kaikki.org/eswiktionary/Ingl%C3%A9s/kaikki.org-dictionary-Ingl%C3%A9s.jsonl
  en-nl forms        https://kaikki.org/nlwiktionary/Engels/kaikki.org-dictionary-Engels.jsonl
  nl-en forms        https://kaikki.org/dictionary/Dutch/kaikki.org-dictionary-Dutch.jsonl
  nl-es forms        https://kaikki.org/eswiktionary/Neerland%C3%A9s/kaikki.org-dictionary-Neerland%C3%A9s.jsonl
  de-en forms        https://kaikki.org/dictionary/German/kaikki.org-dictionary-German.jsonl
  de-nl definitions  https://kaikki.org/nlwiktionary/Duits/kaikki.org-dictionary-Duits.jsonl
  de-es definitions  https://kaikki.org/eswiktionary/Alem%C3%A1n/kaikki.org-dictionary-Alem%C3%A1n.jsonl
  en-de definitions  https://kaikki.org/dewiktionary/Englisch/kaikki.org-dictionary-Englisch.jsonl
  es-de definitions  https://kaikki.org/dewiktionary/Spanisch/kaikki.org-dictionary-Spanisch.jsonl
  nl-de definitions  https://kaikki.org/dewiktionary/Niederl%C3%A4ndisch/kaikki.org-dictionary-Niederl%C3%A4ndisch.jsonl
)

mkdir -p "$raw"
arguments=()
ids=()
for pair use url in $inputs; do
  source=${pair%-*} target=${pair#*-}
  [[ -z $add || $source == $add || $target == $add ]] || continue
  file=$raw/$pair.jsonl
  if [[ ! -s $file ]]; then
    echo "== downloading $pair"
    curl -fL --retry 3 -o "$file.part" "$url"
    mv "$file.part" "$file"
  fi
  if [[ $use == forms ]]; then
    arguments+=("$source:$target=$file")
  else
    arguments+=("$source:$target:definitions=$file")
  fi
  ids+=($pair)
done
(( ${#arguments} )) || { echo "no inputs for language $add" >&2; exit 2; }

echo "== building estudio-dictbuild"
swift build -c release --package-path "$app/EstudioKit" --product estudio-dictbuild
tool=$app/EstudioKit/.build/release/estudio-dictbuild

rm -rf "$built" "$out"
echo "== building dictionary files"
"$tool" build "$built" $arguments
echo "== packing release files"
base="https://github.com/$repo/releases/download/$tag"
if [[ -n $add ]]; then
  published=$work/published-manifest.json
  curl -fL --retry 3 -o "$published" "$base/manifest.json"
  only=${(j:,:)${(@)ids}},forms-$add
  "$tool" package "$built" "$out" "$version" "$base" --only "$only" --merge "$published"
else
  "$tool" package "$built" "$out" "$version" "$base"
fi
ls -l "$built" "$out"

[[ -n $publish ]] || { echo "== built only; add --publish to upload"; exit 0; }

notes=$work/notes.md
cat > "$notes" <<EOF
Dictionary files for Estudio JW (app dictionary schema $schema), data version $version.

The app reads \`manifest.json\` from this release and downloads only the files for the language pairs someone uses. Every file is checked against the SHA-256 checksums in the manifest before it is installed. Files keep their version in their name; a release update adds files and replaces the manifest last, so files that did not change are never downloaded again.

Contents: definitions and word forms from Wiktionary, via [Kaikki.org](https://kaikki.org/) (Wiktextract), filtered and restructured for offline lookup. License: [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), © Wiktionary contributors. See the README for the file format and coverage per pair.

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
echo "== removing files the manifest no longer lists"
listed=$(python3 -c 'import json,sys; print("\n".join(f["url"].rsplit("/",1)[1] for f in json.load(open(sys.argv[1]))["files"]))' "$out/manifest.json")
for asset in $(gh release view "$tag" -R "$repo" --json assets -q '.assets[].name'); do
  if [[ $asset == *.sqlite.xz ]] && ! grep -qxF "$asset" <<< "$listed"; then
    gh release delete-asset "$tag" "$asset" -R "$repo" -y
  fi
done
echo "== published https://github.com/$repo/releases/tag/$tag"
