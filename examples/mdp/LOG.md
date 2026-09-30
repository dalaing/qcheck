# Building a market data pipeline with qcheck — the log

A worked example, kept as it happened. Five pieces — reference data, quotes, bars, positions, end of day — are
written one at a time, each with properties as it is written, then assembled and driven by a state machine. Every
code change is a file under `steps/`, so every transcript below still runs: `t/doctest.q` executes each `q)` block
in a fresh q from the repository root (seed 7, `\c 25 80`) and requires the output shown. Nothing here is planted
except the sabotages of entries 20 and 23, which are labelled as such and exist to test the test; a bug appears in
the log when it appeared in the work.

The log was reviewed on 2026-09-28. Where a statement in it was found to be wrong it has been put right, and
each such place is marked *(corrected: …)* with what it said before. The library's word for what a property's
inputs are drawn from is now *generator*, and its rerun line says `gen`, so the log says so too. The shrinker
and the way a state machine records its commands have both been improved since, so in each report the counts
of shrinks and attempts and the numbers of the rerun line are those of the library as it now is; the counts of
tests are as they were. Two traces are a step shorter than they were, in entries 22 and 23, and are marked.
Nothing else has been changed.

## Piece 1 — reference data

### Entry 1: instruments, tick rounding, lots

An instrument table keyed by symbol (tick size, lot size, contract multiplier) and two helpers: round a price to
the instrument's tick, round a quantity down to whole lots. The generator draws a small instrument table (keys
distinct through `ktab`), then a symbol from it and a price; it sets the piece's table as a side effect, which is
how the piece will be used.

The first properties: rounding is idempotent, and it never moves a price by more than half a tick.

```q
q)system"l examples/mdp/steps/01_ref.q"
q)system"l examples/mdp/steps/01_gen.q"
q).qc.draw .mdp.g.inst
sym| tick lot mult
---| -------------
ACC| 0.05 100 50  
ABC| 0.05 1   10  
AB | 1    1   10  
B  | 0.05 1   1   
q).qc.check[.mdp.g.ref; {[s;px] r:.mdp.round[s;px]; r=.mdp.round[s;r]}];
FAIL falsified after 0 tests, 0 shrinks (15 attempts, seed 7)
x: (`A;0f)
qc: property returned {[s;px] r:.mdp.round[s;px]; r=.mdp.round[s;r]}[(`A;0f)]
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 0 0 0 0 0 0 0 0 0 0]
q).qc.check[.mdp.g.ref; {[s;px] .5>=abs[px-.mdp.round[s;px]]%.mdp.inst[s;`tick]}];
FAIL falsified after 0 tests, 0 shrinks (15 attempts, seed 7)
x: (`A;0f)
qc: property returned {[s;px] .5>=abs[px-.mdp.round[s;px]]%.mdp.inst[s;`tick]}[(`A;0f)]
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 0 0 0 0 0 0 0 0 0 0]
q).qc.check[(.mdp.g.ref; .qc.int 0 1000); {[sp;q] l:.mdp.lots[sp 0;q]; (l<=q) and 0=l mod .mdp.inst[sp 0;`lot]}];
ok 100 tests (seed 7)
```

Not a bug in the piece: a mistake in how I wrote the properties. The generator `g.ref` is a lambda that *returns* a
pair, so the property receives the pair as one argument (`prop @ x`), and a two-parameter property applied to one
argument is a projection — which is what "property returned {…}[(`A;0f)]" is telling me, on the minimal input.
A general-list generator (`(g.ref; .qc.int 0 1000)`) is applied with `.`, which is why the third check worked. The
report is exact about it; I just had to read it.

### Entry 2: the same properties, taking one argument

```q
q)system"l examples/mdp/steps/01_ref.q"
q)system"l examples/mdp/steps/01_gen.q"
q).qc.check[.mdp.g.ref; {s:x 0; px:x 1; r:.mdp.round[s;px]; r=.mdp.round[s;r]}];
ok 100 tests (seed 7)
q).qc.check[.mdp.g.ref; {s:x 0; px:x 1; .5>=abs[px-.mdp.round[s;px]]%.mdp.inst[s;`tick]}];
ok 100 tests (seed 7)
q).qc.check[(.mdp.g.ref; .qc.int 0 1000); {[sp;q] l:.mdp.lots[sp 0;q]; (l<=q) and 0=l mod .mdp.inst[sp 0;`lot]}];
ok 100 tests (seed 7)
```

Rounding and lots hold. The idempotence comparison is `=` on floats, which is tolerant (pitfall 23); a tick
multiple computed twice can differ in the last bit, so tolerant is what I mean here.

### Entry 3: renames, and a generator that found a hang

A rename table (`old`, `new`, effective date) and `canon[s;d]`: the name `s` goes by on date `d`, following
renames in effect. Step 01's `canon` is a `while` loop: as long as a rename from the current name is in effect,
take it.

Writing the generator is where the thinking happened. Renames come from the instrument table; the new name is
either a fresh symbol or *another instrument* — because that is what happens: a name is retired, reused, or a
rename is reverted. That last case, `A→B` then `B→A`, is a cycle, and a `while` that follows renames until none
applies never stops. I did not notice this in the code; I noticed it when the generator was about to produce it.

I ran the idempotence property against step 01 anyway, to see. It hung. There is no transcript of that: a hung
run is the one outcome a property-based test cannot report — qcheck has no per-example timeout (q cannot
interrupt an example from inside) — so the evidence is the absence of output and a process killed by hand. That
is worth knowing about the tool as much as about the code.

Step 02 makes `canon` total: it follows the *latest* effective rename (two renames from one name on different
dates were also possible, and step 01 took whichever row came first) and stops when a name repeats, so a
reversion resolves to the name that is current.

```q
q)system"l examples/mdp/steps/02_ref.q"
q)system"l examples/mdp/steps/02_gen.q"
q).mdp.ren:([]old:`A`B; new:`B`A; eff:2024.01.01 2024.02.01)
q).mdp.canon[`A;2024.03.01]
`A
q).qc.check[.mdp.g.ren; {s:x 0; d:x 1; c:.mdp.canon[s;d]; c=.mdp.canon[c;d]}];
ok 100 tests (seed 7)
q).qc.check[.mdp.g.ren; {s:x 0; d:x 1; (.mdp.canon[s;d]=s) or .mdp.canon[s;d] in exec new from .mdp.ren where eff<=d}];
ok 100 tests (seed 7)
```

Two properties: `canon` is idempotent, and it returns either the name itself or a name some effective rename
maps to. Both pass. Piece 1 tally: one bug (the cycle), found by writing the generator rather than by running it.

## Piece 2 — quotes and enrichment

### Entry 4: a quote cache, and two ways to enrich a trade

Quotes arrive; the piece keeps the day's quotes and the last quote per symbol. A trade is enriched with the
prevailing quote two ways: as it arrives, from the cache (`enrich1`), or afterwards in a batch, as of its time,
with `aj` over the day's quotes (`enrichb`). The property: over a day of interleaved quotes and trades in time
order, the two agree. The generator is one table of events — `mono` timestamps up to ten seconds apart, a kind,
a symbol from the instruments, a quote whose ask is drawn from its bid (`dep`), a trade — and the property
replays it in order, feeding quotes to the cache and enriching trades as they come.

The first run failed on the empty day, and not for a reason in the piece:

```
FAIL falsified after 0 tests, 0 shrinks (12 attempts, seed 7)
x:
  time kind sym bid ask px qty
  ----------------------------
qc.eq
path why  a b
-------------
bid  type 9 0
ask  type 9 0
```

(Reading a `qc.eq` table, here and below: one row per difference; `path` is where in the two values it lies —
a column name, a row index, a dict key — `why` is the kind of difference — `type`, `value`, `count`, `order` — and
`a`, `b` are the two sides. The `rerun:` line under a failure gives the exact choices that reproduce it; the
transcripts here never use it because every step file is kept.)

The minimal example is a stream with no events. Enriching no trades from the cache gives float `bid` and `ask`
columns; `aj` over a quote table with no rows gives general ones — because the generated empty table had general
columns. That was qcheck's doing: `tab`'s empty table was untyped (its design said so, as a limitation), and the
minimal example is *always* the empty table, so every property over a generated table met it first. I fixed the
library rather than the property: `tab` now types its empty columns from a probe of one minimal row (the report
above is quoted, not executed, because the library that produced it is gone; the change and what it found on the
way are in docs/DESIGN.md, M7 and pitfall 26's neighbours).

### Entry 5: a bug in my replay, not in the piece

With typed empties the empty day passes and the property finds this:

```q
q)system"l examples/mdp/steps/03_quotes.q"
q)system"l examples/mdp/steps/03_gen.q"
q)5#.qc.draw .mdp.g.stream
time                          kind  sym bid      ask      px       qty
----------------------------------------------------------------------
2024.01.02D09:30:00.008208256 quote ACC 10       54.78843 45.52337 100
2024.01.02D09:30:00.008213338 trade ACC 24.90625 32.5991  73.05742 10
2024.01.02D09:30:01.038894268 quote ABC 68.21192 97.08473 13.25    10
2024.01.02D09:30:01.039131004 quote ACC 43.85249 65.85082 17.74133 1
2024.01.02D09:30:01.125495236 trade ACC 60.82281 68.5     91.41703 1
q)replay:{[ev] .mdp.quote::0#.mdp.quote; .mdp.qcache::0#.mdp.qcache; out:0#.mdp.enrich1 select time,sym,px,qty from ev; {[e] $[`quote=e`kind; .mdp.onquote enlist `time`sym`bid`ask#e; out,:.mdp.enrich1 enlist `time`sym`px`qty#e]} each ev; out}
q).qc.check[.mdp.g.stream; {inc:replay x; bat:.mdp.enrichb[select time,sym,px,qty from x where kind=`trade; select time,sym,bid,ask from x where kind=`quote]; .qc.eq[inc;bat]}];
FAIL falsified after 2 tests, 11 shrinks (83 attempts, seed 7)
x:
  time                          kind  sym bid ask px qty
  ------------------------------------------------------
  2024.01.02D09:30:00.000000000 trade A   1   1   1  1
qc.eq
path why   a b
--------------
     count 0 1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 0 0 0 0 0 0 1 757503000000000000 1 0 0 0 1 0 0 1 0 0 1 0 0]
```

One trade, no quotes: the incremental side has no rows at all. The piece is fine; my `replay` is not. `out,:…`
inside the inner lambda does not reach `replay`'s local `out` (a lambda does not see the enclosing function's
locals), so it created a global `out` and appended to that, and `replay` returned its own, empty, `out`. Two
pitfalls in one line, found by the smallest stream that has a trade. The replay becomes a fold.

### Entry 6: the tie

```q
q)system"l examples/mdp/steps/03_quotes.q"
q)system"l examples/mdp/steps/03_gen.q"
q)replay:{[ev] .mdp.quote::0#.mdp.quote; .mdp.qcache::0#.mdp.qcache; {[o;e] $[`quote=e`kind; [.mdp.onquote enlist `time`sym`bid`ask#e; o]; o,.mdp.enrich1 enlist `time`sym`px`qty#e]}/[0#.mdp.enrich1 select time,sym,px,qty from ev;ev]}
q).qc.check[.mdp.g.stream; {inc:replay x; bat:.mdp.enrichb[select time,sym,px,qty from x where kind=`trade; select time,sym,bid,ask from x where kind=`quote]; .qc.eq[inc;bat]}];
FAIL falsified after 19 tests, 19 shrinks (124 attempts, seed 7)
x:
  time                          kind  sym bid ask px qty
  ------------------------------------------------------
  2024.01.02D09:30:00.000000000 trade A   1   1   1  1
  2024.01.02D09:30:00.000000000 quote A   1   1   1  1
qc.eq
path   why   a b
----------------
`bid 0 value   1
`ask 0 value   1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 0 0 0 0 0 0 1 757503000000000000 1 0 0 0 1 0 0 1 0 0 1 0 1 0 0 0 0 0 1 0 0 1 0 0 1 0 0]
```

A trade and a quote at the same timestamp, the trade first. As it arrived, the trade saw no quote; the batch `aj`,
which is inclusive on time, gives it the quote that arrived a moment later. This is the as-of tie every kdb shop
meets: time alone does not say what was known when. The piece's answer, step 04: the feed stamps every event with
a sequence number as it arrives, and the batch join is as-of the sequence, not the time.

### Entry 7: two more things the batch join taught me

```q
q)system"l examples/mdp/steps/04_quotes.q"
q)system"l examples/mdp/steps/04_gen.q"
q)replay:{[ev] .mdp.seq::0; .mdp.quote::0#.mdp.quote; .mdp.qcache::0#.mdp.qcache; {[o;e] $[`quote=e`kind; [.mdp.onquote enlist `time`sym`bid`ask#e; o]; o,.mdp.enrich1 enlist `time`sym`px`qty#e]}/[0#.mdp.enrich1 select time,sym,px,qty from ev;ev]}
q).qc.check[.mdp.g.stream; {inc:replay x; bat:.mdp.enrichb[select seq,time,sym,px,qty from inc; .mdp.quote]; .qc.eq[inc;bat]}];
FAIL falsified after 0 tests, 0 shrinks (15 attempts, seed 7)
x:
  time kind sym bid ask px qty
  ----------------------------
qc.eq
path why   a                           b
------------------------------------------------------------------
     order time sym px qty seq bid ask seq time sym px qty bid ask
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 0 0 0 0 0 0 0]
q).qc.check[.mdp.g.stream; {inc:replay x; all (inc[`bid]<=inc`ask) or null inc`bid}];
ok 100 tests (seed 7)
```

Same rows, different column order: `stamp` appended `seq` where the tables declare it first. `.qc.eq`'s `order`
row is that diagnosis. Step 05 puts `seq` first.

```q
q)system"l examples/mdp/steps/05_quotes.q"
q)system"l examples/mdp/steps/04_gen.q"
q)replay:{[ev] .mdp.seq::0; .mdp.quote::0#.mdp.quote; .mdp.qcache::0#.mdp.qcache; {[o;e] $[`quote=e`kind; [.mdp.onquote enlist `time`sym`bid`ask#e; o]; o,.mdp.enrich1 enlist `time`sym`px`qty#e]}/[0#.mdp.enrich1 select time,sym,px,qty from ev;ev]}
q).qc.check[.mdp.g.stream; {inc:replay x; bat:.mdp.enrichb[select seq,time,sym,px,qty from inc; .mdp.quote]; .qc.eq[inc;bat]}];
FAIL falsified after 6 tests, 36 shrinks (155 attempts, seed 7)
x:
  time                          kind  sym bid ask px qty
  ------------------------------------------------------
  2024.01.02D09:30:00.000000000 quote A   1   1   1  1
  2024.01.02D09:30:00.000000001 trade A   1   1   1  1
qc.eq
path    why   a                             b
-------------------------------------------------------------------------
`time 0 value 2024.01.02D09:30:00.000000001 2024.01.02D09:30:00.000000000
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 0 0 0 0 0 0 1 757503000000000000 0 0 0 0 1 0 0 1 0 0 1 0 1 1 1 0 0 0 1 0 0 1 0 0 1 0 0]
q).qc.check[.mdp.g.stream; {inc:replay x; all (inc[`bid]<=inc`ask) or null inc`bid}];
ok 100 tests (seed 7)
```

The enriched trade carries the *quote's* time. `aj` brings every right-hand column across, and the quote table
has a `time` too; joining on `seq` no longer protected it. The minimum says it in one nanosecond. Step 06 joins
only the columns the enrichment is for.

### Entry 8: piece 2 passes

```q
q)system"l examples/mdp/steps/06_quotes.q"
q)system"l examples/mdp/steps/04_gen.q"
q)replay:{[ev] .mdp.seq::0; .mdp.quote::0#.mdp.quote; .mdp.qcache::0#.mdp.qcache; {[o;e] $[`quote=e`kind; [.mdp.onquote enlist `time`sym`bid`ask#e; o]; o,.mdp.enrich1 enlist `time`sym`px`qty#e]}/[0#.mdp.enrich1 select time,sym,px,qty from ev;ev]}
q).qc.check[.mdp.g.stream; {inc:replay x; bat:.mdp.enrichb[select seq,time,sym,px,qty from inc; .mdp.quote]; .qc.eq[inc;bat]}];
ok 100 tests (seed 7)
q).qc.check[.mdp.g.stream; {inc:replay x; all (inc[`bid]<=inc`ask) or null inc`bid}];
ok 100 tests (seed 7)
```

Piece 2 tally: one library limitation (untyped empty tables, fixed in the library), one bug in my test code
(a lambda's locals), and three in the piece — the tie, the column order, the column clash — each found by the
smallest possible stream, each a thing a kdb programmer has met before and will meet again.

## Piece 3 — bars

### Entry 9: per-minute bars, and an order that was never promised

Per symbol and minute: open, high, low, close, volume, count. `onbar` folds each trade into a keyed bar table;
`barsb` is the batch form, one `select … by sym, minute` over the day. The generator is a day of trades, `mono`
times up to thirty seconds apart so that minutes fill and boundaries get crossed. Property: fold equals batch.

```q
q)system"l examples/mdp/steps/07_bars.q"
q)system"l examples/mdp/steps/07_gen.q"
q).qc.check[.mdp.g.trades; {.mdp.bar::0#.mdp.bar; .mdp.onbar x; .qc.eq[.mdp.bar; .mdp.barsb x]}];
FAIL falsified after 4 tests, 25 shrinks (204 attempts, seed 7)
x:
  time                          sym px qty
  ----------------------------------------
  2024.01.02D09:30:00.000000000 B   1  1
  2024.01.02D09:30:00.000000000 A   1  1
qc.eq
path   why   a b
----------------
`sym 0 value B A
`sym 1 value A B
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 0 0 0 0 1 1 0 0 0 0 0 0 1 757503000000000000 0 0 0 1 0 1 0 1 0 0 1 0 0]
q).qc.check[.mdp.g.trades; {.mdp.bar::0#.mdp.bar; .mdp.onbar x; b:0!.mdp.bar; all (b[`h]>=b`o) and (b[`h]>=b`c) and (b[`l]<=b`o) and (b[`l]<=b`c) and b[`n]>0}];
ok 100 tests (seed 7)
```

Two trades, B then A, in the same minute: the fold's table has B's bar first because B arrived first, the batch
has A's first because `by` sorts its keys. Same bars, different row order. `.qc.eq` compares keyed tables row by
row, on purpose (a keyed table is still a table), so the property as written asserts an order the piece never
promised. This one is the property's to fix, not the piece's: a bar table's meaning is its keys, so the property
compares both sides sorted by key. The OHLC sanity property passed alongside.

### Entry 10: piece 3 passes, with one property more

```q
q)system"l examples/mdp/steps/07_bars.q"
q)system"l examples/mdp/steps/07_gen.q"
q)same:{[a;b] .qc.eq[`sym`minute xasc 0!a; `sym`minute xasc 0!b]}
q).qc.check[.mdp.g.trades; {.mdp.bar::0#.mdp.bar; .mdp.onbar x; same[.mdp.bar; .mdp.barsb x]}];
ok 100 tests (seed 7)
q).qc.check[(.mdp.g.trades; .qc.int 0 40); {[t;k] k:k&count t; .mdp.bar::0#.mdp.bar; .mdp.onbar k#t; .mdp.onbar k _ t; a:.mdp.bar; .mdp.bar::0#.mdp.bar; .mdp.onbar t; same[a;.mdp.bar]}];
ok 100 tests (seed 7)
```

The second property is the one the pipeline will lean on: feeding the day in two batches, split anywhere, gives
the bars that feeding it in one does. That is what an incremental bar table is *for*, and it is what a late trade
will test later, when the split is not at the end of the stream but inside a minute already closed. Piece 3 tally:
no bugs in the piece; one over-strict property.

## Piece 4 — positions and PnL

### Entry 11: positions, and two runs that never reached the position logic

Per symbol: signed quantity, average cost of the open position, realised PnL. A fill that adds averages its price
in; one that reduces realises `(px-cost)*closed*mult` and keeps the cost; one that flips realises the whole old
position and opens the remainder at the fill price. `unreal` marks the open positions against a price per symbol.
The generator draws a fill log and a mark. Two properties to start: the position is the signed sum of the fills,
and the book balances — realised plus unrealised equals the cash flow of the fills plus the open position marked.

```q
q)system"l examples/mdp/steps/08_pos.q"
q)system"l examples/mdp/steps/08_gen.q"
q).qc.check[.mdp.g.fills; {f:x 0; .mdp.pos::0#.mdp.pos; .mdp.onfill f; .qc.eq[exec qty from .mdp.pos; exec sum qty*1 -1 `buy`sell?side by sym from f]}];
FAIL falsified after 0 tests, 0 shrinks (18 attempts, seed 7)
x:
  0:
    sym side qty px
    ---------------
  1:
    A: 1f
qc.eq
path why  a b
--------------
     type 7 99
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 0 0 0 0 0 0 0 0 0 1]
q)cash:{[f] exec sum .mdp.inst[sym;`mult]*qty*px*-1 1 `buy`sell?side from f}
q).qc.check[.mdp.g.fills; {f:x 0; mk:x 1; .mdp.pos::0#.mdp.pos; .mdp.onfill f; lhs:(exec sum real from .mdp.pos)+.mdp.unreal mk; rhs:cash[f]+exec sum .mdp.inst[sym;`mult]*qty*mk sym from .mdp.pos; 1e-6>abs lhs-rhs}];
FAIL falsified after 0 tests, 0 shrinks (18 attempts, seed 7)
x:
  0:
    sym side qty px
    ---------------
  1:
    A: 1f
inst
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 0 0 0 0 0 0 0 0 0 1]
```

Both fell at the empty fill log, the minimal example, before a single fill was booked. The first is my property:
one side is a vector (type 7), the other a dictionary (99), and a vector is never a dictionary, so the property
could not have passed on any fill log *(corrected: this said that with fills the two "would only agree by luck
of order")*. Both sides become dictionaries sorted by key. The second is a q lesson that
belongs in the piece: `unreal`'s `exec` names `inst` without its namespace, and a q-SQL expression inside a lambda
defined under `\d .mdp` does *not* resolve the name to `.mdp.inst` the way the rest of the lambda body would
(the table after `from` does resolve; the names inside the expressions do not). Step 09 writes the global in full.
While fixing it I found that indexing a keyed table by a list of keys and a column — `inst[syms;`mult]` — is a
`length` error, where the same with one key works; step 09 looks the multipliers up as a dictionary instead, and
my `cash` had the same mistake.

### Entry 12: the book does not balance on one fill

```q
q)system"l examples/mdp/steps/09_pos.q"
q)system"l examples/mdp/steps/08_gen.q"
q)mult:{exec sym!mult from .mdp.inst}
q)cash:{[f] exec sum mult[][sym]*qty*px*-1 1 `buy`sell?side from f}
q).qc.check[.mdp.g.fills; {f:x 0; mk:x 1; .mdp.pos::0#.mdp.pos; .mdp.onfill f; lhs:(exec sum real from .mdp.pos)+.mdp.unreal mk; rhs:cash[f]+exec sum mult[][sym]*qty*mk sym from .mdp.pos; 1e-6>abs lhs-rhs}];
FAIL falsified after 2 tests, 9 shrinks (60 attempts, seed 7)
x:
  0:
    sym side qty px
    ---------------
    A   buy  1   1
  1:
    A: 1f
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 0 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0 1]
q).qc.check[.mdp.g.fills; {f:x 0; .mdp.pos::0#.mdp.pos; .mdp.onfill f; p:0!select from .mdp.pos where qty<>0; r:select mn:min px,mx:max px by sym from f; k:([]sym:p`sym); all (p[`cost]>=(r[k]`mn)-1e-9) and p[`cost]<=1e-9+r[k]`mx}];
FAIL falsified after 2 tests, 9 shrinks (60 attempts, seed 7)
x:
  0:
    sym side qty px
    ---------------
    A   buy  1   1
  1:
    A: 1f
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 0 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0 1]
q).qc.check[(.qc.elem `A`B; .qc.elem 1 10 100; .qc.flt 1 100); {[s;q;p] .mdp.inst::([sym:`A`B] tick:0.01 0.01; lot:1 1; mult:1 10); .mdp.pos::0#.mdp.pos; .mdp.onfill ([]sym:s,s; side:`buy`sell; qty:q,q; px:p,p); (0=.mdp.pos[s;`qty]) and 0=.mdp.pos[s;`real]}];
FAIL falsified after 0 tests, 0 shrinks (5 attempts, seed 7)
s: `A
q: 1
p: 1f
rerun: .qc.again[]  or  .qc.recheck[gen;prop;0 0 0 0 1]
```

Three properties, one cause, and the smallest case each time: buy one at 1, marked at 1, and the book is off by
one; the cost of an open position is outside the range of the prices paid for it; a round trip at one price
realises something. The position after one buy has cost `0`, not `1`. The average is written
`(c0*abs[q0]+px*abs q)%abs q0+q`, and q has no precedence: right to left, `c0*abs[q0]+…` is `c0*(abs[q0]+…)`, zero
times everything on the first fill. Every q programmer has written this line; the point is that three different
properties refused it with a one-row fill log, and the failing input is so small that the diagnosis is a matter of
evaluating one expression by hand. Step 10 brackets the product.

### Entry 13: piece 4 passes

```q
q)system"l examples/mdp/steps/10_pos.q"
q)system"l examples/mdp/steps/08_gen.q"
q)byk:{k:asc key x; k!x k}
q).qc.check[.mdp.g.fills; {f:x 0; .mdp.pos::0#.mdp.pos; .mdp.onfill f; .qc.eq[byk exec sym!qty from .mdp.pos; byk exec sum qty*1 -1 `buy`sell?side by sym from f]}];
ok 100 tests (seed 7)
q)mult:{exec sym!mult from .mdp.inst}
q)cash:{[f] exec sum mult[][sym]*qty*px*-1 1 `buy`sell?side from f}
q).qc.check[.mdp.g.fills; {f:x 0; mk:x 1; .mdp.pos::0#.mdp.pos; .mdp.onfill f; lhs:(exec sum real from .mdp.pos)+.mdp.unreal mk; rhs:cash[f]+exec sum mult[][sym]*qty*mk sym from .mdp.pos; 1e-6>abs lhs-rhs}];
ok 100 tests (seed 7)
q).qc.check[.mdp.g.fills; {f:x 0; .mdp.pos::0#.mdp.pos; .mdp.onfill f; p:0!select from .mdp.pos where qty<>0; r:select mn:min px,mx:max px by sym from f; k:([]sym:p`sym); all (p[`cost]>=(r[k]`mn)-1e-9) and p[`cost]<=1e-9+r[k]`mx}];
ok 100 tests (seed 7)
q).qc.check[(.qc.elem `A`B; .qc.elem 1 10 100; .qc.flt 1 100); {[s;q;p] .mdp.inst::([sym:`A`B] tick:0.01 0.01; lot:1 1; mult:1 10); .mdp.pos::0#.mdp.pos; .mdp.onfill ([]sym:s,s; side:`buy`sell; qty:q,q; px:p,p); (0=.mdp.pos[s;`qty]) and 0=.mdp.pos[s;`real]}];
ok 100 tests (seed 7)
```

Piece 4 tally: two bugs in the piece (a namespace name inside q-SQL; operator precedence in the average cost), one
mistyped property, and two q facts learned on the way (a keyed table indexed by a list of keys and a column;
`exec … by` gives a dictionary). Four properties stand; the balance-sheet identity is the one the state machine
will carry, since it holds for any fill log and any mark.

## Piece 5 — end of day

### Entry 14: the close, and a query that cannot be asked of a partitioned table

At the close the day's trades, quotes and bars go to a date partition of the HDB — sorted by symbol, `p#sym`,
symbols enumerated — the day tables are cleared, the HDB is remapped, the day advances. Three queries answer for
any date in one shape, from memory if the date is today and from disk otherwise: bars for a symbol in a window,
the day's VWAP, the day's trades. Piece 5 also keeps the day's enriched trades, which nothing had kept until now,
so `ontrade` (enrich, keep, bar) appears here. The property: feed a day, ask every query of every symbol, close
the day, ask again, and the answers agree. The HDB root is a fresh temporary directory per session.

```q
q)system"l examples/mdp/steps/06_quotes.q"
q)system"l examples/mdp/steps/07_bars.q"
q)system"l examples/mdp/steps/11_eod.q"
q)system"l examples/mdp/steps/07_gen.q"
q).mdp.hdb:hsym `$first system"mktemp -d"
q)reset:{.mdp.seq::0; .mdp.today::2024.01.02; .mdp.quote::0#.mdp.quote; .mdp.qcache::0#.mdp.qcache; .mdp.trade::0#.mdp.trade; .mdp.bar::0#.mdp.bar}
q)feed:{[ev] {[e] $[`quote=e`kind; .mdp.onquote enlist `time`sym`bid`ask#e; .mdp.ontrade enlist `time`sym`px`qty#e]} each ev;}
q)ask:{[d;s;a;b] `bars`vwap`trades!(.mdp.qbars[d;s;a;b]; .mdp.qvwap[d;s]; .mdp.qtrades[d;s])}
q).qc.check[(.mdp.g.stream; .qc.ts[.mdp.open;.mdp.close]; .qc.ts[.mdp.open;.mdp.close]); {[ev;a;b] w:asc (a;b); reset[]; feed ev; s:exec sym from .mdp.inst; mem:ask[2024.01.02;;w 0;w 1] each s; .mdp.eod 2024.01.02; .qc.eq[mem; ask[2024.01.02;;w 0;w 1] each s]}];
FAIL falsified after 0 tests, 0 shrinks (18 attempts, seed 7)
ev:
  time kind sym bid ask px qty
  ----------------------------
a: 2024.01.02D09:30:00.000000000
b: 2024.01.02D09:30:00.000000000
nyi
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 0 0 0 0 0 0 0 757503000000000000 757503000000000000]
```

`nyi` on the empty day: `exec qty wavg px from trade where date=d, sym=s` — `exec` is not implemented over a
partitioned table, where the same aggregate in a `select` is. The RDB form and the HDB form of a query are not the
same text with a `date=` added, which is the whole reason to test parity. Step 12 asks the HDB with a `select`.

### Entry 15: the symbols come back different

```q
q)system"l examples/mdp/steps/06_quotes.q"
q)system"l examples/mdp/steps/07_bars.q"
q)system"l examples/mdp/steps/12_eod.q"
q)system"l examples/mdp/steps/07_gen.q"
q).mdp.hdb:hsym `$first system"mktemp -d"
q)reset:{.mdp.seq::0; .mdp.today::2024.01.02; .mdp.quote::0#.mdp.quote; .mdp.qcache::0#.mdp.qcache; .mdp.trade::0#.mdp.trade; .mdp.bar::0#.mdp.bar}
q)feed:{[ev] {[e] $[`quote=e`kind; .mdp.onquote enlist `time`sym`bid`ask#e; .mdp.ontrade enlist `time`sym`px`qty#e]} each ev;}
q)ask:{[d;s;a;b] `bars`vwap`trades!(.mdp.qbars[d;s;a;b]; .mdp.qvwap[d;s]; .mdp.qtrades[d;s])}
q).qc.check[(.mdp.g.stream; .qc.ts[.mdp.open;.mdp.close]; .qc.ts[.mdp.open;.mdp.close]); {[ev;a;b] w:asc (a;b); reset[]; feed ev; s:exec sym from .mdp.inst; mem:ask[2024.01.02;;w 0;w 1] each s; .mdp.eod 2024.01.02; .qc.eq[mem; ask[2024.01.02;;w 0;w 1] each s]}];
FAIL falsified after 0 tests, 0 shrinks (18 attempts, seed 7)
ev:
  time kind sym bid ask px qty
  ----------------------------
a: 2024.01.02D09:30:00.000000000
b: 2024.01.02D09:30:00.000000000
qc.eq
path           why  a  b
-------------------------
`bars   0 `sym type 11 20
`trades 0 `sym type 11 20
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 0 0 0 0 0 0 0 757503000000000000 757503000000000000]
```

Still the empty day, and still not a row in sight: the disk answers carry enumerated symbols (type 20) where
memory's are plain (11). Equal to look at and to join, different to `~` and to `type` — and so to any caller, or
test, that compares an answer from disk with one from memory *(corrected: this said they were different "to a
client that joins the answer to something of its own"; on kdb+ 5.0 the joins give the same results either
way)*. Since the queries promise one shape for any date, step 13 has the disk branch return
memory's shape: the `date` column dropped, the symbols un-enumerated.

### Entry 16: piece 5 passes

```q
q)system"l examples/mdp/steps/06_quotes.q"
q)system"l examples/mdp/steps/07_bars.q"
q)system"l examples/mdp/steps/13_eod.q"
q)system"l examples/mdp/steps/07_gen.q"
q).mdp.hdb:hsym `$first system"mktemp -d"
q)reset:{.mdp.seq::0; .mdp.today::2024.01.02; .mdp.quote::0#.mdp.quote; .mdp.qcache::0#.mdp.qcache; .mdp.trade::0#.mdp.trade; .mdp.bar::0#.mdp.bar}
q)feed:{[ev] {[e] $[`quote=e`kind; .mdp.onquote enlist `time`sym`bid`ask#e; .mdp.ontrade enlist `time`sym`px`qty#e]} each ev;}
q)ask:{[d;s;a;b] `bars`vwap`trades!(.mdp.qbars[d;s;a;b]; .mdp.qvwap[d;s]; .mdp.qtrades[d;s])}
q).qc.check[(.mdp.g.stream; .qc.ts[.mdp.open;.mdp.close]; .qc.ts[.mdp.open;.mdp.close]); {[ev;a;b] w:asc (a;b); reset[]; feed ev; s:exec sym from .mdp.inst; mem:ask[2024.01.02;;w 0;w 1] each s; .mdp.eod 2024.01.02; .qc.eq[mem; ask[2024.01.02;;w 0;w 1] each s]}];
ok 100 tests (seed 7)
q).qc.check[(.mdp.g.stream; .mdp.g.stream); {[e1;e2] reset[]; feed e1; s:exec sym from .mdp.inst; d1:ask[2024.01.02;;.mdp.open;.mdp.close] each s; .mdp.eod 2024.01.02; feed update time+1D from e2; d2:ask[2024.01.03;;.mdp.open+1D;.mdp.close+1D] each s; .mdp.eod 2024.01.03; .qc.eq[(d1;d2); (ask[2024.01.02;;.mdp.open;.mdp.close] each s; ask[2024.01.03;;.mdp.open+1D;.mdp.close+1D] each s)]}];
ok 100 tests (seed 7)
q).qc.check[.mdp.g.stream; {reset[]; feed x; c:.mdp.qcache; .mdp.eod 2024.01.02; (c~.mdp.qcache) and (0=count .mdp.trade) and 0=count .mdp.bar}];
ok 100 tests (seed 7)
```

Two more properties for the road: two days closed in turn are both still answerable, each as it was in memory;
and the close clears the day tables but leaves the quote cache alone, which is the one piece of state that is
meant to carry across the boundary. Piece 5 tally: two bugs in the piece, both in the disk branch of the queries
(an `exec` the HDB cannot run; an enumeration the caller would not expect), both found at the empty day before
the first row was ever written. Nothing was found in the writing itself.

With the pieces in hand: piece 1 one bug, piece 2 three, piece 3 none, piece 4 two, piece 5 two — eight in the
pieces, six in my test code or the library, every one caught by a minimal example a person can read at a glance.
Now the assembly, and the state machine over it.

## The assembly

### Entry 17: one entry point, a state machine, and the first thing it found

`upd[table;rows]` routes quotes, trades and fills to the pieces (step 14): trades are rounded to the tick on the
way in, enriched, kept and barred. The machine (step 15) runs three instruments through six commands — `quote`,
`trade`, a `late` trade timed up to thirty minutes back, `fill`, `eod`, `query` — weighted towards quotes and
trades, over a clock that starts at the open and moves with each quote and trade. Its model is the event log
itself: quotes and trades in arrival order with the feed's sequence number, and the fills. The oracle recomputes
from the log — the trades of a day are the ones timed on it, enriched by the batch join, barred by the batch
select, positions the signed sum of the fills — and the invariant compares the system to it after every step:
positions, today's bars, the quote cache, and the balance-sheet identity of piece 4. `query` asks the same three
questions of the system and of the oracle, for any day so far.

Three slips in the machine itself came first, none worth a transcript: a parameter named `vs` (a keyword, again),
a lookup into an unkeyed table by a key, and a model that numbered events from one where the feed's stamp counts
from zero. Then the first run that reached the system:

```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/14_upd.q"
q)system"l examples/mdp/steps/15_sm.q"
q).qc.check[.qc.sm[.mdp.hooks] .mdp.cmds; ::];
FAIL falsified after 4 tests, 4 shrinks (24 attempts, seed 7)
qc.run round
step cmd   arg                                   res model ok
-------------------------------------------------------------
0    trade 2024.01.02D09:30:00.000000000 `A 1f 1 ::  ::    0 
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 757503000000000000 0 0 0 1 1]
```

The one line of q-SQL in the assembly — `update px:round'[sym;px]` — could not see `round`, the same lesson as
entry 11 (pitfall 26: names inside a q-SQL expression resolve in the root, not the lambda's namespace). Step 16
writes it in full. The trace above is one row long because of a change to qcheck made on the spot: an error in
`run` or `post` used to note the trace *before* the failing step, so the command that raised, and its argument,
were the one thing the report did not show. The noted trace now ends with that step, marked not ok.

### Entry 18: run 1 — the machine passes, and what it did and did not reach

```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/15_sm.q"
q).qc.check[.qc.sm[.mdp.hooks] .mdp.cmds; ::];
ok 100 tests (seed 7)
```

Nothing. Before believing it I asked what the runs had actually exercised, with a property that labels each trace
by the seams I had in mind: a close; a late trade; a query of a past day, answered from disk; the first trade of a
new day arriving before that day's first quote, so that the cache carries yesterday's quote across the close; a
late trade after a close.

```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/15_sm.q"
q)seams:{[tr] c:tr`cmd; .qc.classify[`eod;`eod in c]; .qc.classify[`late;`late in c]; .qc.classify[`query_of_a_past_day; any {[r] $[`query=r`cmd; r[`arg][0]<r[`model]`day; 0b]} each tr]; .qc.classify[`late_timed_yesterday; any {[r] $[`late=r`cmd; ("d"$r[`arg]0)<r[`model]`day; 0b]} each tr]; .qc.classify[`late_after_eod; any (c=`late) and 0<sums c=`eod]; .qc.classify[`first_trade_of_a_day_before_its_first_quote; any (c=`trade) and (0<sums c=`eod) and 0=sums (c=`quote) and 0<sums c=`eod]; 1b}
q).qc.check[.qc.sm[.mdp.hooks] .mdp.cmds; seams];
ok 100 tests (seed 7)
label                                       n  pct req lo       hi       ok b..
-----------------------------------------------------------------------------..
eod                                         52 52      42.31641 61.53562 1  #..
late                                        38 38      29.09745 47.79043 1  #..
query_of_a_past_day                         15 15      9.305903 23.28373 1  #..
first_trade_of_a_day_before_its_first_quote 20 20      13.33659 28.8831  1  #..
late_after_eod                              12 12      6.999337 19.81227 1  #..
```
```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/15_sm.q"
q)seams:{[tr] c:tr`cmd; .qc.classify[`eod;`eod in c]; .qc.classify[`late;`late in c]; .qc.classify[`query_of_a_past_day; any {[r] $[`query=r`cmd; r[`arg][0]<r[`model]`day; 0b]} each tr]; .qc.classify[`late_timed_yesterday; any {[r] $[`late=r`cmd; ("d"$r[`arg]0)<r[`model]`day; 0b]} each tr]; .qc.classify[`late_after_eod; any (c=`late) and 0<sums c=`eod]; .qc.classify[`first_trade_of_a_day_before_its_first_quote; any (c=`trade) and (0<sums c=`eod) and 0=sums (c=`quote) and 0<sums c=`eod]; 1b}
q).qc.chk[300;.qc.sm[.mdp.hooks,enlist[`steps]!enlist 0 60] .mdp.cmds; seams];
ok 300 tests (seed 7)
label                                       n   pct      req lo       hi     ..
-----------------------------------------------------------------------------..
late                                        186 62           56.38834 67.3082..
eod                                         184 61.33333     55.71235 66.6677..
query_of_a_past_day                         111 37           31.73308 42.5956..
first_trade_of_a_day_before_its_first_quote 96  32           26.97745 37.4777..
late_after_eod                              110 36.66667     31.41406 42.2564..
```

Every seam I could name was reached, at twenty steps and at sixty, and the oracle agreed with the system at each.
One label is missing from both tables: `late_timed_yesterday` never came up, because it cannot — the clock
starts at the open, `late` reaches thirty minutes back, and the close moves the clock to the next day's open.
The generator's design decided what the machine could find. Run 1's verdict: the pieces' properties had already
caught the bugs in the pieces, the assembly's one bug was a name, and the seams the clock could reach hold. So,
as agreed, run 2 adds scope: corrections, and late trades that fall on a day already closed.

### Entry 19: run 2 — corrections, and two lessons about resetting a test system

Step 17 adds the two operations a real feed needs: `bust[id]` removes a trade by the feed's sequence number,
recomputing the bar of its minute from what is left; and a trade timed on a day already closed goes into that
day's partition. On a day already closed *(corrected: a bust of one of today's trades does not)*, both go
through `amend[d;f]`, which reads the closed day's trades back, applies `f`, recomputes
the day's bars, rewrites both splays and remaps the HDB. The machine (step 18) gains a `bust` command over the
trades the model still has, and its `late` trade may be timed eighteen hours back, so one reported in the morning
falls on the day before. The model keeps the busted ids and the oracle leaves them out.

```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/17_amend.q"
q)system"l examples/mdp/steps/18_sm.q"
q).qc.check[.qc.sm[.mdp.hooks] .mdp.cmds; ::];
FAIL falsified after 13 tests, 6 shrinks (28 attempts, seed 7)
qc.run ./2024.01.02/trade/seq. OS reports: No such file or directory
step cmd  arg                                   res model ok
------------------------------------------------------------
0    late 2024.01.01D15:30:00.000000000 `A 1f 1 ::  ::    0 
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 2 757438200000000000 0 0 0 1 1]
```

The first step of a run, a trade timed on the day before the system started, and the HDB read fails on a file that
is not there. The partition it names was written by the *previous* example: the machine's reset emptied the HDB
directory but left the process's mapped tables pointing at the partitions it had removed, and the system's test
for "is there a closed day on disk" — is `trade` defined in the root — was satisfied by a stale map. A test that
resets a mapped HDB must unmap it. Doing that produced the second lesson, which cost more time than the first:
`![`.;();0b;`trade`quote`bar inter key `.]` — and when none of the three is defined, the name list is empty, and
a functional delete with no names deletes *everything* in the namespace. Every global the transcript had defined
vanished, silently, on the first example of every run. Pitfall 43. The reset in step 19 is guarded.

Step 19 also retargets the late trade. Eighteen hours back from the first day's open is the day before the system
started, which nothing ever queries; the label `late_timed_on_an_earlier_day` was high but most of those shots
were wasted. A late trade is now one reported for yesterday, timed anywhere in yesterday's session, and only once
there is a yesterday.

### Entry 20: run 2 passes — and a check that the machine could have seen anything

```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/17_amend.q"
q)system"l examples/mdp/steps/19_sm.q"
q).qc.check[.qc.sm[.mdp.hooks] .mdp.cmds; ::];
ok 100 tests (seed 7)
```
```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/17_amend.q"
q)system"l examples/mdp/steps/19_sm.q"
q)seams:{[tr] c:tr`cmd; .qc.classify[`late_timed_on_an_earlier_day; any {[r] $[`late=r`cmd; ("d"$r[`arg]0)<r[`model]`day; 0b]} each tr]; .qc.classify[`bust_of_a_past_day; any {[r] $[`bust=r`cmd; ("d"$first exec time from r[`model][`t] where seq=r`arg)<r[`model]`day; 0b]} each tr]; .qc.classify[`query_of_a_day_with_a_bust_in_it; any {[r] $[`query=r`cmd; (r[`arg][0]) in "d"$exec time from r[`model][`t] where seq in r[`model]`bust; 0b]} each tr]; .qc.classify[`query_of_a_past_day; any {[r] $[`query=r`cmd; (r[`arg][0])<r[`model]`day; 0b]} each tr]; 1b}
q).qc.chk[300;.qc.sm[.mdp.hooks,enlist[`steps]!enlist 0 60] .mdp.cmds; seams];
ok 300 tests (seed 7)
label                            n   pct      req lo       hi       ok bar    
------------------------------------------------------------------------------
late_timed_on_an_earlier_day     109 36.33333     31.09531 41.91694 1  #######
query_of_a_past_day              114 38           32.69178 43.61166 1  #######
query_of_a_day_with_a_bust_in_it 97  32.33333     27.29245 37.82095 1  ###### 
bust_of_a_past_day               73  24.33333     19.82208 29.49362 1  ####   
```

The system passes with corrections and late days in play, and the seams are exercised: a late trade for a closed
day in a third of the runs, a bust of a closed day's trade in a quarter, queries of days that had a bust in them.
A passing machine is only as good as its oracle, so I broke the system four ways and ran the machine each time:
`rebar` doing nothing after a bust (caught: `qc.inv`, a trade and its bust, two steps); a late trade kept in
memory instead of its day (caught, two steps: a close and the late trade *(corrected: this said one step; a
late trade cannot run before a close)*); the close clearing the quote cache (caught: a quote and a close);
and `amend` rewriting the day's trades but not its bars:

```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/17_amend.q"
q)system"l examples/mdp/steps/19_sm.q"
q).mdp.amend:{[d;f] t:f .mdp.past d; .mdp.save1[d;`trade;t]; system"l ",1_string .mdp.hdb;}
q).qc.check[.qc.sm[.mdp.hooks] .mdp.cmds; ::];
ok 100 tests (seed 7)
```
```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/17_amend.q"
q)system"l examples/mdp/steps/19_sm.q"
q).mdp.amend:{[d;f] t:f .mdp.past d; .mdp.save1[d;`trade;t]; system"l ",1_string .mdp.hdb;}
q).qc.chk[300;.qc.sm[.mdp.hooks,enlist[`steps]!enlist 0 60] .mdp.cmds; ::];
FAIL falsified after 146 tests, 23 shrinks (194 attempts, seed 7)
qc.post qc.eq
path why   a b
--------------
bars count 0 1
0:
  step cmd   arg                                     res                                                            ok
  --------------------------------------------------------------------------------------------------------------------
  0    eod   ::                                      ::                                                             1
  1    late  (2024.01.02D09:30:00.000000000;`A;1f;1) "+`seq`time`sym`px`qty`bid`ask!(,0;,2024.01.02D09:30:00.00..." 1
  2    query (2024.01.02;`A;0;0)                     "`bars`vwap`trades!(+`sym`minute`o`h`l`c`v`n!(`symbol$();`..." 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 4 1 2 757503000000000000 0 0 0 1 1 1 5 1 0 0 0]
```

Missed at a hundred runs of up to twenty steps; found at three hundred of up to sixty, and shrunk to the three
steps that are the bug: close the day, report a trade for it, ask for its bars. The sabotage needs three
particular commands in order with matching arguments, and at the default budget the machine simply did not roll
them. The lesson is about budget, not about the oracle: a machine over a system with days in it wants more steps
and more runs than a stack does, and a `cover` requirement on the seams would have said so before I asked.


### Entry 21: run 2, renames — the machine finds what no piece could

The last nudge from the plan. A rename `old→new` takes effect from a day, through piece 1's `ren` and `canon`.
The contract I chose is the one most kdb shops live with: an event is stored under the name current when it
arrives, so a closed day keeps the names it had and nothing on disk is rewritten; the live state — the quote cache
and the positions — follows the rename at the close that rolls into the effective day, the old name's entry
merging into the new name's, the later quote winning, the positions adding up and averaging their cost. `rename`
is the reference-data update; the new name inherits the instrument's terms (step 20). The machine (step 21) gains
a `rename` command — a name still current tomorrow, to a fresh one, effective tomorrow, at most three per run —
and the feed keeps using any name it has ever seen, so old names arrive after their rename. The model stores each
event under its arrival name, as the contract says, and the oracle's live state uses today's names for everything.

Two harness slips first, again without transcripts: `each` over an empty typed column returns a *general* empty
list, so the oracle's "under today's names" table lost its symbol type on the empty fill log and `.qc.eq` reported
the two empty dictionaries as differing in `order` — the diff was empty, since there was nothing to walk, and
`eq` now says `keytype` in that case; and the quote command's postcondition looked the cache up by the arrival name
where the contract says today's. Then:

```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/17_amend.q"
q)system"l examples/mdp/steps/20_rename.q"
q)system"l examples/mdp/steps/21_sm.q"
q).qc.check[.qc.sm[.mdp.hooks] .mdp.cmds; ::];
ok 100 tests (seed 7)
```

A pass at the default budget — which entry 20 had just taught me not to trust. With the seam labels and the
larger budget:

```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/17_amend.q"
q)system"l examples/mdp/steps/20_rename.q"
q)system"l examples/mdp/steps/21_sm.q"
q)seams:{[tr] c:tr`cmd; .qc.classify[`rename_in_effect; any (c=`eod) and 0<sums c=`rename]; .qc.classify[`old_name_used_after_its_rename; any {[r] $[r[`cmd] in `quote`trade`fill; (r[`arg][1])<>.mdp.canon[r[`arg][1];r[`model]`day]; 0b]} each tr]; .qc.classify[`positions_merged_at_a_close; any {[r] $[`eod=r`cmd; any (exec sym from r[`model]`f)<>.mdp.canon'[exec sym from r[`model]`f;r[`model]`day]; 0b]} each tr]; .qc.classify[`query_of_a_past_day_by_a_renamed_name; any {[r] $[`query=r`cmd; (r[`arg][0]<r[`model]`day) and (r[`arg][1])<>.mdp.canon[r[`arg][1];r[`model]`day]; 0b]} each tr]; 1b}
q).qc.chk[300;.qc.sm[.mdp.hooks,enlist[`steps]!enlist 0 60] .mdp.cmds; seams];
FAIL falsified after 117 tests, 24 shrinks (188 attempts, seed 7)
qc.inv
step cmd    arg                 res ok
--------------------------------------
0    fill   (`A;`buy;1;1f)      ::  1
1    rename (`A;`N0;2024.01.03) ::  1
2    fill   (`N0;`sell;1;2f)    ::  1
3    eod    ::                  ::  1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 3 0 0 0 0 0 1 1 7 0 0 0 1 3 3 1 0 0 0 2 1 4]
label                                 n  pct      req lo        hi       ok bar
-------------------------------------------------------------------------------
rename_in_effect                      18 15.38462     9.958576  23.01153 1  ###
old_name_used_after_its_rename        9  7.692308     4.099471  13.9751  1  #
positions_merged_at_a_close           8  6.837607     3.505129  12.91438 1  #
query_of_a_past_day_by_a_renamed_name 2  1.709402     0.4700284 6.019128 1
```

Four steps. Buy one A at 1. Rename A to N0 from tomorrow. Sell one N0 at 2 — the same instrument, under its new
name, before the rename is in effect, so the system holds a long of A and a short of N0. Close the day, and the
roll merges A into N0: quantities add to zero, the cost of a flat position is zero, the realised PnL is the sum of
the two, which is zero. But the book bought at 1 and sold at 2. The balance-sheet identity — realised plus
unrealised equals cash plus the marked position — is off by one, and `qc.inv` says so without a diff, because
the identity is a single boolean.

This is the bug the whole exercise was for. Every piece is right on its own: positions realise PnL correctly on
every fill sequence (entry 13), renames resolve correctly (entry 3), the close writes and clears correctly (entry
16). The merge is a *new* operation that exists only because renames and positions and the day boundary meet, and
I wrote it the way one writes it first — add the quantities, average the costs — which is right when the two
positions point the same way and wrong when they do not: an opposite position under the new name is a partial
close, and a close realises. No test of piece 4 could see it, because piece 4 has no renames; no test of piece 1
could see it, because piece 1 has no positions. The machine reached it in 117 runs and shrank it to the four steps
that are its definition. Step 22 closes the overlap and realises it, at the two costs, and leaves the larger side
at its own cost.

### Entry 22: the next thing the machine found was the oracle's

```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/17_amend.q"
q)system"l examples/mdp/steps/22_rename.q"
q)system"l examples/mdp/steps/21_sm.q"
q)seams:{[tr] c:tr`cmd; .qc.classify[`rename_in_effect; any (c=`eod) and 0<sums c=`rename]; .qc.classify[`old_name_used_after_its_rename; any {[r] $[r[`cmd] in `quote`trade`fill; (r[`arg][1])<>.mdp.canon[r[`arg][1];r[`model]`day]; 0b]} each tr]; .qc.classify[`positions_merged_at_a_close; any {[r] $[`eod=r`cmd; any (exec sym from r[`model]`f)<>.mdp.canon'[exec sym from r[`model]`f;r[`model]`day]; 0b]} each tr]; .qc.classify[`query_of_a_past_day_by_a_renamed_name; any {[r] $[`query=r`cmd; (r[`arg][0]<r[`model]`day) and (r[`arg][1])<>.mdp.canon[r[`arg][1];r[`model]`day]; 0b]} each tr]; 1b}
q).qc.chk[300;.qc.sm[.mdp.hooks,enlist[`steps]!enlist 0 60] .mdp.cmds; seams];
FAIL falsified after 186 tests, 24 shrinks (190 attempts, seed 7)
qc.post qc.eq
path           why   a b
------------------------
`trades `bid 0 value 1
`trades `ask 0 value 1
0:
  step cmd    arg                                      res                                                            ok
  ----------------------------------------------------------------------------------------------------------------------
  0    quote  (2024.01.02D09:30:00.000000000;`A;1f;0f) ::                                                             1
  1    rename (`A;`N0;2024.01.03)                      ::                                                             1
  2    eod    ::                                       ::                                                             1
  3    trade  (2024.01.03D09:30:00.000000000;`A;1f;1)  "+`seq`time`sym`px`qty`bid`ask!(,1;,2024.01.03D09:30:00.00..." 1
  4    query  (2024.01.03;`N0;0;0)                     "`bars`vwap`trades!(+`sym`minute`o`h`l`c`v`n!(,`N0;`s#,202..." 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 757503000000000000 0 0 0 1 0 0 0 1 7 0 0 0 1 4 1 1 757589400000000000 0 0 0 1 1 1 5 0 3 0 0]
label                                 n  pct      req lo       hi       ok ba..
-----------------------------------------------------------------------------..
rename_in_effect                      48 25.80645     20.05226 32.5398  1  ##..
old_name_used_after_its_rename        29 15.5914      11.08037 21.495   1  ##..
positions_merged_at_a_close           28 15.05376     10.62509 20.89677 1  ##..
query_of_a_past_day_by_a_renamed_name 16 8.602151     5.364144 13.5156  1  # ..
```

With the merge fixed the machine ran further, and at 186 stopped on enrichment: a quote for A on day one, a rename
of A to N0 effective day two, a trade under A on day two *(corrected: this said day two, day three and day
three; the shrinker as it was ended on six steps, with a close in front, and ends on five now)*, canonicalised
to N0 and enriched from the cache —
whose A entry had rolled into N0 at the close, as the contract says — and the oracle's batch join, which joined
by the *stored* names, found no quote for N0 and said null. The system did what the contract says: the cache
follows the rename, so the instrument's last quote is the instrument's last quote whatever it was called. The
oracle was written by the stored names and did not follow. Step 23 has the oracle enrich a day's trades from the
instrument's quotes under that day's names. I record it as what it was: a disagreement the machine found between
two readings of my own contract, settled for the system, five steps long *(corrected: this said four)*, found
because the machine kept going.

### Entry 23: run 2 passes, with renames, and the machine can see

```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/17_amend.q"
q)system"l examples/mdp/steps/22_rename.q"
q)system"l examples/mdp/steps/23_sm.q"
q).qc.check[.qc.sm[.mdp.hooks] .mdp.cmds; ::];
ok 100 tests (seed 7)
```
```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/17_amend.q"
q)system"l examples/mdp/steps/22_rename.q"
q)system"l examples/mdp/steps/23_sm.q"
q)seams:{[tr] c:tr`cmd; .qc.classify[`rename_in_effect; any (c=`eod) and 0<sums c=`rename]; .qc.classify[`old_name_used_after_its_rename; any {[r] $[r[`cmd] in `quote`trade`fill; (r[`arg][1])<>.mdp.canon[r[`arg][1];r[`model]`day]; 0b]} each tr]; .qc.classify[`positions_merged_at_a_close; any {[r] $[`eod=r`cmd; any (exec sym from r[`model]`f)<>.mdp.canon'[exec sym from r[`model]`f;r[`model]`day]; 0b]} each tr]; .qc.classify[`query_of_a_past_day_by_a_renamed_name; any {[r] $[`query=r`cmd; (r[`arg][0]<r[`model]`day) and (r[`arg][1])<>.mdp.canon[r[`arg][1];r[`model]`day]; 0b]} each tr]; 1b}
q).qc.chk[300;.qc.sm[.mdp.hooks,enlist[`steps]!enlist 0 60] .mdp.cmds; seams];
ok 300 tests (seed 7)
label                                 n   pct      req lo       hi       ok b..
-----------------------------------------------------------------------------..
rename_in_effect                      108 36           30.77684 41.57717 1  #..
old_name_used_after_its_rename        75  25           20.43691 30.19526 1  #..
positions_merged_at_a_close           69  23           18.59711 28.08564 1  #..
query_of_a_past_day_by_a_renamed_name 40  13.33333     9.946588 17.64726 1  #..
```

Three sabotages of the rename path, each caught at the same budget and shrunk to its definition — a merge that
keeps only the old name's position (a fill under each name, then the close); a roll that forgets the quote cache
(a quote, a rename, a close); a cache merge that keeps the older quote (two renames chained, a quote under the
first name and one under the second, and the close that merges them) *(corrected: this said "two renames
chained across two days, a quote under each end of the chain"; the shrinker as it was ended on six steps
there, and ends on five, in one day, now)*:

```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/17_amend.q"
q)system"l examples/mdp/steps/22_rename.q"
q)system"l examples/mdp/steps/23_sm.q"
q).mdp.mergepos:{[o;n] a:.mdp.pos o; .mdp.pos[n]:`qty`cost`real!(a`qty;a`cost;a`real); .mdp.pos::delete from .mdp.pos where sym=o;}
q).qc.chk[300;.qc.sm[.mdp.hooks,enlist[`steps]!enlist 0 60] .mdp.cmds; ::];
FAIL falsified after 111 tests, 21 shrinks (171 attempts, seed 7)
qc.inv qc.eq
path why   a b
--------------
N0   value 1 2
0:
  step cmd    arg                 res ok
  --------------------------------------
  0    fill   (`A;`buy;1;1f)      ::  1
  1    rename (`A;`N0;2024.01.03) ::  1
  2    fill   (`N0;`buy;1;1f)     ::  1
  3    eod    ::                  ::  1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 3 0 0 0 0 0 1 1 7 0 0 0 1 3 3 0 0 0 0 1 1 4]
```
```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/17_amend.q"
q)system"l examples/mdp/steps/22_rename.q"
q)system"l examples/mdp/steps/23_sm.q"
q).mdp.roll:{[] ks:exec sym from .mdp.pos; o:ks where ks<>.mdp.canon'[ks;.mdp.today]; .mdp.mergepos'[o;.mdp.canon'[o;.mdp.today]];}
q).qc.chk[300;.qc.sm[.mdp.hooks,enlist[`steps]!enlist 0 60] .mdp.cmds; ::];
FAIL falsified after 66 tests, 17 shrinks (93 attempts, seed 7)
qc.inv qc.eq
path   why   a b
-----------------
`sym 0 value A N0
0:
  step cmd    arg                                      res ok
  -----------------------------------------------------------
  0    quote  (2024.01.02D09:30:00.000000000;`A;1f;0f) ::  1
  1    rename (`A;`N0;2024.01.03)                      ::  1
  2    eod    ::                                       ::  1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 757503000000000000 0 0 0 1 0 0 0 1 7 0 0 0 1 4]
```
```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/17_amend.q"
q)system"l examples/mdp/steps/22_rename.q"
q)system"l examples/mdp/steps/23_sm.q"
q).mdp.mergeq:{[o;n] a:.mdp.qcache o; b:.mdp.qcache n; if[null b`seq; .mdp.qcache[n]:a]; .mdp.qcache::delete from .mdp.qcache where sym=o;}
q).qc.chk[300;.qc.sm[.mdp.hooks,enlist[`steps]!enlist 0 60] .mdp.cmds; ::];
FAIL falsified after 91 tests, 32 shrinks (221 attempts, seed 7)
qc.inv qc.eq
path   why   a b
----------------
`ask 0 value 1 2
0:
  step cmd    arg                                       res ok
  ------------------------------------------------------------
  0    quote  (2024.01.02D09:30:00.000000000;`A;1f;0f)  ::  1
  1    rename (`A;`N0;2024.01.03)                       ::  1
  2    quote  (2024.01.02D09:30:00.000000000;`N0;1f;1f) ::  1
  3    rename (`N0;`N1;2024.01.03)                      ::  1
  4    eod    ::                                        ::  1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 757503000000000000 0 0 0 1 0 0 0 1 7 0 0 0 1 0 757503000000000000 3 0 0 1 0 0 1 1 7 2 0 0 1 4]
```

Seeds 8 and 9 were run at the same budget and passed; a doctested log cannot show a claim it does not execute, so
take that as a note, not evidence.

### Entry 24: the suite under random seeds — the oracle, once more

The final system runs as `examples/mdp/run.q`: the surviving properties and the machine under `.qc.main`, three
hundred tests each, seeded from the clock as a CI run would be. Its first run failed twice. The tick property
(entries 1–2) fell to a float: a price near a thousand rounded to a hundredth is within half a tick by
`0.5000000000000004`; the property gains a tolerance. And the machine, at a seed that seed 7 and its neighbours
had not been:
```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/17_amend.q"
q)system"l examples/mdp/steps/22_rename.q"
q)system"l examples/mdp/steps/23_sm.q"
q).qc.chk[`n`seed!(300;826650575i);.qc.sm[.mdp.hooks,enlist[`steps]!enlist 0 60] .mdp.cmds; ::];
FAIL falsified after 240 tests, 28 shrinks (371 attempts, seed 826650575)
qc.post qc.eq
path           why   a b
------------------------
`trades `bid 0 value 1
`trades `ask 0 value 1
0:
  step cmd    arg                                      res                                                            ok
  ----------------------------------------------------------------------------------------------------------------------
  0    quote  (2024.01.02D09:30:00.000000000;`A;1f;0f) ::                                                             1
  1    rename (`A;`N0;2024.01.03)                      ::                                                             1
  2    eod    ::                                       ::                                                             1
  3    late   (2024.01.02D09:30:00.000000000;`A;1f;1)  "+`seq`time`sym`px`qty`bid`ask!(,1;,2024.01.02D09:30:00.00..." 1
  4    query  (2024.01.02;`N0;0;0)                     "`bars`vwap`trades!(+`sym`minute`o`h`l`c`v`n!(,`N0;`s#,202..." 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 757503000000000000 0 0 0 1 0 0 0 1 7 0 0 0 1 4 1 2 757503000000000000 0 0 0 1 1 1 5 1 3 0 0]
```

A quote under A; a rename of A to N0 from tomorrow; the close, which rolls the cache's A into N0; a late trade
under A for yesterday, canonicalised to N0, enriched from the rolled cache — and the oracle, enriching yesterday's
trades under *yesterday's* names (step 23), where A was still A, finds no quote for N0. The cache enriched that
trade with the names it had when the trade arrived; the oracle used the names of the day the trade was timed. For
a trade that arrives on its own day the two are the same, which is why three hundred runs at three seeds had
agreed. Step 24 gives the model's trades their arrival day and enriches each under that day's names:
```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/17_amend.q"
q)system"l examples/mdp/steps/22_rename.q"
q)system"l examples/mdp/steps/24_sm.q"
q).qc.chk[`n`seed!(300;826650575i);.qc.sm[.mdp.hooks,enlist[`steps]!enlist 0 60] .mdp.cmds; ::];
ok 300 tests (seed 826650575)
```

Third reading of the oracle, and I believe the right one: names matter to enrichment only as the cache saw them.
Every disagreement between the system and the oracle in run 2 was over what a rename means, and each one the
machine found was a case I had not written down — which is the other thing a state machine is for.

### Entry 25: after the review — what a reader found that no test had

`docs/REVIEW.md` read the finished system and found things the properties and the machine could not, because none of
them is a *wrong answer*: a trade timed after today was enriched and returned but stored nowhere; a rename of an
unknown name inserted an all-null instrument; a fill for an unknown instrument booked a position with a null
multiplier; "is this day on disk" was answered by "does a table called `trade` exist", the test that the stale
map of entry 19 had fooled; the start day and the session hours were written down in four files; the machine made
a second HDB directory and left both behind. Step 25 is the answer to all of them, in one file, and the machine's
postconditions were strengthened at the same time (step 25 of the machine): a fill must move the position by its
signed quantity, a trade must carry bid *and* ask and a price at the tick, a busted id must be gone from wherever
its day lives, a rename must be in `ren` with the new name inheriting the instrument, and the invariant checks
yesterday on disk as well as today in memory.

```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/17_amend.q"
q)system"l examples/mdp/steps/22_rename.q"
q)system"l examples/mdp/steps/25_final.q"
q)system"l examples/mdp/steps/25_sm.q"
q).mdp.init[]
q).mdp.rename[`Q;`N0;.mdp.today]
q).mdp.upd[`fill; ([]sym:enlist `Q; side:enlist `buy; qty:enlist 1; px:enlist 1f)]
q).mdp.upd[`trade; ([]time:enlist .mdp.opn[.mdp.today+1]; sym:enlist `A; px:enlist 1f; qty:enlist 1)]
q).qc.chk[300;.qc.sm[.mdp.hooks,enlist[`steps]!enlist 0 60] .mdp.cmds; ::];
'mdp: rename: unknown name Q
'mdp: fill for an unknown instrument: Q
'mdp: a trade timed after today: +`seq`time`sym`px`qty`bid`ask!(,0;,2024.01.03D09:30:00.000000000;,`A;,1f;,1;,..
ok 300 tests (seed 7)
```

Two facts came out of writing it. Restoring the working directory after `\l hdb` — the fix pitfall 44 first
suggested — breaks the HDB: the mapped tables read their files relative to that directory, so it has to stay, and
everything else is loaded by absolute path instead (`mdp.q` now has a root). And a postcondition's parameter must
not be called `i`: inside a `select`, `i` is the row index, and `where seq=i` compares the sequence number with
the row number (pitfall 4's implicit column). The stronger machine passes at the review's budget; it found nothing
the weaker one had missed, which is what one hopes for and cannot know without asking.

## Closing: what happened, and what qcheck did

**The tally.** Twelve findings — nine in the system, one in the assembly's one line of q-SQL, two in the oracle:

| where | found by | what |
|---|---|---|
| piece 1 | writing the generator | `canon` loops on a rename cycle (entry 3) |
| piece 2 | property | the as-of tie: a quote and a trade at one timestamp (entry 6) |
| piece 2 | property | `stamp` appended `seq` where the tables declare it first (entry 7) |
| piece 2 | property | `aj` brought the quote's `time` across (entry 7) |
| piece 4 | property | a namespace name inside q-SQL (entry 11) |
| piece 4 | property | precedence in the average cost (entry 12) |
| piece 5 | property | `exec` over a partitioned table (entry 14) |
| piece 5 | property | enumerated symbols from disk (entry 15) |
| assembly | state machine | a namespace name inside q-SQL, again (entry 17) |
| renames × positions × the close | state machine | merging opposite positions loses the realised PnL (entry 21) |
| renames × enrichment | state machine | the oracle joined by stored names (entry 22) |
| renames × late trades × enrichment | state machine | the oracle used the trade's day's names, not its arrival day's (entry 24) |

Piece 3 had none. Eight of the twelve were found in a single piece: one while writing a generator (entry 3), and
seven by a property — three on a one- or two-row example (entries 6, 7 and 12), four on an empty input, before
any row existed (entries 7, 11, 14 and 15) *(corrected: this said all eight fell to a property, six on a one- or
two-row example and two on the empty day)*. The one that mattered most fell to the state machine,
on a four-step trace; no existing piece's property could have seen it (a unit property over `mergepos` with two
opposite positions would have — but nobody had written one, because the merge did not exist until renames met
positions). The two in the oracle were readings of my own contract that the machine made me write down. Beside
these: eight mistakes in my test code (a lambda's locals, a mistyped comparison, a keyword as a parameter four
times — `vs` twice, `inv`, `asof` — a lookup by the wrong key, a float tolerance), two in the harness's reset (a
stale map; a delete of everything), one generator that could not reach the seam it was for, and one that wasted
its shots on a day nobody queried. The test code is code.

**What qcheck did.** The minimal examples were the diagnosis: a one-row fill log, two trades in one minute, a
quote and a trade at one nanosecond, four commands. Reading the failing input *was* understanding the bug, every
time. The typed empty table (entry 4) mattered more than it looks: the minimal example of every table property is
the empty table, so an untyped one would have made every table property fail first for the wrong reason. The
state machine's trace, shrunk, is the reproduction a colleague would want; its `inv` hook carried the one property
(the balance-sheet identity) that holds for any fill log under any names and any marks, and that is the property
that saw the merge. `classify` told me what the runs had actually exercised, which is how run 1's clock design was
caught and how run 2's budget was set.

**What the machine cannot see.** Its oracle borrows from the system: `enrichb` for the batch enrichment,
`barsb` for the batch bars, `canon` for names, `round` and the lot sizes from `inst`. A bug in any of those would
be mirrored on both sides and pass. That is defensible only because the pieces' own properties test each of them
against something else (the incremental enrichment against the batch, the fold against the select, `canon`
against its own idempotence) — but those properties run with no renames, no busts and no day boundary. Some
postconditions are weak too: `fill` asserts nothing (the invariant checks positions after every step, which is
why it can afford to); `bust` of a closed day's trade checks only that the id is not in memory, which it never
was, so a broken partition rewrite is caught only by a later `query` — the reason entry 20 needed three hundred
runs of sixty steps; `trade` compares the bid only; and the invariant covers today, never the disk. The machine
tests the seams between incremental and batch, live and closed; it does not test the batch definitions themselves.

**What qcheck did not do, and what I changed.** It did not tell me the budget: three-command conjunctions need
more than a hundred runs of twenty steps, and I learned that from a sabotage, not from a report (entry 20). A
`cover` requirement on the seams would have. It did not, at first, show the command that raised — an error in
`run` or `post` noted the trace *before* the failing step; it does now (entry 17). Its trace print buried the
steps under a model that was a dict of tables; a model that holds tables is now left out of the print. `eq` said
`order` for two empty dictionaries that differed in key type; it now says `keytype` (entry 21). And `tab`'s empty
table is now typed (entry 4). Four library changes, each from a moment the report was not the diagnosis.

**The q along the way**, for a practitioner's collection: `vs`, `inv` and `asof` are keywords (as `from`,
`value`, `any` were before them); q-SQL inside a namespaced lambda resolves names in the root (pitfall 26, met
twice); a keyed table indexed by a list of keys and a column is a `length` error; `exec` over a partitioned table
is `nyi`; `\l dir` makes `dir` the working directory; a functional delete with no names deletes every global
(pitfall 43); `each` over an empty typed list returns a general one (pitfall 45); and `c0*a+b` is `c0*(a+b)`.

**The final system** is `examples/mdp/mdp.q` (the last step of each piece, and step 25 after the review), its
properties `props.q`, the machine `sm.q` (step 25 of the machine), and `run.q`, which runs both under `.qc.main`
and is run by the test suite; the steps stay, because every
transcript above is executed against them by `t/doctest.q`, and a buggy step that stopped failing as logged would
fail the suite.

