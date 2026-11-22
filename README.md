# Estudio dictionaries

Offline dictionary files for the **Estudio JW** study app. The app does not ship with a dictionary: on first use it downloads the files for the language pairs someone chooses from the releases of this repository, checks them, and keeps them on the device. Word lookups, conjugation tables and searches in the local library then work offline.

This repository contains only dictionary data built from Wiktionary, plus the script that builds and publishes it. It contains no jw.org content.

## Files

Each release is tied to the app's dictionary schema version; the tag is `schema-<version>` (now [`schema-3`](https://github.com/mellelieuwes/estudio-dictionaries/releases/tag/schema-3)). An app reads `manifest.json` from the release for its schema, so a future format change never breaks older apps.

A language pair needs two files:

| File | Contents | Shared by |
|---|---|---|
| `forms-<from>` | every word and inflected form of the From language, with grammar tags | all pairs from that language |
| `<from>-<to>` | the pair's definitions, and descriptions of forms written in the To language | that pair only |

Spanish forms are shared, for example: Spanish → English and Spanish → Dutch both use `forms-es`, so a device with both keeps it once.

Sizes of data version 2026.11.22 (download / on the device):

| File | Download | On the device |
|---|---:|---:|
| `forms-es` | 40.9 MB | 204.6 MB |
| `forms-en` | 1.7 MB | 8.2 MB |
| `forms-nl` | 7.8 MB | 35.4 MB |
| `es-en` | 17.5 MB | 93.6 MB |
| `es-nl` | 4.6 MB | 34.5 MB |
| `en-es` | 0.8 MB | 2.5 MB |
| `en-nl` | 0.6 MB | 2.0 MB |
| `nl-en` | 5.4 MB | 21.7 MB |
| `nl-es` | 0.1 MB | 0.2 MB |

Release assets are named `<file>-<version>.sqlite.xz`: SQLite databases compressed with LZMA in an xz container (`xz -d` unpacks them).

### manifest.json

```json
{
  "format": 1,
  "schemaVersion": 3,
  "version": "2026.11.22",
  "files": [
    {
      "id": "es-en",
      "kind": "pair",
      "source": "es",
      "target": "en",
      "url": "https://github.com/mellelieuwes/estudio-dictionaries/releases/download/schema-3/es-en-2026.11.22.sqlite.xz",
      "size": 17474560,
      "sha256": "…",
      "installedSize": 93560832,
      "installedSha256": "…"
    }
  ]
}
```

`size`/`sha256` describe the download, `installedSize`/`installedSha256` the unpacked SQLite file. A forms file has `"kind": "forms"`, its language as `source` and no `target`. The app installs a file only when the download and the unpacked file match both checksums and the file opens as the dictionary it claims to be; anything else is deleted and downloaded again.

### Database format (schema 3)

Both kinds have `PRAGMA user_version = 3` and an `info(key, value)` table: `kind` = `forms` with `language`, or `kind` = `pair` with `source` and `target`.

- **forms:** `lemma(id, word, pos, entry)` (entry = 1 when Wiktionary has an entry of its own; 0 for a lemma that only appears as the target of inflected forms), `grammar(id, tags)` (comma-separated Wiktextract tags), `form(form, folded, lemma → lemma.id, grammar → grammar.id)`. `folded` is the lowercased spelling without accents (Spanish `ñ` kept), stored only where it differs from `form`.
- **pair:** `definition(word, folded, pos, head, senses)` with `senses` a JSON array of strings, and `description(form, lemma, pos, description)`: what the To-language Wiktionary says about an inflected form, such as "derde persoon enkelvoud van caminar".

Definitions are never reversed or machine translated: Spanish → Dutch comes from the Dutch Wiktionary's Spanish entries, and so on. Inflected forms come from every edition used for that language.

## Building and publishing

The builder is `estudio-dictbuild`, part of the Estudio app's source (`EstudioKit/Sources/estudio-dictbuild`). With a checkout of the app:

```sh
scripts/build-and-publish.sh <path-to-app-folder> 2026.11.22            # build into work/
scripts/build-and-publish.sh <path-to-app-folder> 2026.11.22 --publish  # and upload with gh
```

The script downloads six extracts from Kaikki.org (once), imports them into one staging database (only words with a part of speech, glosses joined per sense, a fixed set of usage labels kept, form-of glosses kept as form descriptions, conjugation-table metadata dropped), writes the nine files, compresses them, writes `manifest.json`, uploads the files and then the manifest, and removes files of older versions from the release. Kaikki marks these per-language extracts as deprecated; if they disappear, the same JSONL can be produced by running [Wiktextract](https://github.com/tatuylonen/wiktextract) on the Wiktionary dumps.

| Pair | Kaikki.org extract |
|---|---|
| es → en | [English Wiktionary, Spanish](https://kaikki.org/dictionary/Spanish/) |
| es → nl | [Dutch Wiktionary, Spaans](https://kaikki.org/nlwiktionary/Spaans/) |
| en → es | [Spanish Wiktionary, Inglés](https://kaikki.org/eswiktionary/Ingl%C3%A9s/) |
| en → nl | [Dutch Wiktionary, Engels](https://kaikki.org/nlwiktionary/Engels/) |
| nl → en | [English Wiktionary, Dutch](https://kaikki.org/dictionary/Dutch/) |
| nl → es | [Spanish Wiktionary, Neerlandés](https://kaikki.org/eswiktionary/Neerland%C3%A9s/) |

## License and attribution

The dictionary data is derived from [Wiktionary](https://www.wiktionary.org/) and is © Wiktionary contributors, licensed under [Creative Commons Attribution-ShareAlike 4.0](https://creativecommons.org/licenses/by-sa/4.0/) (see [LICENSE](LICENSE)). It was extracted by [Kaikki.org](https://kaikki.org/) using Wiktextract (Tatu Ylonen, “Wiktextract: Wiktionary as Machine-Readable Structured Data”, LREC 2022) and then filtered and restructured as described above. You may reuse these files under the same license.

<sub>Written by an AI agent (omp · anthropic/claude-opus-5-5).</sub>
