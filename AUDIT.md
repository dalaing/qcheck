# Audit — the conventions and pitfalls, as applied

*2026-09-27, against the working tree: commit `81ab299` plus the uncommitted choice-tree change (C19). Scope:
`qc.q` (401 lines), every file in `t/`, `examples/`, `tools/`, and `spikes/`. Method: every file read in full,
then mechanical checks in q for the things a reader gets wrong (reserved words and shadowing across all files,
`like` patterns, `each` after a generator, keyed tables at every dict test, overflow at the bounds, and each
suspected behaviour reproduced before it was written down). Line numbers are `file:line` in the current tree.*

**Status (2026-09-27, after the cleanup pass): every box is ticked.** One item was withdrawn on review (C7), one
accepted as the price of C21 (pitfall 23's `less`); everything else was fixed in the commits following `e37f7d0`,
one per item or per fix covering several. The suite grew from 1019 to 1034 tests.

Tags. **bug** — observable wrong behaviour. **break** — the convention's letter is not followed. **spirit** —
the letter is met but the intent is not, or only by accident. For pitfalls: **relies** — the code knows about
the hazard and works around it (kept here so a cleanup does not undo it); **exposed** — the hazard is live.
Every actionable item carries a `[ ]` checkbox; tick it when the cleanup lands. Notes and *relies* entries have
none — there is nothing to do for them.

Headline: three bugs (C9 size leak, C18 empty rerun line, C18 vacuous test; a fourth, C7 `such` over a constant,
was withdrawn on review), one
harness weakness that turns failing assertions into skipped files (C2), a family of bare q errors where usage
errors should be (C14 / pitfall 28), unpinned seeds in five test files (C8), and residual long arithmetic on
bounds (C21). The spikes are validation scripts with their own mini-engines and are audited only for the
pitfalls; their root-level `draw`, `int`, `lst` are intentional.

---

## Part 1 — Conventions

### C1 — the implicit `d` is a canary
Every library generator begins with `dd[d;form]`; the defaults (`bool`, `chr`, `str`, `sym`, `list`, `tab`)
inherit it by projection, and the `cast` compositions in `.qc.t` pass an extra argument through to the wrapped
generator, so the canary fires there too. Spikes that define generators use `.qc.dd` (`spikes/a13_float.q:8`,
`spikes/a6_lists.q:4`).
- [x] **spirit** `qc.q:125`, `qc.q:131` — `dbl` and `gid` have no configurable form, yet the message reads "the
  configurable form is .qc.dbl". True but unhelpful; the message should say the generator takes no arguments.
- Note: `lin` (`qc.q:80`) and `cast` (`qc.q:121`) take no `d`. Correct — they are not generators.

### C2 — guards are conds, not conjunctions
- [x] **spirit** `qc.q:305` `chain`: `(k<count c) and c[k;`s]=c[k-1;`e]` indexes past the end when `k=count c`.
  Harmless (a null row) but the second term is meaningful only when the first holds.
- [x] **spirit** `qc.q:128` `flt`: `(2<>count r) or r[0]>r 1` evaluates the comparison on a malformed range. Same
  outcome either way, same shape as the origin of C2.
- [x] **break, with a consequence** — the tests. *(Fixed in the harness: `t/run.q` evaluates per statement; the chains stay.)* Chained `and` whose later terms assume the earlier ones raise
  instead of failing when the property under test misbehaves. Reproduced with a passing run (`x` is `::`,
  `notes` is `()`): `t/core.q:63` raises `type`, `t/sm.q:22` raises `type`, `t/shrink.q:33` raises `rank`,
  `t/types.q:52` raises `rank`. The shape recurs (`t/core.q:65`, `t/sm.q:38`, `t/report.q:38`). Because
  `t/run.q:6` traps at file granularity, one raising assertion is reported as a single "file loads" failure and
  every later test in that file is skipped — the suite under-reports exactly when something is broken.

### C3 — type dispatch is total
Every `$[type …]` in `qc.q` has an else; the shape zoo in `t/self.q:39-42` mechanises it.
- [x] **spirit** `t/ranges.q:6` `nmr:{$[.qc.fn x; .Q.s1 x; .Q.s1 x]}` — both branches identical; dead dispatch.
- `fn` (`qc.q:38`) counts `::` as callable — see pitfall 10 and C20.

### C4 — absence is empty, not `::`
The result dict, history, cover and trace tables all comply (`t/core.q:133`, `t/outcomes.q:19-24`).
- [x] **spirit** `qc.q:32`, `qc.q:222` — `TX` is seeded with a sentinel key `0N 0N` that is a real-looking value and
  stays in the dict (`count .qc.TX` is one more than the tree's edges). Pitfall 19 says to seed with an empty
  vector key. (Choice-tree code, this change.)

### C5 — a name is free iff not in `.Q.res,key .q`; a local never shadows an engine global
The library is enforced by `t/names.q` (green). A scan of every `t/`, `examples/`, `spikes/`, `tools/` file
found no reserved word used as a name or parameter. (The scan script itself first named a function `scan`,
which is reserved — the pitfall is alive.)
- [x] **spirit** — root globals in test files reuse engine-global names *(renamed)*: `N` (`t/sm.q:6`), `K` (`t/outcomes.q:17`),
  `T` (`t/bench.q:5`, `t/self.q:30`), `L` (`t/docs.q:3`, `t/doctest.q:5`, `t/readme.q:5`), `t` (`t/report.q:66`),
  `run1` (`t/readme.q:11`), `st` (`t/dist.q:37`), `sh` (`t/self.q:34`). Different namespace, so not shadowing,
  but the same edit-distance hazard C5 describes.
- [x] **spirit** `t/dist.q:34` — `q:asc[nb] 250 500 750` overwrites the `q` that every other test file uses as its
  config dict. Harmless only because `t/outcomes.q:4` redefines it before the next use; the suite is one
  session and the files share a namespace.

### C6 — a top-level draw is an example
Clean. `t/core.q:119-125` pins it. `.qc.note` at the REPL accumulates until the next draw, by design.

### C7 — zero choices means exhausted, so every structure records at least one
- [x] ~~**bug** `qc.q:89` `such` over a constant records nothing~~ — **withdrawn.** `such[p] 5` is a constant
  at every size, and C7 says a constant spec honestly runs once; the dual is about generators that *could*
  vary, and `such` over a varying `g` records through `g`. Recording a forced bit per try would add a choice
  to every filter for no information. No change.

### C8 — tests pin seeds
Files whose fresh draws depend on the RNG state the previous file left behind rather than a pin. They are
deterministic today only through `t/run.q:7` loading files alphabetically:
- [x] **break** `t/contracts.q` — no `system"S"` anywhere; c1, c4–c9 draw fresh (`:7,10,13-17`); only c11's `chk`
  reseeds.
- [x] **break** `t/core.q:14-17` (before the pin at `:18`) and `:119-125`.
- [x] **break** `t/ranges.q:12,14,15,22,24,25` — every `modes` draw.
- [x] **break** `t/review.q:5`, `t/sm.q:12,29`.
- [x] **break** `t/readme.q` — runs the README's blocks with `cfg`seed` null, i.e. a time-based seed
  (`qc.q:249`); only "loads without error" is asserted, so it cannot flake on a verdict, but it is the one place
  the suite executes unpinned properties. `tools/doc_child.q:3` pins 7 for the transcripts.
- `examples/*.q` are unpinned by design (they are demos), and `examples/sm_ipc.q:15` turns a probabilistic
  verdict into an exit code. See C18: they are not run by the suite anyway.

### C9 — engine state is restored at the example boundary, from run-level values
- [x] **bug** `qc.q:246-247` — `tidy` restores the run flag, `cf`, `dp` and `st`, but not `bs`. `chk1` resets every
  example with the run's size (`c`sz` or the ramped size, `qc.q:255`), so `bs` ends the run at the last
  example's size. Reproduced: after `.qc.chk[`sz!enlist 3; .qc.list .qc.int 0 9; {1b}]`, `.qc.bs` is 2 and
  every later top-level `.qc.draw` produces lists of at most two elements until `.qc.new[]`. `recheck1`
  (`qc.q:277`) resets with `cfg`sz`, so it does not leak; the error path of `chk` leaves `bs` at the run's size.
- [x] **spirit (accepted)** `qc.q:354` `wide` restores the console by hand under a trap — the console is not engine state and has no run-level value to restore it from, so this is the right shape there; — the "restore what you changed"
  pattern C9 replaced, kept here because the console is not engine state. `small` (`qc.q:85`) is documented.
- [x] **break** in tests — direct edits of engine state with hand-written restores: *(now `.t.sz` via `cfg\`sz`+`new[]`, the harness restores the defaults per file, and the budget test uses `cfg\`choices`)*
  `t/core.q:57` sets `.qc.cf[`choices]:100` (the *effective* config, outside a run) and restores it to a
  hard-coded `8192` instead of `.qc.cfg`choices``; `t/contracts.q:13` and `t/ranges.q:15` set `.qc.run` by
  hand; `.qc.reset[…]` is called directly to change the size in `t/contracts.q:6`, `t/core.q:30,42,105,140`,
  `t/types.q:42,57`, `t/sm.q:43`, `t/dist.q:32`, `t/review.q:30`. There is no public way to set the interactive
  size other than `cfg`sz` followed by `new[]`.

### C10 — the four sources of a choice are four entry points
- [x] **break** `t/contracts.q:13` (c5) and `t/ranges.q:15` rebuild the shrinker's strict-prefix source by hand *(now `.qc.strict`)*
  (`.qc.run:1b; .qc.reset[c;100;0b;1b]; .qc.dr; .qc.i; .qc.run:0b`). That is the exact thing C10's origin says
  the tests should not have to do; the fourth source has no owner the tests can call.

### C11 — ranges widen with size
Clean in the library (`lst` and `sm` caps, `rec`, `small`); `t/core.q:113` deliberately narrows to test the
rule. `lin` overflows for a huge `hi` — filed under C21.

### C12 — layout is order
- [x] **spirit** `qc.q:168-170` — a state-machine step's length depends on the command's `gen`: a `{::}` gen draws
  nothing, so a pop step is two choices and a push step three. Under shortlex the shrinker therefore prefers
  input-less commands regardless of meaning. Inherent in §1.7's design and probably right, but it is an
  exception to "every alternative draws the same number of choices" that the design does not state.
- `.qc.t` values differ in length (`chr` one choice, `spc` three); `t` is a dict, not a `one`, so no order is
  implied — unless a user puts them in `one`, as `t/self.q:19` does on purpose.

### C13 — spans are units
Clean. `lst`, `sm`, `sub`/`subb` and `such`'s `try` spans all open and close on every path; `spc`, `dbl`,
`flt` and `gid` draw inside the enclosing `call` span.

### C14 — the error vocabulary is closed and classified
- [x] **break** — bare q errors reach the user for malformed input, where a `qc: …` usage error belongs
  (each reproduced): a non-symbol label in `classify`/`label`/`cover` (`qc.q:180-184`) raises `type` from
  `covt` at report time; `tab`/`tabr` given a keyed table (`qc.q:149`) raises `nyi`; `checks` given a keyed
  table (`qc.q:272`), `sm` given a keyed table as `h` (`qc.q:164`) and a keyed table as the config (`qc.q:190`)
  raise `type` (the audit first said `rank`: that came from a malformed test literal, `([k:`n]v:5)` with atom
  columns is itself a rank error); `one` of a dict and `freq` with non-numeric weights (`qc.q:87-88`) raise
  `type`.
- [x] **break** `qc.q:190` `conf` silently accepts unknown keys: `.qc.chk[enlist[`seeed]!enlist 5; …]` runs with
  the default seed and says nothing.
- [x] **spirit** `qc.q:226` `'"qc: tree"` *(now reads "internal error in the choice tree, please report")* uses the usage-error spelling for an internal invariant that a user can
  never cause. (Choice-tree code, this change.)
- `t/names.q` enforces the literals; `t/outcomes.q:11-15` exercises every class in both phases. Clean there.

### C15 — verdicts from random data carry confidence
Clean (`qc.q:209-219`; `t/report.q:57-61`, `t/stop.q:38-49`).

### C16 — at the API boundary an atom is a one-element list
Clean at every documented site. `classify`/`cover` with a symbol *list* label register several labels
(`qc.q:180` `LX,s`) — works, by accident. `one` of a dict fails with a bare error (C14).

### C17 — measure the distribution you ship
Clean (`t/dist.q`, `t/core.q:136-144`). The one distribution assertion that is vacuous is under C18.

### C18 — examples are tests
- [x] **gap** `examples/reverse.q`, `tree.q`, `sm_table.q`, `sm_ipc.q` are not executed *(now `t/examples.q`)* by `t/run.q`; only README
  blocks (`t/readme.q`) and `q)` transcripts (`t/doctest.q`) are. The layout (`DESIGN.md` §1.9) lists them next
  to the tests as if they were covered.
- [x] **gap** `DESIGN.md`'s non-transcript ```` ```q ```` blocks *(now loaded by `t/readme.q`; loading them found `.qc.str 0 5` in §1.3)* (lines 47, 56, 63, 69, 91, 141, 232) are neither
  loaded nor doctested; `t/docs.q` checks only that the `.qc.` names they mention exist.
- [x] **bug** `t/types.q:29` — the predicate `{x=x*4 div 4}` parses as `x=x*(4 div 4)`, i.e. `x=x`; the assertion
  "a quarter of values are dyadic" is `0.15<1` and cannot fail (reproduced: mean 1 on `0.1 0.3 0.7 0.123`). The
  harness rejects non-boolean results but cannot see a vacuous one.
- [x] **bug** `qc.q:396` — the rerun line for an empty choice vector prints `.qc.recheck[spec;prop;]`, a projection
  with the argument elided, so it does not round-trip. Reachable: `.qc.check[42;{x<>42}]`. The round-trip
  property `t/reportx.q:7` draws `lst[1 300]`, never the empty vector.

### C19 — `n` is a budget; the run stops when it has learned what it can
Clean after this change; `t/stop.q` covers exhaustion, the tree, the budget switch and the contradiction
fallback. Two loose ends are filed under C4 (the `TX` sentinel) and C14 (`qc: tree`).

### C20 — the library never applies a value it has not checked is callable
- [x] **spirit** `qc.q:272` `chks` does not check that each entry is a `(spec;prop)` pair. A bare lambda is caught
  downstream by `need` ("the property must be a function"); a bare generator by the canary ("too many
  arguments; the configurable form is .qc.int r") — both reproduced, both misleading.
- [x] **spirit** `qc.q:38` `fn` admits `::` (it is `101h`, pitfall 10), so `need` passes it everywhere: `sized (::)`
  draws the size itself as a constant (reproduced: 100), `such[::] g` is accepted and then raises a bare `type`
  on list values (reproduced). The `::` *property* is special-cased (`qc.q:248`); generator slots are not.

### C21 — arithmetic on choice bounds is done in floats, or guarded
Handled: `wid` (`qc.q:220`), `zig` (`:285`), `bsr` (`:331`), `tput`'s product (`:238`), `pick` (`:226`, a wrap
becomes `0N` and `within` rejects it).
- [x] **exposed** `qc.q:286` `skey` and `:317` `bkey` — `v-o` can *wrap*, not only null, and `0W^` catches only
  nulls. Reproduced: `skey[enlist 0W; enlist -5]` gives distance 1.84e19 from the wrapped difference. Both
  values are huge so the order is only wrong between two huge values, but the claim "in floats or guarded" is
  not met.
- [x] **exposed** `qc.q:329` `pdup` (`d:cv[ps]-cC[`o] ps`) and `:338` `pred` (`k:(vi-oi)&cC[`hi][j]-vj`) subtract
  longs from full-range choices; a wrapped candidate is clamped by `ch` on replay, so it is wasted rather than
  wrong.
- [x] **exposed** `qc.q:58-59` `mix` — `o+1`, `o-1` and `o+sign*magnitude` are long adds; at `hi=0W` they wrap to
  `0N`, which `lo|hi&` turns into `lo`, so a boundary pick silently lands on the wrong end. Rare (only when `o`
  is within the magnitude of `0W`); `bits hi-lo` is guarded.
- [x] **exposed** `qc.q:80` `lin` — `(hi-lo)*s` overflows: `.qc.lin[0;0W] 100` is `0 -1`, which fails later as
  `qc: range` with no hint of why (reproduced).
- [x] **exposed** `qc.q:95`, `qc.q:167` — `lo+sz` overflows for `lo` near `0W`: `lst[0W 0W]` spins on forced bits
  until `qc.toolarge` (reproduced).
- [x] **exposed, documented** `qc.q:54` `unif` — on the full range the halves are `[lo, lo+0W)` and `(hi-0W, hi]`,
  so 0 is unreachable through the `u hint (reproduced over 20 000 draws). Only small ranges use `u`, but the
  comment says "width may overflow", not "a value is missing".

---

## Part 2 — Pitfalls

**1. Never `each` a generator.** No `g each xs` anywhere (grep over every file). *Relies*: `t/core.q:43,141`,
`t/dist.q:6` use `{.qc.draw x} each n#enlist g`; `t/core.q:12` uses `.qc.draw k#enlist g`; `spikes/a5_rand.q:20`
notes it.

**2. `'[f;g]` after `:` is an each-assign.** *Relies*: `qc.q:121` `cast` parenthesises. No other site.

**3. Reserved words.** *Relies*: `t/names.q` enforces the library; the scan found none elsewhere. Column names
are pitfall 18.

**4. q-sql parameter shadowed by a column.** *Relies*: `qc.q:304` `chain` takes `s0 l0 d0` against columns
`s l d`; `qc.q:314` `pdesc` uses `s0 e0 l0`; `qc.q:211` `covt`'s parameter is `tests` and its local `nn` sits
beside column `n`; `spikes/a15_rec.q:46` comments on it. Nothing exposed.

**5 and 24. `like` wildcards and classes.** No pattern in any file has a middle `*` or a `[` (mechanical check).
*Relies*: `t/report.q:42`, `t/reportx.q:5` match the rerun line with end-anchored halves.

**6. `xs,:y` does not promote a typed vector.** *Relies*: `qc.q:97` `xs:xs,enlist x`, `:111,116` `cs:cs,enlist c`,
`:51` choices cast to long before `C,:`; `:229` `p,:v` is long onto long.
- [x] *Exposed*: `qc.q:180` `LX::distinct LX,s` — a non-symbol label promotes `LX` to a general list, which is
  what breaks `covt` later (C14).

**7. `rand 0`, `rand -k`, `1+0W`.** *Relies*: `qc.q:54` `unif` guards the width with `0<n`; `qc.q:58-59` `mix`
only calls `rand` on `8`, `5`, `2`, `2 xexp …` and `1+bits …` (never below 2).
- [x] *Exposed*: `qc.q:52` `fresh` with all-zero weights calls `rand 0f`, gets 0, and `binr` picks alternative 0 —
  `freq[0 0] (a;b)` always yields `a` with no error (reproduced); `freq` validates negatives but not "all zero".
- [x] The comment at `qc.q:47` says `fresh` is the only call site of `rand`; `unif` and `mix` also call it (they
  are `fresh`'s helpers).

**8. `system"S n"` returns nothing.** *Relies*: `qc.q:249` sets, `qc.q:279` reads back with `system"S"`.

**9. A parameterless lambda is unary.** *Relies*: `qc.q:68` `g[]`, `qc.q:167,176` `h[`init][]`, `h[`fini][]`.

**10. `::` is `101h`.** *Relies*: `qc.q:70` `dr`, `:351` `kind`, `:369` `df` test `(::)~x` first or route `101h`
harmlessly.
- [x] *Exposed*: `qc.q:38` `fn:{type[x] within 100 112}` therefore accepts `::` — see C20.

**11. Symbols intern forever.** *Relies*: `qc.q:137-138` bounded default alphabet; `qc.q:64` `lbl` interns one
symbol per distinct projection *structure*; `qc.q:348` `dbf` one per `(spec;prop)`; `qc.q:106` `tabs` one per
arity range.
- [x] *Exposed*: `qc.q:182` `collect` interns one symbol per distinct rendered *value*, unbounded over a wide
  generator (the comment says "bounded by the distinct values", which is the problem, not the bound). *(Documented
  in §1.4 and the README as "for small value spaces"; labels stay symbols because the cover table is keyed by them.)*

**12. `.Q.s` truncates to `\c` and flips nested tables.** *Relies*: `qc.q:354` `wide` around `fmt` and `collect`;
`qc.q:348` `dbf` hashes `-8!` bytes; `qc.q:396` the rerun line uses `string`; `tools/doc_child.q:4,6` sets
`\c 25 80` and uses `.Q.s` on purpose. `qc.q:273` `show tb` in `chks` is console-bound by design.

**13. `\l` errors drop into the debugger.** *Relies*: `t/run.q:6` `.Q.trp` around `system"l"`; `t/readme.q:11`
trap; `t/doctest.q:10` runs the child with `< /dev/null`; every example and spike ends in `exit`.

**14. `over` on an empty list; `()[0]` is `()`.** *Relies*: `qc.q:105` `$[m=0; …; conv over m#enlist T]`. The
`depth`/`nodes` walkers in `t/shrink.q:25-26`, `examples/tree.q:4-6`, `spikes/bench.q:8-9` terminate on `()`
because `each` over an empty list is empty.

**15. `bin` is −1 below the first weight.** *Relies*: `qc.q:52` uses `binr`; `spikes/a17_uniform.q:13` too.

**16. Two atom leaves collapse into a typed vector.** *Relies*: `qc.q:109-116` `sub`/`subb` build children with
`,enlist`, so a node function receives a typed vector for atom leaves; every node function in the tree tests
and examples dispatches on `0<type x` (`t/shrink.q:25-26`, `examples/tree.q:4`, `spikes/bench.q:8-9`,
`spikes/a17_uniform.q:29`). `qc.q:149` `tabr` and `:163` `smtab` rely on `flip` of general rows. Documented in
`examples/tree.q:4`; the user-facing rule lives only in a comment and this pitfall.

**17. `key` of a namespace includes the empty symbol.** *Relies*: `t/names.q:8`, `t/docs.q:5`.

**18. Reserved words as column names.** Every table literal checked (`C`, `E`, `TR`, `H`, `smt`, `dft`, `covt`'s
table, `chks`' table, `.t.R`, `.b.cases`): none reserved.

**19. Dict seeding.** *Relies*: `qc.q:292` `K` is seeded with an empty vector key; `qc.q:21` `L` is seeded with a
`::` key on purpose and only ever indexed with atoms (the comment at `:64` says why).
- [x] *Exposed (cosmetic)*: `qc.q:32,222` `TX` is seeded with `0N 0N` — see C4.

**20. `flip (a;b;c) ix` indexes the three-list.** *Relies*: `qc.q:327` `pdup` parenthesises.

**21. Nulls compare equal to themselves and below everything.** *Relies*: `qc.q:54` `unif` (`0<n` is false for a
null width), `qc.q:226` `pick` (a wrapped bound is `0N`, so `within` rejects it), `qc.q:219` `opn` (a null
requirement is never open), `qc.q:213` `covt` says `or null req` explicitly, `qc.q:220` `wid` and `:55` `bits`
test `null` first. `t/types.q:19` and `t/review.q:28` write `null x`, as the pitfall asks.
- [x] *Spirit*: `qc.q:305` `chain` compares a past-the-end null (C2).

**22. `sum ()` is `()`.** *Relies*: `qc.q:193` `pass` treats `()` as vacuously true; `t/shrink.q:15` and the
`sum100`/`squares` cases in `spikes/bench.q:14` depend on it for the empty list.

**23. `=` on floats is tolerant.** *Relies*: `t/self.q:31` (Catalan recurrence on floats near 1e22) benefits
from the tolerance.
- [x] *Exposed*: `t/types.q:29` compares floats with `=` — and is vacuous (C18).
- [x] *Exposed (accepted)*: `qc.q:287` `less` compares zig distances with `~` and `<`; distances are floats by C21, so two values above 2^53 that differ by less than the float spacing compare equal — the price of not wrapping, taken knowingly; two distances that differ by less than
  2^-43 relative compare equal, which can only happen for values above 2^43 — the same family as the C21 residue.

**23a. `"f"$0W` is finite.** *Relies*: `qc.q:220` `wid` casts only after the null check; `qc.q:285` `zig`;
`t/types.q:14` `inf` distinguishes the float-based types; `qc.q:125` `dbl` starts the exponent at −1022.

**25. `"1"` is a char atom.** *Relies*: `qc.q:359-362` `fmt1` returns `.Q.s1` strings (`t/report.q:6` pins
`enlist["1"]`); `qc.q:390-396` builds the report with `string`; `tools/doc_child.q:6` `"'",last r`.

**26. q-sql resolves globals in the root.** *Relies*: `qc.q:212` writes `.qc.RQ`, `.qc.wlo`, `.qc.wil`. The other
q-sql sites (`:302,304,307,314`) touch only columns and locals.

**27. Table indexing is row first.** *Relies* everywhere: `qc.q:89` `E[count[E]-1;`x]`, `:170-173` `c[j;`gen]`,
`:237-240` `TR[m;`lo]`, `:304-329` `tb[j;`s]`; `t/report.q:17` `d[0;`path]`.

**28. `f[::]`; a keyed table is `99h`.** Keyed-table checks present: `qc.q:70` `dr`, `:164` `sm`'s `cmds`,
`:187` `shape`, `:191` `byname`, `:352` `kind`, `:375` `df`. *Relies*: `qc.q:172` `c[j;`post][m;a;]` elides
properly; `examples/sm_ipc.q:14` uses `::` as a trap handler; `qc.q:151` `ktab` passes `::` as `d` explicitly.
- [x] *Exposed* — keyed-table check missing at: `qc.q:149` `tabr` (`99h<>type cg`, raises `nyi`), `:272` `chks`
  (`99h<>type d`, raises `type`), `:190` `conf` (`99h=type x`, raises `type`), `:164` `sm`'s `h` (`smh,h`, raises
  `type`), `:206` `named` (harmless: a keyed-table spec is a constant). Each reproduced. *(Fixed: one `dct`
  predicate used at all four sites.)*
- [x] The other half of the pitfall does not reproduce on this build: `{x}[::]` applies and returns `::` (type
  `101h`, not a projection), and `{[a;b] (a;b)}[::;1]` is `(::;1)`. The pitfall text should say what is meant or
  be dropped.

**29. `in` is reserved; a list literal evaluates right to left.** `in` is not a column (`arg`, `res`). *Relies*
(and it is a trap): tests assign inside the right-hand term of an `and` and read the name in the left-hand term
— `t/core.q:116-117,139,144`, `t/types.q:51-52`, `t/dist.q:26`, `t/reportx.q:12-13`, `t/ranges.q:17`. It works
because of right-to-left evaluation; combined with C2 it is what makes `t/types.q:52` raise `rank` instead of
failing when the value is not a table.

---

## Part 3 — Outside both lists

- [x] `qc.q:34` `reset` casts the prefix with `"j"$`, so `.qc.recheck[…; enlist 3.7]` silently replays choice 4.
- [x] `qc.q:47` comment: "The only call site of rand is fresh" — `unif` and `mix` call it too (pitfall 7).
- [x] `DESIGN.md` §4 pitfall 28's `f[::]` claim is inaccurate on kdb+ 5.0 (pitfall 28 above).
- [x] `DESIGN.md` §1.7/C12: the state-machine step-length exception is undocumented (C12 above).

---

## Part 4 — Suggested order for the cleanup pass

1. [x] **Bugs.** C9: `tidy` (or the end of `chk1`) restores `bs`/`sz` from `cfg`sz`. C18: the rerun line spells an
   empty vector (`` `long$() ``) and `t/reportx.q:7` draws `lst[0 300]`. C18: `t/types.q:29` becomes an exact
   test. `t/dist.q:34` stops clobbering `q`. (C7 `such`: withdrawn, see above.)
2. [x] **The harness (C2).** Make `.t.t` fail, not raise, on a raising assertion — take the condition as a lambda or
   have the harness trap each test — so one broken property no longer hides the rest of its file. Then the
   dependent `and` chains in `t/` can stay as they are or become conds at leisure.
3. [x] **Usage errors (C14, pitfall 28, C20).** `qc: …` for: keyed tables at `conf`, `tabr`, `chks`, `sm`'s `h`;
   non-symbol labels in `label`/`classify`/`cover`; unknown config keys; all-zero `freq` weights; non-pair
   `checks` entries; `one`/`freq` given a dict. Spell `qc: tree` as an internal error or drop it.
4. [x] **Seeds (C8).** One `system"S n"` at the top of `t/contracts.q`, `t/core.q`, `t/ranges.q`, `t/review.q`,
   `t/sm.q`; pin `t/readme.q`.
5. [x] **Test hygiene (C9, C10).** A test-visible owner for strict replay (or a `.qc.strict` entry) so tests stop
   setting `.qc.run` and calling `.qc.dr`; set the interactive size through `cfg`sz`+`new[]` rather than
   `.qc.reset`; restore `cf` from `cfg` in `t/core.q:57`.
6. [x] **Coverage (C18).** A `t/examples.q` that loads each example under a trap with a pinned seed (sm_ipc.q
   optional or skipped without a spare port); load `DESIGN.md`'s snippet blocks the way `t/readme.q` loads the
   README's.
7. [x] **Bounds arithmetic (C21).** `skey`/`bkey` in floats before `0W^`; `pdup`, `pred`, `mix` and `lin` in floats
   or guarded; `lst`/`sm` cap in floats; say in `unif`'s comment what the full range misses.
8. [x] **Docs.** Pitfall 28's text; C12's state-machine exception; the `qc.q:47` comment; the `dd` message for
   non-configurable generators; `TX`'s seed.

---

## M7 pass (2026-09-27)

The conventions rerun over the M7 code (`mono`, `uniq`, `dep`, `atr`, `mark`, `cands`, `udraw`, `rowd`, `tabx`,
`schema`, `schx`, `colg`, and `t/tables.q`):
- C1 canary on every new generator (contracts c10 over the six registry rows). `schema` is a constructor, as
  `lin` is; the generator it returns carries the canary (`t/tables.q`).
- C2 every guard is a cond; the one `and` (`count[at] and count rs`) has independent terms.
- C5 `t/names.q` green; five keyword collisions were caught while writing (`asc`, `attr`, `like`, `cols`, `vs`)
  and are recorded in the M7 paragraph.
- C9 the per-table state (`CS`, `UR`, `US`) is saved before and restored after every table, on the error path
  through the trap in `tabx`; it is not part of `reset` because it is per table, not per example.
- C13 rows stay spans; constrained columns draw inside the row span.
- C14 usage errors for a bad attribute, a non-function `dep`, a key that is not a column, a non-table schema,
  `p#` with `s#`. Bare errors that remain: none found.
- C16 `ktab`'s `k` accepts an atom (`(),k`); `atr`'s `a` is an atom by nature.
- C20 `dep`'s `f` goes through `need`.
- C21 `cands` uses `wid` for the range width.
- Pitfall 6 (dict form) the row accumulator behind a `::` seed; pitfall 28 `dct` at `tabr`, `ktab`; pitfall 30
  `lst`'s seed carries the rows.
- Not done: `tab`'s empty table stays untyped (documented in §1.3; `schema` is the typed way).
