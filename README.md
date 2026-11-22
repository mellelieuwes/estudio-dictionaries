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

Sizes (download / on the device). Files keep their data version in their name: the ES/EN/NL files are from 2026.11.22, the German files from 2026.11.22.1 (added later without changing the others).

| File | Download | On the device | Contents |
|---|---:|---:|---:|
| `forms-es` | 40.9 MB | 204.6 MB | 2.24 M forms |
| `forms-en` | 1.7 MB | 8.2 MB | 0.12 M forms |
| `forms-nl` | 7.8 MB | 35.4 MB | 0.50 M forms |
| `forms-de` | 29.9 MB | 190.5 MB | 2.31 M forms |
| `es-en` | 17.5 MB | 93.6 MB | 124,487 entries |
| `es-nl` | 4.6 MB | 34.5 MB | 20,030 entries |
| `en-es` | 0.8 MB | 2.5 MB | 20,432 entries |
| `en-nl` | 0.6 MB | 2.0 MB | 13,727 entries |
| `nl-en` | 5.4 MB | 21.7 MB | 73,928 entries |
| `nl-es` | 0.1 MB | 0.2 MB | 1,904 entries |
| `de-en` | 13.1 MB | 77.6 MB | 103,003 entries |
| `de-nl` | 0.3 MB | 1.2 MB | 7,548 entries |
| `de-es` | 0.2 MB | 0.5 MB | 4,115 entries |
| `en-de` | 1.6 MB | 7.7 MB | 13,733 entries |
| `es-de` | 0.2 MB | 0.9 MB | 2,992 entries |
| `nl-de` | 0.1 MB | 0.2 MB | 1,124 entries |

An entry is a word with one part of speech and at least one definition in the To language.

Coverage follows the Wiktionary editions and is very uneven. German → English is broad; the other German directions are thin: the Dutch Wiktionary has no `Versammlung` or `Bibel`, the Spanish Wiktionary's German entries are mostly basic vocabulary and names, and the German Wiktionary's Spanish and Dutch entries lack words like `predicar`, `congregación`, `gemeente` or `mooi`. Missing words are shown as missing in the app; nothing is filled in from another language. JW terms such as `Königreichssaal` or `Dienstamtgehilfe` are not dictionary headwords; the app's JW vocabulary covers them, and unlisted German compounds are shown as their parts.

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

- **forms:** `lemma(id, word, pos, entry)` (entry = 1 when Wiktionary has an entry of its own; 0 for a lemma that only appears as the target of inflected forms), `grammar(id, tags)` (comma-separated Wiktextract tags), `form(form, folded, lemma → lemma.id, grammar → grammar.id)`. `folded` is the lookup spelling following the app's language rules (lowercase, accents removed except Spanish `ñ` and German `ä ö ü`, German `ß` as `ss`), stored only where it differs from `form`.
- **pair:** `definition(word, folded, pos, head, senses)` with `senses` a JSON array of strings, and `description(form, lemma, pos, description)`: what the To-language Wiktionary says about an inflected form, such as "derde persoon enkelvoud van caminar".

Definitions are never reversed or machine translated: Spanish → Dutch comes from the Dutch Wiktionary's Spanish entries, and so on. Inflected forms come from the editions marked `forms` in the script (the English Wiktionary for German); the others contribute definitions and form descriptions only, because their forms of foreign words are unreliable (pronouns listed as verb forms, nouns with articles).

## Building and publishing

The builder is `estudio-dictbuild`, part of the Estudio app's source (`EstudioKit/Sources/estudio-dictbuild`). With a checkout of the app:

```sh
scripts/build-and-publish.sh <path-to-app-folder> 2026.11.22                      # build everything into work/
scripts/build-and-publish.sh <path-to-app-folder> 2026.11.22 --publish            # and upload with gh
scripts/build-and-publish.sh <path-to-app-folder> 2026.11.22.1 --add de --publish # add one language
```

The script downloads the extracts from Kaikki.org (once), imports them into one staging database (only words with a part of speech, glosses joined per sense with German-Wiktionary footnote markers and sense numbers removed, a fixed set of usage labels kept, form-of glosses kept as form descriptions, conjugation-table metadata, auxiliaries, periphrastic tenses and article forms dropped), writes the files, compresses them, writes `manifest.json`, uploads the files and then the manifest, and removes files the manifest no longer lists. With `--add <language>` it builds only the inputs involving that language, publishes `forms-<language>` and its pair files, and merges them into the published manifest: every other file keeps its name, URL and checksums, so devices never download them again, and apps that do not know the language ignore its files. Kaikki marks these per-language extracts as deprecated; if they disappear, the same JSONL can be produced by running [Wiktextract](https://github.com/tatuylonen/wiktextract) on the Wiktionary dumps.

| Pair | Kaikki.org extract | Use |
|---|---|---|
| es → en | [English Wiktionary, Spanish](https://kaikki.org/dictionary/Spanish/) | forms |
| es → nl | [Dutch Wiktionary, Spaans](https://kaikki.org/nlwiktionary/Spaans/) | forms |
| en → es | [Spanish Wiktionary, Inglés](https://kaikki.org/eswiktionary/Ingl%C3%A9s/) | forms |
| en → nl | [Dutch Wiktionary, Engels](https://kaikki.org/nlwiktionary/Engels/) | forms |
| nl → en | [English Wiktionary, Dutch](https://kaikki.org/dictionary/Dutch/) | forms |
| nl → es | [Spanish Wiktionary, Neerlandés](https://kaikki.org/eswiktionary/Neerland%C3%A9s/) | forms |
| de → en | [English Wiktionary, German](https://kaikki.org/dictionary/German/) | forms |
| de → nl | [Dutch Wiktionary, Duits](https://kaikki.org/nlwiktionary/Duits/) | definitions |
| de → es | [Spanish Wiktionary, Alemán](https://kaikki.org/eswiktionary/Alem%C3%A1n/) | definitions |
| en → de | [German Wiktionary, Englisch](https://kaikki.org/dewiktionary/Englisch/) | definitions |
| es → de | [German Wiktionary, Spanisch](https://kaikki.org/dewiktionary/Spanisch/) | definitions |
| nl → de | [German Wiktionary, Niederländisch](https://kaikki.org/dewiktionary/Niederl%C3%A4ndisch/) | definitions |

## License and attribution

The dictionary data is derived from [Wiktionary](https://www.wiktionary.org/) and is © Wiktionary contributors, licensed under [Creative Commons Attribution-ShareAlike 4.0](https://creativecommons.org/licenses/by-sa/4.0/) (see [LICENSE](LICENSE)). It was extracted by [Kaikki.org](https://kaikki.org/) using Wiktextract (Tatu Ylonen, “Wiktextract: Wiktionary as Machine-Readable Structured Data”, LREC 2022) and then filtered and restructured as described above. You may reuse these files under the same license.

<sub>Written by an AI agent (omp · anthropic/claude-opus-5-5).</sub>
