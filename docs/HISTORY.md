# qcheck — history

What was built, in what order, and what each round of review found. Moved here from `DESIGN.md` (its §3 and §5)
so that the design document holds the design, the conventions and the pitfalls; the audits that the review rounds
name live beside this file. Line references inside the audits are to the trees they were written against.

## 1. Implementation plan

**M0 — validate.** Done: this document and `spikes/`. Every assumption that can be tested without engine
code is ✅ above; the four that need a shrinker or a state machine are scheduled where they can first be run.

**M1 — engine without shrinking.** Done: `qc.q`, `t/core.q`, `t/names.q`, `examples/reverse.q`,
`examples/tree.q`. Amended after the fact by the conventions in §1.10 (canary, run flag, exhaustion,
cond-chain guards, pinned seeds, name assertion), then by C9 and C10 (base size, `minimal` and `replay`). The conventions that
followed came from the evidence of M2 onwards, as §1.10 records.

**M2 — shrinker.** Done: eight passes, candidate cache, attempt budget, the `same`-error rule, shrink history,
`recheck` with stale detection, failure db, `cfg`clamp` switch; 27 tests in `t/shrink.q`; A6, A7, A8 and A13
measured with the real shrinker (no separate mini-shrinker was needed). Exit met: the A8 table is in §1.5.
Things the shrinker taught, folded back: span units and forced stop bits (§1.3), group duplicates by range,
windowed pairs, an empty general list is a vacuous pass (`all ()` is true), replay at full size, and the
reachability caveat on the order (§1.5) with the float layout it dictates for M4. The fold-in of M2's lessons
into conventions (C11–C13) is complete; further convention work waits for M3 evidence.

**M3 — reporting.** Done: `fmt` (total dispatch, console width managed), `diff` (type → count → value, one
row each), `eq` with `order`, `cover` with requirements and the `cover` outcome, `collect`, `checks`, `lf`/`again`,
`report` as lines; 42 tests in `t/report.q`. Exit met: the mock in §1.6 is asserted by a test. Folded back
afterwards: the closed error vocabulary (C14), confidence-based coverage (C15), and the exact rerun line.
`symc`/`sym` and `tabr`/`tab` belong to M4 and follow the naming rule with the canary (C1).

**M4 — type zoo.** Done: `spc` (the uniform `[kind; special; value]` wrapper), `.qc.t` for all eighteen atom
types, `dbl` (A13's `[sign; e; m]`, exponent from −1022 because `2 xexp -1074` underflows), `flt r` (ranged,
`[sign; k; m]` = `±m/2^k` with `m` bounded per `k` so no clamping is needed), `gid`, `chrc`/`chr`, `strc`/`str`,
`symc`/`sym`, `vec`, `tabr`/`tab`/`ktab`; 33 tests in `t/types.q`. Exit met: every `.qc.t c` value has type `c`,
its minimal value is `c$0`, and `{null x}` shrinks each numeric and temporal type back to `c$0` from wherever
the failure was found. Two float encodings were kept on purpose: a ranged one cannot reach `1e300` with a
long mantissa, and the exponent form is not uniform on any interval. Folded back afterwards: C16 (atoms as
one-element lists, closing `replay[5]`), C17 (the one-sided-range skew of the integer mixture and uniform node
counts for `rec`), the hint vocabulary, and the empty-table note.

**M5 — state machines.** Done: `sm` with defaults merge, `steps` range, forced stop when no command is
available, step spans (C13), trace table `step cmd arg res model ok` (empty table when empty, C4), `qc.post`
and `qc.run <e>` as failure signals raised from inside a spec; 16 tests in `t/sm.q`. What it taught, folded
back: a failure signal raised while a spec is drawn is a falsification, not a generator error (C14 now
classifies by stem, since `qc.run` carries the system's error text); and q indexes tables row-first
(`c[j;`gen]`, not `c[`gen;j]`). Original exit:
`examples/sm_table.q` (a kdb table against a dict model) and `examples/sm_ipc.q` (A14) both find and shrink
planted bugs.

**M6 — polish.** Done: `README.md` from the §1.2–1.7 examples (its snippets are run by `t/self.q`'s sibling
check in the verification); `t/self.q` uses qcheck on qcheck's pure parts — the shortlex order is a strict total
order under which deletion and moving toward the origin are strictly smaller, the edit primitives are exact,
`diff` finds a difference iff `~` fails and `eq` agrees, `fmt` is total and restores the console, the Wilson
bound is a probability monotone in the count, the counting tables satisfy the Catalan recurrence, the shrink
history never lengthens and every shrunk result rechecks — and the design's "a nested check signals" is now
enforced by a guard in `chk` and `recheck`, which the dogfooding is exactly where one would have tried.
Dogfooding found one real bug: `byname` took any 99h value for a dict of parameters, so a property over a
*keyed table* failed with a type error from `key`; the fix's first draft then broke twenty tests by writing
the guard with `and` — C2 and C3 in one line, and the reason the conventions exist. Folded back afterwards (the M6
check): the interactive entry points refuse to run inside a run, as `chk` does (C10 complete); every runner
dispatcher is exercised over one shape zoo; the README's blocks are executed by `t/readme.q` (C18).

**M7 — tables and schemas.** Done, from spikes A18–A21 and A23: `mono`, `uniq`, `dep` as constrained columns
drawn row by row inside `tab`; `atr`; `schema` as a constructor over a sample table; distinct keys in `ktab`;
`t/tables.q` (the A18 minima, the A20 as-of-join bug, meta round trips for six shapes) and six registry rows.
What it taught, folded back: a dict amended with one symbol has a typed value list and refuses the next long, so
the row grows behind a `::` seed (pitfall 6 in dict form); `where` over a dict gives keys, over a list indices;
`p#` failing is reported as `u-fail`; `asc`, `attr`, `like`, `cols`, `vs` are all keywords (pitfall 3, five times
in one milestone); `0#` of a table drops attributes while `0#` of a vector keeps them; and a general column's
`meta` type is read from its first element only.

**M8 — scale.** Done, from A22: `chn` records a block of n choices in one call (fresh values by `n?` through
`freshn`, `unifn`, `mixn`; replay by slicing the prefix), `bulk` and `btab` draw over it, `pblk` deletes the same
chunk from every block of a span and lowers the length (ddmin), and `cfg`choices` bounds draw calls rather than
recorded rows. `t/scale.q`: a million longs in under half a second, `x~asc x` over 1e5 elements to `1 0` in
under 100 attempts, a `btab` bug over 1e5 rows to one row. What it taught: a block span with several columns
needs the chunk removed from every block, or the columns misalign and the minimum stalls (found by the
transcript, 12 rows where one would do); and `blk` was already a name in the shrinker — a collision the
`t/names.q` scan cannot see because both are in `.qc` (the generator is `bulk`).

**M9 — integration.** Done: `must`/`mustc` (the report as one signal, A24), `main` (exit code = failures), the
`ms` column in `checks` (returned, not printed), `.j.j` documented as the machine-readable form (A25), and the
`\S` reseed as pitfall 32. `t/integ.q`: the signal's first line is the verdict for falsified, gave-up and
coverage outcomes; every outcome round-trips through `.j.j`/`.j.k`; `main`'s exit codes checked in a child q.

**M10 — time, values, state machines.** Done, from A26 and A27: the zoo rebuilt over `tin` so `tf` (finite) and
`t` (full domain) share one table of inner generators; `dble` so a real never overflows; `ts` and `dates`;
`val`; `inv` and `w` in `sm` with `qc.inv` as a fourth failure stem. `t/types.q`: no null or infinity from any
`tf`, `t` still reaches them, the xbar bug shrinks to four timestamps at the open, `val` round-trips; `t/sm.q`:
the invariant falsifies and shrinks, weights are honoured 3:1. What it taught: `f'[a;b]` over a three-argument
`f` is a projection of the each, not a list of results; the space and the empty symbol *are* q's nulls for `c`
and `s`, so a finite zoo must drop them; `value`, `any`, `inv` are keywords (the hook keeps `inv` as a dict key,
never a name); and drawing the command index by weights moved the state-machine transcripts by four examples.

**M11 — cookbook.** Done: six recipes in `COOKBOOK.md`, every transcript executed by `t/doctest.q` and every
name checked by `t/docs.q`: the as-of join (M7), upsert on keyed tables (`uniq` keys), a splayed table read back
(`schema`, `.Q.en`, enumeration), a tickerplant handler as a state machine with an invariant (M10), serialisation
and JSON over `val`, per-minute bars over `mono` and `ts`. Each recipe's planted bug shrinks to its analytic
minimum. Writing them found nothing new in the library; two recipes taught q facts the reader meets anyway (the
empty table is the smallest witness of enumeration; JSON's smallest non-round-tripping value is a byte).

**M12 — the worked example.** Done: `examples/mdp/` — a market data pipeline (reference data, quotes and
enrichment, per-minute bars, positions and PnL, end of day to a splayed partition, then corrections and renames)
built one piece at a time with a property suite per piece, then a state machine over the assembled system with the
event log as its model and a full recompute as its oracle. Developed honestly and logged as it went in `LOG.md`,
nothing planted: every step, including the buggy ones, is a file under `steps/`, and every transcript in the log
is executed against it by `t/doctest.q`. Twelve findings surfaced; eight fell to a property over one piece on a
one- or two-row example, one to the state machine on a four-step trace (a long under an old name and a short under the
new one merge at the close into a flat position with no realised PnL: a bug that exists only where renames,
positions and the day boundary meet, and that no piece's tests could see). What it changed in the library: `tab`'s
empty table is typed by a probe (M7's limitation, removed); an error in a state machine's `run` or `post` notes the
trace *including* the step that raised; a model that holds tables is left out of the trace print; `eq` reports
`keytype` for two empty dicts whose keys differ in type. What it taught about using it: the default budget does
not find three-command conjunctions (a sabotage showed it: 100×20 missed, 300×60 found and shrank it to three
steps), `classify` over the trace is how to know what a machine has reached, and the test harness is code (a reset
that deleted every global, pitfall 43; a generator that could not reach its seam). `run.q` runs the final system's
properties and machine under `.qc.main` and is run by `t/examples.q`.

---

## 2. Review rounds

After M6 the user asked for an intensive review and then for repeated rounds guided by principles that
generalise the *classes* of bug met across the milestones, stopping only when a round finds nothing. Each row
names the principle, the class it generalises, what the round found when the principle was applied to the
whole codebase rather than to the instance that had surfaced it, and the mechanical check that now enforces it.

| round | principle | what applying it found | check |
|---|---|---|---|
| 0 | the intensive review itself | `flt` on a huge range errored; `sm` took a plain dict for a keyed table and skipped `fini` on errors; `eq`'s order row leaned on an accident; `elem`/`one`/`freq` failed obscurely on empty input; two locals shadowed engine globals; the ok-line suffix indexed a possibly missing key | `t/review.q` |
| 1 | C5 extended: names and shadowing | no reserved identifier anywhere; twenty-two locals shadowing `C t i N ns` | `t/names.q` scan |
| 2 | C20: callability; C2 audit | nine application sites unguarded (`sized 5` would have written to IPC handle 5); one `and` that ran the shrinker's passes after the budget | `need`; `t/review.q` |
| 3 | C21: bounds arithmetic in floats | `zig 0W` overflowed the shrink key; binary search stopped on full ranges; counting tables went infinite silently | `t/review.q` |
| 4 | C9 audit: restored on every exit | `recheck` unprotected; a run's config leaked into the REPL; `fini` skipped on a discard; composition labels could grow per draw | `t/review.q` |
| 5 | G1 audit: exact identity; C18 extended | the failure-db key hashed a width-truncated string; `collect` labels truncated; `.qc.lin` missing; the harness had been coercing non-booleans | `t/docs.q`; strict `.t.t` |
| 6 | C17 audit: measured distributions | the tests' first bounds were wrong, the distributions right (full-domain longs are ~9% specials because the normal branch's boundary picks include `±0W`) | `t/dist.q` |
| 7 | convergence: every scan and audit rerun, the library read once more | one input guard (negative weights) | — |
| 8 | convergence, repeated | nothing | — |
| 9 | the audit (`AUDIT.md`): every convention and pitfall against every file, each finding reproduced | a run's size leaking into later draws (C9); an elided rerun line for an empty vector and a test that was `x=x` (C18); bare q errors for keyed tables and non-symbol labels (C14, pitfall 28); unpinned seeds in five files (C8); long arithmetic wrapping at six more sites (C21); the examples and the design's snippets not run (C18); a raising assertion skipping its file (C2) | `t/examples.q`, `t/review.q`, the per-statement harness in `t/run.q` |
| 10 | the second audit (`AUDIT2.md`), over phase 2 | two `mono` columns of different types (pitfall 6 in dict form, now C23); `colg` sending table-valued columns down the enumeration branch; `unifn`'s long condition (pitfall 42); a `uniq` used set collapsing to a table; the C9 regression test appended before its list existed (pitfall 41); bare errors at the new boundaries; no C22 after five milestones | `t/tables.q`, `t/scale.q`, `t/review.q`, `t/dist.q` (C25), `t/names.q` (duplicate definitions) |

Two of the round-4/5 fixes were themselves wrong on first writing (`md5` takes chars, not bytes; a list-valued
dict key indexes several keys), which is the same lesson as C2/C3 at M6: the conventions exist because the
fixes are subject to them too. Converged: the last round found nothing.

### 3. The suite that would have caught them

After the review rounds the tests were reorganised by contract and driven by data, so that a bug class is
covered wherever it can occur rather than where it happened to surface. Every generator is a row of a
registry (`t/0gens.q`) and every contract runs over every row (`t/contracts.q`, one test per generator per
contract): draws at every size, minimal is the origin, a choice is recorded, replay across sizes, exact
self-replay under shrinking, type stability, bounds, label stability, clean state, the canary, and joining a
running example. The range grid (`t/ranges.q`) puts `int`, `lst` and `flt` through fourteen range shapes in
five modes. The outcome matrix (`t/outcomes.q`) pins the pass rule, every signal in both phases, the result
schema per outcome, and the engine's state after every exit including error exits. The A8 minima are asserted
with attempt caps (`t/bench.q`); the rerun line round-trips as a property (`t/reportx.q`); distributions are
measured (`t/dist.q`); and every transcript in the documentation is executed (`t/doctest.q`).

Mapping the recorded bugs to their covering family: `rand 0`, `1+0W`, `unif`'s overflow, the mixture's
one-sided skew, `wid` on full ranges and `flt`'s huge-range error — ranges and dist; size-0 lists, forced
stop bits, span units and replay at full size — contracts 3, 4 and 5; typed-empty lists, `"f"$0W`, char atoms
— contract 6 and the type rows; `::` as 101h, keyed tables as 99h, `byname` — the shape zoo in self.q and
contract 1 over the type rows; `qc.eq` swallowed by a prefix, engine signals in the property phase — outcomes;
the run flag poisoning a session, `cf` leaking, `dp` left dirty — outcomes' state-after-exit and contract 9;
truncated rerun lines and db keys — reportx and review; the composition label growth — contract 8; C16 atoms
— review and the registry's single-item rows; every README line that did not parse — doctest and readme.
Building the suite found one more inconsistency (an engine signal raised in the property phase was a
falsification, not a discard) and nothing else: 1013 tests, all green; 1019 with the choice tree's cases in `t/stop.q`; 1034 after the audit's cleanup pass; 1462 after phase 2 and the worked example (the count at the time of each writing — `q t/run.q` prints the current one).
