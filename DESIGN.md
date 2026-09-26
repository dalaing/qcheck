# qcheck — property-based testing for q

*Design document. Status: complete — assumptions validated on kdb+ 5.0 (2026.07.23, m64); M1–M6 implemented in `qc.q`, tests in `t/`, examples in `examples/`, usage in `README.md`.*

qcheck takes the choice-sequence engine and integrated shrinking of **Hypothesis**, the failure reporting and
`Range`-style generator control of **Hedgehog**, and the state-machine testing of both, and expresses them in
the shape a seasoned q programmer expects: a handful of primitives, data over objects, tables for anything with
structure, composition through the verbs q already has.

Contents: 1 Design · 2 Assumptions and validation log · 3 Implementation plan · 4 Pitfalls.

---

## 1. Design

### 1.1 Why the Hypothesis model is the q model

Hedgehog's `Gen a = Seed -> Size -> Tree (Maybe a)` needs laziness, closures and monadic bind. q has none of
these: lambdas do not capture lexical scope, evaluation is strict, and there is no `>>=`.

Hypothesis's model is different: a generator is an *imperative procedure that reads choices from a stream*.
The engine records the choices; shrinking edits the recorded stream and replays. In q this becomes:

- the choice stream is a **table of parallel long vectors**, edited with `_`, `@[;;:;]` and `,`;
- generation state is **global**, like `.z`, `.Q` and `\S`, so *bind is `;` inside a lambda*;
- shrink passes are **vector transformations** and the shrinker is `while[changed; ...]` over them;
- the *values* of choices are recorded, not RNG state, so user code calling `rand` inside a property cannot
  break replay or shrinking. That matters in q, where the RNG is a single process-global (A3).

The library rests on three ideas, each one q-native:

1. **One draw primitive** — a bounded long with an origin (its shrink target). Everything is built on it.
   Size is not a second primitive: it is a *budget* that structures spend — lists read it for expected
   length, and recursion partitions it among children (§1.3).
2. **One interpreter** — `.qc.draw` is a homomorphism over q data: functions are called, dicts and general lists
   are drawn elementwise, everything else is a constant. *Any q data structure of generators is a generator.*
3. **One order** — shortlex on the choice vector: fewer choices, then each choice closer to its origin.
   "Simpler" is defined once, for every type, by construction.

### 1.2 Vocabulary and calling convention

A **generator** is any q function value (lambda, projection, composition — `type` within `100 112h`) that, when
applied to `::` (called as `g[]`), draws from the stream and returns a value. Users never see that trailing
argument: library generators are functions whose *last* parameter is the implicit `d`, so supplying the
configuration arguments yields a projection, and the projection is the generator.

```q
.qc.int 0 100            / projection of {[r;d] ...}  -> a generator
.qc.list .qc.int 0 100   / right-to-left evaluation reads like  list (int 0 100)
.qc.lst[0 5] .qc.sym     / config first, generator last: .qc.list is the projection .qc.lst[0 0W]
```

**Map is composition.** `'[f;g]` (or the idiom `(f g@)`) applied to `::` gives `f g[]`. Written right after
`:` the compose form must be parenthesised, or q reads `:'` as an each-modified assignment:

```q
h:('[neg;.qc.int 0 9])              / generator of negated ints
(reverse .qc.list[.qc.int 0 9]@)
```

**Bind is sequencing.** No combinator:

```q
{n:.qc.draw .qc.int 1 9; .qc.draw .qc.lst[n,n] .qc.sym}      / dependent generation
```

**Product is a list, record is a dict.** `.qc.draw` recurses:

```q
(.qc.int 0 9; .qc.sym)                 / generator of a pair
`name`age!(.qc.sym; .qc.int 0 120)     / generator of a dict -> named inputs in the failure report
(`add; .qc.int 0 9)                    / constants embed freely
.qc.draw 3#enlist .qc.int 0 9          / three independent draws
```

Interpreter rule: recurse into `0h` lists and `99h` dicts; call function values; everything else — atoms,
typed vectors, tables, and `::` (type `101h`, treated as a constant) — is returned as is. A function-valued
*constant* is wrapped with `.qc.const`. `.qc.draw` never applies a *value*, which is why everything goes
through it: `g each xs` applies the drawn value to each element, and a small integer value is an IPC handle
write (pitfall 1).

**Naming.** A configurable generator takes its configuration first and has a short base name; its default is a
*different* word bound by projection: `lst`/`list`, `bit`/`bool`, `symc`/`sym`, `chk`/`check`. A default cannot
be re-parameterised — `.qc.list[3 5] g` would bind `3 5` as the generator — and every library generator detects
the attempt and names the configurable form (§1.10, C1). A user generator written as `{...}` receives `::` in
`x`; a lambda that uses `x` for anything is a generator error.

**A range is a vector or a function of size.** Hedgehog's `Range` becomes `lo hi` or `lo hi origin` (origin
defaults to `0` clamped into `[lo;hi]`), or a unary function of the current size returning such a vector:

```q
.qc.int -100 100        / constant range, shrinks toward 0
.qc.int 1 1000 1        / shrinks toward 1
.qc.int {0,x}           / grows with size (size ramps 0..100 over a run)
.qc.int .qc.lin[0;1000] / helper: linear in size, = {0,1000*x%100}
```

A range function must **widen with size**: its lower bound never rises, its upper bound never falls, its
origin does not move (C11). Shrink candidates, `recheck`, `replay` and saved failures are all replayed at the
full configured size, and that is sound only because a value found under a smaller size still lies inside the
larger range. `{(x div 2;x)}` — "at least half the size" — breaks the rule and would replay a size-6
counterexample as a different value. `.qc.lin` and the library's own size-dependence (`lst`'s cap, `rec`'s node
count, `small`'s halving) obey it, and `t/core.q` checks every library generator replays across sizes.

### 1.3 Generators (namespace `.qc`)

| Name | Meaning |
|---|---|
| `.qc.draw x` | interpret a spec: function → call; dict / general list → draw elementwise; else constant |
| `.qc.minimal x`, `.qc.replay[choices;x]` | the other interactive entry points: the simplest value of a spec; the value a recorded choice vector produces (C10) |
| `.qc.ch[r;w]` | **the primitive**: a long in range `r` = `lo hi o`; `w` is a fresh-draw distribution hint |
| `.qc.int r` | long in range; no nulls or infinities |
| `.qc.bool`, `.qc.bit p` | boolean; `bit p` draws `1b` with probability `p` on fresh draws; origin `0b` |
| `.qc.flt r` | float in `[lo;hi]`, layout `[sign; k; m]` = `±m/2^k`; 0 (or the nearest bound) is simplest, integers before halves before quarters; `.qc.dbl` is any finite double, `[sign; e; m]` = `±m·2^e` |
| `.qc.chr`, `.qc.chrc s` | a char from `.qc.AZ` (letters, digits, space; origin `"a"`), or from alphabet `s` |
| `.qc.str`, `.qc.strc[s;r]` | a string (typed even when empty), alphabet `s`, length range `r` |
| `.qc.sym`, `.qc.symc[s;r]` | a symbol over a **bounded** alphabet: default `"abcd"`, lengths 0–3, ≤ 85 symbols, the null symbol simplest |
| `.qc.t c` | **dict** type-char → generator of that atom type's *full* domain: `.qc.spc[specials] g` wraps a normal generator in the uniform layout `[kind; special; value]` (C12); `.qc.t"j"`, `.qc.t"p"`, `.qc.t"jf"` (a pair); origin is `c$0`; `.qc.gid` for guids |
| `.qc.list g`, `.qc.lst[r] g` | variable-length list of `g`, length range `r` (default `0 0W`, capped by size); homogeneous atoms become a typed vector automatically |
| `.qc.vec[r] c` | typed vector of `.qc.t c`, typed even when empty |
| `.qc.tab cols`, `.qc.tabr[r] cols`, `.qc.ktab[k;r] cols` | a table from a dict of column generators, drawn as rows so a row is one span (C13); row-count range `r`; keyed on columns `k`. An empty draw has untyped columns (no row was drawn to learn them); use `tabr[1 0W]` when a typed empty table matters |
| `.qc.one gs` | one of several alternative specs; the first is the simplest *provided it draws no more choices than the others* (C12) |
| `.qc.freq[w] gs` | weighted alternatives, parallel lists |
| `.qc.elem xs` | an element of a constant list (preferred over generating symbols) |
| `.qc.such[p] g` | filter with bounded retries, then discard |
| `.qc.rec[k;leaf;node]` | **recursive structures**: child-count range `k`, leaf spec, and `node`, a function of the list of already-drawn children (below) |
| `.qc.const x` `.qc.sized f` `.qc.small g` | constant escape hatch; `f` of size returning a spec; halve the budget for a sub-spec |

**Recursion.** The naive q tree `{$[.qc.draw .qc.bool; (tree;tree); leaf]}` is a *critical* branching process:
finite with probability 1 but with infinite expected size, so it occasionally runs into q's stack limit
(A4, A16). Halving the size per level (`.qc.small`) makes it finite but dull: every tree at a given size has
depth ≈ log₂ size and the same silhouette (A15: depth IQR ≤ 4, max depth 5 at size 30).

`.qc.rec[k;leaf;node]` instead **spends the size budget exactly**. One draw of it:

1. draws the node count `n` from `0,size` (a recorded choice, origin 0 — the simplest tree is a leaf);
2. builds a subtree with budget `b`: if `b<1` draw `leaf`; otherwise spend one unit, draw the child count `m`
   from `k`, give each child but the last a drawn share of the remaining budget and the last child the rest,
   build the children with their shares, and return `node children`.

```q
tree:.qc.rec[2 2; .qc.int 0 9; {(x 0;x 1)}]                     / binary tree
rose:.qc.rec[0 4; .qc.sym;     {(`n;x)}]                        / rose tree, 0..4 children
json:.qc.rec[0 4; .qc.one (.qc.int -9 9;.qc.str 0 5;.qc.bool);
             {$[.qc.draw .qc.bool; x; (.qc.draw .qc.lst[n,n:count x] .qc.sym)!x]}]   / list or dict node
```

- `node` receives *values*, so it can compute on its children, draw more (a tag, dict keys) and build any q
  structure. It is the F-algebra of the type; generation is an unfold driven by the budget. No global
  self-reference and no closure is needed.
- Every structural decision — `n`, each `m`, each share — is a recorded choice with origin 0, so the shrinker
  can shrink a whole tree by one integer, prune a subtree by one integer, and delete subtrees by span deletion.
- Bounded by construction: nodes ≤ size, no discards, no reliance on the depth guard. Minimal mode gives a leaf.
- The value of a `rec` draw is a **union**: a value of `leaf`'s type when the budget is 0 (always for the minimal
  example), otherwise whatever `node` returned. Properties dispatch on the leaf case first, and remember that two
  atom children of one type collapse into a typed vector unless `node` tags them (C3).

**Which shapes, and how often.** The choice stream fixes *what* is recorded; the distribution over shapes is
decided entirely by the *fresh-draw weights* of the arity and share choices, exactly as the integer mixture is
a fresh-draw matter for `int`. Two laws are worth having, and they differ a lot:

- **Uniform over shapes** (the default). Every tree with `n` internal nodes is equally likely. This is what a
  critical Boltzmann sampler conditioned on size gives — Yorgey's leaf-or-branch-at-½ sampler with a size
  window and early abort, [byorgey.wordpress.com, 2013](https://byorgey.wordpress.com/2013/04/25/random-binary-trees-with-a-size-limited-critical-boltzmann-sampler-2/),
  O(n/ε) expected — but we get it without rejection: the arity is drawn with weight `C[m][r]` (the number of
  `m`-tuples of trees totalling `r`) and each child's size `j` with weight `T[j]·C[m-i][r-j]`, the classic
  counting ("recursive") method. Exact size, zero discards, O(size²) floats computed once per `k` and cached.
  For binary trees this is the Catalan split `P(left=i) ∝ Cᵢ·Cₙ₋₁₋ᵢ`, strongly U-shaped: typical depth Θ(√n).
- **Uniform cut** (`.qc.recb`, "balanced"). Each share uniform on `0,remaining`: the random binary-search-tree
  law, typical depth Θ(log n), bushier. Useful when the property is about breadth rather than depth.

Measured (A15 uniform cut, A17 uniform over shapes; 500–1000 trees per row; node = internal node):

| law | shape | size | nodes q25/50/75 | depth q25/50/75 | max depth |
|---|---|---|---|---|---|
| halve (`.qc.small`) | binary | 30 | 0 / 0 / 5 | 0 / 0 / 4 | 5 |
| stick-breaking, unknown arity | binary | 30 | 0 / 2 / 7 | 0 / 2 / 5 | 10 |
| uniform cut (`recb`) | binary | 30 | 7 / 15 / 22 | 5 / 7 / 8 | 13 |
| uniform cut (`recb`) | binary | 100 | 25 / 48 / 74 | 8 / 10 / 12 | 19 |
| uniform cut, n fixed | binary | n=100 | 100 | 12 / 13 / 14 | 19 |
| **uniform over shapes (`rec`)** | binary | n=100 | 100 | 25 / 29 / 34 | 51 |
| **uniform over shapes (`rec`)** | rose 0–4 | n=60 | 60 | 16 / 19 / 21 | 32 |

A17 also checked the law itself: over 14 000 draws the 14 binary shapes with 4 nodes each appeared between
950 and 1055 times. Counting tables are floats; the binary count at size 100 is 8.97e56, and floats hold to
about size 500 (log-domain tables if `cfg`sz` is ever raised that far). Build time for size 100: 10 ms binary,
64 ms for arity 0–4, with naive spike code.

**The primitive in detail.** `ch` advances the cursor, then takes its value from one of four sources:
replaying a prefix (the value is *clamped* into `[lo;hi]`), minimal mode (returns the origin), shrinking past
the end of the prefix (signals `"qc.overrun"`), or a fresh random draw. It appends `(v;lo;hi;o)` to the choice
table and returns `v`. Fresh integer draws use a mixture: one time in eight a boundary value
(`o lo hi o+1 o-1`), otherwise a magnitude uniform over the *bit-widths of the range* (`count 2 vs 0|hi-lo`,
63 when the width overflows to null) and a sign. Measured on `-1e6 1e6`: 25% under 10, 52% under 1000, 7.5%
at a bound (A5). The distribution is the generator's business and is never recorded, so it can be tuned
without affecting replay. The hints are a closed vocabulary, chosen deliberately by each generator:

| hint `w` | fresh-draw law | used by |
|---|---|---|
| `::` | the integer mixture: a boundary value (`o lo hi o+1 o-1`) one time in eight, else a random magnitude with a sign only where the origin leaves room | `int`, `dbl`'s exponent and mantissa |
| `` `u `` | uniform | `rec`'s node count, `one`/`elem`/`freq` indices, `flt`'s mantissa and fraction width, `spc`'s special index |
| float `p` | Bernoulli on a 0/1 range | `bit`, list continue bits, `spc`'s kind |
| float vector | weights over the range | `freq`, `rec`'s shape law |
 `ch` is the **only** call site of `rand`, behind two guards: `lo=hi` returns `lo`
(`rand 0` silently returns an arbitrary long), and an overflowing width (`1+0W` is `0N` on this build) falls
back to drawing a random half of the range (A5).

**Budgets.** `.qc.draw` counts nesting depth and signals `"qc.toodeep"` at `cfg`depth` (default 200); the
choice table is capped at `cfg`choices` (default 8192) with `"qc.toolarge"`. Both are named errors that
arrive before q's own `'stack` (about 1000 user levels through the interpreter, A16). During generation they
count as discards, reported separately (§1.4).

**Span units.** A span is what the shrinker deletes, zeroes, reorders or replaces, so each span must be a
self-contained unit: a list element's span holds its decision bit *and* the element, and every iteration
records a bit — forced `1` under the minimum, forced `0` at the cap — so the structure is the same at every
size and a replay at a larger size still finds its stop; a subtree's span holds its share *and* the subtree,
with the root's share being the node count and the last child's share a forced degenerate choice, so
replacing a tree by any of its subtrees is exact. (Both were found by the shrinker accepting nothing: a
deletion that leaves a bit behind, or a tree that ended at the size cap, overruns on replay.)

**Collecting elements.** `list`, `rec` and friends accumulate with `xs:xs,enlist y`, never `xs,:enlist y`:
in-place append onto a typed vector does not promote to a general list when the element's type differs — it is
a type error — while the plain join does (A1).

**q-specific coverage for free.** Every atom type's null and infinities; the 2000.01.01 epoch as the natural
origin for all temporals (`` `date$0 `` is `2000.01.01`); guids from sixteen byte draws (`0x0 sv`); typed
versus general lists; empty-list typing. Symbols default to a bounded alphabet because q interns symbols
forever: 1e5 unbounded symbols cost 5.4 MB that is never reclaimed (A11).

### 1.4 Properties and the runner

```q
.qc.check[spec; prop]            / .qc.cfg defaults
.qc.chk[cfg; spec; prop]         / cfg: dict merged over defaults, e.g. `n`seed!1000 42i; a long means n; :: means defaults
.qc.recheck[spec; prop; choices] / exact replay, no shrinking
```

`recheck` is `.qc.replay` plus the property. `draw`, `minimal`, `replay` and the shrinker are the four sources a
choice value can come from — fresh, origin, prefix, refusal — each owning its own example boundary (C10).

How the drawn value reaches the property:

- general-list spec → `prop . x` (one argument per element);
- dict spec and `prop` a lambda whose parameter names are all keys of the dict → applied **by name**,
  `` .qc.check[`n`xs!(.qc.int 0 9;.qc.list .qc.sym); {[xs;n] n<=count xs}] ``; otherwise the dict is passed whole;
- anything else → `prop @ x`. `.qc.check[::;prop]` is the interactive form: the spec draws to `::`, and the
  unary property draws whatever it needs with `.qc.draw`.

A property passes iff it returns `::` or `all` of a boolean result. Any signal fails it — except the engine's
own control signals (`qc.discard qc.overrun qc.toodeep qc.toolarge qc.misaligned`), an explicit list, not a
prefix: `qc.eq` is a real failure and shrinks like one. A `prop` of `::`
means "generation must not fail", which is how you test a generator. Draws made inside the property live in
the same choice stream and shrink with everything else — this is what makes state machines trivial (§1.7).

Inside a property: `.qc.eq[a;b]` (q's `~`, explained: on failure the diff table is noted and the property
fails with `"qc.eq"`; a reordered dict or table is reported as `order`), `.qc.note x` (Hedgehog's `annotate`),
`.qc.label s`, `.qc.classify[s;b]`, `.qc.collect x` (label by value), `.qc.cover[s;pct;b]` (the run fails with
`why` `` `cover `` only when it is confident the label's rate is under `pct`: the Wilson 95% upper bound of the
observed rate is below it, C15),
`.qc.discard[]`. After any failure `.qc.again[]` rechecks it and `.qc.lf` holds its spec, property and choices.
`.qc.checks d` runs a dict of name → `(spec;prop)` and returns a table (`.qc.chks[cfg;d]` with config).

Run loop for one property: (0) replay the saved failure from the db if there is one (`cfg`db`, default `` `:.qc ``,
one file per property keyed by `cfg`name` or an md5 of the spec and property source; a saved example that no
longer fails is deleted, a shrunk one is saved) — if the replay overruns or clamps any choice the generator has
changed since it was saved, and `recheck` says so rather than silently testing a different input; (1) example 0 in *minimal mode* — every fresh draw returns its origin, so the
simplest input is always tried first, for free — and a passing example that drew **no choices** has exhausted
the space, so the run ends after it with `n` 1 (a constant spec, or a property that never draws; C7);
(2) `n` examples with size ramping 0→100; (3) on failure,
shrink (§1.5); (4) report (§1.6). Discards are counted by cause (`filter`, `toodeep`, `toolarge`, explicit);
more than `disc`×`n` of them ends the run as "gave up", and the report names the dominant cause.

The result is data: `` `ok`why`n`shrinks`seed`x`err`bt`notes`cover`choices`disc`stale `` with `why` one of
`` `ok`falsified`gaveup`cover`error ``. Every field is always present and typed the same way: absent
composites are empty (`disc` an empty dict, `cover` an empty table, `notes` an empty list, `err` an empty
string); only `x` is `::` when there is no counterexample (C4).

Seeds are 32-bit ints, because that is what `\S` takes and `system"S"` returns (A3): `cfg`seed` of `0N`
becomes `"i"$1+.z.p mod 2147483646`, never 0, and is printed and accepted as an int.

Defaults in `.qc.cfg`: `n` 100 · `seed` `0N` · `sz` 100 · `shrinks` 2000 · `disc` 10 · `tries` 50 (filter
retries) · `depth` 200 · `choices` 8192 · `same` 1b (a shrink must reproduce the same error text) ·
`db` `` `:.qc `` · `v` 1.

### 1.5 Shrinking

State: `.qc.C` choices (`v lo hi o`), `.qc.E` spans (`s e l d x`: start, end, label id, depth, discarded),
`.qc.P` the prefix under replay, `.qc.i` the cursor, `.qc.L` a dict from generator identity to label id.

Replaying a candidate `P'`: reset, generate and run. Each draw takes `lo|hi&P' i` — **clamp on
misalignment** — so any prefix is a valid input and filters, dependent draws and state machines never see an
impossible value (A3). Running past the end of `P'` while shrinking signals `"qc.overrun"`: candidate invalid.
A candidate is accepted iff it is valid, still fails (with the same error text when `same` is set), and is
strictly smaller under the shortlex key `(count v; zig 0W^v-o)`, `zig:{(2*abs x)-x>0}` (0, 1, −1, 2, −2, …).
The four tests run as a cond chain in that order — cache, validity, failure, size — because q's `and`
evaluates every term and the property run is the expensive one (C2).
The `0W^` guards the one range whose distances overflow — the full long domain of `.qc.t"j"` — where ties at
the extremes are harmless.

Structure the shrinker exploits: every `.qc.draw` of a function wraps a **span** labelled by the generator's
identity; `list` wraps each element and emits a *continue bit* before it — forced bits are recorded as
`ch[1 1 1]`, a degenerate range the shrinker skips, so the structure is identical whether forced or not;
`rec` wraps each subtree; `such` marks rejected spans as discarded.

Labels: `.qc.L` is keyed by the generator value for lambdas and compositions, and by the **underlying lambda**
(`first value g`) for projections. Keying a projection by itself would hash its bound arguments on every draw
(`.qc.elem` over a large list), and `.qc.lst[0 5]` and `.qc.lst[3 3]` are the same *kind* of span, which is
what the reorder and descendant passes want. Lookup costs 180 ns (A10).

Passes, coarse to fine, repeated to a fixpoint under an attempt budget, with a dict cache keyed by the choice
vector (q dicts accept vector keys, A1). The loop and every pass are iterative, never recursive:

1. drop discarded spans; delete spans, largest first, with adaptive runs of adjacent siblings;
2. zero a span (set every choice to its origin);
3. replace a span by a descendant with the same label (collapses recursion);
4. reorder sibling spans of the same label into sorted order (canonical lists);
5. minimise duplicated values together (`group v`), then each choice individually by binary search toward its
   origin;
6. redistribute numeric pairs (`x-k, y+k`) and lower pairs together.

Each pass is a loop over the *current* structure that re-derives it after every accepted attempt (indices
shift, so nothing is precomputed), and the shrinker cycles the passes until a whole cycle accepts nothing or
the attempt budget is spent. Passes that need coordinated moves: duplicates are grouped by value *and* range
(a list's decision bits and its elements can share a value); pairs are sought within a window of three
positions among choices of the same range, because list elements are separated by their bits. The candidate
cache is a dict keyed by choice vectors and must be seeded with a vector key — seeded with `::` it amends
elementwise. Lists use continue bits rather than a length prefix so that deleting an element is one span
deletion: measured in A6, continue bits reach 9/9 minima, a length prefix 6/9.

Replay of candidates happens at the full configured size, not the size the failure was found at: ranges only
grow with size, replayed values are clamped into them, and the forced stop bits make lists terminate
regardless. Clamp-on-misalignment and reject-on-misalignment reach the same minima with the same attempts
(A7); reject is faster per attempt because it aborts early, but clamp keeps the invariant that every prefix
is a valid input, which the state machines and the interactive `replay` rely on.

**What the order can and cannot do.** Shortlex decides which of two *reachable* candidates is simpler; it does
not make every simpler value reachable. The passes make single-position and same-range moves, so a value
that is simpler under the order but needs two fields to change at once is a local minimum: a float encoded as
integer part plus fraction cannot get from −0.5 to −1, and a NaN drawn on the special branch cannot cross to
a normal value. Two consequences for encodings (A13): lay fields out so that the moves the shrinker makes are
the moves you want (sign · mantissa · 2^exponent, exponent first: moving the exponent toward 0 turns a
fraction into an integer while the mantissa stays put), and keep every alternative the same length — under
shortlex a two-choice special branch ranks below a four-choice normal branch, so `0w` would be "simpler" than
`100f` for `x<100` whenever both are reached.

Cost model (A2, A10): about 0.5 µs to append a choice, 0.5 µs for its span, 0.2 µs for the label — call it
1.2 µs per draw. A 1000-choice example generates in about a millisecond, so the default budget of 2000 shrink
attempts is a worst case of a few seconds on top of the property's own cost. Measured on the A8 suite: 18
properties shrink to their analytic minima in 546 attempts and 146 ms in total, the worst case 79 attempts.

**A8 — shrink quality** (`spikes/a8_bench.q`; every case reaches its analytic minimum):

| property | found | shrinks | attempts |
|---|---|---|---|
| `x~asc x` on lists of `0..99` | `1 0` | 7 | 31 |
| `x~reverse x` | `0 1` | 8 | 33 |
| `x~distinct x` | `0 0` | 2 | 14 |
| `5>count x` | `0 0 0 0 0` | 2 | 36 |
| `100>=sum x` | `2 99` | 13 | 54 |
| no adjacent equal | `0 0` | 3 | 14 |
| `x<=50` | `51` | 2 | 12 |
| `x>=0` on `-99..99` | `-1` | 0 | 2 |
| `x>=y` | `0 1` | 0 | 3 |
| nested lists, total < 6 | `(,0;0 0 0 0 0)` | 5 | 79 |
| nested lists, sum ≤ 5 | `,,6` | 4 | 33 |
| binary tree, depth < 3 | `(0;(0;0 0))` | 4 | 34 |
| binary tree, nodes < 4 | `(0;(0;(0;0 0)))` | 3 | 40 |
| rose tree, < 3 children | `` (`n;0 0 0) `` | 1 | 12 |
| filtered `such[{x>0}]`, sorted | `2 1` | 8 | 55 |
| `x<1000000` on `0..0W` | `1000000` | 32 | 62 |
| interactive draw `n<10` | choices `,10` | 4 | 10 |
| `100>sum x*x` | `,10` | 6 | 22 |

Hypothesis's attempt counts were not measured (it is not installed here); its documented minima for the
comparable cases (`[1, 0]`, `[0, 1]`, `[0, 0]`, five zeros, `51`, `-1`, a three-node chain) agree.

### 1.6 Rich output

- **The formatter** (`.qc.fmt`) is a total dispatch over the eight shapes (C3): atoms, typed vectors and
  functions print as q prints them; a dict prints one `key: value` line per key, with tables, dicts and nested
  general lists indented as blocks under their key; a general list of blocks is numbered; tables print as
  tables, cut to `cfg`rows` with an explicit `... n more rows`. It widens the console to 400 columns for the
  duration and restores it, because `.Q.s` and `.Q.s1` both truncate to `\c` and `.Q.s` prints a table
  nested in a dict in flip notation (A9).
- **The counterexample** is a dict keyed by the property's parameter names (`(value prop)[1]`, A1) or by the
  spec's own keys, printed by the formatter.
- **`.qc.diff[a;b]`** returns a table `([] path; why; a; b)`, `why` one of `` `type`count`value`key`order ``,
  built type-first, then count, then values, never comparing values of different types (C2, C3). `a`/`b` hold
  the types for a `type` row, the counts for a `count` row, the values otherwise; `path` is the list of keys,
  columns and indices down to the difference. Strings compare as a whole; keyed tables compare unkeyed; dicts
  and tables compare by key and column name, so reordering is not a difference to `diff` but is to `~`, which
  is why `eq` reports it as `order`. q's classic bugs — `7h` vs `6h`, `1 2 3` vs `1 2 3f`, a missing key, an
  extra row — become one row each.
- Notes in order (a noted table prints as a table, which is how `eq`'s diff arrives); the error text unless
  it is the plain `false` of a property that returned `0b`; the `.Q.trp` backtrace at `cfg`v` 2; the seed;
  and a rerun line naming `.qc.again[]` and the shrunk choice vector, rendered exactly.
- The coverage table `label n pct req hi ok bar` whenever a label was used — `hi` is the Wilson upper bound
  `ok` is judged against — and a requirement that was never hit still has its row, with `n` 0.
- **Display is not transport.** `.Q.s` and `.Q.s1` truncate to the console and are used only for looking at
  data; the one line meant to be copied back, the rerun line, renders the choice vector exactly with `string`
  and `sv`. (Found by an 81-choice failure whose rerun line ended in `..`.)

`.qc.report r` returns the lines and `.qc.rep r` prints them, so the report is testable; this is
`t/report.q`'s assertion of the mock below, now real output of `.qc.check[.qc.list .qc.int 0 100;{.qc.eq[x;asc x]}]`:

```
FAIL falsified after 4 tests, 7 shrinks (31 attempts, seed 7)
x: 1 0
qc.eq
path why   a b
--------------
0    value 1 0
1    value 0 1
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 1 1 0 0]
```

(`ok`/`FAIL` rather than `✓`/`✗`: the marks print fine on this console, but `like` and `ss` count them as three
bytes and a log file may not be UTF-8; plain words are safer in the one line people grep for.)

### 1.7 State machines

A state machine is a **keyed table of commands**. `.qc.sm[h] cmds` is a *spec* whose value is the executed
trace, so it composes with `.qc.check` like any other generator, and the property `::` reads as "run the
machine; the postconditions are the property":

```q
S:([]v:`long$())                                            / the real system: a stack kept in a table
push:{`S insert enlist x;}
pop:{r:$[2<count S; first S`v; last S`v]; delete from `S where i=count[S]-1; r}   / bug once three are stacked
cmds:([cmd:`push`pop]
  pre: ({1b};             {0<count x});                     / model -> can this command run?
  gen: ({.qc.int 0 9};    {::});                            / model -> input spec (:: for none)
  run: (push;             pop);                             / input -> output, acting on the real system
  post:({[m;i;o] 1b};     {[m;i;o] o=last m});              / model before, input, output -> ok?
  upd: ({[m;i;o] m,i};    {[m;i;o] -1_m}))                  / model before, input, output -> model after
.qc.check[.qc.sm[`m0`init!(`long$();{S::0#S})] cmds; ::]
```

```
FAIL falsified after 7 tests, 4 shrinks (46 attempts, seed 2007092841)
qc.post
step cmd  arg res model ok
--------------------------
0    push 0   ::  ,0    1
1    push 0   ::  0 0   1
2    push 1   ::  0 0 1 1
3    pop  ::  0   0 0   0
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 0 0 1 0 0 1 0 1 1 1]
```

`h` holds `m0` (the model), `init` and `fini` (run before and after every example *and every replay*, so the
real system must be resettable), and `steps` (a range, default `0 0W`, capped by size). `cmds` is a keyed
table, or a table with a `cmd` column; missing columns take the defaults (`pre` always, `gen` `::`, `run`
`::`, `post` true, `upd` identity). Each step draws a command among those whose `pre` holds, draws its input
from `gen m`, runs it, checks `post`, applies `upd`, and appends a row `step cmd arg res model ok` (the model
*after* the step; `in`/`out` are reserved words). Because execution is interleaved with generation
(Hypothesis-style, not Hedgehog's generate-then-execute) outputs are concrete at generation time: **no
symbolic-variable machinery** — the model stores whatever it needs. Constraints on *inputs* belong in `gen`,
which draws only valid inputs from the model (`{.qc.int 0,x`balance}`), not in a filter; `pre` says whether
the command can run at all. Drawing an `sm` spec executes the real system, on every path that draws: examples,
shrink candidates, `minimal`, `replay`, a saved failure, `again[]`, and after a discard — which is why `init`
is part of `h` and not something the property does.

A step's span holds its decision bit, command index and input draw and nothing else (C13), so deleting a step
is one span deletion and misaligned command indices clamp to available commands; when no command is
available a forced stop is still recorded (C7). A false postcondition notes the trace, with the failing row's
`ok` 0b, and raises `qc.post`; an error inside `run` or `post` notes the trace so far and raises `qc.run <e>`
or `qc.post <e>`. These are **failure signals** (C14): although they arise while the spec is being drawn, they
are falsifications, not generator errors, and they shrink like any other failure — the shrinker deletes steps
and shrinks inputs with the ordinary passes. The report prints the trace from the notes; there is no separate
counterexample because the trace *is* the input.

Measured (`examples/sm_table.q`, `examples/sm_ipc.q`): the stack bug above shrinks to the analytic minimum in
46 attempts (three pushes with one distinct value, then a pop); a counter in a **second q process**, driven
and reset over IPC, wraps after three increments and shrinks to exactly four `inc` steps with the `get` steps
deleted (A14).

Out of scope for v1: parallel / linearizability testing (needs up-front generation; q is single-threaded per
process anyway).

### 1.8 Deliberately absent

No objects, no monad or transformer, no `Range`/`Size` types (a range is a vector or a function; size is a
number), no exception hierarchy (error strings), no printing framework (tables and `show`), no hooks or
plugins, no `peach` (state is global, so `.qc.check` is not reentrant and a nested call signals). One file,
`qc.q`, aiming at ≤ 900 lines.

### 1.9 Layout

```
qc.q            the library
README.md       usage, built from the examples in §1.2–1.7
DESIGN.md       this document
spikes/         one script per validated assumption; sh spikes/run.sh runs them all
t/              qc's own tests            (q t/run.q)
examples/       reverse.q tree.q sm_table.q sm_ipc.q   (sm_ipc.q starts a child q process)
```

### 1.10 Conventions

Each of these fell out of implementing M1 as a local fix; each is an instance of something general, so it is
stated once here and honoured everywhere after.

**C1 — the implicit `d` is a canary.** Users never supply the trailing `d`, so a non-`::` `d` is proof of one
argument too many (`.qc.list[3 5] g`, `.qc.bool[0.9]`). Every library generator starts with `dd[d;form]` and
signals `qc: too many arguments; the configurable form is …`. Type-overloading the default instead was rejected:
a range may be a function of size, and a generator is a function, so the two are indistinguishable by type.
Hence the naming rule in §1.2. Origin: `.qc.list[3 5] g` silently producing a constant list.

**C2 — guards are conds, not conjunctions.** q evaluates every argument of `and`/`or`; any check whose later
terms are meaningful only when earlier ones hold is `$[c1; $[c2; …]; 0b]`. This is also a cost rule for the
shrinker's acceptance chain (§1.5) and the order of `diff` (§1.6). Origin: `byname` calling `key` on a list,
`tabs` indexing a missing table.

**C3 — type dispatch is total.** Every `$[type …]` has an explicit else, and every consumer of a union-typed
value (`rec`, `one`, `freq`, `.qc.t`) handles the leaf or scalar case first. Origin: `named` on `()`, a test
that assumed a `rec` value is a node.

**C4 — absence is empty, not `::`.** A composite that may be absent is an empty composite of its type; `::` is
kept for "no value" scalars and for the `::` spec and property. The result dict, the shrink history (M2), the
coverage and trace tables (M3, M5) all follow this. Origin: joining a failure dict onto a `::` sentinel.

**C5 — a name is free iff `not x in .Q.res,key .q`.** `key .q` holds the keywords defined in q.k; `.Q.res` the
primitives (`bin`, `cov`, `like` …); both are reserved. Library names are chosen by that test and `t/names.q`
asserts it at load; the advice to users is the same one-liner. Origin: `bin`, `tables`, `cov`.

**C6 — a top-level draw is an example.** `draw` entered at depth 0 outside a run resets the example state
first (keeping the size), so each interactive draw stands alone, `.qc.C` and `.qc.E` afterwards show exactly
what it drew, and an error inside a draw leaves nothing inconsistent. Inside `chk` and `recheck` a `run` flag
suppresses this so draws inside a property share the example's stream. Origin: choices accumulating at the
REPL until `qc.toolarge`.

**C7 — zero choices means exhausted, so every structure records at least one.** A passing example that drew
nothing ends the run with `n` 1: the cheapest form of Hypothesis's exhaustion rule, it makes the constant-spec
mistake visible as "✓ 1 test" and is honest for genuinely constant properties. The rule has a dual: a generator
that *could* vary must always record a choice, even when the current size leaves it no room — a list with
capacity 0 records its stop bit, `rec` at size 0 records its node count, a single-alternative `one` records
its degenerate index. (Found the hard way: at size 0 an unrecorded empty list made every list property look
exhausted after example 0.) A user generator that is constant at size 0 but not later should draw something
at size 0 too. The dual is enforced by a generic test in `t/core.q`: `minimal` at size 0 over every library
generator must leave at least one recorded choice. Enumerating small finite spaces from the recorded bounds
(`prd 1+hi-lo` ≤ `n`) is a future item.

**C8 — tests pin seeds.** Probabilistic tests ("check finds a counterexample") run under a fixed `seed`; a
counterexample not found under the pinned seed is a test bug, fixed by strengthening the property or the seed,
never by retrying.

**C9 — engine state is restored at the example boundary, from run-level values.** Nothing restores what it
changed; `reset` sets every piece of per-example state from values the run owns. The size has a *base* `bs`
(set per example by `chk`, by `new` interactively); `reset` sets `sz` from it and the entry points' error
handlers restore it. `small` and `sized` still restore on success, but correctness does not depend on that.
Origin: an error inside `.qc.small` at the REPL left the size halved for good, because the next top-level draw
reset with the halved value.

**C10 — the four sources of a choice are four entry points.** `ch` takes a value from a prefix, from the
origin, from a fresh draw, or refuses. Each has an owner of its example boundary: `.qc.replay`, `.qc.minimal`,
`.qc.draw`, and the shrinker. All three public ones are one four-line function (`top`) with a flag. Origin:
after C6, replaying a prefix or drawing the minimal example interactively required setting `.qc.run` by hand —
which is what the tests were doing.

**C11 — ranges widen with size.** Because every replay happens at the full configured size, a range function
of size must have a non-increasing lower bound, a non-decreasing upper bound and a fixed origin. Then a
failure's identity is its choice vector alone: nothing stores a size, and `recheck`, `replay` and the db take
one argument. The alternative — storing the size with every failure and threading the pair through all three
— was rejected as the price of supporting pathological ranges. The library's generators are checked for
replay invariance across sizes in `t/core.q`; user range functions are on trust. Origin: the "ranges only grow
with size" sentence in §1.5, which was stated as a fact and is a requirement.

**C12 — layout is order.** Shortlex makes the number of choices the first criterion and their sequence the
second, so an encoding's layout *is* its simplicity order. Two obligations follow: every alternative of a
`one`, `freq` or `.qc.t` draws the same number of choices, or the shorter one is silently simpler; and fields
are ordered so that the single-field moves the passes make are the moves you want (exponent before mantissa,
node count before shape). Origin: A13, where `0w` outranked `100f` and `-0.5` could not reach `-1`.

**C13 — spans are units.** Whatever decides a thing's structure lives inside the thing's span — a list
element's decision bit, a subtree's share, a state-machine step's command index and input — and every
iteration records its decision even when it is forced. Deletion, descendant replacement and replay at a
larger size all depend on it. Origin: a shrinker that accepted nothing because deleting an element left its
bit behind, and a tree that ended at the size cap without a stop.

**C14 — the error vocabulary is closed and classified.** Three classes, three spellings: control signals
(`qc.discard qc.overrun qc.toodeep qc.toolarge qc.misaligned`, the `ENG` list; never counterexamples, discards
during generation, invalid candidates during shrinking), failure signals (`qc.<stem>` optionally followed by
detail, stems `qc.eq qc.post qc.run` in `FS`; a falsification wherever raised, even while a spec is being
drawn, and they shrink like one), and usage errors (`qc: …`, colon and space: canary, range, config, bad
property result). A new engine signal goes in `ENG`; a new failure stem goes in `FS`; `t/names.q` scans the
source for `'"qc.` literals to enforce both. Origin: a `qc.*` prefix test that classified `qc.eq` as an engine signal and silently
disabled shrinking for every `eq` property.

**C15 — verdicts from random data carry confidence.** A coverage requirement is a statement about a rate,
observed over a random sample; comparing the sample percentage with the requirement fails 18% of runs when the
true rate is 92% and the requirement 90. `cover` fails only when the run is confident the rate is below the
requirement — the Wilson 95% upper bound of the observed rate is under it — and a run that cannot tell passes
rather than flakes. This is the same concern as C8 seen from the library's side. Hedgehog's answer, keep
generating until confident either way, is better and is deferred because it changes the run loop.

**C16 — at the API boundary an atom is a one-element list.** `"z"` is a char atom, `` `a `` a symbol atom, `7`
a long atom; a user who means "the alphabet z", "the one command a" or "the single value 7" will write the
atom. Every library function that takes a list configuration begins with `(),x`: `rng` for ranges, `chrc` for
alphabets, `elem`, `one`, `freq`, `spc`'s specials, `reset`'s prefix (so `replay[5]` is a one-choice prefix, not
IPC handle 5), and `rec`'s arity as `2#(),k`, which makes `rec[2;…]` read as "exactly two children". Origin:
`symc["z";1 1]` indexing a char atom.

**C17 — measure the distribution you ship, on the ranges people use.** A5 measured the integer mixture on a
symmetric range and it looked right; on `int 0 1000`, the commonest shape, a random sign on the magnitude
clamped half the draws to the bound and 56% of values were 0 — and the same draw set `rec`'s node count, so
most engine trees were leaves while A15's spike, with its own uniform draw, showed the intended spread. Every
fresh-draw law now has a distribution test in `t/core.q` on a one-sided and a symmetric range, and `rec`
draws its node count uniformly, as designed.

---

## 2. Assumptions and validation log

Run with `sh spikes/run.sh` from the repo root. Results below are from kdb+ 5.0 2026.07.23 m64 on macOS,
2026-09-26.

| # | Assumption | Spike | Result | Consequence for the design |
|---|---|---|---|---|
| A1 | `g[]` convention; `'[f;g]` and `(f g@)` compose; `draw` recursion over dicts/lists; param names via `value`; vector-keyed dicts; epoch and guid facts; join promotion | `a1_calling.q` 25/25 | ✅ | `::` is type `101h`; `draw` treats it as a constant. `xs,:y` onto a typed vector does not promote (type error), `xs:xs,y` does: all element collection uses the plain join. |
| A2 | Per-draw append cost ≤ 1 µs | probe | ✅ 0.5–0.6 µs per row for 1e5 appends to a global table | Choice table stays a table. Cost model in §1.5. |
| A3 | Seeding is deterministic; replay from the choice vector survives user `rand`; clamping works | `a3_seed.q` 6/6 | ✅ | `system"S n"` returns nothing, `system"S"` returns an int: seeds are 32-bit ints. Past the prefix draws are fresh, so `recheck` must detect overrun and report a changed generator. |
| A4 | Custom signals are distinguishable; `.Q.trp` gives backtraces; runaway recursion is catchable | `a4_errors.q` 9/9 | ✅ with a caveat | `'stack` arrives after ~2000 q frames, before any choice budget can fire. Hence the named depth guard (A16) and `.qc.rec`'s budget (A15). |
| A5 | `rand` edge cases; a safe uniform draw over any long range; the magnitude mixture gives small values often | `a5_rand.q` 13/13 | ✅ after two fixes, amended after M4 | `rand -k` is a domain error; `rand 0` returns an arbitrary long silently; `1+0W` is `0N`. One guarded call site. Bit-widths bounded by the range width — the first version put 64% of draws at the bounds; bounded, 7.5%. The spike measured a symmetric range only; on one-sided ranges a random sign clamped half the draws (56% zeros on `0..1000`), fixed after M4 with distribution tests in `t/` (C17). |
| A9 | A failure report is readable in 80 columns with nested tables shown as tables | `a9_show.q` 7/7 | ✅ | `.Q.s` prints a nested table as `+`a`b!(...)`; the custom formatter is required and prototyped. `\c` governs `.Q.s` width and is widened for reports. |
| A10 | Span labelling per draw ≤ 2 µs | `a10_labels.q` 5/5 | ✅ | Dict keyed by the generator: 180 ns. Serialised bytes: 320 ns. `md5 .Q.s1`: 4.6 µs — rejected. Projections are keyed by their underlying lambda (`first value g`). |
| A11 | Bounded symbol alphabets keep memory flat | `a11_sym.q` 2/2 | ✅ | 1e5 bounded draws: +28 symbols. Unbounded: +100 031 symbols, +5.4 MB `symw`, never reclaimed. `.qc.sym` defaults to `"abcd"`, lengths 0–3. |
| A12 | kdb+ 5.0 behaves as 4.x for what we use | folded into A1/A3/A4/A5 | ✅ | Only surprise: `1+0W` is `0N` rather than wrapping; handled in A5 and in the shrink key. |
| A15 | A recursion scheme exists that is bounded, discard-free, spends the budget, and varies shape | `a15_rec.q` 7/7 | ✅ | Five strategies measured (table in §1.3). Halving: narrow. Depth-first fuel: chains. Stick-breaking with unknown arity: wastes budget geometrically (median 2 nodes of 30). Exact partition with an explicit child-count range: uniform node counts across the budget, zero discards → the `.qc.rec[k;leaf;node]` API; its shape law is settled by A17. |
| A16 | The interpreter's depth guard fires cleanly before q's stack | `a16_depth.q` 6/6 | ✅ | 998 user levels fit through a prototype `draw` before `'stack`; `"qc.toodeep"` fires at the configured depth with a backtrace naming the user generator; the interpreter is usable afterwards. |
| A17 | Uniform-over-shapes recursion is achievable with exact size and no rejection, as fresh-draw weights on the existing arity/share choices | `a17_uniform.q` 10/10 | ✅ | Counting tables give the Catalan numbers; size-4 shapes uniform within 15%; binary n=100 exact, depth median 29 (max 51) vs 13 (max 19) under the uniform cut; rose 0–4 exact at n=60 with no arity hack; tables for size 100 in 10–64 ms. `.qc.rec` defaults to this law; `.qc.recb` keeps the uniform cut. |
| A6 | Continue-bit lists shrink better than length-prefixed lists | `a6_lists.q` 2/2 | ✅ | Same shrinker, nine list properties: continue bits 9/9 minima (357 attempts); length prefix 6/9 (275) — it cannot delete a middle element without also decrementing the length, so `sum100`, `bound5` and the filtered case stall on padded lists. |
| A7 | Clamp-on-misalign beats reject-on-misalign | `a7_clamp.q` 2/2 | ✅ (a draw) | 18/18 minima either way, 546 vs 549 attempts; reject is ~2× faster per attempt (aborts early) and picks left chains where clamp picks right. Clamp kept: every prefix stays a valid input. `cfg`clamp` exists for experiments. |
| A8 | Shrink quality: analytic minima on the classic suite | `a8_bench.q` 3/3 | ✅ | 18/18 minima, 546 attempts, 146 ms, worst case 79 attempts (table in §1.5). Hypothesis's attempt counts not measured. |
| A13 | Float encoding shrinks to `0f`, small integers, dyadic fractions; can produce `0n 0w -0w` | `a13_float.q` 3/3 | ✅ after a redesign | Encoding for M4: `[kind; special; sign; e; m]`, value `sign·m·2^e`, all fields always drawn (uniform layout), exponent before mantissa. 8/8 cases: `x<100`→`100f`, exact `x+1=x`→`2^53`, `x<0.5`→`1f`, `x>=0`→`-1f`, `within 0.25 0.75`→`0.5`, NaN and `0w` reachable. The first layout (integer part + `num/2^k`, numerator drawn with the small-magnitude mixture) reached only 4/7: `-0.5` could not reach `-1`, and `0.5`-like values were almost never generated. Bonus finding: under q's tolerant `<>`, `x<>x+1` first fails near 2^43 (found `8.8e12`), not 2^53. |
| A14 | State machine against a second q process over IPC, reset on every replay | `examples/sm_ipc.q` | ✅ | The example starts a child q on a random port, drives a counter over `hopen`, resets it with `init` before every example and replay, finds the wrap after three increments and shrinks to four `inc` steps in 23 attempts, then closes the child. |

---

## 3. Implementation plan

**M0 — validate.** Done: this document and `spikes/`. Every assumption that can be tested without engine
code is ✅ above; the four that need a shrinker or a state machine are scheduled where they can first be run.

**M1 — engine without shrinking.** Done: `qc.q`, `t/core.q`, `t/names.q`, `examples/reverse.q`,
`examples/tree.q`. Amended after the fact by the conventions in §1.10 (canary, run flag, exhaustion,
cond-chain guards, pinned seeds, name assertion), then by C9 and C10 (base size, `minimal` and `replay`). Further
convention work waits for evidence from M2.

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
the guard with `and` — C2 and C3 in one line, and the reason the conventions exist.

---

## 4. Pitfalls

Pure q facts that the conventions in §1.10 do not already cover. For users:

1. **Never `each` a generator.** `g each xs` applies the drawn *value* to each element; if the value is a small
   integer, q treats it as an IPC handle and writes to it. Draw several with `.qc.draw k#enlist g`.
2. `'[f;g]` written immediately after `:` parses as an each-modified assignment; parenthesise.
3. A name is free iff `not x in .Q.res,key .q` (C5); `bin`, `tables` and `cov` are all taken. Assigning to a
   reserved word is an error, not a shadow.
4. In q-sql a parameter with the same name as a column is shadowed by the column (`where sz=sz` is always
   true); name parameters differently from columns.
5. `like` supports one `*` run at each end, not a wildcard in the middle (`nyi`); test two substrings instead.

For the implementer:

6. `xs,:y` onto a typed vector does not promote to a general list; `xs:xs,y` does. A boolean appended to a
   long vector is a type error either way — choices are cast to long before recording.
7. `rand 0` does not error. `rand -k` does. `1+0W` is `0N`. Guard all three in the one place that calls `rand`.
8. `system"S n"` returns nothing; read the seed back with `system"S"`; seeds are ints.
9. A q lambda with no explicit parameters is unary; `{...}[]` always works.
10. `::` has type `101h`, the same range as unary primitives.
11. Symbols are interned forever; never generate them from an unbounded alphabet by default.
12. `.Q.s` renders nested tables in flip notation and truncates to `\c`.
13. A script that errors while being loaded with `\l` drops into the debugger and waits on stdin; spike
    scripts end with `exit` and are run under `timeout`.
14. `over` on an empty list returns the projection, not the seed. `()[0]` is `()`, so a recursive walk over a
    malformed empty node never terminates.
15. For a weighted draw, `sums[w] bin x` is −1 below the first weight; `binr` is the verb.
16. `(`L;`L)` is a symbol vector, not a general list: two leaf children of the same atom type collapse into a
    typed vector, and any walk that dispatches on `0h=type` must allow for it.
17. `key` of a namespace includes the empty symbol for the namespace itself; drop it before comparing names.
18. `cut`, `min` and `sum` are reserved too: not as function names, and not as *column* names in a table literal
    (`([] min:...)` is an assign error).
19. A dict seeded with a `::` key amends elementwise when indexed with a vector (`K[1 2 3]:0` adds keys 1, 2, 3);
    seed vector-keyed dicts with an empty vector key.
20. `flip (a;b;c) ix` indexes the three-list; the rows are `(flip (a;b;c)) ix`.
21. `0n=0n` is true, `0n<100` is true and `0n>=0` is false: nulls compare equal to themselves and below
    everything. A property about NaN says `null x`, not `x<>x`; a property that means "non-negative" must
    decide what it means for null.
22. `sum ()` is `()`, and `100>=()` is `()`: comparisons with an empty general list return an empty general
    list, which is why the pass rule treats `()` as vacuously true.
23. `=` and `<>` on floats are tolerant (about 2^-43 relative): `x<>x+1` is already false near 8.8e12. Exact
    tests subtract and compare with 0.
23a. `"f"$0W` is the finite float 9223372036854775807, not `0w` (same for `e` and the float-based `z`); float
    infinities are `0w`/`0we`/`0wz`, and `2 xexp -1074`
    underflows to 0 (the smallest exponent `xexp` reaches is about −1022). `ss`, `sv`, `cols` are keywords.
24. In `like` patterns `[` and `]` are character classes and a middle `*` is `nyi`; match `.qc.again[]` with two
    end-anchored patterns, not one literal.
25. `"1"` is a char atom, `enlist "1"` the one-character string; a formatter returns the latter.
26. Inside q-sql, names resolve as columns, then the function's locals, then *root* globals — never the
    defining namespace: write `.qc.RQ`, not `RQ`, in an `update`. The `from` expression is ordinary code and
    is unaffected.
27. Indexing a table with a list of column names returns the columns, not a row: `t[`a`b]` is two vectors,
    `t[0;`a]` is a cell — and two-index table access is **row first**: `t[`a;0]` is a type error.
28. `f[::]` is a projection with the argument *elided*, not applied — but `g[]` fills elided arguments with `::`,
    so `.qc.const (::)` still draws to `::`. A keyed table is `99h`: every dict test needs `not 98h=type key x`.
29. `in` is reserved and cannot be a column name; the trace uses `arg` and `res`. A list literal
    `(f[]; g[])` evaluates right to left, so `(.qc.minimal g; count .qc.C)` counts before it draws.
