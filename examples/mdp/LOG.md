# Building a market data pipeline with qcheck — the log

A worked example, kept as it happened. Five pieces — reference data, quotes, bars, positions, end of day — are
written one at a time, each with properties as it is written, then assembled and driven by a state machine. Every
code change is a file under `steps/`, so every transcript below still runs: `t/doctest.q` executes each `q)` block
in a fresh q from the repository root (seed 7, `\c 25 80`) and requires the output shown. Nothing here is planted;
a bug appears in the log when it appeared in the work.

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
FAIL falsified after 0 tests, 0 shrinks (12 attempts, seed 7)
x: (`A;0f)
qc: property returned {[s;px] r:.mdp.round[s;px]; r=.mdp.round[s;r]}[(`A;0f)]
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 1 0 0 0 0 0 0 0 0 0 0]
q).qc.check[.mdp.g.ref; {[s;px] .5>=abs[px-.mdp.round[s;px]]%.mdp.inst[s;`tick]}];
FAIL falsified after 0 tests, 0 shrinks (12 attempts, seed 7)
x: (`A;0f)
qc: property returned {[s;px] .5>=abs[px-.mdp.round[s;px]]%.mdp.inst[s;`tick]}[(`A;0f)]
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 1 0 0 0 0 0 0 0 0 0 0]
q).qc.check[(.mdp.g.ref; .qc.int 0 1000); {[sp;q] l:.mdp.lots[sp 0;q]; (l<=q) and 0=l mod .mdp.inst[sp 0;`lot]}];
ok 100 tests (seed 7)
```

Not a bug in the piece: a mistake in how I wrote the properties. The spec `g.ref` is a lambda that *returns* a
pair, so the property receives the pair as one argument (`prop @ x`), and a two-parameter property applied to one
argument is a projection — which is what "property returned {…}[(`A;0f)]" is telling me, on the minimal input.
A general-list spec (`(g.ref; .qc.int 0 1000)`) is applied with `.`, which is why the third check worked. The
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

The minimal example is a stream with no events. Enriching no trades from the cache gives float `bid` and `ask`
columns; `aj` over a quote table with no rows gives general ones — because the generated empty table had general
columns. That was qcheck's doing: `tab`'s empty table was untyped (its design said so, as a limitation), and the
minimal example is *always* the empty table, so every property over a generated table met it first. I fixed the
library rather than the property: `tab` now probes one minimal row of its column generators, outside the example,
and types its empty columns from what they would have drawn (commit `a9ea097`; the report above is quoted, not
executed, because the library that produced it is gone). A dependent column sees the columns before it in the
probe, which is what let `ask` come out typed. Found on the way, in the fix itself: a parameter named `vs` — a
keyword — made an `each` apply to the operator instead of the list; `t/names.q` now refuses reserved words as
parameters, which it had never checked.

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
FAIL falsified after 2 tests, 11 shrinks (63 attempts, seed 7)
x:
  time                          kind  sym bid ask px qty
  ------------------------------------------------------
  2024.01.02D09:30:00.000000000 trade A   1   1   1  1  
qc.eq
path why   a b
--------------
     count 0 1
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 1 0 0 0 0 0 0 1 757503000000000000 1 0 0 0 1 0 0 1 0 0 1 0 0]
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
FAIL falsified after 19 tests, 19 shrinks (90 attempts, seed 7)
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
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 1 0 0 0 0 0 0 1 757503000000000000 1 0 0 0 1 0 0 1 0 0 1 0 1 0 0 0 0 0 1 0 0 1 0 0 1 0 0]
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
FAIL falsified after 0 tests, 0 shrinks (12 attempts, seed 7)
x:
  time kind sym bid ask px qty
  ----------------------------
qc.eq
path why   a                           b                          
------------------------------------------------------------------
     order time sym px qty seq bid ask seq time sym px qty bid ask
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 1 0 0 0 0 0 0 0]
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
FAIL falsified after 6 tests, 37 shrinks (124 attempts, seed 7)
x:
  time                          kind  sym bid ask px qty
  ------------------------------------------------------
  2024.01.02D09:30:00.000000000 quote A   1   1   1  1  
  2024.01.02D09:30:00.000000001 trade A   1   1   1  1  
qc.eq
path    why   a                             b                            
-------------------------------------------------------------------------
`time 0 value 2024.01.02D09:30:00.000000001 2024.01.02D09:30:00.000000000
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 1 0 0 0 0 0 0 1 757503000000000000 0 0 0 0 1 0 0 1 0 0 1 0 1 1 1 0 0 0 1 0 0 1 0 0 1 0 0]
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
FAIL falsified after 4 tests, 25 shrinks (176 attempts, seed 7)
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
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 1 1 0 0 0 0 1 1 0 0 0 0 0 0 1 757503000000000000 0 0 0 1 0 1 0 1 0 0 1 0 0]
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
FAIL falsified after 0 tests, 0 shrinks (13 attempts, seed 7)
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
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 1 0 0 0 0 0 0 0 0 0 1]
q)cash:{[f] exec sum .mdp.inst[sym;`mult]*qty*px*-1 1 `buy`sell?side from f}
q).qc.check[.mdp.g.fills; {f:x 0; mk:x 1; .mdp.pos::0#.mdp.pos; .mdp.onfill f; lhs:(exec sum real from .mdp.pos)+.mdp.unreal mk; rhs:cash[f]+exec sum .mdp.inst[sym;`mult]*qty*mk sym from .mdp.pos; 1e-6>abs lhs-rhs}];
FAIL falsified after 0 tests, 0 shrinks (13 attempts, seed 7)
x:
  0:
    sym side qty px
    ---------------
  1:
    A: 1f
inst
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 1 0 0 0 0 0 0 0 0 0 1]
```

Both fell at the empty fill log, the minimal example, before a single fill was booked. The first is my property:
one side is a vector (type 7), the other a dictionary (99); with no fills they cannot be equal, and with fills they
would only agree by luck of order. Both sides become dictionaries sorted by key. The second is a q lesson that
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
FAIL falsified after 2 tests, 9 shrinks (49 attempts, seed 7)
x:
  0:
    sym side qty px
    ---------------
    A   buy  1   1 
  1:
    A: 1f
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 1 0 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0 1]
q).qc.check[.mdp.g.fills; {f:x 0; .mdp.pos::0#.mdp.pos; .mdp.onfill f; p:0!select from .mdp.pos where qty<>0; r:select mn:min px,mx:max px by sym from f; k:([]sym:p`sym); all (p[`cost]>=(r[k]`mn)-1e-9) and p[`cost]<=1e-9+r[k]`mx}];
FAIL falsified after 2 tests, 9 shrinks (49 attempts, seed 7)
x:
  0:
    sym side qty px
    ---------------
    A   buy  1   1 
  1:
    A: 1f
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 1 0 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0 1]
q).qc.check[(.qc.elem `A`B; .qc.elem 1 10 100; .qc.flt 1 100); {[s;q;p] .mdp.inst::([sym:`A`B] tick:0.01 0.01; lot:1 1; mult:1 10); .mdp.pos::0#.mdp.pos; .mdp.onfill ([]sym:s,s; side:`buy`sell; qty:q,q; px:p,p); (0=.mdp.pos[s;`qty]) and 0=.mdp.pos[s;`real]}];
FAIL falsified after 0 tests, 0 shrinks (2 attempts, seed 7)
s: `A
q: 1
p: 1f
rerun: .qc.again[]  or  .qc.recheck[spec;prop;0 0 0 0 1]
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
FAIL falsified after 0 tests, 0 shrinks (13 attempts, seed 7)
ev:
  time kind sym bid ask px qty
  ----------------------------
a: 2024.01.02D09:30:00.000000000
b: 2024.01.02D09:30:00.000000000
nyi
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 1 0 0 0 0 0 0 0 757503000000000000 757503000000000000]
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
FAIL falsified after 0 tests, 0 shrinks (13 attempts, seed 7)
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
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 1 0 0 0 0 0 0 0 757503000000000000 757503000000000000]
```

Still the empty day, and still not a row in sight: the disk answers carry enumerated symbols (type 20) where
memory's are plain (11). Equal to look at, different to compare — and different to a client that joins the answer
to something of its own. Since the queries promise one shape for any date, step 13 has the disk branch return
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
