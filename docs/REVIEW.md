# Review — the whole project after M12

Date: 2026-09-27, at commit `b049cc9` (65 commits). Scope: `qc.q`, `t/`, `tools/`, `examples/` (including
`examples/mdp/`), `spikes/`, and every document. Method: four independent read-throughs (library, tests, docs,
worked example), each claim verified against the file or by running q; measurements taken on this machine. Nothing
has been changed. Every item has a box so this can drive a cleanup pass the way `AUDIT.md` and `AUDIT2.md` did.

Status: **closed** — every task in §8 is ticked or carries its decision; the tree is green (1492 tests) at the closing commit.
Moved from the top level to `docs/` on closing; its `file:line` references and the measurements in §0 are to the tree it
was written against (`DESIGN.md` was at the top level then and is `docs/DESIGN.md` now).

## 0. The state of the tree

| measure | value |
|---|---|
| `q t/run.q` | **1461/1462** — red (see 1.1); ~115–125 s wall |
| of which `t/doctest.q` | 71 s; `examples/mdp/LOG.md` alone 64–75 s (35 transcript blocks, one of 9 s) |
| of which `t/examples.q` | 22 s; `examples/mdp/run.q` ≈ 17–21 s at n=300 |
| `sh spikes/run.sh` | 27 spikes, all pass, 31 s |
| `qc.q` | 527 lines; 13 lines over 200 chars |
| docs | README 134, EXAMPLES 260, COOKBOOK 194, DESIGN 1051, LOG 1117, AUDIT 420, AUDIT2 336 lines |
| `.qc/` | 30 failure-db files, gitignored, written by the suite |

## 1. Must fix (the tree is red or misleading)

- [x] **M1** **1.1 `examples/mdp/run.q` flakes and the flake is sticky.** `props.q:25` `round_trip_realises_nothing`
  asserts `0=.mdp.pos[s;`real]` exactly; at `s=`A q=100 p=81.94471613838644` the average `(p*100)%100` is one ulp
  off and `real=-1.42e-12`. Fails at roughly 1 seed in 2 at n=300 (verified: seeds 16–22 of 1..30). Because
  `run.q` uses the default failure db, the first failing CI run wrote `.qc/348cbc…` and every later run replays it
  "after 0 tests", so `t/examples.q:17` has failed on every suite run since. Fix: the same `1e-9` tolerance the
  neighbouring properties have (`props.q:23-24`), and decide whether `run.q` should run with `db:`` ` `` (the db
  belongs to a developer's session, not a CI script). Also: `t/examples.q`'s FAIL line does not print the child's
  output, so nothing said which property failed or that it was a replay.
- [x] **M2** **1.2 The suite's own output hides failures.** `t/readme.q` echoes ~44 lines of generator definitions
  (README's bare-expression block `README.md:21-25` loaded via `system"l"`), and `t/run.q:16` `show`s the summary
  at the default 25-line console, so `stop.q`/`tables.q`/`types.q` rows print as `..`. A FAIL line scrolls off
  before the summary. Fix: `\c` before the summary; load README blocks with output suppressed or assign them.
- [x] **M3** **1.3 `t/examples.q:15` skips `sm_ipc.q` with `-1 …` and records no test**, so a machine that cannot start a
  child q shows a clean file.

## 2. Library (`qc.q`)

### 2.1 Conventions
- [x] **L1** `qc.q:51,53,85` — `i+:1`, `nch+:1`, `dp+:1` reach globals only because `+:` is not a declaration; other
  globals use `::`. Two idioms; a later `i:i+1` would silently make a local. State the convention (or use `::`).
- [x] **L2** `qc.q:423` — `pdisc` is an implicit-`x` lambda whose `select … where x` relies on the column `x` shadowing
  the parameter (pitfall 4).
- [x] **L3** `qc.q:252,358,369` — `and`/`or` where C2 asks for cond chains (both sides are safe today; `qc.q:300`'s own
  comment says "a cond chain, not and (C2)").
- [x] Checked and clean: reserved names (`t/names.q` passes), `,:` on undefined globals, typed amends,
  each-over-triadic (all eight `f'[a;b]` sites project to two args), q-sql globals (`qc.q:321` uses `.qc.`),
  trailing comments swallowing code, error prefixes (all 60 signals carry `qc:`/`qc.`).

### 2.2 Duplication (no dead code found; every top-level name is referenced)
- [x] **L4** `qc.q:318-319` `wil`/`wlo` differ by a sign; `qc.q:154,170` `dbl`/`dble` differ by constants; `qc.q:160,168`
  `gid` inlines `gidf`'s body; `qc.q:138-146` `sub`/`rec` vs `subb`/`recb` duplicate the child loop.
- [x] **L5** `qc.q:124,126` — `bulk`/`btab` repeat the `nr` cap verbatim; `qc.q:118,275` — the stop-bit law appears in
  `lst` and `sm`; `qc.q:212,234` — the `CS/UR/US` initialiser triple twice; `qc.q:243,251` — `{$[`=mark x; uniq x; x]}`
  twice; `qc.q:404-405` — `dl[v;s;e]` is `pt[v;s;e;()]`.
- [x] **L6** `qc.q:277-281` — `note smnote R; h[`fini][]` four times, and `:280` runs `fini` *before* `note` where the
  others run it after.
- [x] **L7** `qc.q:476-477` vs `:492-501` — `kind` and `df` are parallel type dispatches over the same shapes.

### 2.3 Robustness
- [x] **L8** `qc.q:274-279` — `sm`'s `fini` is skipped when `pre` raises, when the decision-bit/command-index `ch` raises
  (`qc.overrun`/`toolarge`/`toodeep`; only `gen` is trapped), or when `upd` raises. Verified: `strict[enlist 1]`
  over an `sm`, and a raising `upd`, both leave the fini counter at 0. C9 says fini runs "on every way out".
- [x] **L9** `qc.q:91` — `top`'s handler restores `run dp st sz` but not `mn sh i P`: after a failed `.qc.minimal`,
  `.qc.mn` stays `1b` (harmless because every entry resets; weaker than C6 claims).
- [x] **L10** `qc.q:225-226` — `probe` saves 12 globals but not `sz bs N LX`; a `small` that raises inside a probed
  generator leaves `sz` halved for the rest of that example (`qc.q:104` restores only on success).
- [x] **L11** `qc.q:468-469` — `shr` leaves `sspec sprop cv cC cE co K` holding the last failing spec/property/tables after
  `chk` returns; `tidy` does not clear them (a property closure kept alive across runs).
- [x] **L12** `qc.q:109` — an error inside `such`'s `draw g` leaves the `try` span open on `st`/`dp` until the next reset.
- [x] **L13** Vague usage errors: `"qc: range"` ×3 (`qc.q:46,47,157`), `"qc: cmds"` ×3 for three different faults
  (`qc.q:269,270`), `"qc: cfg"` (`qc.q:299`) — every other usage error says what was wrong.

### 2.4 Readability (the five densest places)
- [x] **L14** `qc.q:269` (289 chars) — `sm`'s first line: five validations and a four-way cond; `sm` (269-284) nests four
  traps each re-implementing fini+note.
- [x] **L15** `qc.q:234` (278 chars) — `tabx`'s uniq setup uses `h` left of the `where h:` that defines it.
- [x] **L16** *(left as is, by decision in G4)* `qc.q:358` (268 chars) — `chk1` line 2; the loop condition at `:362` is a seven-branch cond, `:370` six.
- [x] **L17** *(left as is, by decision in G4)* `qc.q:344-350` — `tput`: two nested conds inside a while, five table amends per iteration, a second while.
- [x] **L18** `qc.q:69,206,227` — one-line functions with 150–200-char trailing comments.

### 2.5 Stale comments
- [x] **L19** `qc.q:50` "rand is called only by fresh and its helpers unif and mix" — `freshn/unifn/mixn` (63-66) also
  draw via `n?` since M8. `qc.q:111-114` two comment blocks restate the same rule. `qc.q:475` "eight shapes" but
  `kind` returns nine. `qc.q:305` `FS` includes `qc.inv` while DESIGN C14 lists only `qc.eq qc.post qc.run`.

## 3. Tests (`t/`, `tools/`)

### 3.1 Coverage gaps
- [x] **T1** `.qc.dble` (`qc.q:170`) has zero tests and zero doc mentions. `.qc.discard[]` and `.qc.label` are never
  called directly in `t/`. `.qc.check`/`.qc.checks` (default-config forms) run only inside `.qc.main` in the child
  scripts of `t/integ.q:21-22`.
- [x] **T2** Smoke-only: `chrc`, `gidf` (registry row only), `spc`, `strc`, `lin`, `rerun` (round-trip only), `val` (no
  shrink test). No test drives cfg keys `tries`, `depth` (one toodeep case), `disc`, `rows`. No test of `report`
  with `v>1` (`qc.q:519` backtrace line) or the `stale:` line (`qc.q:520`).

### 3.2 Brittleness
- [x] **T3** `t/scale.q:9,25` wall-clock bounds (0.5 s, 5 s) are machine-dependent; `t/bench.q:6-8` pins per-case attempt
  caps and a 1200 total (a deliberate guard, but any shrinker reorder trips it).
- [x] **T4** `t/run.q:4` `.t.t` accepts an empty boolean vector (`all 0#0b` is `1b`) silently; only an empty general
  list is flagged. Nothing hits it today; any `x within r` over an empty draw would pass vacuously.
- [x] **T5** Failure text is name-only: long and-chains (`core.q:75`, `review.q:20-24` nine clauses, `tables.q:61`) do
  not say which conjunct broke, and no value is printed.
- [x] **T6** `core.q:123-124`, `reportx.q:11` rely on right-to-left evaluation to assign in the right operand and read in
  the left — correct, reads as a bug.
- [x] **T7** Every choice-recording change rewrites ~82 pinned-seed transcripts (README 2, EXAMPLES 16, COOKBOOK 11,
  DESIGN 2, LOG 51). Known and accepted (C8), but the number is now large enough to state in DESIGN.

### 3.3 Duplication
- [x] **T8** 15 files repeat `q:.qc.cfg,`v`n`seed`db!(0;100;7;`)` / `.qc.new[]; .qc.cfg[`v]:0`, 17 end with
  `.qc.cfg[`v]:1`, although `t/run.q:12` restores cfg and calls `new` per file. Move `q` into `run.q`.
- [x] **T9** `D:{[g;n] …}` in `dist.q:6` and `tables.q:6`; `depth/nodes` in `shrink.q:25-26` duplicate `.b.depth/.b.nodes`
  (`spikes/bench.q:8-9`); the 14 shrink minimums in `shrink.q:6-24` are re-asserted by `bench.q`.
- [x] **T10** Scratch-dir boilerplate in `bench.q`, `shrink.q`, `integ.q:20`, `doctest.q:4`, `readme.q:9`; child-q
  runner in `examples.q:4` and `integ.q:23`; two fence parsers (`doctest.q:5` vs `readme.q:5`).
- [x] **T11** The same fact asserted 2–4×: record/replay (`core.q:98-104`, `types.q:78-81`, `sm.q:63-65`, contracts
  c3/c4), canaries (`core.q:123-126`, `types.q:82`, `sm.q:60`, `tables.q:60`, c10), exhausted-constant
  (`core.q:135,139` vs `stop.q:13,36`), cover 950/800/910 (`stop.q`, `outcomes.q:22`, `report.q`, `reportx.q`),
  eq `order` row (`report.q:36` vs `review.q:15`).

### 3.4 Harness
- [x] **T12** `t/run.q:11` splits statements by leading space: a column-0 `}`/`)` closer would split a lambda (none today).
- [x] **T13** All-or-nothing loops: `contracts.q:21-33` (11 tests × 87 rows in one `each`), `bench.q:7`, `ranges.q:21-22` —
  one raise records one "line N raised" and the remaining rows never run.
- [x] **T14** `t/run.q:14` loads every entry of `` key `:t `` except `run.q` (a stray `foo.q~` would be evaluated); test
  globals (`q D S F R G …`) live in the root and leak between files (`0gens.q`→`contracts.q`/`outcomes.q` depends on
  alphabetical order, deliberately).
- [x] **T15** `t/names.q` checks reserved words, shadowing and double definitions in `qc.q` only; `examples/**`,
  `tools/`, `spikes/`, `t/` are unchecked — and the worked example hit `vs`, `inv`, `asof` as names four times.
  `t/docs.q` name-checks DESIGN/README/COOKBOOK/LOG but not EXAMPLES.md.

### 3.5 Doctests
- [x] **T16** Blind spots worth stating in DESIGN: prose claims; timing; stdout vs stderr (merged); the child's exit code;
  any statement ending in `;` or an assignment is silenced (`doc_child.q:6`) so a wrong value can hide behind a
  trailing `;`; `\`-prefixed lines are skipped (`doc_child.q:7`), so `q)\l x.q` is a silent no-op; output beyond
  25×80 is compared only up to `..`; fences with trailing space/CR are silently not blocks.
- [x] **T17** Cost: `LOG.md` is ~60% of the suite's wall clock (three `.qc.chk[300;.qc.sm …]` blocks and several
  100-test machines). Options: a `QC_DOCTEST=fast` mode that skips blocks tagged slow; run the LOG doctest in
  `t/examples.q`'s child alongside `run.q`; or shorten the LOG's budgets where the transcript does not depend on them.

## 4. Documentation

### 4.1 Stale or wrong
- [x] **D1** `README.md:86` result keys omit `stop` (`qc.q:324`; `DESIGN.md:306` is right).
- [x] **D2** `README.md:4-5` "3.5 or later, unverified" vs `DESIGN.md:3-4` "4.0 or later … now stated as such".
- [x] **D3** `DESIGN.md:122,243` still say an empty `tab` has untyped columns; `DESIGN.md:893` (M12) and `qc.q:222-227`
  say otherwise. §1.3 is stale.
- [x] **D4** `DESIGN.md:11` contents line omits §5 (`:1004`). `DESIGN.md:322-324` lists 11 cfg defaults; `qc.q:7` has 15
  (`nmax clamp name rows` missing; `EXAMPLES.md:259` prints all 15 unglossed).
- [x] **D5** `DESIGN.md:545-546,712` say doctests cover "README, EXAMPLES and this file"; `t/doctest.q:15` runs five files.
- [x] **D6** Counts: `DESIGN.md:1049` test count stops at 1034; `AUDIT2.md:11` says 1450; today 1462.
- [x] **D7** File lists: `README.md:127-134` omits EXAMPLES.md, AUDIT*.md, `tools/`, `.qc/`; `DESIGN.md:534-552` omits
  AUDIT*.md and `.qc/`; `DESIGN.md:3-4` names README/COOKBOOK but not EXAMPLES.md or LOG.md.
- [x] **D8** Public names README never mentions: `bit bool chr chrc const dble gid gidf recb sized small spc strc symc
  tabr`; runner names absent: `lin strict label discard lf nch mustc chks new AZ`. `symc tabr bool lf nch` are
  used in COOKBOOK/EXAMPLES without introduction; `gidf` appears in no document.
- [x] **D9** Ordering: conventions run C16, C19, C20, C21, C18, C17, C22 (`DESIGN.md:662-726`); pitfall 32 precedes 31
  (`:967,970`); review round 10 precedes 9 (`:1022-1023`).
- [x] **D10** `DESIGN.md:797` "Further convention work waits for evidence from M2" — plan tense inside a Done milestone.
- [x] **D11** `AUDIT.md:3` "401 lines", `AUDIT2.md:3` "511 lines"; both files' `file:line` references are against dead
  trees; `AUDIT2.md:19` "no C22 exists" and `AUDIT.md:379` "tab's empty table stays untyped" are now false with no
  superseded marker.

### 4.2 Structure
- [x] **D12** `DESIGN.md` (1051 lines) has one contents line and no anchors; §1.3's generator table is followed by 110
  lines of rationale before the runner; runner entry points exist only as prose (`:283-290`); C1–C25 and the 45
  pitfalls have no index line.
- [x] **D13** Three overlapping histories: §2 validation log, §3 milestone plan, §5 review rounds, plus
  `AUDIT.md:361-420` restating M7–M11. Proposal: `docs/HISTORY.md` (or `docs/audits/`) holds §3, §5, AUDIT.md,
  AUDIT2.md and this file once closed; DESIGN keeps §1, §2, §4; README gets a "which file for what" paragraph.
- [x] **D14** Repeated transcripts: sorted-list in README:9-12, EXAMPLES:122-126, DESIGN:449-458; JSON byte in
  EXAMPLES:55-60 and COOKBOOK:146-151. `COOKBOOK.md:3,8` repeat one sentence.
- [x] **D15** Missing: none — every finding is covered.

### 4.3 Onboarding
- [x] **D16** README gives `\l qc.q` and, only inside the Files block, `q t/run.q` / `sh spikes/run.sh`. Nothing on
  copying `qc.q` into a project, that `\l qc.q` is cwd-relative, that doctests need `q` on PATH
  (`t/doctest.q:10`), that the suite writes `./.qc/`, spawns child q processes and takes two minutes, or that the
  measurements are macOS-only (`DESIGN.md:754`).
- [x] **D17** *(the owner chose MIT: `LICENSE` at the top level, a one-line notice in `qc.q`'s header since the file travels alone, and README names the licence)* No LICENSE file and no licence mention anywhere.

### 4.4 Terminology
- [x] **D18** "spec" vs "generator" (README:17-19 vs :54-55; DESIGN:41 vs :110): the distinction (spec = anything `draw`
  interprets; generator = a function) is stated nowhere. "tests"/"examples"/"inputs" and
  "witness"/"counterexample" are used interchangeably. The `check`/`chk` naming rule (`DESIGN.md:84-88`) is not
  in README, where `chk`, `lst`, `symc`, `tabr` first appear.

## 5. The worked example (`examples/mdp/`)

### 5.1 The final system
- [x] **X1** **It is a patch stack, not a source.** `22_rename.q:11-12` redefines `upd` wholesale (a copy of `16_upd.q:5`
  plus one clause) and `:22-23` wraps `13_eod.q`'s `eod`; `mdp.q:6` gives no hint that step 22 overrides 16 and
  13. Decide: either say so in `mdp.q`, or add a `mdp/src/` with the final pieces as plain files and have `mdp.q`
  load those (the steps stay for the log).
- [x] **X2** Namespace split is explained where it starts (`13_eod.q:6`, `17_amend.q:4`) but `22_rename.q` leaves
  `\d .mdp` at `:21` and defines `.mdp.eod0`/`.mdp.eod` in the root with no comment; the reader must hold pitfall
  26 both ways (`22_rename.q:13` relies on the from-table resolving in the namespace, `13_eod.q:15` on the root).
- [x] **X3** `mdp.q:5-6` loads by relative path with nothing enforcing the cwd; after the first `.mdp.eod` the cwd *is*
  the HDB (`13_eod.q:13`), so any later relative `\l` fails — `run.q` survives only because it loads everything
  first. `eod` should restore the cwd (pitfall 44) or `mdp.q` should resolve paths from `.z.f`.
- [x] **X4** Hard-coded and duplicated constants: start day 2024.01.02 in `13_eod.q:9`, `props.q:9`, `08_gen.q:8`,
  `24_sm.q:13`; session 09:30–16:00 in `08_gen.q:8` and `24_sm.q:14`.
- [x] **X5** Two `mktemp -d` per run (`mdp.q:7`, then `24_sm.q:15` silently overrides `.mdp.hdb`); neither is removed
  (four new `$TMPDIR/tmp.*` per `q run.q`). `mktemp`, `rm -rf …/*`, `1_string hdb` are unix-only and undocumented.
- [x] **X6** `17_amend.q:7-8` `ontrade`: a trade timed *after* today is stored nowhere yet returned enriched — silent
  loss. `17_amend.q:5,12` detect "a day on disk" by `` `trade in key `. `` — the stale-map test of entry 19.
- [x] **X7** `22_rename.q:10` `rename` validates nothing (unknown `o` inserts an all-null `inst` row; `n` may exist; `e`
  may be past); `:11` `upd` on zero rows makes `sym` a general list (pitfall 45, guarded in the oracle at
  `24_sm.q:24` but not here); `10_pos.q:8` an unknown sym gives null `mult` → null `real`, silently.

### 5.2 The log
- [x] **X8** Tally prose vs table: "six mistakes in my test code" (`LOG.md:1085-1086`) enumerates seven; "keyword as a
  parameter three times" is four by the log's own account (`vs` twice, `inv`, `asof`).
- [x] **X9** Wrong cross-references: table row 1 cites entry 2 for the canon cycle (it is entry 3, `:66`); entry 24 says
  "the tick property (entry 3)" (it is entries 1–2).
- [x] **X10** Overclaims to soften: row 1 "found by: property" (`:99` says the run hung with no report); ":1083 each on a
  one- or two-row example" (entries 14–15 fell on the empty day); ":1084 could not have fallen to anything else"
  (a two-position unit property over `mergepos` would find it — the honest claim is "no existing piece's property
  could"); ":6 Nothing here is planted" needs "except the labelled sabotages of entries 20 and 23"; ":1003 Seeds 8
  and 9 pass (not shown)" is unverifiable in a doctested log — show it or drop it.
- [x] **X11** Width: 70 lines exceed 120 columns; sm traces reach 495–593 chars (`:589,608,691,799,847,907`) because `res`
  prints whole enriched tables, while the classify tables in the same blocks are cut at 80 with `..` (the `bar`
  column lost). A library option to print `res` through `fmt`'s width, or `\c` in the transcripts, would fix both.
- [x] **X12** Boilerplate: entries 17–24 repeat 7–9 `system"l steps/…"` lines in ~15 blocks (~110 lines); a loader file
  per step set would halve the second half.
- [x] **X13** Never explained for a newcomer: the `qc.eq` `path why a b` table (first at `:119`) and the `rerun:` choice
  vectors. Entry 4 mixes library history (`commit a9ea097`, `t/names.q`) into the pipeline story.

### 5.3 The harness (`24_sm.q`, `sm.q`)
- [x] **X14** The oracle is built from the system: `enrichb` (`24_sm.q:22`), `barsb` (`:23`), `canon` (`:24,58-61`),
  `round` and `inst[;`lot]` (`:59-60`, after `rename` has mutated `inst`). The machine cannot catch a bug in the
  as-of join, the batch bar select, rename resolution, tick rounding or lot sizing. Defensible because `props.q`
  covers those — but with no renames, busts or day boundaries. The log should say this plainly in the closing.
- [x] **X15** Postconditions: `fill` is `1b` (`:52`); `bust` `not i in trade`seq` (`:56`) is trivially true for a past-day
  bust, so a broken partition rewrite is caught only by a later `query` — exactly why entry 20 needed 300×60;
  `rename` (`:57`) only checks an `inst` row exists; `trade`/`late` (`:50-51`) compare `bid` only. The invariant
  (`:67-71`) covers today only; nothing on disk is in it.
- [x] **X16** **Seam label bug**: `sm.q:4` `old_name_used_after_its_rename` indexes `r[`arg][1]` for `fill`, but a fill's
  arg is `(sym;side;qty;px)`, so for fills it canonicalises `` `buy``/`` `sell`` and fills never count.
  `late_timed_on_an_earlier_day` is tautological under the final generator (every late trade is yesterday); its
  33% is the command frequency, not a seam. `sm.q:4` is one ~1,000-character line.

### 5.4 The step files
- [x] **X17** 30 files for "24 steps": 01–04, 07, 08 each carry two files; each piece skips numbers (upd 14/16, sm
  15/18/19/21/23/24). The number is a global clock but nothing says so — a `steps/README` line would.
- [x] **X18** First versions (`07_bars`, `08_pos`, `11_eod`, `14_upd`, `15_sm`) say only "step N"; the 4-line piece
  description is copied verbatim into 08/09/10_pos, 11/12/13_eod and all six sm files (drift risk); `03_gen.q` vs
  `04_gen.q` differ only in comments; `07_gen.q` ⊂ `08_gen.q`.
- [x] No orphans: every step is named in LOG.md at least once.

### 5.5 `run.q` and its test
- [x] **X19** See 1.1. Also: `.qc.main` seeds from the clock and prints a per-property seed, so a CI failure *is*
  reproducible with `.qc.chk[`n`seed!…]` — but the classify tables in that output are cut at 80 columns
  (`ok #..`); `run.q` should set `\c` for CI logs.

## 6. Housekeeping
- [x] **H1** `AUDIT.md`, `AUDIT2.md` are closed, dated snapshots with dead line references; move them (and this file when
  closed) under `docs/` and keep the §5 rows in DESIGN as pointers.
- [x] **H2** `.qc/` is written by the suite and by `run.q` into the repo root (gitignored). Say so in README; consider
  `db:`` ` `` for `t/` and `examples/*.q`, or a `.qc/` under `$TMPDIR` for tests.
- [x] **H3** Two `mktemp` HDBs and one doctest scratch dir per run are left in `$TMPDIR` by `run.q`; `t/doctest.q` and
  `t/readme.q` clean theirs.

## 7. What is sound (checked, no action)

The library has no dead code and no reserved-word collisions; every `,:` target is pre-defined; every each-both
over a triadic is projected; all signals carry the `qc` prefix. The spikes all run. The failure db is
gitignored. Every step file is referenced by the log; every changed step's header says what changed and why. The
doctest mechanism holds the log to its transcripts — the flake in 1.1 was caught by the suite, which is the point
of having `run.q` in it, and the sticky replay is the failure db doing its job in the wrong place.

## 8. The cleanup checklist

One task is one commit unless it says otherwise. Each task names the findings it closes; §9 checks that every
finding is named. Tick a task here and its findings above when the commit lands.

### A. Make the tree green and its output honest
- [x] **A1** `props.q` round-trip property gets the `1e-9` tolerance its neighbours have; `run.q` runs with the
  failure db off (`.qc.cfg[`db]:`` ` ``) and `\c` widened for CI logs; the stale `.qc/` entry is removed by
  hand once. (M1, X19, H2 for `run.q`)
- [x] **A2** `t/examples.q` prints the child's last lines on a FAIL, and records a skipped `sm_ipc.q` as a test
  that says "skipped: no child q" rather than nothing. (M1's reporting half, M3)
- [x] **A3** `t/readme.q` loads README's bare-expression blocks without echo (assign the block's lines, or
  redirect the console); `t/run.q` sets `\c` before the summary and prints the FAIL lines again after it. (M2)
- [x] **A4** `t/run.q` loads only `*.q` from `t/`; `.t.t` treats an empty boolean list as a failure ("no cases"),
  and prints the value when a test's argument is not a boolean. (T4, T14's stray-file half)

### B. The log should not be wrong about itself
- [x] **B1** `sm.q` seam label for fills uses `r[`arg][0]`; the tautological `late_timed_on_an_earlier_day` label
  is dropped or replaced by "late trade for a day with a bust in it"; the one-line `seams` becomes a readable
  multi-line definition. Regenerate the affected transcripts (entry 23's labelled run is in `LOG.md`, not `sm.q`,
  so only `run.q`'s output changes). (X16)
- [x] **B2** `LOG.md` closing: tally prose matches the table (seven test-code mistakes, four keyword parameters);
  cross-references fixed (canon cycle → entry 3; tick property → entries 1–2); the softened claims (found by
  writing the generator; empty-day examples; "no existing piece's property could"; sabotages named in the header;
  seeds 8 and 9 shown or dropped). (X8, X9, X10)
- [x] **B3** `LOG.md` closing gains a paragraph on what the oracle borrows from the system (`enrichb`, `barsb`,
  `canon`, `round`, `inst`) and therefore cannot catch, and on the postconditions that are weak (`fill`, `bust`
  of a past day, `trade` comparing `bid` only, the invariant covering today only). (X14, X15's documentation half)
- [x] **B4** A newcomer's two footnotes in the log: what the `qc.eq` diff table's columns mean, at its first
  appearance, and what the `rerun:` line is for; entry 4's library history moved to one sentence with a pointer to
  DESIGN. (X13)
- [x] **B5** `steps/README.md` (ten lines): the numbering is a global clock, a piece may skip numbers, `NN_gen.q`
  files are the generators at that step, which steps `mdp.q` loads; first-version headers (`07_bars`, `08_pos`,
  `11_eod`, `14_upd`, `15_sm`) say what the step introduces; the copied piece description is kept in the first
  file of each piece only, the others pointing to it. (X17, X18)

### C. The worked example's code
- [x] **C1** `mdp.q` says which steps override which (`22_rename.q` redefines `upd` of 16 and wraps `eod` of 13),
  or a `src/` directory holds the final pieces as plain files and `mdp.q` loads those. Decide and do one. (X1)
- [x] **C2** `22_rename.q` explains its namespace split (the root definitions after `\d .`) the way 13 and 17 do.
  (X2)
- [x] **C3** *(the working directory is not restored — the mapped HDB needs it; instead `mdp.q` loads by an absolute root, and pitfall 44 now says so)* `eod` restores the working directory after `\l hdb` (pitfall 44); `mdp.q` resolves the step paths
  from `.z.f` so it loads from anywhere; the `mktemp`/`rm -rf` unix assumptions are stated in `mdp.q`'s header.
  (X3, X5's documentation half)
- [x] **C4** One `hdb` per run: `24_sm.q` uses `.mdp.hdb` if set instead of a second `mktemp`; `run.q` removes
  the directory at exit. (X5, H3)
- [x] **C5** *(done for the final system: `25_final.q` defines `day0`, `opn`, `cls`, and `props.q` and `25_sm.q` read them;
  the earlier steps keep their literals because they are the history the log's transcripts load.)* The start day and session hours are defined once (`.mdp.day0`, `.mdp.opn`, `.mdp.cls` in the
  reference-data step or `mdp.q`) and read from there by `08_gen.q`, `13_eod.q`, `props.q`, `24_sm.q`. Because
  the log's transcripts load steps directly, this must not change their output — verify with the doctest. (X4)
- [x] **C6** `ontrade` signals on a trade timed after today instead of losing it; `past` tests `d in .Q.pv`
  (guarded for no HDB) instead of `` `trade in key `. ``; `rename` validates `o` exists, `n` does not, `e` is
  not past; `upd` guards the empty table (pitfall 45); `onfill` signals on an unknown sym. Each as a new step
  file (25_…) so the log stays reproducible, with a short log entry 25 recording them as review findings, not
  machine findings. (X6, X7)
- [x] **C7** Library: an option for the trace print to run `res` through `fmt` at the console width (or truncate
  cells), so sm traces stop being 500 characters wide; the classify table's `bar` column survives 80 columns.
  Then regenerate the affected `LOG.md` transcripts. (X11)
- [x] **C9** Stronger postconditions, as a new step `25_sm.q` that `sm.q` loads (the log's entry 24 keeps
  `24_sm.q`): `fill` checks the position's quantity moved by the fill; `trade`/`late` compare `bid`, `ask` and the
  rounded `px`; a `bust` of a past day checks the partition no longer holds the id; `rename` checks the `ren` row
  and the inherited `inst` row; the invariant gains one disk check (yesterday's trade count equals the oracle's)
  when a day is on disk. (X15's strengthening half)
- [x] **C8** A loader per step set (`steps/load_run1.q`, `load_run2.q`) so entries 17–24 open with one line
  instead of nine; regenerate those transcripts. (X12)

### D. Documentation: stale claims, then structure
- [x] **D-a** README: result keys include `stop`; version claim made consistent with DESIGN; Files block lists
  EXAMPLES.md, AUDIT*.md (or their new home), `tools/`, `.qc/`; the `check`/`chk` naming rule stated where `chk`
  first appears; a "spec vs generator" sentence. (D1, D2, D7's README half, D18)
- [x] **D-b** DESIGN §1: the two "untyped empty tab" sentences replaced; cfg defaults list all 15 keys with a
  gloss each; doctest coverage lists the five files; contents line includes §5; file table lists AUDIT*.md and
  `.qc/`; status line names EXAMPLES.md and LOG.md. (D3, D4, D5, D7's DESIGN half)
- [x] **D-c** DESIGN order and tense: C16–C22 in order, pitfalls 31/32, review rounds 9/10; the M2 plan sentence
  rewritten as done; test count updated and the sentence changed to "at the time of writing" so it stops rotting.
  (D6, D9, D10)
- [x] **D-d** A public-name index: one table (generators · runner · inside-a-property) in README or a new
  `REFERENCE.md`, every `dd` string in `qc.q` present; `t/docs.q` checks the table against `qc.q` both ways.
  Covers the 15 unmentioned generators and 9 runner names. (D8, D15)
- [x] **D-e** DESIGN structure: a contents block with anchors; §1.3 reference table separated from the rationale
  that follows it; the runner's entry points as a table; an index line for C1–C25 and for the pitfalls. (D12)
- [x] **D-f** History consolidation: `docs/HISTORY.md` takes DESIGN §3 and §5 and the two audits (with a
  superseded note on each), DESIGN keeps §1, §2, §4 with pointers; `REVIEW.md` joins them when closed. (D11, D13,
  H1)
- [x] **D-g** *(by decision: the first-property transcript stays in README (the front page), EXAMPLES (the tour) and
  DESIGN §1.6 (which explains the report line by line), and the JSON byte in EXAMPLES and COOKBOOK — each file is
  read on its own; COOKBOOK's repeated sentence removed.)* Repeated transcripts kept in one place each (sorted list: README only; JSON byte: COOKBOOK only),
  the others pointing; COOKBOOK's repeated sentence removed. (D14)
- [x] **D-h** README onboarding: install (copy `qc.q`, `\l` is cwd-relative), run the suite (needs `q` on PATH,
  writes `./.qc/`, spawns children, ~2 min), platform note (measurements macOS), and a LICENSE file with the
  licence named in README. (D16, D17, H2's README half)
- [x] **D-i** Terminology sweep: one word each for test/example/input and witness/counterexample across the five
  documents, stated once in DESIGN. (D18's second half)
- [x] **D-j** DESIGN: the doctest mechanism's blind spots (silenced statements, skipped `\` lines, merged stderr,
  25×80 cut, seed 7 only, fence spelling) stated where the mechanism is described, and the pinned-transcript
  count as the cost of C8. (T16, T7)

### E. Library robustness, each with a test
- [x] **E1** `sm`: `fini` runs on every exit — `pre`, the decision and index draws, and `upd` trapped like `gen`;
  one helper `bail[h;R;e]` replaces the four `note … fini` copies with one order. Tests: a raising `pre`, `upd`,
  and a `strict` overrun each leave the fini counter at 1. (L6, L8)
- [x] **E2** `top` restores `mn sh i P` on error; `probe` saves and restores `sz bs N LX`; `shr` clears `sspec
  sprop cv cC cE co K` in `tidy`; `such` closes its spans in a trap. Tests: after a failed `minimal`, `.qc.mn`
  is `0b`; after a probed generator raises inside `small`, `sz` is back; after `chk`, `sprop` is `::`. (L9, L10,
  L11, L12)
- [x] **E3** Usage errors say what was wrong: three `range` messages, three `cmds` messages, the `cfg` message.
  Tests assert the texts. (L13)

### F. Test suite hygiene
- [x] **F1** `t/run.q` owns `q` (the pinned cfg), the scratch-dir helper and the child-q runner; the 15 files
  drop their copies and the 17 trailing `.qc.cfg[`v]:1`; test-file globals move under `.t.` (or each file
  deletes its own at the end) so nothing leaks between files except by the harness. (T8, T10, T14's leaking half)
- [x] **F2** `t/names.q` runs its reserved-word, shadowing and double-definition checks over `examples/**/*.q`,
  `tools/*.q`, `t/*.q` and `spikes/*.q` too (shadowing of engine globals only for `qc.q`); `t/docs.q` name-checks
  EXAMPLES.md. (T15)
- [x] **F3** *(done in part, by decision: the two shared helpers moved to `t/run.q` and `spikes/bench.q`; the repeated
  assertions were read again and kept — they are layers, not copies: contracts over every registry row vs. named
  lists in core/types; stop semantics in stop.q vs. result shape in outcomes.q vs. the report line in reportx.q; one
  canary per file for that file's generators. Trimming them would lose the layer that names the failure.)* Duplicate assertions trimmed to one home each (record/replay, canaries, exhausted-constant, cover
  950/800/910, eq order row, ok-line patterns); `D` and `depth/nodes` helpers shared; `bench.q` stops re-asserting
  `shrink.q`'s minimums. (T9, T11)
- [x] **F4** All-or-nothing loops become per-row tests or trap per row and report which row raised
  (`contracts.q`, `bench.q`, `ranges.q`); `.t.t` gains an optional detail argument so and-chains can say which
  conjunct failed, used in `core.q:75`, `review.q:20-24`, `tables.q:61`. (T5, T13)
- [x] **F5** `scale.q`'s wall-clock bounds become ratios or are moved to `spikes/` as measurements; `bench.q`'s
  caps documented as a deliberate guard in its header; the right-to-left assignments in `core.q`, `reportx.q`
  written as two statements. (T3, T6)
- [x] **F6** `t/run.q` statement splitting documented (leading-space continuation) with a check that no test file
  has a column-0 closer. (T12)
- [x] **F7** Coverage: tests for `dble` (plus a doc line), `discard`, `label` direct, `check`/`checks` in-process,
  `val` shrinking, cfg `tries`/`depth`/`disc`/`rows`, `report` with `v>1` and the `stale:` line; `chrc`, `spc`,
  `strc`, `lin`, `rerun`, `gidf` get one behavioural assertion each. (T1, T2)
- [x] **F8** Suite time: `t/doctest.q` honours `QC_FAST=1` by skipping blocks whose first input contains
  `.qc.chk[300`, or the LOG's slow blocks are moved behind the same flag as `t/examples.q`'s children; README
  states both modes. (T17)

### G. Library duplication and readability (last: each may change pinned transcripts)
- [x] **G1** `wil`/`wlo` → one function with a sign; `dbl`/`dble` share a body; `gid` calls `gidf`; `sub`/`rec`
  and `subb`/`recb` share the child loop. (L4)
- [x] **G2** The `nr` cap, the stop-bit law, the `CS/UR/US` initialiser, the `mark` test and `dl` each defined
  once. (L5)
- [x] **G3** `df` dispatches on `kind`. (L7)
- [x] **G4** *(done in part: `sm`'s validations one per line, `tabx`'s uniq setup left to right, the five long trailing
  comments moved above their lines; `chk1`'s loop conds and `tput` were left as they are — restructuring the runner
  loop and the tree walk is not worth the risk to eighty pinned transcripts for a readability gain.)* `sm`'s first line split into validation lines; `tabx`'s uniq setup named step by step; `chk1`'s
  second line and its two conds given names; `tput` split into its two loops; the three 150–200-char trailing
  comments moved above their lines. (L14, L15, L16, L17, L18)
- [x] **G5** Comments: `rand` callers, the duplicate `lst` comment, "nine shapes", C14 gains `qc.inv`. (L19)
- [x] **G6** Convention for global mutation (`::` everywhere, or a stated rule for `+:`), `pdisc` written with a
  named parameter, the three `and`/`or` sites as cond chains — or C2 amended to allow them where both sides are
  safe. (L1, L2, L3)

## 9. Coverage of the review by the checklist

Every finding id in §1–§6 must appear in at least one task in §8. The table was generated by scanning this file
(ids in §8 against ids in §1–§6) and is to be regenerated before the review is closed. A second, read-through
pass checked that each *compound* finding is covered in all its parts, not just cited: it added C9 (X15 had only
its documentation half in B3) and extended F1 (T14's leaking globals were not in A4). §0's measurements are
covered by F8 (time) and A1/H2 (`.qc/`); §7 needs no action.

| finding | task |
|---|---|
| M1 | A1, A2 |
| M2 | A3, D-c |
| M3 | A2 |
| L1 | G6 |
| L2 | G6 |
| L3 | G6 |
| L4 | G1 |
| L5 | G2 |
| L6 | E1 |
| L7 | G3 |
| L8 | E1 |
| L9 | E2 |
| L10 | E2 |
| L11 | E2 |
| L12 | E2 |
| L13 | E3 |
| L14 | G4 |
| L15 | G4 |
| L16 | G4 |
| L17 | G4 |
| L18 | G4 |
| L19 | G5 |
| T1 | F7 |
| T2 | F7 |
| T3 | F5 |
| T4 | A4 |
| T5 | F4 |
| T6 | F5 |
| T7 | D-j |
| T8 | F1 |
| T9 | F3 |
| T10 | F1 |
| T11 | F3 |
| T12 | F6 |
| T13 | F4 |
| T14 | A4, F1 |
| T15 | F2 |
| T16 | D-j |
| T17 | F8 |
| D1 | D-a |
| D2 | D-a |
| D3 | D-b |
| D4 | D-b |
| D5 | D-b |
| D6 | D-c |
| D7 | D-a, D-b |
| D8 | D-d |
| D9 | D-c |
| D10 | D-c |
| D11 | D-f |
| D12 | D-e |
| D13 | D-f |
| D14 | D-g |
| D15 | D-d |
| D16 | D-h |
| D17 | D-h |
| D18 | D-a, D-i |
| X1 | C1 |
| X2 | C2 |
| X3 | C3 |
| X4 | C5 |
| X5 | C3, C4 |
| X6 | C6 |
| X7 | C6 |
| X8 | B2 |
| X9 | B2 |
| X10 | B2 |
| X11 | C7 |
| X12 | C8 |
| X13 | B4 |
| X14 | B3 |
| X15 | B3, C9 |
| X16 | B1 |
| X17 | B5 |
| X18 | B5 |
| X19 | A1 |
| H1 | D-f |
| H2 | A1, D-h |
| H3 | C4 |

Missing: none — every finding is covered.

