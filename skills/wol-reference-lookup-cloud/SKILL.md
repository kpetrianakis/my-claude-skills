---
name: wol-reference-lookup-cloud
description: Detect Bible and JW-publication references (Greek or English) in pasted text — a passage, article, or talk outline — and retrieve their real content strictly from wol.jw.org. Built for claude.ai / sandboxed environments where there is no shell and URL fetching is restricted to previously-surfaced links. Use when the user pastes text containing citations like "Ματθαίος 13:31, 32", "w14 15/12 σ. 7 ¶7, 8", "g16.2 p. 3", or asks to look up / check the references in a passage or outline. Supports bible-only, publications-only, or both.
---

# WOL Reference Lookup (cloud / sandboxed environments)

Resolves Bible and JW-publication references **exclusively from wol.jw.org**.

> Companion skill: `wol-reference-lookup` is the Claude Code version, which
> uses `curl` + HTML parsing and is more precise. Use that one wherever a
> shell with network access exists. This one exists because that method is
> impossible here.

## 0. The two constraints that shape everything

Both were confirmed in a real session — design around them, don't fight them:

1. **Fetching is provenance-gated.** The URL-fetch tool only accepts URLs that
   already appeared in a *prior search result* or that the *user pasted into
   the conversation*. A URL you constructed yourself — even a perfectly valid
   WOL chapter URL — will be **refused**. Do not build URLs and try to fetch
   them; that loop burns dozens of calls and resolves nothing.
2. **Search reaches the whole web, not just WOL.** A plain search for a Bible
   citation surfaces biblehub, biblegateway, and other translations. Those are
   **not acceptable sources** for this skill (see §1).

## 1. SOURCE EXCLUSIVITY — the rule that overrides everything

**Every piece of content you output must come from a wol.jw.org URL.**

- Every search **must** be site-restricted: include `site:wol.jw.org` in the
  query. No exceptions.
- Before using *any* snippet or fetched page, **check its source URL**. If the
  host is not `wol.jw.org`, discard it — do not quote it, do not paraphrase
  it, do not use it to "confirm" anything.
- Another translation of the same verse is **not** a substitute. Neither is a
  JW-adjacent site, a mirror, a quotation of WOL on a third-party page, or
  your own memory of the passage.
- If wol.jw.org yields nothing for a reference, that reference is
  **unresolved**. Say so. That is a correct outcome, not a failure to work
  around.

## 2. Mode

- **bible** — scripture citations only
- **publications** — JW-literature citations only
- **both** (default) — including combined citations like
  `Ματ 28:20· w22.07 σ. 9 ¶6-8` (two independent lookups, presented together)

## 3. Detect references

**Bible**
- `<Book> <chapter>:<verse>` — `Ματθαίος 13:31, 32`, `John 3:16`, `Ησ 60:22`
- Abbreviations, Greek and English: `Ησ`, `Ματ`/`Ματθ.`, `Απ`, `Κολ`, `1Θε`,
  `Παρ.`, `Φλπ`, `Λου`, `Matt.`, `Isa.`, `Rev.`, `1 Thess.`… use your knowledge
  of the 66 books.
- `·` / `;` separate citations: `Ησ 32:1, 2· 40:11` = two lookups.
  `,` separates verses in one chapter: `13:31, 32` = verses 31 and 32.
- Strip leading imperatives: `Διαβάστε`/`Διάβασε`/`Read`/`Παράβαλε`/`See`.

**Publications** (Latin-letter codes even in Greek text)
- Modern monthly: `<code><YY>.<MM>` — `w22.07`, `g16.2`
- Pre-2016 semi-monthly: `<code><YY> <DD>/<MM>`, **day/month order** —
  `w14 15/12`, `w08 15/7`. Wrong order breaks resolution.
- Page: `σ.`/`σελ.`/`p.`/`pp.` — Paragraph: `¶`/`παρ.`
- **Bare number, no label** (`w99 1/5 7`, `th 23`) = a **page**.
- Never reject an unfamiliar code — `w`, `g`, `km`, `mwb`, `wp`, `yb`, `lv`,
  `th`, `be`, `ia`, `rr` and many more exist.

## 4. Plan before searching

1. Enumerate every reference in the text.
2. **De-duplicate and group by chapter / document.** `Ματ 13:31` and
   `Ματ 13:44` are one chapter — one lookup, not two. Several paragraph
   ranges in one article are one lookup.
3. Work group by group, never repeating a query you've already run.

## 5. Retrieval — one group at a time, strict budget

**Budget per group: 1 search, plus 1 fetch only if a wol.jw.org URL surfaced.
Then stop and record the outcome.** No reworded retries, no second angle. If
that budget doesn't resolve it, it's unresolved — move on immediately. (In the
session that motivated this skill, unbudgeted retrying consumed enormous
effort and still left most references unresolved.)

### Bible references

1. Search, site-restricted, in the **citation's own language**:
   `site:wol.jw.org <Greek book name> <chapter>:<verse>`
   e.g. `site:wol.jw.org Ματθαίος 13:31`
   Adding `nwt` or the chapter URL pattern
   (`wol.jw.org/el/wol/b/r11/lp-g/nwt/40/13`) as literal query text sometimes
   surfaces the exact chapter page — worth including, still one search.
2. **Read the returned snippets before anything else.** WOL chapter snippets
   frequently contain the verse text outright. If a wol.jw.org snippet clearly
   contains the verse, you are done — no fetch needed. This is the cheapest and
   most reliable path, and it is how most successful lookups actually resolve.
3. If the snippets are insufficient **and** a wol.jw.org chapter URL appeared
   in the results, fetch that one URL. Extract the requested verse(s) by their
   inline printed numbers: verse numbers appear in **strictly increasing
   order**, so track the last confirmed number and accept only the next one —
   this prevents a cross-reference inside the text (e.g. "(1 Κορ. 14:9)") from
   being mistaken for a verse marker.
4. Otherwise: unresolved.

### Publication references

1. Search, site-restricted, combining the citation with its distinguishing
   words: `site:wol.jw.org <code> <date/issue> <a distinctive phrase if known>`
   e.g. `site:wol.jw.org w14 15/12 Σκοπιά`
2. **Read the snippets first** — WOL article snippets often carry the
   paragraph text directly. If the cited paragraph's text is visible in a
   wol.jw.org snippet, use it and stop.
3. If a wol.jw.org article URL (`/wol/d/...`) surfaced and you still need the
   paragraph, fetch that URL once. Paragraphs are printed with their numbers
   inline and increase sequentially — locate the cited number and read to the
   next one.
4. **Locating an article is not resolving the citation.** If you found the
   right article but could not obtain the cited paragraph's text, report it
   as *"article located, paragraph text not retrieved"* — never present the
   article title alone as though the reference were resolved, and never
   summarise what the paragraph probably says.
5. Always report the article's real title as it appears on WOL. If the
   document's own numbering disagrees with the citation (`th 23` → a document
   headed "ΜΕΛΕΤΗ 20", because 23 was a page inside lesson 20), surface the
   real title and flag the mismatch.

## 6. Critical rules

- **Never hallucinate.** No search results, no usable snippet, paragraph not
  found → **"not found — could not resolve on wol.jw.org"**. Never fill a gap
  from memory or from another site (§1).
- **Never substitute another language edition.** A Greek citation is resolved
  by the Greek WOL page or not at all. Do not offer English text in place of
  a Greek citation — not even labelled. Report it unresolved.
- **Don't recurse into cross-references** found inside retrieved text — those
  are text to display, not new lookups, unless the user explicitly asks.
- **Extract only what was cited** — the specific verses or paragraphs, never a
  whole chapter or article.
- Respect §2 mode — but resolve *both halves* of a combined citation in "both".

## 7. Output

Per reference, in source order:
- The original citation as written
- Bible: verse number(s) + text
- Publication: real article title + paragraph/page number(s) + text
- Unresolved: an explicit line saying so, and briefly why (nothing on WOL /
  article located but paragraph not retrieved / Greek page not reachable)

Then a compact status table: resolved ✅ / partial ⚠️ / unresolved ❌ per
reference, so gaps are visible at a glance.

Close with one line noting content came from wol.jw.org search results and is
worth spot-checking — this method is less exact than the Claude Code version.
