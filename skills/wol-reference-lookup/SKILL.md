---
name: wol-reference-lookup
description: Detect Bible and JW-publication references (Greek or English) inside pasted text — a passage, article, or talk outline — and fetch their real content from wol.jw.org (Watchtower ONLINE LIBRARY). Use whenever the user pastes text containing citations like "Ματθαίος 13:31, 32", "John 3:16", "w14 15/12 σ. 7 ¶7, 8", "g16.2 p. 3", or asks to "look up", "find the references in", or "check the citations in" a passage/outline. Supports selecting bible-only, publications-only, or both. Works in both Claude Code (shell/curl available) and claude.ai (sandboxed, text-only fetch) — auto-detects which and adapts.
---

# WOL Reference Lookup

Finds every Bible and/or JW-publication reference in a block of text and pulls the
real text/paragraph content for each one directly from wol.jw.org — never from
memory. This document is the accumulated, verified method for Claude Code; it
also contains a **draft, not-yet-field-tested** fallback for environments
(like claude.ai) where raw HTML isn't available. Follow section 0.5 first to
pick the right path.

## 0. Mode selection

Ask or infer which reference types to process:
- **bible** — only scripture citations (e.g. "Ματ 28:20", "John 3:16")
- **publications** — only JW-literature citations (e.g. "w22.07 σ. 9 ¶6-8")
- **both** (default) — everything, including combined citations like
  `Ματ 28:20· w22.07 σ. 9 ¶6-8` (a scripture *and* a publication paragraph in
  one parenthetical — treat as two independent references to resolve
  separately, then present together since the source paired them)

If the user's request doesn't specify, default to **both**.

## 0.5. Determine which fetch method you actually have

Don't ask the user which environment they're in — detect it yourself, since
it depends on which tools you were given, not on where you "are":

1. Make one test fetch of any WOL Bible chapter page, e.g.
   `https://wol.jw.org/en/wol/b/r1/lp-e/nwt/40/13` (Matthew 13, English),
   using whatever fetch-capable tool you have (a shell/Bash tool with `curl`,
   or a URL-fetch tool like `WebFetch`/`web_fetch`).
2. Inspect what came back:
   - If it's **raw HTML** — you can see literal tags like `<span id="v40-13-1-1"`
     and `data-pnum=` in the response — use the **HTML method** (2A / 3A
     below). This is the verified, primary method. This is how Claude Code's
     Bash tool behaves.
   - If it's **cleaned text or markdown** with the HTML stripped or converted
     (numbers, prose, maybe `[link](url)`-style links, but no visible tags or
     `data-pnum`/`id="v...` attributes) — use the **plain-text method** (2B /
     3B below). This is expected in claude.ai's `web_fetch`, and is a
     **first-draft, unverified** approach — flag this to the user in your
     output (see section 4) so they know to sanity-check the result.
   - If the fetch fails entirely (no network access, tool errors out) — say
     so plainly; don't fall back to answering from memory.
3. Once determined, use the same method for the rest of the session/request
   — no need to re-probe per reference.

## 1. Detect references in the pasted text

Scan for these shapes (Greek and English both occur, sometimes in the same
document) — this step is identical regardless of fetch method:

**Bible references**
- `<Book> <chapter>:<verse>` or `<verse-range>` e.g. `Ματθαίος 13:31, 32`,
  `John 3:16`, `Ησ 60:22`
- Abbreviated book names are common and must be recognized: Greek (`Ησ`,
  `Ματ`/`Ματθ.`, `Απ`, `Κολ`, `1Θε`, `Παρ.`, `Εκκλ.`, `Ζαχ.`, etc.) and English
  (`Matt.`, `Isa.`, `Rev.`, `Col.`, `1 Thess.`, etc.). Use your own knowledge
  of the 66 Bible books to resolve unfamiliar abbreviations — don't require an
  exact table match.
- Multiple citations under one book, chapters separated by `·` or `;`:
  `Ησ 32:1, 2· 40:11` = Isaiah 32:1-2 **and** Isaiah 40:11 (two lookups).
  Verses within one chapter separated by `,`: `13:31, 32` = verses 31 and 32.
- Leading imperative words are not part of the reference — strip them:
  `Διαβάστε`/`Διάβασε`/`Read`/`Παράβαλε`/"See" etc.

**Publication references** (always use Latin-letter codes even in Greek text)
- Modern monthly format: `<code><YY>.<MM>` e.g. `w22.07` (Watchtower 2022,
  July), `g16.2` (Awake! 2016, issue 2)
- Pre-2016 semi-monthly format: `<code><YY> <DD>/<MM>` — **day/month order**,
  e.g. `w14 15/12` (Watchtower, Dec 15 2014), `g95 22/8` (Awake!, Aug 22 1995).
  Getting the day/month order wrong breaks resolution — always day first.
- Page marker: `σ.`/`σελ.` (Greek) or `p.`/`pp.` (English) + number(s)
- Paragraph marker: `¶` + number or range, e.g. `¶7, 8` or `¶6-8`
- Do not maintain a fixed list of valid codes (`w`, `g`, `km`, `mwb`, `wp`,
  `yb`, book-study codes like `ia`, `rr`, etc. all exist) — any code WOL's own
  search recognizes will resolve; rely on the not-found handling in step
  3A/3B rather than pre-filtering codes.

## 2A. Resolve Bible references — HTML method (verified, Claude Code)

1. Pick the language edition based on the reference's own script: Greek book
   name → Greek edition; English/Latin book name → English edition (or follow
   an explicit user instruction to use a specific language).
2. Known region/library codes (verified):
   - English: `r1` / `lp-e`
   - Greek: `r11` / `lp-g`
   - Any other language: discover it by requesting
     `curl -sIL https://wol.jw.org/<2-letter-lang>` and reading the
     `Location:` redirect header, e.g. `/el/wol/h/r11/lp-g` — this is the
     pattern `/wol/h/r<region>/lp-<code>` for every language WOL supports.
3. Map the book name to its canonical number (language-independent, same
   numbering in every WOL edition):

   ```
   1 Genesis        18 Job            35 Habakkuk        52 1 Thessalonians
   2 Exodus         19 Psalms         36 Zephaniah       53 2 Thessalonians
   3 Leviticus      20 Proverbs       37 Haggai          54 1 Timothy
   4 Numbers        21 Ecclesiastes   38 Zechariah       55 2 Timothy
   5 Deuteronomy    22 Song of Sol.   39 Malachi         56 Titus
   6 Joshua         23 Isaiah         40 Matthew         57 Philemon
   7 Judges         24 Jeremiah       41 Mark            58 Hebrews
   8 Ruth           25 Lamentations   42 Luke            59 James
   9 1 Samuel       26 Ezekiel        43 John            60 1 Peter
   10 2 Samuel      27 Daniel         44 Acts            61 2 Peter
   11 1 Kings       28 Hosea          45 Romans          62 1 John
   12 2 Kings       29 Joel           46 1 Corinthians   63 2 John
   13 1 Chronicles  30 Amos           47 2 Corinthians   64 3 John
   14 2 Chronicles  31 Obadiah        48 Galatians       65 Jude
   15 Ezra          32 Jonah          49 Ephesians       66 Revelation
   16 Nehemiah      33 Micah          50 Philippians
   17 Esther        34 Nahum          51 Colossians
   ```

4. Fetch the chapter:
   `curl -s "https://wol.jw.org/<lang>/wol/b/r<region>/lp-<code>/nwt/<bookNum>/<chapter>"`
   (e.g. `https://wol.jw.org/el/wol/b/r11/lp-g/nwt/40/13` = Matthew 13, Greek)
5. Extract each requested verse. Verse text lives in one or more
   `<span id="v<book>-<chapter>-<verse>-<sentence>">` tags (a verse can be
   split across several sentence-spans, `-1`, `-2`, `-3`...). Regex per verse:

   ```python
   pat = (rf'id="v{book}-{chap}-{v}-1".*?</a>(.*?)'
          rf'(?=<span id="v{book}-{chap}-{v+1}-1"|<span class="footnoteRefLink|<div class="pswp")')
   ```

   The `<div class="pswp"` alternative is required as a fallback terminator
   for the **last verse of a chapter** (there is no "verse+1" to stop at).
   After matching, strip tags and **replace `</p>\s*<p[^>]*>` with a single
   space before stripping tags** — otherwise adjacent sentence-spans in
   separate `<p>` tags get concatenated with no space (e.g. "χίλιοικαι").
   Strip the trailing `+` cross-reference marker characters — they're WOL's
   own footnote markers, not article text.

## 2B. Resolve Bible references — plain-text method (DRAFT, unverified)

Use only when 0.5 determined you don't have raw HTML access. This relies on
the fact that WOL visibly prints verse numbers inline before each verse's
text (e.g. "31 Τους είπε και άλλη μια παραβολή...") — even a
text/markdown-only fetch should preserve that, since it's rendered content,
not markup.

1. Build the same chapter URL as in 2A step 1-4 (book-number table and
   region/language codes are identical regardless of fetch method) and fetch
   it with your text-capable tool.
2. Scan the returned text for a token matching the target verse number
   followed by the verse's own text. **Verse numbers appear in strictly
   increasing order through the chapter** — use that to disambiguate a real
   verse marker from a number that merely appears in running text (e.g. a
   cross-reference like "(1 Κορ. 14:9)" embedded inside verse 1's own text
   is not a marker for "verse 14" of the current chapter). Track the last
   confirmed verse number and only accept a candidate that's the immediate
   next integer.
3. Extract from that verse-number marker up to (but not including) the next
   sequential verse-number marker, or the end of the chapter's text for the
   last verse.
4. If the citation covers multiple verses, repeat for each and concatenate
   in order.
5. **This is unverified.** After producing a result this way, say so in the
   output (see section 4) and ask the user to spot-check it against the real
   page at least once.

## 3A. Resolve publication references — HTML method (verified, Claude Code)

WOL's own search endpoint parses publication citation strings for you — do
not try to guess or compute the internal numeric document IDs yourself.

1. URL-encode the citation exactly as written (keep the code, date/issue, and
   page marker; the paragraph marker isn't needed for resolving the article,
   only for picking which paragraph to extract afterward):
   `curl -s "https://wol.jw.org/<lang>/wol/l/r<region>/lp-<code>?q=<encoded citation>"`
2. **Check for success before doing anything else.** Look for links matching
   `href="/<lang>/wol/d/r<region>/lp-<code>/<docid>`. If **none** are found,
   the citation did not resolve — **stop and report it as not found**. Do not
   fall back to guessing the content from general knowledge. (Verified: WOL
   returns HTTP 200 with an empty results area for unresolvable queries — no
   distinct "not found" message, so absence of any `/wol/d/.../` link is the
   actual signal.)
3. Take the first (or only, if a page number was given) resolved docId and
   fetch the article: `curl -s "https://wol.jw.org/<lang>/wol/d/r<region>/lp-<code>/<docid>"`
4. Capture the article title from `<title>...</title>` (strip the
   ` — ΔΙΑΔΙΚΤΥΑΚΗ ΒΙΒΛΙΟΘΗΚΗ...` / site-name suffix) — always show it
   alongside the resolved text so the citation's source is traceable.
5. Extract the requested paragraph(s) by the **printed** paragraph number,
   which is `data-pnum="<N>"` on a `<span class="parNum">` inside the `<p>` —
   NOT the `id="pN"` / `data-pid="N"` attributes, which are raw DOM order and
   do not match the article's own numbering (headings, overview questions,
   and footnotes each consume their own `<p>` without being numbered
   paragraphs).

   ```python
   idx = html.find(f'data-pnum="{n}"')
   p_start = html.rfind('<p ', 0, idx)
   p_end   = html.find('</p>', idx)
   chunk = html[p_start:p_end]
   chunk = re.sub(r'</p>\s*<p[^>]*>', ' ', chunk)   # join wrapped sentence-<p>s
   text = re.sub('<[^>]+>', '', chunk)
   ```
6. For a paragraph *range* (`¶6-8`), repeat step 5 for each number in range.
7. **Not every publication has `data-pnum`.** Older material (pre-~2008) and
   lesson/outline-format publications often have no paragraph numbering at
   all. If `data-pnum` is absent, or the citation gives a **bare number with
   no `σ.`/`παρ.` label** (e.g. `w99 1/5 7`), treat that number as a **page**,
   not a paragraph:
   ```
   start = html.find(f'id="page{n}"')
   end   = html.find(f'id="page{n+1}"')  # or html.find('class="pswp"') if absent
   ```
   Page markers are `<span id="page<N>" class="pageNum" data-no="<N>">` and
   can appear **mid-sentence** inside running text (the page break doesn't
   respect paragraph boundaries) — extract everything between the two
   markers regardless of how many `<p>` tags it spans.
8. **Report exactly what you resolved — don't reconcile it with what the
   citation implied.** A resolved document's own internal numbering can
   legitimately disagree with the number in the citation. Example: citation
   `th 23` resolved to a document internally titled "ΜΕΛΕΤΗ 20" (Study 20) —
   the "23" was a *page* number that happens to fall inside lesson 20, not
   "lesson 23." Always surface the document's actual title/heading as fetched
   and flag any such mismatch explicitly rather than silently relabeling it
   to match the user's citation.

## 3B. Resolve publication references — plain-text method (DRAFT, unverified)

Use only when 0.5 determined you don't have raw HTML access.

1. Fetch the search URL exactly as in 3A step 1:
   `https://wol.jw.org/<lang>/wol/l/r<region>/lp-<code>?q=<encoded citation>`
   with your text-capable tool. In manual testing (via curl) this page's
   *raw HTML* already embeds a substantial excerpt of the matched article —
   likely enough of the surrounding paragraphs to be visible in a
   text/markdown conversion too, without a second fetch.
2. Look for the resolved title in the returned text (it's the prominent
   heading near the top of the results). If nothing resembling a matched
   article/publication appears at all — genuinely empty or generic "search"
   boilerplate only — treat as **not found**, same rule as 3A step 2.
3. If your fetch tool preserves links (e.g. renders them as markdown
   `[text](url)`), look for a link whose path contains
   `/wol/d/r<region>/lp-<code>/<docid>` and fetch that URL directly for the
   full article text, then apply the paragraph-number-scanning technique
   from 2B step 2 (paragraphs are numbered the same visible way verses are:
   printed inline, increasing sequentially) to isolate the requested
   paragraph(s).
4. If your fetch tool does **not** preserve links and the excerpt from step 1
   doesn't include the specific paragraph/page requested, say plainly that
   you found the right publication/article but could not isolate the exact
   paragraph without a way to fetch further into it — do not guess at
   surrounding content to fill the gap.
5. **This whole path is unverified** — flag it in your output per section 4.

## 4. Critical rules

- **Never hallucinate.** If a Bible chapter fetch 404s, or a publication
  search returns no docId link (or no recognizable match in plain-text mode),
  report that specific reference as **"not found — could not resolve on
  wol.jw.org"** and move on to the next one. Do not paraphrase from memory or
  guess likely content.
- **Do not recurse into cross-references found inside resolved text.** A
  fetched verse or paragraph will often itself contain more citations (e.g.
  ¶8 of `w14 15/12` cites `Ησ. 60:22`) — treat those as plain text to display,
  never as further lookups to perform, unless the user explicitly asks you to
  chase a specific one.
- Respect the mode from step 0 — don't resolve Bible refs in publications-only
  mode or vice versa (but still resolve *both halves* of a combined citation
  like `Ματ 28:20· w22.07 σ. 9` when mode is "both").
- **If you used the plain-text method (2B/3B), say so explicitly in your
  reply**, e.g. "(resolved via the draft plain-text method — please
  spot-check this against the real page)". This method hasn't been validated
  against a live claude.ai session yet; treating its output as equally
  trustworthy to the HTML method would be its own form of overclaiming.

## 5. Bulk mode — extracting from a full passage/article/outline

The user can paste an entire talk outline or article. Process:
1. Read the whole text once and enumerate every distinct reference span per
   the detection rules in step 1 (de-duplicate identical citations).
2. Resolve each independently per steps 2A/3A or 2B/3B (whichever 0.5 chose).
3. Present results in the order they appeared in the source, each block
   labeled with the original citation text as written, so the user can match
   it back to the source document.

## 6. Output format

For each reference, show:
- The original citation text as it appeared in the source
- For Bible refs: verse number(s) + text
- For publication refs: resolved article/publication title + paragraph
  number(s) + text
- For anything unresolved: a clear "not found" line — never silently omit a
  failed reference from the output.
- If the plain-text method was used anywhere in the response, a one-line
  disclosure per section 4's rule — once per response is enough, doesn't need
  repeating per reference.

## Environment notes

**Claude Code / Windows (git-bash):** `curl` via the Bash tool writes fine to
`/tmp/...`, but a plain `python3` call may resolve to a native Windows
executable that cannot see git-bash's `/tmp` path — copy fetched HTML into a
Windows-path scratch directory before parsing it with a python heredoc, and
write any Greek-text output to a file and use the Read tool rather than
printing to the console (the console codepage can't encode Greek and will
crash the script).

**claude.ai:** the plain-text method (2B/3B) is a first draft written from
reasoning about how WOL renders content, not from an actual test inside a
claude.ai session. The first time it's used for real, treat any surprising or
wrong output as a bug to report back rather than a one-off fluke — this
section should be updated once real usage data exists.
