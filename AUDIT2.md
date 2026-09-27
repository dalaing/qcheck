# Audit 2 — the conventions and pitfalls, as applied after phase 2

*2026-09-27, against `6f5b7de` (M11 complete): `qc.q` (511 lines), every file in `t/`, `examples/`, `tools/`,
`spikes/`. Method as in `AUDIT.md`: every file read in full, mechanical checks in q (reserved words and engine-name
mirrors across every file, `like` patterns, `each` after a generator, keyed tables at dict tests, duplicate
definitions inside `.qc`, each-both over three-argument functions), and every claimed behaviour reproduced before
it was written down. Line numbers are `file:line` in the current tree. The suite is green at 1438/1438.*

**Status: open.** Every actionable item carries a `[ ]` checkbox. Tags as before: **bug** — observable wrong
behaviour; **break** — the convention's letter is not followed; **spirit** — the letter is met, the intent is not,
or only by accident; for pitfalls **relies** — handled knowingly (do not undo) and **exposed** — live.

Headline: five bugs, all in phase-2 code — two `mono` columns of different types raise `type` (the per-table
state is a dict amended into a typed value list, pitfall 6 in dict form again); `colg` sends a column whose value
is a table or keyed table down the enumeration branch (`tc>=20h` catches `98h` and `99h`); `unifn` uses a long
vector as the condition of `?[c;a;b]`, so a bulk draw with the `u` hint on the full range raises `type`; a
`uniq` column over a generator that draws dicts raises `type` (its used-set collapses to a table); and in
`t/outcomes.q` the two calls added to test the C9 size leak are appended *before* the list is defined and are
silently lost, so that regression test never runs. Then a family of bare q errors at new boundaries (C14), the
phase-2 lessons never folded into §1.10 (no C22 exists), and the usual test-file patterns: dependent `and`-chains
(now failing alone rather than skipping the file), right-to-left assignments, and root names that mirror engine
names.

---

## Part 1 — Conventions

### C1 — the implicit `d` is a canary
Every phase-2 generator begins with `dd` (`mono`, `uniq`, `dep`, `atr`, `bulk`, `btab`, `ts`, `dates`, `val`,
`gidf`, `dble`, `schx`), and contracts c10 covers the 24 new registry rows. `schema` is a constructor and says so.
- Note: the enumeration generator `colg` builds (`qc.q:232`, `{[f;d] f$draw elem value f}`) has no `dd`; it is
  internal and only reachable through `schx`, which has one. Acceptable.

### C2 — guards are conds, not conjunctions
Library: clean. The phase-2 `and`s have independent terms (`qc.q:224` `count[at] and count rs`, `:189`
`(k=`ktab) and n>1`, `:448` `(a<k) and not ok`); the type tests in `vnode`, `cands` and `mark` are cond chains.
- [ ] **spirit (tests)** dependent chains that raise rather than fail when the property under test misbehaves,
  reproduced against a passing run: `t/tables.q:12` (`rank`), `t/sm.q:43` (`type`), `t/integ.q:9` (`type`); the
  shape recurs at `t/tables.q:24,61`, `t/scale.q:31,33`, `t/types.q:30`. Since the first audit the harness fails
  each such statement alone (`t/run.q:12-13`), so the cost is a misnamed failure, not a skipped file. Same standing
  as in `AUDIT.md`: acceptable, listed so nobody reads a `raised: type` as a harness fault.

### C3 — type dispatch is total
- [ ] **bug** `qc.q:232` `colg`: the first test `tc>=20h` is meant for enumerations (`20h`–`76h`) but also catches
  `98h` and `99h`, so a column whose value is a table (rows that are conforming dicts collapse to one) raises
  `type` from `key`, and a keyed-table value builds an enumeration generator over the key table. Reproduced:
  `.qc.colg ([]a:1 2;b:3 4)` raises `type`. The test should be `tc within 20 76h`; tables and keyed tables then
  fall to the general branch.
- [ ] **bug** `qc.q:64` `unifn`: `?[n?2; lo+n?0W; hi-n?0W]` gives the vector conditional a long vector; it needs
  booleans and raises `type` (`.qc.unifn[-0W;0W;5]`). Reachable through `chn` with the `u` hint on a range whose
  width overflows; no public caller passes `u` to `chn` today, so it is latent. `mixn` beside it is correct.
- `kind`, `fmt1`, `df`, `mark` (`:204`), `cands` (`:206`), `vnode` (`:187-190`) all end in an else.

### C4 — absence is empty, not `::`
Clean. The per-table state (`qc.q:207`) is three empty dicts; `tabx`'s `em` uses `::` for "no typed empties",
which is the documented scalar use; `TX` is seeded with an empty vector key.

### C5 — names: reserved words and engine globals
`t/names.q` is green and the scan finds no reserved word used as a *name* in any file.
- [ ] **break** `spikes/a26_time.q:6-7` — `from` is a reserved word used as a lambda **parameter** (`{[from;to;d]`).
  q accepts it, which is why it ran; the first audit's rule says never.
- [ ] **spirit** root globals in test files that mirror engine names, new since the first pass: `dp`
  (`t/tables.q:27`, mirrors the interpreter depth), `schema` (`t/outcomes.q:19`, now mirrors `.qc.schema`), `t`
  (`t/tables.q`, `t/sm.q`, `t/dist.q`, `examples/aj.q`; mirrors the type zoo). Spikes mirror deliberately
  (`a22_scale.q` patches `.qc.shr`, `.qc.chn`); that is what a spike is for.
- [ ] **gap** the scan cannot see a collision *inside* `.qc` (M8 defined `blk` twice; caught by hand). A duplicate
  definition check over `qc.q` belongs in `t/names.q`; today there are none.

### C6 — a top-level draw is an example
Clean. `top` now also sets `cf` from `cfg` (`qc.q:91`), so a `cfg` edit reaches the next interactive draw.

### C7 — zero choices means exhausted; every structure records a choice
Clean. Contracts c3 covers every new registry row; `bulk` records its length, `val` records `rec`'s node count,
`ts`/`dates` one choice each.

### C8 — tests pin seeds
New files pin (`t/tables.q:5`, `t/scale.q:5`, `t/integ.q:5`); `t/stop.q`, `t/reportx.q`, `t/report.q`,
`t/outcomes.q`, `t/self.q` draw only through `chk`, which seeds itself.
- [ ] **spirit** `t/examples.q:13` asserts that `examples/aj.q`, run with a random seed, finds its planted bug.
  Near-certain in 100 tests, not pinned. Same standing as the other example assertions in the first audit.

### C9 — engine state is restored at the example boundary
- [ ] **bug (test)** `t/outcomes.q:32-33` — `calls,:(…)` precedes `calls:(…)`. At top level `,:` on an undefined
  global defines it (reproduced), and the definition on the next line then replaces it, so the two calls that
  exercise the C9 size leak through `clean` are never run. The regression test for `2b1ef15` does not exist.
- Library: `CS`, `UR`, `US` are saved before and restored after every table, on the error path through the trap
  (`qc.q:220-222`); `nch` is reset per example (`:36`); `tidy` restores `bs` and `sz`; `mustc` goes through `chk`.
  Clean.

### C10 — the four sources of a choice are four entry points
Clean; `strict` is the fourth (`qc.q:95`). Tests use it (`t/contracts.q:14`, `t/ranges.q:16`).

### C11 — ranges widen with size
Clean. `bulk`'s and `btab`'s length cap `lo+1000*size` widens (`qc.q:124,126`); `mono` inherits its delta
generator's law; `ts`, `dates`, `schema` are constant.

### C12 — layout is order
- `val`'s leaf alternatives draw unequal numbers of choices (`qc.q:186`); accepted in the M10 pass as a
  reach-not-order generator. `vnode`'s dict keys add a variable number of choices per key. No change proposed.

### C13 — spans are units
Clean. A bulk span is length plus blocks (`beg`blk`, `qc.q:124,126`) and `pblk` relies on that layout; constrained
columns draw inside the row span; `dep`'s spec is drawn through `draw`.

### C14 — the error vocabulary is closed and classified
- [ ] **break** bare q errors at phase-2 boundaries (each reproduced): `ts`/`dates` given non-temporal bounds
  (`qc.q:181-182`, `type`); `btab` given a non-char type in a column spec (`:127`, `type`); `atr[`u]` over a vector
  with repeats (`:203`, `u-fail` — `atr` sorts for `s` and `p` but does not make `u` distinct); two `mono` columns
  of different types (`:214-215`, `type`, the C3/pitfall-6 bug above); `uniq` over a generator that draws dicts
  (`:209`, `type`); `colg` on a table-valued column (`:232`, `type`).
- [ ] **spirit** `qc.q:124,126` — `bulk[0 9;(0W-5;0W)]` reports `qc: range`, which is true only because the cap
  arithmetic wrapped (see C21); the message blames the user's range.
- `qc.inv` is in `FS` (`:289`) and `t/names.q` sees it; `must`'s `qc: FAIL …` is documented. Clean otherwise.

### C15 — verdicts from random data carry confidence
Clean (unchanged).

### C16 — at the API boundary an atom is a one-element list
Clean. `bulk`'s and `btab`'s ranges go through `rng`; `ktab`'s `k` through `(),k`; `atr`'s `a`, `ts`'s and
`dates`'s bounds are atoms by nature. A `btab` column spec given as a lone range atom fails as `qc: range`.

### C17 — measure the distribution you ship
`t/scale.q:16-20` measures the vectorised laws, `t/sm.q:48` the weights, `t/types.q:35` `val`'s reach.
- [ ] **spirit** `mix` and `mixn` (`qc.q:65-66,75-76`), `unif` and `unifn` are two implementations each of one
  law; nothing asserts they agree. A pinned test comparing their distributions on the same ranges is the C17
  form of "two implementations".

### C18 — examples are tests
Clean: `COOKBOOK.md`, `EXAMPLES.md`, `README.md`, `DESIGN.md` transcripts run; every example runs; every `.qc.`
name in the four documents exists.
- [ ] **gap (process)** the plan's fold-back step — "conventions folded back into §1.10 as C22+" at the end of each
  milestone — was not done: §1.10 still ends at C21, and the lessons live only in the M7–M11 paragraphs of §3.
  Candidates: per-table generator state saved and restored around the structure that owns it (M7); heterogeneous
  lists grow behind a `::` seed (M7, pitfall 30); a block is one draw call and one span (M8); the error a caller
  framework sees is one signal whose first line is the verdict (M9).

### C19 — `n` is a budget
Clean. A bulk block appends n rows to `C`, so the choice tree's path product exceeds the budget on the first
example and the run samples, as intended.

### C20 — the library never applies a value it has not checked is callable
Clean. `dep`'s `f` and `sm`'s `inv` go through `need`; `w` is checked numeric and positive; `mark` compares
functions with `~`; `colg`'s `f$` is an enumeration, not an application.

### C21 — arithmetic on choice bounds is done in floats, or guarded
- [ ] **exposed** `qc.q:124,126` — `nr[1]&:nr[0]+sz*1000` is long arithmetic; near `0W` it wraps and the range
  fails as `qc: range` (reproduced). `"j"$("f"$nr 0)+sz*1000` saturates instead.
- [ ] **exposed** `qc.q:64` `unifn` — the same `?[n?2;…]` bug as under C3; the overflow branch it guards is
  right, the guard's result is not usable.
- Handled: `mixn` adds in floats and saturates; `cands` uses `wid`; `tin`'s `j` range is built from `-0W+1` and
  `0W-1`; `chn`'s prefix slice uses `0|n&count[P]-j`.

---

## Part 2 — Pitfalls

**1. Never `each` a generator.** None anywhere (grep). *Relies*: every test draws with `{.qc.draw x} each n#enlist g`.

**2. `'[f;g]` after `:`.** *Relies*: `qc.q:149` `cast` parenthesises.

**3. Reserved words.** *Relies*: `t/names.q` for the library; the scan for the rest.
- [ ] *Exposed*: `spikes/a26_time.q:6-7` uses `from` as a parameter name (C5 above).
- Recorded in §3, not §4: `asc`, `attr`, `like`, `cols`, `vs`, `value`, `any`, `inv` all bit during phase 2.

**4. q-sql parameter shadowed by a column.** *Relies*: `qc.q:445-446` `pblk` filters `cE` on the local `bl`;
`:366-367` `chks` deletes `ms`; `:256` `sm` updates `w`. Nothing exposed.

**5 and 24. `like` wildcards.** No middle `*` or `[` in any pattern (mechanical).

**6. `xs,:y` does not promote a typed vector.**
- [x] *Exposed (bug)*: `qc.q:207,215` — `CS` starts as `(0#`)!()`; the first `CS[k]:v` makes its value list typed,
  and a second `mono` column of another type raises `type` (reproduced with a long and a timestamp column). The
  row accumulator in `rowd` was seeded for exactly this reason (`:212`); `CS` was not.
- [x] *Exposed*: `qc.q:209` `US[k]:US[k],enlist v` — for dict-valued `v`, `enlist v` is a table and the next
  non-conforming dict cannot join (pitfall 30); reproduced as `type` through `uniq` over `one` of two dict shapes.
- *Relies*: `lst`, `sub`, `subb`, `rowd` grow behind a `::` seed; `nxt`'s `p,:v` is long onto long.

**7. `rand 0`, `rand -k`, `1+0W`.** *Relies*: `unifn` checks `0<k` before `n?k`; `mixn` draws `n?8`, `n?5`, `n?2`,
`n?1f`, `n?1+bits …`. *Exposed*: the `?[n?2;…]` in `unifn` is a type, not a range, error (C3).

**8. `\S`.** *Relies*: `chk1` sets, `recheck1` reads back. Pitfall 32 documents the side effect.

**9. A parameterless lambda is unary.** *Relies*: `h[`init][]`, `h[`fini][]`, `g[]`.

**10. `::` is `101h`.** *Relies*: `fn` rejects it (`qc.q:40`); `dr`, `kind`, `df` test `(::)~x` first.

**11. Symbols intern forever.** *Relies*: `tin`'s `symc["abcd";1 3]`, `vnode`'s dict keys from `sym`, `vleaf`'s
`sym`; `collect` documented as for small value spaces.

**12. `.Q.s` truncates.** *Relies*: `must` signals `report`, which goes through `fmt` and `rerun`.

**13. `\l` errors drop into the debugger.** *Relies*: `main` calls `exit`, so `t/integ.q:20-25` runs it in a child
q; `t/examples.q` runs each example as a child; the doc child ends in `exit`.

**14. `over` on an empty list.** *Relies*: `ctab`. `pblk`'s `raze (a+til w2)+/:k*til m` has `m>=1` always (a block
span has at least one block).

**15. `binr`.** *Relies*: `fresh`, `freshn`.

**16. Two atom leaves collapse into a typed vector.** *Relies*: `vnode` returns typed-vector and table children as
they are (`qc.q:187`); `colg` reads a nested column's type from its first element (`:233`).

**17. `key` of a namespace.** *Relies*: `t/names.q`, `t/docs.q`.

**18. Reserved words as column names.** New columns `ms`, `w`, `nc`, `nx`, `c`, `p`, `v`: none reserved.

**19. Dict seeding.** *Relies*: `TX` with an empty vector key. `CS`/`UR`/`US` are symbol-keyed, so the issue there
is pitfall 6, not 19.

**20. `flip (a;b;c) ix`.** *Relies*: `pdup`.

**21. Nulls compare low.** *Relies*: `pick`, `tput`, `wid`, `bits` (unchanged).

**22. `sum ()` is `()`.** *Relies*: `pass`.

**23. Tolerant float `=`.** *Relies*: `t/types.q:46` is now an exact test. `less` on float distances: accepted
(`AUDIT.md`).

**23a. `"f"$0W` is finite.** *Relies*: `dble` (`qc.q:169`) caps the exponent at 103 so `"e"$` never overflows; `tin`
stops `h i j` one short of their infinities.

**25. `"1"` is a char atom.** *Relies*: `t/examples.q:5` and `t/integ.q:24-25` parse the exit code with `"J"$`.

**26. q-sql resolves globals in the root.** *Relies*: `covt`; `pblk`'s `where l=bl` uses a local. Nothing exposed.

**27. Row-first table indexing.** *Relies*: `c[av;`w]`, `TR[m;…]`, `tb[j;…]` throughout.

**28. Keyed tables are `99h`.** *Relies*: `dct` at `conf`, `tabr`, `ktab`, `btab`, `sm`'s hooks, `chks`; `schema`
accepts them on purpose. *Exposed*: `colg`'s `tc>=20h` (C3 above) treats a keyed-table column value as an
enumeration.

**29. Right-to-left evaluation inside an expression.** *Relies (and a trap)*, new instances: `t/types.q:30`,
`t/scale.q:13`, `t/tables.q:21` assign in the right-hand term and read the name in the left-hand term; with C2
this is what turns a wrong value into `rank` instead of a failure.

**30. A list of conforming dicts is a table.** *Relies*: `lst`, `sub`, `subb`, `rowd` seeds; `vnode` accepts
table children. *Exposed*: `US` (pitfall 6 above).

**31. `in` compares within one type.** *Relies*: `spikes/a27_value.q:23` casts; `qc.q:256` compares type shorts
with shorts.

**32. `chk` reseeds the process RNG.** Documented (`DESIGN.md` §4). Nothing to do.

### Proposed pitfalls 33–42

Each is a q fact that bit during phase 2 or this audit and is not yet in `DESIGN.md` §4 (Part 4, step 5 adds them).
They are audited here like the others, so the cleanup that writes them down also knows where they stand.

**33. `f'[a;b]` over a three-argument `f` is a projection of the each, not a list of results.** The each-both fills
two of three arguments and returns a function; `count` of it is 1, and a `!` against thirteen keys fails with
`length`. *Relies*: `qc.q:178` wraps `spc` in a two-argument lambda before the each-both and says why in its
comment. `bkey'[c`s;c`e]` (`:423`) is two-argument, so it is safe. No other each-both over a named function in the
library or the tests (grep). *Exposed*: none.

**34. `0#` of a table drops its columns' attributes; `0#` of a vector keeps its attribute.** So an empty table
generated from a schema must carry no attributes, or its `meta` differs from `meta 0#t`. *Relies*: `qc.q:224`
applies attributes only when there are rows; `qc.q:238` strips the typed empties with `` `# `` because they are made
from vectors (`0#'vals`), not from the table; `spikes/a21_meta.q:17-18` does both. *Exposed*: none.

**35. `meta`'s `f` column names only keyed-table foreign keys.** An enumerated symbol column (`` `dom$ ``) shows `t`
`s` and an empty `f`, indistinguishable from a plain symbol column; the domain is only in the values (`key c`).
*Relies*: `qc.q:232` `colg` reads the enumeration from `key c`, never from `meta`; `qc.q:229-231` says so;
`spikes/a21_meta.q:2-5` records the redesign. *Exposed*: none — and it is why `schema` takes a table, not a
`meta`.

**36. `count` is `#:` and `key` is `!:` in k, so "the first token's text ends in a colon" is not "an
assignment".** `string first parse "count x"` is `"#:"`. *Relies*: `tools/doc_child.q:5-6` `.d.asg` recognises an
assignment by an identifier followed by a single colon in the source text. `t/names.q:17` scans the *source* for
`:` (where `count` is spelled out), so it is unaffected. *Exposed*: none. (Before the fix, `key .qc.cfg`'s output
had been silenced in `EXAMPLES.md` since it was written.)

**37. `system "q …"` prints the child's output instead of returning it.** A `system` command whose first token is
`q` runs the child with the console attached; wrap it in `sh -c '…'` (or start with `/usr/bin/env q`) to capture.
*Relies*: `t/examples.q:4` and `t/integ.q:23` use `sh -c`, `t/doctest.q:10` uses `/usr/bin/env q`.
`examples/sm_ipc.q:4` and `spikes/a24_signal.q:12` start a background child with `system"q -p … &"` and redirect
its output, which is the intended use. *Exposed*: none.

**38. A lambda does not capture the enclosing function's locals.** An inner `{…}` sees globals and its own
parameters only; an outer local used inside is an undefined name (`'at`). *Relies*: every inner lambda in the
library is projected on what it needs — `qc.q:224` `{[at;tb;c] …}[at]/`, `:222` `{[r;cg;ks] …}[r;cg]`, `:366`
`{[c;n;sp] …}[c]'`, `:127` `{[n;s] …}[n] each`; `pdup`'s and `blk`'s inner lambdas read `cv`, a global.
`t/tables.q:44` `{[t;i] …}[t] each`, `spikes/a21_meta.q:18-19`. *Exposed*: none found by reading; a mechanical
check (an inner lambda's free identifiers that are locals of the enclosing lambda) does not exist and would be a
`t/names.q` addition.

**39. `where` over a dict returns keys; over a list, indices.** Both are wanted in different places and they
read alike. *Relies*: `qc.q:220` `uc:where ks=`uniq` and `:224` `where at=`p` take keys from dicts on purpose;
`qc.q:236` `cs where `u=attr each vals` indexes a list of column names by the list result, which is what the
first draft got wrong (a symbol list indexed by nothing). *Exposed*: none.

**40. `p#` on a non-parted vector reports `u-fail`, the same error as `u#`.** *Relies*: `qc.q:224` sorts the
parted columns first (`(where at=`p),where at=`s`) so `p#` always holds; `qc.q:237` refuses a schema with both a
`p#` and an `s#` column, since one sort cannot serve both; `atr` (`:203`) sorts before `p#`. *Exposed*: none — the
misleading text is q's, and the design's M7 paragraph names it.

**41. `x,:y` on an undefined global defines it at top level.** No error, no warning: `calls,:(1;2)` creates
`calls`. A later `calls:(…)` then replaces it and the appended values are gone. *Exposed*: `t/outcomes.q:32-33`
(the C9 finding above — the size-leak calls are appended one line before the list they should join). *Relies*:
every other `,:` in the tests and spikes has its target defined earlier (`.t.r`, `.s.nodes`, `.s.used`,
`.g.rows`; mechanical check over `t/`, `spikes/`, `examples/`). A statement-level lint — `,:` on a name with no
earlier definition in the file — would belong with the harness.

**42. `?[c;a;b]` needs a boolean `c`.** The vector conditional on a long vector raises `type`; `n?2` gives longs,
not booleans. *Exposed*: `qc.q:64` `unifn` (the C3 bug above). *Relies*: `qc.q:65-66` `mixn` builds its condition
as `0=n?8`, a boolean.

---

## Part 3 — Outside both lists

- [ ] **Pitfall candidates 33–42** are audited in Part 2 above and need writing into `DESIGN.md` §4: each is a q
  fact that bit once and is recorded only in a §3 milestone paragraph, a commit message, or this audit.
- [ ] `qc.q:200` `mono`'s comment says "adds a delta drawn from g"; a `g` that can go negative makes the column
  unsorted with no warning (reproduced: `mono[int 0 9;int -9 9]` is unsorted). The design (§1.3) says "sorted by
  construction". Either `mono` clamps the delta at zero, or the design says the delta must be non-negative.
- [ ] `qc.q:203` `atr[`u]` neither dedupes nor checks; the `u-fail` is q's, not the library's (C14 above).
- [ ] `t/scale.q:26` test name says "shrinks to two elements 99 and 1 or one of 99..." — its assertion is
  `3>=count`; the name should say what is asserted.

---

## Part 4 — Suggested order for the cleanup pass

1. [ ] **Bugs.** `CS` seeded like `rowd`'s row (`qc.q:207,220`); `colg`'s enumeration test `tc within 20 76h`;
   `unifn`'s condition a boolean (`0=n?2` or `n?01b`); `US` grows behind a `::` seed or holds `-8!` keys; the two
   `t/outcomes.q` calls moved after the definition (and a look at whether `clean` then still passes).
2. [ ] **Usage errors (C14).** `qc: …` for non-temporal `ts`/`dates` bounds, a non-char `btab` type, `atr[`u]` on
   repeats (or make it distinct), a `bulk`/`btab` length range that wraps.
3. [ ] **C21.** The `bulk`/`btab` cap in floats.
4. [ ] **Tests and names.** A duplicate-definition check in `t/names.q`; `from` renamed in `spikes/a26_time.q`; the
   three root mirrors renamed; `t/scale.q:26`'s name; a `mix`/`mixn` and `unif`/`unifn` agreement test (C17).
5. [ ] **Design.** C22–C25 from the phase-2 lessons; pitfalls 33–42 as audited in Part 2 (two of them, 41 and 42,
   are the live ones behind the `t/outcomes.q` and `unifn` bugs); `mono`'s non-negative-delta contract stated where
   `mono` is defined and in §1.3.
