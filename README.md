# Word Wise (KOReader plugin)

Shows short inline definitions above difficult words, like Kindle's Word Wise —
painted as a per-page overlay on the book you're reading (no copy, no file
rewrite). Difficulty is adjustable: a low hint level shows only rare/hard words,
a high one also glosses more common ones.

![Word Wise showing glosses above difficult words](screenshot.png)

## Install

1. Download **`wordwise.koplugin.zip`** from the
   [latest release](https://github.com/asxelot/wordwise.koplugin/releases/latest)
   and unzip it. It expands to a correctly-named `wordwise.koplugin/` folder
   (dictionary bundled) — ready to copy, no renaming needed.
2. Copy the `wordwise.koplugin` folder into KOReader's `plugins/` directory:
   - Kindle: `/mnt/us/koreader/plugins/`
   - Kobo: `/mnt/onboard/.adds/koreader/plugins/`
   - Android: `koreader/plugins/`
   - Desktop / emulator: `<koreader>/plugins/`
3. Restart KOReader.

<details>
<summary>Install from source instead</summary>

`git clone` this repo, or use the green **Code → Download ZIP** button and
unzip it. A ZIP download unzips as **`wordwise.koplugin-main`** — remove the
`-main` so the folder ends in `.koplugin`, or KOReader won't recognize it
(cloning already gives the right name). Then copy it into `plugins/` as above.
</details>

## Activate

Open a book, then: **☰ (or ⋮) → more tools → Word Wise → Show inline hints**.
Pick a hint level (1 = only the rarest words … 5 = most hints). Short definitions
then appear above difficult words on every page. Turn it off from the same menu.

## A dictionary is included

The plugin **ships with a built-in open dictionary** (`wordwise.db`, ~30k hard
words), so it works out of the box — no setup. The bundled dictionary contains
no proprietary content and is freely redistributable (see *How the bundled
dictionary is built* below).

### Bring your own (optional)

Any database you drop into KOReader's data directory **overrides** the bundled
one, so you can supply a better/personal dictionary without deleting anything:

```
<koreader data dir>/wordwise/wordwise.db
```

(Any `*.db` in `wordwise/` is used; `wordwise.db` is preferred if present.)

### Running on a Kindle? It's auto-detected

If no override is present and the plugin finds Kindle's own Word Wise corpus
on disk (`/mnt/us/system/kll/kll.en.en.klld` — populated once Word Wise has
been used at least once), it converts that into `wordwise/wordwise.db`
automatically on first run (`wordwise_kindle.lua`) and uses it from then on.
This is Amazon/Merriam-Webster content read from *your own device*; the
conversion happens on-device and the result is never bundled/distributed —
same personal-use terms as the standalone conversion below.

Resolution order: `wordwise/wordwise.db` → first `*.db` in `wordwise/` →
auto-converted Kindle corpus (device only) → bundled.

### Canonical schema

Whatever the source, the engine reads exactly this shape:

```sql
CREATE TABLE entries (
    word       TEXT PRIMARY KEY COLLATE NOCASE,
    short_def  TEXT NOT NULL,      -- the gloss shown above the word
    difficulty INTEGER NOT NULL,   -- 1 rarest .. 5 most common
    pos        TEXT                -- part of speech (optional)
);
```

A word is glossed when `difficulty <= hint level`. Exact headwords from the
selected dictionary take priority; conservative English inflection rules let
forms such as `studied`, `walked`, and `running` match their base headwords.

## How the bundled dictionary is built

`wordwise.db` is assembled from three open ingredients (`tools/build_open_dict.py`):

- **word list** — Open English WordNet lemmas (permissive license)
- **difficulty** — word-frequency (Zipf) from the [`wordfreq`](https://pypi.org/project/wordfreq/)
  package; only words below the "common" threshold are kept as hard words
- **glosses** — short definitions written for this project, stored in the
  editable source `tools/open_glosses.tsv` (`word<TAB>gloss`)

To improve a definition, edit `open_glosses.tsv` and rebuild:

```sh
cd tools
python3 build_open_dict.py build --glosses open_glosses.tsv --out ../wordwise.db
```

To regenerate the hard-word list itself (needs `pip install wn wordfreq` and the
`oewn:2024` lexicon):

```sh
python3 build_open_dict.py candidates > candidates.tsv
```

### Alternative sources

- **Kindle Word Wise (personal use).** If you're running the plugin on a
  (jailbroken) Kindle itself, this happens automatically — see *Running on a
  Kindle?* above. To convert a copy pulled off your own device for use
  elsewhere (e.g. testing in the emulator), use `tools/build_wordwise_db.py`
  on `kll.en.en.klld` (or the older `WordWise.kll.en.en.db`) and drop the
  result in `wordwise/`. This is Amazon/Merriam-Webster licensed content — for
  personal use only; **do not redistribute it.**
- **Wiktionary (CC BY-SA)** via the [Proficiency](https://github.com/xxyzz/Proficiency)
  `en_en` data, reshaped into the canonical schema.
