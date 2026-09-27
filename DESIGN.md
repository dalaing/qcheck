# qcheck — property-based testing for q

*Design document. Status: complete — assumptions validated on kdb+ 5.0 (2026.07.23, m64) only (the README says
3.5 or later should work and that this is unverified); M1–M12 implemented in `qc.q`, tests in `t/`, examples in `examples/`, usage in `README.md`, a tour in `EXAMPLES.md`, recipes in `COOKBOOK.md`, a worked example with its log in `examples/mdp/`; the two items once deferred are folded in as C19, and C19's own deferred step — Hypothesis's DataTree, enumeration of value-dependent structure — is in.*

qcheck takes the choice-sequence engine and integrated shrinking of **Hypothesis**, the failure reporting and
`Range`-style generator control of **Hedgehog**, and the state-machine testing of both, and expresses them in
the shape a seasoned q programmer expects: a handful of primitives, data over objects, tables for anything with
structure, composition through the verbs q already has.

Contents (each heading is a link):
- [1. Design](#1-design)
  - [1.1 Why the Hypothesis model is the q model](#11-why-the-hypothesis-model-is-the-q-model)
  - [1.2 Vocabulary and calling convention](#12-vocabulary-and-calling-convention)
  - [1.3 Generators (namespace `.qc`)](#13-generators-namespace-qc)
  - [1.4 Properties and the runner](#14-properties-and-the-runner)
  - [1.5 Shrinking](#15-shrinking)
  - [1.6 Rich output](#16-rich-output)
  - [1.7 State machines](#17-state-machines)
  - [1.8 Deliberately absent](#18-deliberately-absent)
  - [1.9 Layout](#19-layout)
  - [1.10 Conventions](#110-conventions)
- [2. Assumptions and validation log](#2-assumptions-and-validation-log)
- [3. Implementation plan and review rounds](#3-implementation-plan-and-review-rounds) — moved to docs/HISTORY.md
- [4. Pitfalls](#4-pitfalls)
 - conventions: C1 · C2 · C3 · C4 · C5 · C6 · C7 · C8 · C9 · C10 · C11 · C12 · C13 · C14 · C15 · C16 · C17 · C18 · C19 · C20 · C21 · C22 · C23 · C24 · C25 are in §1.10, indexed at its head; pitfalls 1–45 in §4, indexed at its head.

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

The words, used the same way in every document: a **spec** is anything `.qc.draw` interprets — a generator, a list
or dict of specs, or a constant; a **generator** is the function kind of spec; an **example** is one value drawn
from a spec (the *input* to the property); a **test** is one run of the property on one example, which is what the
report counts; a **counterexample** is the example a failure shrinks to. Long and short names differ by taking a
range or a configuration first (`list`/`lst`, `check`/`chk`).

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
| `.qc.minimal x`, `.qc.replay[choices;x]`, `.qc.strict[choices;x]` | the other interactive entry points: the simplest value of a spec; the value a recorded choice vector produces; the same with the prefix strict, so a draw past it is `qc.overrun` — what every shrink candidate sees (C10) |
| `.qc.ch[r;w]` | **the primitive**: a long in range `r` = `lo hi o`; `w` is a fresh-draw distribution hint |
| `.qc.int r` | long in range; no nulls or infinities |
| `.qc.bool`, `.qc.bit p` | boolean; `bit p` draws `1b` with probability `p` on fresh draws; origin `0b` |
| `.qc.flt r` | float in `[lo;hi]`, layout `[sign; k; m]` = `±m/2^k`; 0 (or the nearest bound) is simplest, integers before halves before quarters; `.qc.dbl` is any finite double, `[sign; e; m]` = `±m·2^e`; `.qc.dble` the same over single-precision exponents and mantissas (values a float32 column can hold) |
| `.qc.chr`, `.qc.chrc s` | a char from `.qc.AZ` (letters, digits, space; origin `"a"`), or from alphabet `s` |
| `.qc.str`, `.qc.strc[s;r]` | a string (typed even when empty), alphabet `s`, length range `r` |
| `.qc.sym`, `.qc.symc[s;r]` | a symbol over a **bounded** alphabet: default `"abcd"`, lengths 0–3, ≤ 85 symbols, the null symbol simplest |
| `.qc.t c` | **dict** type-char → generator of that atom type's *full* domain: `.qc.spc[specials] g` wraps a normal generator in the uniform layout `[kind; special; value]` (C12); `.qc.t"j"`, `.qc.t"p"`, `.qc.t"jf"` (a pair); origin is `c$0`; `.qc.gid` for guids |
| `.qc.list g`, `.qc.lst[r] g` | variable-length list of `g`, length range `r` (default `0 0W`, capped by size); homogeneous atoms become a typed vector automatically |
| `.qc.vec[r] c` | typed vector of `.qc.t c`, typed even when empty |
| `.qc.tab cols`, `.qc.tabr[r] cols`, `.qc.ktab[k;r] cols` | a table from a dict of column generators, drawn as rows so a row is one span (C13); row-count range `r`; keyed on columns `k`. an empty draw's columns are typed from a probe of one minimal row (M7's limitation, removed at M12) |
| `.qc.mono[b;g]`, `.qc.uniq g`, `.qc.dep f` | **constrained columns**, recognised by `tab`: the first row draws `b` and each later row adds a delta drawn from `g`, which must be non-negative — a negative delta is a usage error, never a quietly unsorted column (sorted by construction, so sorted under every shrink, A18); distinct values — over an `elem` or a small constant `int` range by indexing the values not yet used, capping the rows to the set (A19), otherwise by retrying and discarding; `f` receives the row so far (the columns before it) and returns a spec. On their own each is its plain part |
| `.qc.atr[a] g` | the drawn value with attribute `a` (`s` and `p` after a sort); attributes survive every engine path, `~` ignores them (A23) |
| `.qc.schema t` | a constructor (as `lin` is): reads a sample table once — types, an enumeration's domain from `key`, attributes, typed empties from `0#`, keys — and returns a generator of tables shaped like it (A21). `meta` alone cannot see enumerations; a `p#` and an `s#` column together are refused |
| `.qc.bulk[r;nr]`, `.qc.btab[nr] cols` | **bulk data** (M8, A22): a long vector of a length in `nr` with values in `r`, recorded as one block by `chn` — a million values in milliseconds, one unit of the choice budget; a table of blocks over one drawn row count, a column a range or `(type char; range)`. A block shrinks by chunk deletion (`pblk`) as well as by its values. Lengths cap at `lo+1000*size` |
| `.qc.tf c` | the **finite** domain of an atom type: no null, no infinity (`h i j` stop one short of their infinities, `e` fits a real, `c` has no space, `s` no empty symbol); `t c` is `tf c` wrapped in `spc` with the specials (M10) |
| `.qc.ts[from;to]`, `.qc.dates[from;to]` | one timestamp or date in a window, the start simplest (dates accepted as timestamp bounds); a monotone series is `mono[ts[a;b];int 0 60000000000]` in a table or `atr[`s] list ts[a;b]` (A26) |
| `.qc.val` | an arbitrary q value: `rec` over the full-domain zoo with list, dict, table and keyed-table nodes — every atom type, both list kinds, dicts, tables at size 30; `-9!-8!x` round-trips all of it (A27) |
| `.qc.one gs` | one of several alternative specs; the first is the simplest *provided it draws no more choices than the others* (C12) |
| `.qc.freq[w] gs` | weighted alternatives, parallel lists |
| `.qc.elem xs` | an element of a constant list (preferred over generating symbols) |
| `.qc.such[p] g` | filter with bounded retries, then discard |
| `.qc.rec[k;leaf;node]` | **recursive structures**: child-count range `k`, leaf spec, and `node`, a function of the list of already-drawn children (below) |
| `.qc.const x` `.qc.sized f` `.qc.small g` | constant escape hatch; `f` of size returning a spec; halve the budget for a sub-spec |

#### How they are built

The table above is the reference (`REFERENCE.md` has every name in one line); what follows is why the
generators are shaped as they are.

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
json:.qc.rec[0 4; .qc.one (.qc.int -9 9;.qc.strc[.qc.AZ;0 5];.qc.bool);
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
number of draw calls is capped at `cfg`choices` (default 8192; a bulk block counts once, whatever its length) with `"qc.toolarge"`. Both are named errors that
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

**Tables with constraints (M7).** A column is either a plain generator or a projection of `mono`, `uniq` or `dep`;
`tab` recognises the latter (`mark`) and then draws each row column by column, in column order, with three pieces
of per-table state — the previous value of each `mono` column, the candidates not yet used and the values used so
far of each `uniq` column — saved and restored around the table so tables nest. Rows remain spans (C13); the
constraints live in the choices, which is why they hold on every shrink candidate (A18, A19, A20). `ktab` sends
its key columns through `uniq`, so keys are distinct. An empty `tab` has typed columns: `tab` probes one minimal
row of its column generators outside the example (`probe`, C22's state saved and restored) and types the empty
columns from what they would have drawn; `schema` knows from `0#` of the sample. A `uniq` over a generator whose
space is smaller than the rows discards (`sym` has 85 values; a `u#` column with 100 rows cannot be drawn).

### 1.4 Properties and the runner

(The entry points — `check chk checks chks must mustc main draw minimal replay strict recheck again report` — are one
line each in `REFERENCE.md`; this section is what they do and why.)

```
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
`.qc.label s`, `.qc.classify[s;b]`, `.qc.collect x` (label by value: one symbol is interned per distinct value, for
good — use it on small value spaces, pitfall 11), `.qc.cover[s;pct;b]` (the run fails with
`why` `` `cover `` only when it is confident the label's rate is under `pct`: the Wilson 95% upper bound of the
observed rate is below it, C15),
`.qc.discard[]`. After any failure `.qc.again[]` rechecks it and `.qc.lf` holds its spec, property and choices.
`.qc.checks d` runs a dict of name → `(spec;prop)` and returns a table (`.qc.chks[cfg;d]` with config).

Run loop for one property — **`n` is a budget; the run stops when it has learned what it can** (C19):
(0) replay the saved failure from the db if there is one (`cfg`db`, default `` `:.qc ``,
one file per property keyed by `cfg`name` or an md5 of the spec and property source; a saved example that no
longer fails is deleted, a shrunk one is saved) — if the replay overruns or clamps any choice the generator has
changed since it was saved, and `recheck` says so rather than silently testing a different input; (1) example 0 in *minimal mode* — every fresh draw returns its origin, so the
simplest input is always tried first, for free; (2a) every example's choices are recorded as a path in the
run's **choice tree** (`.qc.TR`: one node per prefix, holding the range drawn there or the conclusion an
example reached there; a node is exhausted when it concludes or all of its children are — Hypothesis's
DataTree), and while every recorded path has a product of widths within the budget the run **enumerates**:
the next example is the tree's simplest open branch — descend from the root taking at each node the value
nearest the origin whose child is absent or open, then origins for the rest — so every input is tried once,
in shortlex order for a fixed structure, and the run stops `exhausted` when the root is: `ok 4 tests,
exhausted` is a proof, not a sample, and a constant spec is the one-input case. This covers structure that
depends on earlier choices (`one`, short lists, `rec` at a small size, small state machines) because the tree
is the structure. A path whose product exceeds the budget switches the run to sampling for good (a tree whose
every path fits has at most `n` leaves, so the switch is only ever taken when the space may not fit); so does
a contradiction — a range or an ending at a prefix that differs from what an earlier example found there,
meaning the structure depended on something other than the choices — and then no exhaustion is claimed.
Otherwise (2b) `n` examples with size ramping 0→100, and if a coverage requirement is still open at the budget (the requirement lies between the Wilson
lower and upper bounds) the run continues until it is settled or `cfg`nmax` (default `10*n`) is reached; (3) on failure,
shrink (§1.5); (4) report (§1.6). Discards are counted by cause (`filter`, `toodeep`, `toolarge`, explicit);
more than `disc`×`n` of them ends the run as "gave up", and the report names the dominant cause.

The result is data: `` `ok`why`stop`n`shrinks`attempts`seed`x`err`bt`notes`cover`choices`hist`disc`stale `` with `why` one
of `` `ok`falsified`gaveup`cover`error `` and `stop` — why the loop ended — one of `` `exhausted`n`cover`nmax`fail`gaveup ``.
Every field is always present and typed the same way: absent
composites are empty (`disc` an empty dict, `cover` an empty table, `notes` an empty list, `err` an empty
string); only `x` is `::` when there is no counterexample (C4).

**Inside another framework, and as a script (M9).** `.qc.must[spec;prop]` (`.qc.mustc[cfg;spec;prop]` with a
config) runs the check quietly, returns the result on ok, and otherwise signals the whole report as one error
string — `qc: FAIL falsified after 3 tests, …` on the first line, the counterexample and rerun line after it — so a
property can sit inside k4unit, qspec or a `.Q.trp` script and be one failing assertion (A24: the text survives
`@`, `.Q.trp` and IPC intact). `.qc.main d` runs a suite dict, prints its table and exits with the number of
failures, the shape of a CI script. The result dict is machine-readable as it is: `.j.j r` serialises every
outcome and `.j.k` reads it back (A25; symbols become strings, `::` null, the int seed a float, a function its
source). `checks` returns an `ms` column per property and prints the table without it, so transcripts stay exact.

Seeds are 32-bit ints, because that is what `\S` takes and `system"S"` returns (A3): `cfg`seed` of `0N`
becomes `"i"$1+.z.p mod 2147483646`, never 0, and is printed and accepted as an int.

Defaults in `.qc.cfg`: `n` 100 (tests) · `nmax` `0N` (the cap when coverage extends a run; `0N` is 10×`n`) ·
`seed` `0N` (from the clock) · `sz` 100 · `shrinks` 2000 · `disc` 10 (discards per test before giving up) ·
`tries` 50 (filter retries) · `depth` 200 · `choices` 8192 · `same` 1b (a shrink must reproduce the same error
text) · `clamp` 1b (an out-of-range replayed choice is clamped, not rejected) · `db` `` `:.qc `` · `name` `` ` ``
(the label `checks` prints) · `rows` 20 (rows of a table shown in a report) · `v` 1 (verbosity: 0 silent, 2 adds
the backtrace).

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
6. redistribute numeric pairs (`x-k, y+k`) and lower pairs together;
7. (M8) delete the same chunk from every block of a bulk span and lower its length, ddmin-style — first, since a
   block of 1e5 values must shrink to a handful before the per-choice passes can afford to touch it.

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
- The coverage table `label n pct req lo hi ok bar` whenever a label was used — `lo`/`hi` are the Wilson
  bounds: `ok` is judged against `hi`, and a requirement between them is *open* (C19) — and a requirement
  that was never hit still has its row, with `n` 0.
- **Display is not transport.** `.Q.s` and `.Q.s1` truncate to the console and are used only for looking at
  data; the one line meant to be copied back, the rerun line, renders the choice vector exactly with `string`
  and `sv`. (Found by an 81-choice failure whose rerun line ended in `..`.)

`.qc.report r` returns the lines and `.qc.rep r` prints them, so the report is testable. The transcript below
is executed by `t/doctest.q` (seed 7) and must print exactly this:

```q
q).qc.check[.qc.list .qc.int 0 100;{.qc.eq[x;asc x]}];
FAIL falsified after 5 tests, 8 shrinks (36 attempts, seed 7)
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
q)S:([]v:`long$())
q)push:{`S insert enlist x;}
q)pop:{r:$[2<count S; first S`v; last S`v]; delete from `S where i=count[S]-1; r}
q)cmds:([cmd:`push`pop] pre:({1b};{0<count x}); gen:({.qc.int 0 9};{::}); run:(push;pop); post:({[m;i;o] 1b};{[m;i;o] o=last m}); upd:({[m;i;o] m,i};{[m;i;o] -1_m}))
q).qc.check[.qc.sm[`m0`init!(`long$();{S::0#S})] cmds; ::];
FAIL falsified after 10 tests, 3 shrinks (43 attempts, seed 7)
qc.post
step cmd  arg res model ok
--------------------------
0    push 0   ::  ,0    1
1    push 0   ::  0 0   1
2    push 1   ::  0 0 1 1
3    pop  ::  0   0 0   0
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 0 0 1 0 0 1 0 1 1 1]
```

The columns of `cmds`: `pre` (model → can this command run?), `gen` (model → input spec, `::` for none), `run`
(input → output, acting on the real system), `post` (model before, input, output → ok?), `upd` (model before,
input, output → model after). `pop` has a planted bug: it returns the first item once three are stacked.

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

An `inv` hook (model → boolean, or a list of them) is checked after every step's `upd`; a false one notes the
trace and raises `qc.inv`, a failure signal like `qc.post`. A `w` column weights the choice among the commands
whose `pre` holds (positive numbers; the default is one each), through the `freq` law. (M10.)

A step's span holds its decision bit, command index and input draw and nothing else (C13), so deleting a step
is one span deletion and misaligned command indices clamp to available commands (steps therefore differ in
length by command, the one exception to C12's rule, stated there); when no command is
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
t/              q t/run.q — one table. families: 0gens (the generator registry), contracts (every contract
                over every registered generator), ranges (the range grid), outcomes (verdicts, signals, schema,
                state after every exit), bench (the A8 minima with attempt caps), dist (distributions), reportx,
                doctest (every q) transcript in README, EXAMPLES, COOKBOOK, this file and examples/mdp/LOG.md; QC_FAST=1
                skips the state-machine blocks, most of the suite's time), docs (names in docs exist),
                names (reserved words, shadowing), readme (README and DESIGN code blocks load), examples (each
                examples/*.q runs as a child q and reports what its prose promises), and the per-milestone files
EXAMPLES.md     a tour in verified transcripts
REFERENCE.md    every public name, one line each; t/docs.q checks it against qc.q both ways
COOKBOOK.md     recipes for kdb tasks, each a planted bug found and shrunk, every transcript doctested (M11)
examples/mdp/   a market data pipeline built in pieces with a doctested development log, LOG.md (M12)
tools/          doc_child.q, the REPL-imitating child that t/doctest.q runs
docs/           HISTORY.md (the milestone plan and the review rounds, once §3 and §5 here), AUDIT.md, AUDIT2.md (closed)
REVIEW.md       the review after M12 with its checklist, at the top level while open
.qc/            the failure database a run writes (gitignored); t/ and examples/mdp/run.q run without one
examples/       reverse.q tree.q sm_table.q sm_ipc.q aj.q   (sm_ipc.q starts a child q process)
```

### 1.10 Conventions

Each of these fell out of implementing M1 as a local fix; each is an instance of something general, so it is
stated once here and honoured everywhere after.

Index: C1 the implicit `d` is a canary · C2 guards are conds, not conjunctions · C3 type dispatch is total · C4 absence is empty, not `::` · C5 a name is free iff `not x in · C6 a top-level draw is an example · C7 zero choices means exhausted, so every structure records at least one · C8 tests pin seeds · C9 engine state is restored at the example boundary, from run-level values · C10 the four sources of a choice are four entry points · C11 ranges widen with size · C12 layout is order · C13 spans are units · C14 the error vocabulary is closed and classified · C15 verdicts from random data carry confidence · C16 at the API boundary an atom is a one-element list · C17 measure the distribution you ship, on the ranges people use · C18 examples are tests · C19 `n` is a budget; the run stops when it has learned what it can · C20 the library never applies a value it has not checked is callable · C21 arithmetic on choice bounds is done in floats, or guarded · C22 state that belongs to a structure is saved and restored around that structure · C23 a list that may hold anything grows behind a `::` seed · C24 a block is one draw call, one span and one unit of the budget · C25 two implementations of one law agree by test.

**C1 — the implicit `d` is a canary.** Users never supply the trailing `d`, so a non-`::` `d` is proof of one
argument too many (`.qc.list[3 5] g`, `.qc.bool[0.9]`). Every library generator starts with `dd[d;form]` and
signals `qc: too many arguments; the configurable form is …`. Type-overloading the default instead was rejected:
a range may be a function of size, and a generator is a function, so the two are indistinguishable by type.
Hence the naming rule in §1.2. Origin: `.qc.list[3 5] g` silently producing a constant list.

**C2 — guards are conds, not conjunctions.** q evaluates every argument of `and`/`or`; any check whose later
terms are meaningful only when earlier ones hold is `$[c1; $[c2; …]; 0b]`. `and`/`or` stay where every term is safe and cheap on its own (three sites: `chk1`'s
arity test, `chks`'s shape test, the shrinker's acceptance), which is what the rule is for. This is also a cost rule for the
shrinker's acceptance chain (§1.5) and the order of `diff` (§1.6). Origin: `byname` calling `key` on a list,
`tabs` indexing a missing table.

**C3 — type dispatch is total.** Every `$[type …]` has an explicit else, and every consumer of a union-typed
value (`rec`, `one`, `freq`, `.qc.t`) handles the leaf or scalar case first. Origin: `named` on `()`, a test
that assumed a `rec` value is a node.

**C4 — absence is empty, not `::`.** A composite that may be absent is an empty composite of its type; `::` is
kept for "no value" scalars and for the `::` spec and property. The result dict, the shrink history (M2), the
coverage and trace tables (M3, M5) all follow this. Origin: joining a failure dict onto a `::` sentinel.

**C5 — a name is free iff `not x in .Q.res,key .q`, and a local never shadows an engine global.** `key .q` holds
the keywords defined in q.k; `.Q.res` the primitives (`bin`, `cov`, `like` …); both are reserved. `t/names.q`
scans the source (strings and comments blanked) for every parameter, local and column name, and fails on a
reserved word or on a lambda local that shares a name with an engine global — the review rounds found
twenty-two of those (`C`, `t`, `i`, `N`, `ns`), none yet a bug, each one edit away from being one. Origin:
`bin`, `tables`, `cov`; then `ss`, `sv`, `cols`, `keys`, `in`.

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
generator must leave at least one recorded choice. The zero-choice rule is now the one-input case of C19's
enumeration.

**C8 — tests pin seeds.** Probabilistic tests ("check finds a counterexample") run under a fixed `seed`; a
counterexample not found under the pinned seed is a test bug, fixed by strengthening the property or the seed,
never by retrying.

**C9 — engine state is restored at the example boundary, from run-level values.** Nothing restores what it
changed; `reset` sets every piece of per-example state from values the run owns. The size has a *base* `bs`
(set per example by `chk`, by `new` interactively); `reset` sets `sz` from it and the entry points' error
handlers restore it. `small` and `sized` still restore on success, but correctness does not depend on that. The audit in the review
rounds extended this to every exit: `chk` and `recheck` restore the run flag, the effective config *and* the base
size on every exit (the audit found `bs` leaking a run's size into later interactive draws); a state machine's `fini` runs on every way out of a step, including a discard inside `gen`; and the
label dict is keyed by structure so a composition built per draw cannot grow it.
Origin: an error inside `.qc.small` at the REPL left the size halved for good, because the next top-level draw
reset with the halved value.

**C10 — the four sources of a choice are four entry points.** `ch` takes a value from a prefix, from the
origin, from a fresh draw, or refuses. Each has an owner of its example boundary: `.qc.replay`, `.qc.minimal`,
`.qc.draw`, and — for the refusal, shared with the shrinker — `.qc.strict`. All four are one function (`top`)
with two flags. Origin: after C6, replaying a prefix or drawing the minimal example interactively required
setting `.qc.run` by hand — which is what the tests were doing; the audit found them still doing it for the
strict case, hence `strict`.

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
node count before shape). One deliberate exception: a state-machine step is as long as its command's input, so
a command without an input (two choices) ranks simpler than one with (three) and the shrinker prefers it —
acceptable, because a shorter trace with fewer inputs is what one wants to read. Origin: A13, where `0w`
outranked `100f` and `-0.5` could not reach `-1`.

**C13 — spans are units.** Whatever decides a thing's structure lives inside the thing's span — a list
element's decision bit, a subtree's share, a state-machine step's command index and input — and every
iteration records its decision even when it is forced. Deletion, descendant replacement and replay at a
larger size all depend on it. Origin: a shrinker that accepted nothing because deleting an element left its
bit behind, and a tree that ended at the size cap without a stop.

**C14 — the error vocabulary is closed and classified.** Three classes, three spellings: control signals
(`qc.discard qc.overrun qc.toodeep qc.toolarge qc.misaligned`, the `ENG` list; never counterexamples, discards
during generation, invalid candidates during shrinking), failure signals (`qc.<stem>` optionally followed by
detail, stems `qc.eq qc.post qc.run qc.inv` in `FS`; a falsification wherever raised, even while a spec is being
drawn, and they shrink like one), and usage errors (`qc: …`, colon and space: canary, range, config, bad
property result; and `must`'s `qc: FAIL …`, the library telling the caller that the property failed). A new engine signal goes in `ENG`; a new failure stem goes in `FS`; `t/names.q` scans the
source for `'"qc.` literals to enforce both. Origin: a `qc.*` prefix test that classified `qc.eq` as an engine signal and silently
disabled shrinking for every `eq` property.

**C15 — verdicts from random data carry confidence.** A coverage requirement is a statement about a rate,
observed over a random sample; comparing the sample percentage with the requirement fails 18% of runs when the
true rate is 92% and the requirement 90. `cover` fails only when the run is confident the rate is below the
requirement — the Wilson 95% upper bound of the observed rate is under it — and a run that cannot tell passes
rather than flakes. This is the same concern as C8 seen from the library's side. Hedgehog's other half —
keep generating until confident either way — is C19's coverage extension.

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
draws its node count uniformly, as designed. `t/dist.q` now measures every hint and every generator on the
ranges people use: list lengths, alternatives, weights, bits, the full-domain wrapper, signs, float means, tree
and step counts — with pinned seeds and multi-sigma bounds, never exact rates.


**C18 — examples are tests.** `t/readme.q` loads every runnable code block of `README.md` and of this document
as a script and fails on the first error (which is how a stale `.qc.str 0 5` in §1.3 was found), `t/examples.q`
runs every `examples/*.q` as a child q and checks that it exits cleanly and reports what its prose promises, and `t/self.q` runs every dispatcher of the runner over one fixed shape zoo (atoms, vectors,
strings, chars, general lists, dicts, the empty dict, tables, keyed tables, `::`, lambdas, projections): the
mechanical form of C3, added after `byname` failed on a keyed table that `fmt` and `diff` had already been
tested over. `t/docs.q` checks that every name in the `.qc` namespace that the design and README mention exists (it found `.qc.lin`,
promised and never written). The harness fails a test whose result is not a boolean instead of letting
`all` coerce it — a dozen test bugs across the milestones had passed that way — and evaluates each file one
top-level statement at a time under a trap, so an assertion that raises (a dependent `and`-chain meeting a
broken property, C2) fails alone, named by its line, instead of skipping the rest of its file. And every `q)` transcript in
README.md, EXAMPLES.md, COOKBOOK.md, examples/mdp/LOG.md and this document is executed by `t/doctest.q` in a fresh q that imitates the REPL
(seed 7, `\c 25 80`, silent on `;`, assignments and `::`), and must print exactly the text shown. What that cannot
see, so that nobody relies on it: prose claims outside a fence; timing; stderr from stdout (merged); the child's exit
code; the value of a statement that ends in `;` or is an assignment (silenced — a wrong value can hide behind a
trailing `;`); a line beginning `\` (skipped, so `q)\l x.q` is a no-op — the transcripts use `system"l …"`); output
beyond 25×80, compared only up to the `..`; behaviour at any seed but 7; and a fence spelled with a trailing space,
which is silently not a block. The cost of pinning (C8): a change to what any generator records rewrites every
transcript that drew from it — about eighty blocks across the five documents at M12. Origin: README snippets verified
by hand once, and a dispatcher the dogfooding had not reached.

**C19 — `n` is a budget; the run stops when it has learned what it can.** One rule replaced three stopping
conditions added one at a time. A run ends `exhausted` (every input tried: the minimal example, run at full
size so its ranges are the real ones, reveals the space; when the product of the widths fits the budget the
run enumerates the space in shortlex order — `w vs t` for the digits, each range's values nearest the origin
first — and abandons the claim if a replay's structure differs from example 0's), at the budget `n` with no
coverage question open, `cover` when an open question was settled by extending the run, `nmax` when it stayed
open to the cap, or `fail`/`gaveup` (a space whose every input was discarded is a give-up, not a pass).
Exhaustion was first exact only for value-independent structure (booleans, enums, small ranges, tuples and
records of them, the `spc` layout): example 0 revealed the ranges and the run replayed their mixed-radix digits,
abandoning the claim if a later example's structure differed. The choice tree replaced that: the tree *is* the
structure, so `one`, short lists and small state machines are exhausted too, the fixed-structure order is
unchanged, and the switch to sampling is taken on the first path whose product of widths exceeds the budget
(every path fitting bounds the leaves by `n`) or on a contradiction. Two things it taught while being built: the widths of
full-range choices overflow and a null compares *low*, so `prd` must see `0w` not `0N`; and an error that
escapes `chk` must clear the run flag on its way out (C9), or every later run in the session refuses as
nested. Origin: the two items deferred from C7 and C15, which turned out to be the same question.

**C20 — the library never applies a value it has not checked is callable.** In q, applying a non-function
indexes it, and a small integer is an IPC handle: `5 @ x` writes to handle 5. Every site where the library
applies something a user handed it — the property, `sized`'s function, `such`'s predicate, `rec`'s node, a
state machine's hooks and columns, `checks`' pairs — goes through `need` first and fails with `qc: … must be a
function`; a lambda property's arity is checked against a list spec up front. Origin: pitfall 1 seen from the
library's side, during the review rounds.

**C21 — arithmetic on choice bounds is done in floats, or guarded.** A difference, product or midpoint of two
longs from a full range overflows, the result is `0N` or wraps, and a null compares *low* — so an overflow does
not fail, it quietly makes the wrong branch look smaller. `wid`, the shortlex keys (`skey`, `bkey`, whose
differences from the origin are taken in floats — a long difference *wraps* on a full range, which `0W^` did not
catch), the binary search's midpoint, `pdup`'s and `pred`'s distances, `mix`'s magnitude, `lin`, the list and
step caps and the choice tree's path product all compute in floats and saturate on the way back to longs; `rec`
refuses sizes whose counting tables would overflow. The price is that two distances above 2^53 can compare
equal. Origin: `1+0W`, then `zig 0W`, then `prd` of widths that were null; the audit found the rest.

**C22 — state that belongs to a structure is saved and restored around that structure.** A constrained
table's columns need memory across rows (the last `mono` value, `uniq`'s remaining and used values); it lives in
three globals that `tabx` saves on entry and restores on every exit, including the error path, so tables nest and a
failed table leaves nothing behind. Per-example state belongs to `reset` and per-run state to `chk1`; this is the
third tier, owned by the structure. Origin: M7, where the first draft kept the state per example and two tables in
one spec shared it.

**C23 — a list that may hold anything grows behind a `::` seed.** `enlist d` is a table, a list of conforming
dicts is a table, and a dict amended with one long has a typed value list: the next element of another shape
cannot join (pitfalls 6 and 30). Every accumulator in the library that can receive mixed elements — `lst`, `sub`,
`subb`, the row in `rowd`, `mono`'s state, `uniq`'s used set — starts as `enlist (::)` (or `(enlist `)!enlist (::)`)
and drops the seed at the end, which leaves exactly what q would have built for a homogeneous list. Origin: A27
(`rec` over dicts), then two `mono` columns of different types in the second audit.

**C24 — a block is one draw call, one span and one unit of the budget.** `chn` records n choices in one call;
`bulk` and `btab` wrap it in one span whose layout (a length, then m blocks of that length) the shrinker's `pblk`
knows; `cfg`choices` counts calls, not rows. Anything that reads the layout — `pblk`, the choice tree's path
product — must handle a block as a unit or it either stalls (a chunk deleted from one block of several) or
switches regime (a path product over n rows). Origin: A22 and M8.

**C25 — two implementations of one law agree by test.** Where a law has a scalar and a vectorised form (`mix`
and `mixn`, `unif` and `unifn`), `t/dist.q` measures both on the same ranges with a pinned seed and requires them
to agree within a few sigma; the vectorised form's first bug (a long vector given to the vector conditional) was
invisible to every other test because no public caller reached it. Origin: the second audit.
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
| A18 | A monotone table column: deltas in the choices vs sorting after the draw | `a18_sorted.q` 5/5 | ✅ | Both encodings reach the analytic minimum on four planted bugs (gap, bucket, running max, window) and no candidate was ever unsorted; deltas need fewer attempts (138 vs 199) because a shrink of one choice moves every later time together instead of permuting rows. Rows stay spans (C13) either way. Chosen for M7: deltas. |
| A19 | A key column without duplicates: filter per row, index the remaining keys, or dedupe after | `a19_distinct.q` 5/5 | ✅ | All three reach the minimum. Indexing the remaining keys: one choice per row, no retries, 84 attempts and 14 choices per example at full density against `such` 228 and 19; both discard once rows exceed the key space, so a library `uniq` over a finite set caps the rows, and over an open generator falls back to filtering. Dedupe never discards but the row count is not the one drawn (and 21 choices per example). Chosen for M7: remaining keys for finite sets, filter otherwise. |
| A23 | Attributes set inside a generator survive every path | `a23_attr.q` 5/5 | ✅ | `s u g p` all survive draw, replay, strict, every shrink candidate, the counterexample and the failure db. `~` ignores attributes, so `eq` cannot report a missing one: a property about attributes says `attr x`. `` `s# `` on an unsorted vector signals `s-fail`, so `attr` composes safely with `asc`. |
| A24 | A multi-line report survives as an error string through `@`, `.Q.trp` and IPC | `a24_signal.q` 5/5 | ✅ | Intact on all three, including over a socket to a child q; the first line is a one-line summary a framework can print. So `must` can signal the whole report (M9). |
| A25 | The result dict is machine-readable as it is | `a25_json.q` 3/3 | ✅ | `.j.j` never errors on any of twelve outcomes (including a table in `notes` and a function as the counterexample) and `.j.k` reads every one back with the same keys. Losses: symbols become strings, `::` becomes null (`0n` back), the int seed becomes a float, a function becomes its source text. No json function is needed; M9 documents `.j.j r` and the four losses. |
| A20 | Two tables over one drawn symbol list (a foreign key by shared draw) shrink together | `a20_fk.q` 5/5 | ✅ | Every shrink candidate stayed referentially valid (`elem s` clamps into the shrunk list, A7) and a planted as-of-join bug shrank to its analytic minimum in 83 attempts: one symbol, two quotes at one time with different prices, one trade. No new primitive is needed; the idiom is a lambda that draws the shared list and then the tables. Spike lesson: `cols` is a keyword (pitfall 3). |
| A22 | Scale: 1e3..1e6-element vectors under per-element and bulk recording | `a22_scale.q` 5/5 | ✅ | Bulk (one call records n choices: fresh by `n?`, replay by slicing the prefix, one `C,:`) generates 1e6 longs in 9 ms against 2.5 s for 1e5 per-element. Bulk truncation alone stops at the shortest failing *prefix* (9 elements for `x~asc x`); with a block-deletion pass (ddmin over the block, shortening the length choice) every size shrinks to `1 0`: 37/39/44 attempts and under 3 ms at 1e3/1e4/1e5. A seeded bulk draw recording `(n;seed)` was dropped unmeasured: q has one RNG stream, so it would reseed the process mid-example (A3). Chosen for M8: bulk recording plus the block pass; the ramp keeps per-element failures small anyway. Also found: interactive draws read `cf`, which `cfg` did not reach without a run (fixed). |
| A26 | Finite temporal generators: timestamps in a session as base plus deltas, dates in a range | `a26_time.q` 7/7 | ✅ | Timestamps never leave the session and are monotone in every example; a planted `xbar` bug (four in one minute) shrinks to four timestamps at the open; a date bug shrinks to the first failing date; `gtime ltime x` round-trips; the minimal list is empty and the minimal date the first. Defaults for M10: a session `09:30`–`16:00` on a given day, a calendar year of dates. |
| A27 | An arbitrary q value from `rec` over the zoo with list, dict, table and keyed-table nodes | `a27_value.q` 5/5 | ✅ | At size 30, 1000 draws reach every one of the 18 atom types, typed vectors, general lists, dicts, tables and keyed tables (depth quartiles 5/7/10; 11/16/21 at size 100), and `-9!-8!x` round-trips every value. Two library facts surfaced: children that are dicts with different keys made `sub` and `lst` fail with `mismatch` (pitfall 30, fixed), and a node function receives conforming dict children as a table. |
| A21 | A generator from a schema | `a21_meta.q` 3/3 | ✅ after a redesign | Reading `meta` fails on enumerations: its `f` names only keyed-table foreign keys, so an enumerated column looks plain. Reading a *sample table* works: the type from `type`, the enumeration domain from `key`, the attribute from `attr`, typed empties from `0#`, keys from `keys`. Six shapes (plain, keyed, nested, attributed, general, enumerated) round-trip `meta` and the enumerated column stays `20h`. `0#` of a table drops attributes while `0#` of a vector keeps them, so an empty table carries none. For M7: the schema generator takes a table; `tabr`'s own empty table has untyped columns, which a schema fixes. Spike lessons: `like` and `vs` are keywords; a lambda does not capture the enclosing locals. |

---

## 3. Implementation plan and review rounds

Moved to `docs/HISTORY.md`: the milestone plan M1–M12 with what each was and found, the review rounds 1–10 and the
suite that would have caught what they found, and pointers to the two audits (`docs/AUDIT.md`, `docs/AUDIT2.md`) and
the review after M12 (`REVIEW.md`, at the top level while it is open).

## 4. Pitfalls

Pure q facts that the conventions in §1.10 do not already cover. For users:

Index: 1 Never · 2  · 3 A name is free iff · 4 In q-sql a parameter with th · 5  · 6  · 7  · 8  · 9 A q lambda with no explicit  · 10  · 11 Symbols are interned forever · 12  · 13 A script that errors while b · 14  · 15 For a weighted draw · 16  · 17  · 18  · 19 A dict seeded with a · 20  · 21  · 22  · 23  · 24 In · 25  · 26 Inside q-sql · 27 Indexing a table with a list · 28  · 29  · 30  · 31  · 32  · 33  · 34  · 35  · 36  · 37  · 38 A lambda does not capture th · 39  · 40  · 41  · 42  · 43 A functional delete with an  · 44  · 45 .

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
28. `f[]` and `f[::]` are the same call: an elided argument arrives as `::`, so `.qc.const (::)` draws to `::` and a
    generator cannot tell "called with nothing" from "called with `::`" (which is why the canary `d` works). A keyed
    table is `99h`: every dict test needs `not 98h=type key x` — `dct` is that test, used at every dict boundary.
29. `in` is reserved and cannot be a column name; the trace uses `arg` and `res`. A list literal
    `(f[]; g[])` evaluates right to left, so `(.qc.minimal g; count .qc.C)` counts before it draws.
30. `enlist d` is a table, and a list of conforming dicts *is* a table — there is no other representation — so
    joining a dict that does not conform onto it is `mismatch`. A list that may hold anything is grown behind a
    `::` seed and the seed dropped at the end: atoms still collapse to a typed vector, conforming dicts to a
    table, and anything else stays general (`lst`, `sub`, `subb`; found by A27, whose node function must also
    accept children that arrive as a table).
31. `in` and `?` compare within one type: `.Q.t?"j"` is a long and `type x` a short, so
    `(neg .Q.t?c) in type each xs` is a type error where `=` would have coerced; cast one side.

32. `.qc.chk` reseeds the process RNG with `\S` (a random seed unless `cfg`seed` is pinned), and q cannot save or
    restore an RNG *state*, only reseed. A process whose own `rand` stream matters — a simulation, a sampler —
    should pin `cfg`seed` or expect its stream to move after every check.
33. `f'[a;b]` over a three-argument `f` is a projection of the each, not a list of results: `count` of it is 1.
    Wrap `f` in a two-argument lambda first (`t`'s construction over `spc`).
34. `0#` of a table drops its columns' attributes; `0#` of a vector keeps its attribute. An empty table generated
    from a schema therefore carries none, and its typed empties are stripped with `` `# `` when they come from vectors.
35. `meta`'s `f` column names only keyed-table foreign keys; an enumerated symbol column shows `t` `s` and an
    empty `f`. The enumeration's domain is in the values: `key c`.
36. `count` is `#:` and `key` is `!:` in k, so `":"=last string first parse s` says "assignment" for `count x`. An
    assignment is an identifier followed by a single colon in the source text (`tools/doc_child.q`).
37. `system "q …"` runs the child with the console attached and prints its output instead of returning it; wrap
    the command in `sh -c '…'`, or begin it with `/usr/bin/env q`.
38. A lambda does not capture the enclosing function's locals; an outer local used inside an inner `{…}` is an
    undefined name. Project the inner lambda on what it needs (`{[at;tb;c] …}[at]/`).
39. `where` over a dict returns keys; over a list, indices. `cs where b` indexes a list of names by the indices;
    `where d` on a dict of booleans is already the names.
40. `p#` on a non-parted vector reports `u-fail`, the same text as a failed `u#`. Sort by the parted columns first;
    a table cannot carry both `p#` and `s#` on random rows.
41. `x,:y` on an undefined global defines it at top level, silently; a later `x:…` replaces it and the appended
    values are gone (`t/outcomes.q`, the first version of the C9 regression test). Define before appending.
42. `?[c;a;b]` needs a boolean `c`; `n?2` gives longs and raises `type`. `n?01b`, or a comparison.
43. A functional delete with an empty name list — `![`.;();0b;`symbol$()]` — deletes *every* global in the
    namespace, silently. The list is empty whenever an `inter` finds nothing, so guard it with `if[count k; …]`
    (found resetting the market data example's HDB: `examples/mdp/LOG.md` entry 19).
44. `\l dir` makes `dir` the working directory as well as loading it, and maps its tables in the root — and the
    mapped tables read their files relative to that directory, so it must *stay* the working directory (restoring
    the old one breaks the next query with `./2024.01.02/trade/seq. OS reports: No such file`). Load everything else
    by absolute path afterwards. A test that empties the directory leaves tables pointing at partitions that are
    gone: empty the contents, not the directory, and delete the mapped tables (entry 19 again).
45. `f each` (and `f'[xs;a]`) over an *empty* typed list returns a general empty list, `()`, not a typed one: a
    column mapped that way loses its type on the empty table, and two empty dicts then differ in key type (which
    `eq` now names). Leave an empty table alone: `$[count t; update c:f'[c] from t; t]` (`LOG.md` entry 21).
---

