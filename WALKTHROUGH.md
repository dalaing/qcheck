# Building a market data pipeline with qcheck

`README.md` explains property-based testing on lists and a stack, and `COOKBOOK.md` on problems of a page each.
This is the long example: a small market data system, the kind a kdb+ programmer has built before, written a
piece at a time and tested with qcheck as it was written. There are five pieces, then the assembly, then a stateful
test of the whole.

It is told in the order it happened, wrong turns included. Several of the failures below are mistakes in the
tests and not in the system, and one of the longest stretches ends with the discovery that the test had passed
a system known to be broken. That is what using a property-based testing library is like, and it is more use to see
it than to see a tidy result.

You need q and `README.md`, its section on stateful testing included. Nothing here depends on knowing the library
well.

**The code.** Every change made along the way is kept as a file under `examples/mdp/steps/`, numbered in the
order of the changes: `01_ref.q` is reference data as first written and `02_ref.q` as corrected. The versions
with bugs are kept on purpose, so that every session below still runs and still fails as shown. The finished
system is `examples/mdp/mdp.q`, its properties `examples/mdp/props.q`, its stateful test `examples/mdp/sm.q`, and
`q examples/mdp/run.q` runs them all. `examples/mdp/LOG.md` is the log that was kept during the work, entry by
entry; this document is the same story told for a reader.

**The blocks.** A block that shows a `q)` prompt is a session of its own, run from the repository root with
`qc.q` loaded and ``.qc.cfg[`db`seed]:(`;7i)``; what follows each line is what q prints. The test suite runs
every one and requires the output shown. A block that begins with a comment naming a file is an excerpt of that
file, and the suite checks that too.

## The system

| piece | what it does |
|---|---|
| 1. reference data | instruments with their tick and lot sizes; renames of symbols, effective from a date |
| 2. quotes | keeps the last quote of each symbol, and enriches each trade with the quote prevailing when it arrived |
| 3. bars | open, high, low, close and volume for each symbol and minute, kept up to date trade by trade |
| 4. positions | signed quantity, average cost and realised PnL for each symbol, from fills |
| 5. end of day | writes the day to a date partition, clears the day's tables, answers queries for any date |

Each piece has its state in a table in the `.mdp` namespace and a function or two that update it.

## Piece 1: reference data

### A failure that was not a bug

An instrument table keyed by symbol, and two helpers: round a price to the instrument's tick, and round a
quantity down to whole lots.

```q
/ examples/mdp/steps/01_ref.q
inst:([sym:`symbol$()] tick:`float$(); lot:`long$(); mult:`long$())     / price increment, lot size, contract multiplier
round:{[s;px] t:inst[s;`tick]; t*floor 0.5+px%t}                          / px to the nearest tick of s
lots:{[s;q] l:inst[s;`lot]; l*q div l}                                    / q rounded down to whole lots of s
```

The generators draw an instrument table of one to five rows, with distinct symbols because `ktab` keys are
distinct. `g.ref` is a generator written as a function: it draws the table, installs it as the piece's table,
which is how the piece will find it, and then draws a symbol *from that table* and a price.

```q
/ examples/mdp/steps/01_gen.q
g.inst:.qc.ktab[`sym;1 5] `sym`tick`lot`mult!(.qc.symc["ABCD";1 3]; .qc.elem 0.01 0.05 0.25 1f; .qc.elem 1 10 100; .qc.elem 1 10 50)
g.px:.qc.flt 0 1000
g.ref:{[d] inst::.qc.draw g.inst; (.qc.draw .qc.elem exec sym from inst; .qc.draw g.px)}   / sets the piece's table, gives (sym; px)
```

The first two rules: rounding a rounded price changes nothing, and rounding never moves a price by more than
half a tick.

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
```

Both fail on the simplest input there is, the symbol `A` at a price of 0, and rounding 0 is not hard. The report
says what happened: `property returned {…}[(`A;0f)]`. The property returned a function. `g.ref` is one
generator that *returns* a pair, so the property is given the pair as one argument, and a function of two
parameters applied to one argument is a projection, which is neither true nor false.

Had the generator been a list of two generators, `(g1;g2)`, the property would have been given two arguments.
The fix is to the properties, which take the pair and take it apart:

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

The third rule is about lots: the rounded quantity is no more than the quantity and is a whole number of lots.
Its generator is a list of two, the pair from `g.ref` and a quantity, so its property has two parameters.

The first lesson came before the first bug: a failure on the simplest input is as likely to be a mistake in the
test as in the code, and the report usually says which.

### A bug found by writing the generator

Symbols get renamed. A rename table holds the old name, the new name and the date it takes effect, and
`canon[s;d]` is the name that `s` goes by on date `d`. As first written, it follows renames for as long as one
applies:

```q
/ examples/mdp/steps/01_ref.q
canon:{[s;d] while[count r:exec new from ren where old=s,eff<=d; s:first r]; s}   / the name s goes by on date d
```

The generator of renames had to be decided next. The old name is an instrument. The new name is either a fresh
symbol or *another instrument*, because that is what happens: a name is retired and reused, or a rename is
reverted.

```q
/ examples/mdp/steps/02_gen.q
g.ren:{[d] inst::.qc.draw g.inst; s:exec sym from inst; ren::.qc.draw .qc.tabr[0 4] `old`new`eff!(.qc.elem s; .qc.one (.qc.elem s;.qc.symc["XYZ";1 2]); g.day); (.qc.draw .qc.elem s; .qc.draw g.day)}
```

A reversion is `A` to `B` and then `B` to `A`, which is a cycle, and a loop that follows renames until none
applies never leaves a cycle. Nobody had noticed that in `canon`. It was noticed while writing the generator, at
the moment of deciding that a new name could be an old one.

The property was run against the first `canon` anyway, and the run hung. There is no report to show, and that
is worth knowing about the tool: a hung example is the one outcome a property-based test cannot report, because
q cannot interrupt an example from inside. The evidence is a process that prints nothing and has to be killed.

The corrected `canon` follows the *latest* rename in effect (two renames of one name on different dates were
possible too, and the first version took whichever row came first) and stops when a name comes round again:

```q
/ examples/mdp/steps/02_ref.q
nxt:{[s;d] r:exec new from `eff xasc select from ren where old=s,eff<=d; $[count r; last r; s]}   / the name s became on d, if any
canon:{[s;d] seen:(); while[$[s in seen; 0b; not s~n:nxt[s;d]]; seen,:s; s:n]; s}   / follow renames until none applies or a name repeats
```

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

Two rules: the canonical name of a canonical name is itself, and a canonical name is either the name asked
about or one that some rename in effect leads to. Neither says what the right name *is*. Saying that would mean
writing `canon` a second time, and the rules that are easy to state already pin it down a good deal.

Piece 1: one bug, found by thinking about what the inputs could be.

## Piece 2: quotes and enrichment

Quotes arrive, and the piece keeps the day's quotes and the last quote of each symbol. A trade is enriched with
the prevailing bid and ask in one of two ways: as it arrives, from the cache, or afterwards in a batch, with an
as-of join over the day's quotes.

```q
/ examples/mdp/steps/03_quotes.q
onquote:{[q] quote,:q; qcache::qcache upsert `sym xkey q}                        / several rows: the last per sym wins
enrich1:{[t] t lj `sym xkey select sym,bid,ask from qcache}                       / the prevailing quote now
enrichb:{[t;q] aj[`sym`time;t;`sym`time xasc q]}                                  / the prevailing quote as of each trade's time
```

Two ways to compute one thing is a rule waiting to be written: over a day of quotes and trades, **the two
agree**. Each is the other's oracle.

The generator is one table of events in time order. `mono` gives timestamps that start in the session and move
on by up to ten seconds a row. Each event is a quote or a trade for one of the instruments, and carries the
fields of both kinds, of which the property uses the ones that apply. The ask is drawn with `dep`, from a range
that starts at the row's bid, so that no quote is crossed.

```q
/ examples/mdp/steps/04_gen.q
g.ev:{[s] .qc.tabr[0 40] `time`kind`sym`bid`ask`px`qty!(.qc.mono[.qc.ts[open;close];.qc.int (0;"j"$0D00:00:10)]; .qc.elem `quote`trade; .qc.elem s;
  .qc.flt 1 100; .qc.dep {[r] .qc.flt (r`bid;100)}; .qc.flt 1 100; .qc.elem 1 10 100)}
g.stream:{[d] inst::.qc.draw g.inst; .qc.draw g.ev exec sym from inst}
```

### A bug in the test

The property has work to do before it can compare anything. It replays the stream in order, feeding quotes to
the cache and enriching each trade as it comes, and collects the enriched trades:

```q
/ examples/mdp/walk.q
replay0:{[ev] .mdp.quote::0#.mdp.quote; .mdp.qcache::0#.mdp.qcache; out:0#.mdp.enrich1 select time,sym,px,qty from ev;
  {[e] $[`quote=e`kind; .mdp.onquote enlist `time`sym`bid`ask#e; out,:.mdp.enrich1 enlist `time`sym`px`qty#e]} each ev;
  out}
agree0:{[rp;ev] inc:rp ev;
  bat:.mdp.enrichb[select time,sym,px,qty from ev where kind=`trade; select time,sym,bid,ask from ev where kind=`quote];
  .qc.eq[inc;bat]}
```

```q
q)system"l examples/mdp/steps/03_quotes.q"
q)system"l examples/mdp/steps/03_gen.q"
q)system"l examples/mdp/walk.q"
q)5#.qc.draw .mdp.g.stream
time                          kind  sym bid      ask      px       qty
----------------------------------------------------------------------
2024.01.02D09:30:00.008208256 quote ACC 10       54.78843 45.52337 100
2024.01.02D09:30:00.008213338 trade ACC 24.90625 32.5991  73.05742 10
2024.01.02D09:30:01.038894268 quote ABC 68.21192 97.08473 13.25    10
2024.01.02D09:30:01.039131004 quote ACC 43.85249 65.85082 17.74133 1
2024.01.02D09:30:01.125495236 trade ACC 60.82281 68.5     91.41703 1
q).qc.check[.mdp.g.stream; agree0[replay0]];
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

One trade and no quotes, and the two sides differ in their `count`: the incremental side has no rows and the
batch side has one. No row was lost by the piece. `replay0` lost it. The inner function appends to `out`, and a
function in q does not see the locals of the function around it, so `out,:` made a *global* called `out` and
appended to that, and `replay0` returned its own `out`, still empty.

The smallest stream that has a trade in it found a bug in six lines of test code. The replay becomes a fold,
which passes the enriched trades along instead of reaching for them. (It also sets a sequence number back to 0,
which is for what comes two sections on.)

```q
/ examples/mdp/walk.q
replay:{[ev] .mdp.seq::0; .mdp.quote::0#.mdp.quote; .mdp.qcache::0#.mdp.qcache;
  {[o;e] $[`quote=e`kind; [.mdp.onquote enlist `time`sym`bid`ask#e; o]; o,.mdp.enrich1 enlist `time`sym`px`qty#e]}/[0#.mdp.enrich1 select time,sym,px,qty from ev;ev]}
```

### The tie

```q
q)system"l examples/mdp/steps/03_quotes.q"
q)system"l examples/mdp/steps/03_gen.q"
q)system"l examples/mdp/walk.q"
q).qc.check[.mdp.g.stream; agree0[replay]];
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

A trade and a quote with the same timestamp, the trade first. When the trade arrived there was no quote, so the
incremental side has nulls (the blanks under `a`). The batch join is inclusive on time, so it gives the trade
the quote that arrived a moment *after* it.

This is the as-of tie that every kdb+ shop meets sooner or later: time alone does not say what was known when.
Nobody set out to test for it. The generator's timestamps can repeat, because a delta of zero is in range, and
shrinking pushes deltas towards zero, so that if a tie can break a rule, a tie is what the report will show.

The piece's answer is for the feed to stamp every event with a sequence number as it arrives, and for the batch
join to be as of the sequence number:

```q
/ examples/mdp/steps/04_quotes.q
stamp:{[t] seq::seq+count t; update seq:.mdp.seq-reverse 1+til count t from t}   / (q-sql resolves names in the root: .mdp.seq)
enrichb:{[t;q] aj[`sym`seq;t;`sym`seq xasc q]}                                    / the prevailing quote as of each trade's arrival
```

The rule changes with it. The batch side now joins the stamped trades to the stamped quotes:

```q
/ examples/mdp/walk.q
agree:{[ev] inc:replay ev; bat:.mdp.enrichb[select seq,time,sym,px,qty from inc; .mdp.quote]; .qc.eq[inc;bat]}
```

### Two more, from the same rule

```q
q)system"l examples/mdp/steps/04_quotes.q"
q)system"l examples/mdp/steps/04_gen.q"
q)system"l examples/mdp/walk.q"
q).qc.check[.mdp.g.stream; agree];
FAIL falsified after 0 tests, 0 shrinks (15 attempts, seed 7)
x:
  time kind sym bid ask px qty
  ----------------------------
qc.eq
path why   a                           b
------------------------------------------------------------------
     order time sym px qty seq bid ask seq time sym px qty bid ask
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 0 0 0 0 0 0 0]
```

This fails on the empty stream, and `why` is `order`: the two tables have the same columns in a different
order. `stamp` added `seq` at the end, and the tables declare it first. With no rows at all there is still a
difference to find, since an empty table has its columns. Step 05 puts `seq` first, and the rule gets further:

```q
q)system"l examples/mdp/steps/05_quotes.q"
q)system"l examples/mdp/steps/04_gen.q"
q)system"l examples/mdp/walk.q"
q).qc.check[.mdp.g.stream; agree];
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
```

A quote, and a trade one nanosecond later, and the enriched trade carries the *quote's* time. `aj` brings every
column of the right-hand table across, and the quote table has a `time` of its own. Joining on `time` had hidden
this, since the join column is kept from the left, and the move to `seq` uncovered it. The counterexample puts
the two times one nanosecond apart, the smallest difference that shows. Step 06 joins only the columns that the
enrichment is for:

```q
/ examples/mdp/steps/06_quotes.q
enrichb:{[t;q] aj[`sym`seq;t;`sym`seq xasc select sym,seq,bid,ask from q]}         / the prevailing quote as of each trade's arrival
```

```q
q)system"l examples/mdp/steps/06_quotes.q"
q)system"l examples/mdp/steps/04_gen.q"
q)system"l examples/mdp/walk.q"
q).qc.check[.mdp.g.stream; agree];
ok 100 tests (seed 7)
q).qc.check[.mdp.g.stream; {inc:replay x; all (inc[`bid]<=inc`ask) or null inc`bid}];
ok 100 tests (seed 7)
```

The second rule is a sanity check that costs a line: no enriched trade has a bid above its ask.

Piece 2: three bugs (the tie, the order of the columns, the clash of the two `time` columns) and one in the
test, from one rule, each shown on a stream of two rows or fewer.

## Piece 3: bars

For each symbol and minute: open, high, low, close, volume and count. `onbar` folds trades into a keyed table
one at a time, and `barsb` computes the same from a whole day with one `select`. Two ways again, so the same
kind of rule: **the fold agrees with the batch**.

```q
/ examples/mdp/steps/07_bars.q
onbar:{[t] {[r] k:`sym`minute!(r`sym;0D00:01 xbar r`time); b:bar k;
  bar[k]:$[null b`n; `o`h`l`c`v`n!(r`px;r`px;r`px;r`px;r`qty;1); `o`h`l`c`v`n!(b`o;b[`h]|r`px;b[`l]&r`px;r`px;b[`v]+r`qty;b[`n]+1)]} each t;}
barsb:{[t] select o:first px,h:max px,l:min px,c:last px,v:sum qty,n:count i by sym,minute:0D00:01 xbar time from t}
```

```q
/ examples/mdp/walk.q
fold:{[t] .mdp.bar::0#.mdp.bar; .mdp.onbar t; .mdp.bar}                        / the bars of a day, trade by trade
```

### A rule that said too much

```q
q)system"l examples/mdp/steps/07_bars.q"
q)system"l examples/mdp/steps/07_gen.q"
q)system"l examples/mdp/walk.q"
q).qc.check[.mdp.g.trades; {.qc.eq[fold x; .mdp.barsb x]}];
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
```

Two trades in one minute, for `B` and then for `A`. The fold has `B`'s bar first, because `B` arrived first, and
the batch has `A`'s first, because `by` sorts. The bars are the same and the rows are in a different order.

Nothing promised an order. What a keyed table means is in its keys, and a caller that looks a bar up by symbol
and minute will never see the difference. So this one is the rule's to fix: it compares the two sides sorted by
key.

```q
/ examples/mdp/walk.q
same:{[a;b] .qc.eq[`sym`minute xasc 0!a; `sym`minute xasc 0!b]}                / equal as bar tables: sorted by key first
split:{[t;k] k:k&count t; .mdp.bar::0#.mdp.bar; .mdp.onbar k#t; .mdp.onbar k _ t; a:.mdp.bar; same[a;fold t]}   / fed in two batches, or in one
```

```q
q)system"l examples/mdp/steps/07_bars.q"
q)system"l examples/mdp/steps/07_gen.q"
q)system"l examples/mdp/walk.q"
q).qc.check[.mdp.g.trades; {same[fold x; .mdp.barsb x]}];
ok 100 tests (seed 7)
q).qc.check[(.mdp.g.trades; .qc.int 0 40); split];
ok 100 tests (seed 7)
q).qc.check[.mdp.g.trades; {b:0!fold x; all (b[`h]>=b`o) and (b[`h]>=b`c) and (b[`l]<=b`o) and (b[`l]<=b`c) and b[`n]>0}];
ok 100 tests (seed 7)
```

`split` is the rule the pipeline will lean on: a day fed in two batches, split anywhere, gives the bars that
the day fed in one does. That is what an incremental table is *for*.

Piece 3: no bugs, and one rule that asserted more than was meant. Deciding that the order of the rows was not
part of the contract was a decision about the system, and the test forced it.

## Piece 4: positions and PnL

For each symbol: a signed quantity, the average cost of the open position, and the PnL realised so far. A fill
that adds to a position averages its price in. One that reduces it realises the difference between its price
and the cost, and leaves the cost alone. One that flips it realises the whole of the old position and opens the
rest at its own price.

The generator draws a fill log and a mark, a price for each symbol to value the open positions at. The rules:

- the position is the signed sum of the fills;
- **the book balances**: realised plus unrealised PnL equals the cash the fills brought in plus the open
  position valued at the mark.

The second is the kind of rule to look for in any system that has money in it. It is an identity that holds for
every fill log and every mark, it takes four lines, and it does not care how the position was arrived at.

```q
/ examples/mdp/walk.q
book:{[f] .mdp.pos::0#.mdp.pos; .mdp.onfill f;}                                / book a fill log from flat
signed:{[f] exec sum qty*1 -1 `buy`sell?side by sym from f}                    / the signed quantity filled, per sym
balances:{[x] f:x 0; mk:x 1; book f;
  lhs:(exec sum real from .mdp.pos)+.mdp.unreal mk;
  rhs:cash[f]+exec sum mult[][sym]*qty*mk sym from .mdp.pos;
  1e-6>abs lhs-rhs}
```

### Two runs that never reached a fill

```q
q)system"l examples/mdp/steps/08_pos.q"
q)system"l examples/mdp/steps/08_gen.q"
q)system"l examples/mdp/walk.q"
q).qc.check[.mdp.g.fills; {book x 0; .qc.eq[exec qty from .mdp.pos; signed x 0]}];
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
q).qc.check[.mdp.g.fills; balances];
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

Both fail on the empty fill log, before a single fill has been booked.

The first is the test's mistake. `why` is `type`, 7 against 99: one side is a vector of quantities and the other
is a dict from symbol to quantity, which is what `exec … by` gives. A vector is never a dict, so this rule
could not have passed on any fill log, and the empty one was only the first it was tried on. Both sides become
dicts, in the order of their keys.

The second is the piece's, and the message is the whole report: `inst`. The function that values the open
positions names `inst` inside a q-SQL expression:

```q
/ examples/mdp/steps/08_pos.q
unreal:{[mk] exec sum inst[sym;`mult]*qty*(mk sym)-cost from pos}
```

It is defined under `\d .mdp`, where the rest of the body would find `.mdp.inst` by that name. The expressions
inside q-SQL do not: they look in the root, where there is no `inst`. (The table after `from` is found all the
same, which is what makes this easy to miss.) The corrected version names its globals in full. It also looks
the multipliers up in a dict, because a keyed table indexed by a list of keys and a column is a `length` error.

### Three rules, one cause

```q
q)system"l examples/mdp/steps/09_pos.q"
q)system"l examples/mdp/steps/08_gen.q"
q)system"l examples/mdp/walk.q"
q).qc.check[.mdp.g.fills; balances];
FAIL falsified after 2 tests, 9 shrinks (60 attempts, seed 7)
x:
  0:
    sym side qty px
    ---------------
    A   buy  1   1
  1:
    A: 1f
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 0 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0 1]
q).qc.check[.mdp.g.fills; costs];
FAIL falsified after 2 tests, 9 shrinks (60 attempts, seed 7)
x:
  0:
    sym side qty px
    ---------------
    A   buy  1   1
  1:
    A: 1f
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 0 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0 1]
q).qc.check[(.qc.elem `A`B; .qc.elem 1 10 100; .qc.flt 1 100); trip];
FAIL falsified after 0 tests, 0 shrinks (5 attempts, seed 7)
s: `A
q: 1
p: 1f
rerun: .qc.again[]  or  .qc.recheck[gen;prop;0 0 0 0 1]
```

Three rules fail, each on the smallest case it could. Buy one at 1, mark it at 1, and the book is out of
balance. The cost of an open position lies outside the prices paid for it (`costs`). A round trip at one price
realises something (`trip`).

With an input that small the diagnosis is a matter of working one expression by hand. After one buy at 1 the
position has a cost of 0:

```q
/ examples/mdp/steps/08_pos.q
  $[(q0=0) or sgn[q0]=sgn q; [c:(c0*abs[q0]+px*abs q)%abs q0+q; pos[r`sym]:`qty`cost`real!(q0+q;c;r0)];                    / opening or adding
```

q has no precedence. `c0*abs[q0]+px*abs q` is `c0*(abs[q0]+px*abs q)`, and on the first fill `c0` is 0. Every q
programmer has written this line. Three different rules refused it, and none of them had been written with
precedence in mind.

```q
/ examples/mdp/steps/10_pos.q
  $[(q0=0) or sgn[q0]=sgn q; [c:((c0*abs q0)+px*abs q)%abs q0+q; pos[r`sym]:`qty`cost`real!(q0+q;c;r0)];                    / opening or adding
```

```q
q)system"l examples/mdp/steps/10_pos.q"
q)system"l examples/mdp/steps/08_gen.q"
q)system"l examples/mdp/walk.q"
q).qc.check[.mdp.g.fills; {book x 0; .qc.eq[byk exec sym!qty from .mdp.pos; byk signed x 0]}];
ok 100 tests (seed 7)
q).qc.check[.mdp.g.fills; balances];
ok 100 tests (seed 7)
q).qc.check[.mdp.g.fills; costs];
ok 100 tests (seed 7)
q).qc.check[(.qc.elem `A`B; .qc.elem 1 10 100; .qc.flt 1 100); trip];
ok 100 tests (seed 7)
```

Piece 4: two bugs, and one property that compared a vector with a dict. Remember `balances`. It comes back.

## Piece 5: end of day

At the close, the day's trades, quotes and bars are written to a date partition of an HDB, sorted by symbol
with the symbols enumerated; the day's tables are cleared; the HDB is mapped again; and the day moves on. Three
queries answer for any date, from memory when the date is today and from disk when it is not: the bars of a
symbol in a window, its VWAP, and its trades.

The rule is a round trip through the close: **ask every question, close the day, ask again, and the answers are
the same**.

```q
/ examples/mdp/walk.q
ask:{[d;s;a;b] `bars`vwap`trades!(.mdp.qbars[d;s;a;b]; .mdp.qvwap[d;s]; .mdp.qtrades[d;s])}   / the three queries, of one sym
memdisk:{[ev;a;b] w:asc (a;b); reset[]; feed ev; s:exec sym from .mdp.inst;
  mem:ask[day1;;w 0;w 1] each s;
  .mdp.eod day1;
  .qc.eq[mem; ask[day1;;w 0;w 1] each s]}
```

Its inputs are a stream of events and the two ends of a window. The HDB is a fresh temporary directory.

### Two bugs on a day with nothing in it

```q
q)system"l examples/mdp/steps/06_quotes.q"
q)system"l examples/mdp/steps/07_bars.q"
q)system"l examples/mdp/steps/11_eod.q"
q)system"l examples/mdp/steps/07_gen.q"
q)system"l examples/mdp/walk.q"
q).mdp.hdb:hsym `$first system"mktemp -d"
q).qc.check[(.mdp.g.stream; .qc.ts[.mdp.open;.mdp.close]; .qc.ts[.mdp.open;.mdp.close]); memdisk];
FAIL falsified after 0 tests, 0 shrinks (18 attempts, seed 7)
ev:
  time kind sym bid ask px qty
  ----------------------------
a: 2024.01.02D09:30:00.000000000
b: 2024.01.02D09:30:00.000000000
nyi
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 0 0 0 0 0 0 0 757503000000000000 757503000000000000]
```

`nyi`, on a day with no events. The VWAP query is an `exec`, and `exec` over a partitioned table is not
implemented, where the same aggregate in a `select` is. The query of memory and the query of disk are not the
same text with `date=d` added, which is the reason to test that they agree. Step 12 asks the HDB with a
`select`.

```q
q)system"l examples/mdp/steps/06_quotes.q"
q)system"l examples/mdp/steps/07_bars.q"
q)system"l examples/mdp/steps/12_eod.q"
q)system"l examples/mdp/steps/07_gen.q"
q)system"l examples/mdp/walk.q"
q).mdp.hdb:hsym `$first system"mktemp -d"
q).qc.check[(.mdp.g.stream; .qc.ts[.mdp.open;.mdp.close]; .qc.ts[.mdp.open;.mdp.close]); memdisk];
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

The empty day again, and still not a row in sight. The answers from disk have enumerated symbols (type 20)
where the answers from memory have plain ones (11). They look the same at the console and they join the same.
They are different to `~` and to `type`, and so to any caller, or test, that compares an answer from disk with
one from memory. The queries promise one shape for any date, so
step 13 has the disk branch return the shape that memory returns:

```q
/ examples/mdp/steps/13_eod.q
.mdp.dq:{[t] update sym:value sym from delete date from t}
.mdp.qvwap:{[d;s] $[d<.mdp.today; first exec v from select v:qty wavg px from trade where date=d, sym=s; exec qty wavg px from .mdp.trade where sym=s]}
```

```q
q)system"l examples/mdp/steps/06_quotes.q"
q)system"l examples/mdp/steps/07_bars.q"
q)system"l examples/mdp/steps/13_eod.q"
q)system"l examples/mdp/steps/07_gen.q"
q)system"l examples/mdp/walk.q"
q).mdp.hdb:hsym `$first system"mktemp -d"
q).qc.check[(.mdp.g.stream; .qc.ts[.mdp.open;.mdp.close]; .qc.ts[.mdp.open;.mdp.close]); memdisk];
ok 100 tests (seed 7)
q).qc.check[(.mdp.g.stream; .mdp.g.stream); twodays];
ok 100 tests (seed 7)
q).qc.check[.mdp.g.stream; closes];
ok 100 tests (seed 7)
```

Two more rules came with the pass: two days closed in turn can both still be asked about, and the close empties
the day's tables while leaving the quote cache as it was. The cache is the one piece of state that is meant to
cross the boundary.

Piece 5: two bugs, both in the disk branch of the queries, both found on the empty day before the first row was
ever written. An empty table still has column types and a partitioned table still refuses `exec`. The simplest
input is tried first and it is more often enough than one would think.

### Where things stood

Eight bugs in five pieces, seven of them shown on an input that can be read at a glance and one found before
anything was run, and four mistakes in the tests. Every rule so far has been about one piece alone.

## The assembly

`upd[table;rows]` is what a feed handler calls. It routes quotes, trades and fills to the pieces, rounding the
price of a trade to the tick on the way in. A system like this has no single input to draw. What it answers
depends on everything it has been sent, so the test is a stateful one: sequences of commands, made on the system
and checked against a model.

### The model and the oracle

The stateful test runs three instruments through six commands:

| command | what it does | how often |
|---|---|---|
| `quote` | a quote, a little after the last event | 4 |
| `trade` | a trade, a little after the last event | 4 |
| `late` | a trade reported late, timed up to thirty minutes back | 1 |
| `fill` | a fill | 2 |
| `eod` | closes the day | 1 |
| `query` | the three queries, of any day so far | 2 |

The last column is the `w` column of the command table: the weights with which a command is chosen.

The **model** is the log of what was sent: the quotes and trades in the order they arrived, each with the
sequence number the feed will have given it, the fills, and a clock. The right answers are computed from that
log by the *oracle*, a handful of one-line functions:

```q
/ examples/mdp/steps/15_sm.q
otr:{[m;d] select from m[`t] where d="d"$time}                                   / the trades of day d: those timed on it
oenr:{[m;d] enrichb[otr[m;d]; m`q]}
obars:{[m;d] 0!barsb otr[m;d]}
opos:{[m] exec sum qty*1 -1 `buy`sell?side by sym from m`f}
olq:{[m] select last bid,last ask by sym from m`q}
```

The trades of a day are the ones timed on it, enriched by the batch join and barred by the batch `select`. The
positions are the signed sums of the fills. The last quote of a symbol is the last one in the log. The
incremental code, which is the part in doubt, is checked against the batch code run over everything that was
ever sent.

The **invariant** compares the system with the oracle after every step: the positions, today's bars, the quote
cache, and, from piece 4, that the book balances.

```q
/ examples/mdp/steps/15_sm.q
invar:{[m] d:m`day; mk:(syms!count[syms]#1f),exec sym!0.5*bid+ask from 0!qcache; mu:exec sym!mult from inst;
  (.qc.eq[byk exec sym!qty from pos; byk opos m];
   .qc.eq[`sym`minute xasc 0!bar; `sym`minute xasc obars[m;d]];
   .qc.eq[`sym xasc select sym,bid,ask from 0!qcache; `sym xasc 0!olq m];
   1e-6>abs ((exec sum real from pos)+unreal mk)-(exec sum mu[sym]*qty*px*-1 1 `buy`sell?side from m`f)+exec sum mu[sym]*qty*mk sym from pos)}
```

The whole test is `examples/mdp/steps/15_sm.q`, some sixty lines. Three slips in it came first, none of them
in the system: a parameter called `vs`, which is a keyword; a lookup into a table that had no key; and a model
that numbered events from one where the feed counts from zero. Then the first run that reached the system:

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

`qc.run round` says that `run` signalled an error, and that the error was `round`. The trace is one step long: a
single trade. The one line of q-SQL in the assembly, `update px:round'[sym;px] from x`, could not see `.mdp.round`
under the name `round`. It is the bug of piece 4 over again, in code that no piece's rules had run.

### A pass, and what it was worth

```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/15_sm.q"
q)system"l examples/mdp/walk.q"
q).qc.check[.qc.sm[.mdp.hooks] .mdp.cmds; ::];
ok 100 tests (seed 7)
q).qc.check[.qc.sm[.mdp.hooks] .mdp.cmds; reached];
ok 100 tests (seed 7)
label               n  pct req lo       hi       ok bar
--------------------------------------------------------------
close               52 52      42.31641 61.53562 1  ##########
late                38 38      29.09745 47.79043 1  #######
query_of_a_past_day 15 15      9.305903 23.28373 1  ###
late_after_a_close  12 12      6.999337 19.81227 1  ##
```

A hundred sequences, and nothing. Before believing it, it is worth asking what those sequences did. The places
where this system is likely to break are its seams: a close; a late trade; a query answered from disk; a late
trade after a close. `reached` is a property that always passes and counts the traces in which each of them
happened.

```q
/ examples/mdp/walk.q
reached:{[tr] c:tr`cmd;
  .qc.classify[`close; `eod in c];
  .qc.classify[`late; `late in c];
  .qc.classify[`late_after_a_close; any (c=`late) and 0<sums c=`eod];
  .qc.classify[`late_timed_yesterday; any {[r] $[`late=r`cmd; ("d"$r[`arg]0)<r[`model]`day; 0b]} each tr];
  .qc.classify[`query_of_a_past_day; any {[r] $[`query=r`cmd; r[`arg][0]<r[`model]`day; 0b]} each tr];
  1b}
```

Four of the five were reached, in between a tenth and a half of the runs, give or take. One label is missing from
the table because no trace ever had it: `late_timed_yesterday`. It cannot happen. The clock starts at the open, a
late trade reaches thirty minutes back, and the close moves the clock to the *next* open, so a late trade is always
timed today. A late trade for a day already closed is the case most likely to go wrong, and the stateful test as built
could never produce it.

**The generator decides what a test can find.** A passing run is a statement about the inputs that were drawn,
and the only way to know what those were is to count.

So the stateful test was given more to do: corrections, and late trades that fall on a day already closed.

## Corrections

Two operations that a real feed needs. `bust[id]` removes a trade by its sequence number and recomputes the bar of
its minute from what is left. A trade timed on a day already closed goes into that day's partition. On a day
already closed, both go through `amend`, which reads the closed day's trades back, changes them, recomputes the
day's bars, writes both again and maps the HDB again. The stateful test gains a `bust` command, and its late trades
may now be timed on the day before.

### The test system has state too

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

The first step of a sequence, a late trade for the day before the system started, and a read from the HDB fails
on a file that is not there. The partition it names was written by the *previous* sequence. `init` had emptied
the HDB directory and left the process's mapped tables pointing at the partitions it had removed.

`README.md` says that `init` must reset everything, and this is the case that shows why. The state of this
system is its tables, its directory *and the process's map of the directory*. A reset that misses one of them
gives failures that depend on what ran before.

Unmapping the tables held a second lesson, which cost more time than the first. The tables were removed with a
functional delete, ``![`.;();0b;names]``, where `names` is whichever of `trade`, `quote` and `bar` are defined.
When none is, `names` is empty, and a functional delete with no names deletes *everything* in the namespace.
Every global the session had defined vanished, silently, on the first sequence of every run. The reset now
checks that there is something to delete.

The late trade was given a better target as well. Thirty minutes back had never reached a closed day, and
eighteen hours back mostly landed on the day before the system started, which nothing ever queries. A late trade
is now one reported for yesterday, timed within yesterday's session, and only once there has been a yesterday:
the `pre` of `late` is `{[m] m[`day]>day0}`.

### Testing the test

With that, the stateful test passed. A stateful test is only as good as its oracle, so the next step was to break
the system on purpose and see whether the test noticed. Four sabotages were tried. Three were caught at once,
each shrunk to two steps or fewer: a bust that does not recompute the bar; a late trade kept in memory; a close
that clears the quote cache. The fourth was `amend` rewriting a day's trades and not its bars:

```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/17_amend.q"
q)system"l examples/mdp/steps/19_sm.q"
q).mdp.amend:{[d;f] t:f .mdp.past d; .mdp.save1[d;`trade;t]; system"l ",1_string .mdp.hdb;}
q).qc.check[.qc.sm[.mdp.hooks] .mdp.cmds; ::];
ok 100 tests (seed 7)
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

**The test passed a system that was known to be broken.** A hundred sequences of up to twenty steps did not
find it. Three hundred of up to sixty did, and shrank it to the three steps that are the bug: close the day,
report a trade for it, ask for its bars. The bars come back empty where there should be one.

(In this report `qc.post qc.eq` says that a postcondition failed with a diff, and the diff comes first: the
answer to the query had no `bars` and the oracle had one. The trace has no `model` column, because a model that
holds tables is left out of the print.)

The bug needs three particular commands in order, with a late trade and a query that name the same day and
symbol, and at the default budget the test did not happen to roll them. A stateful test of a system that has
days in it wants longer sequences, and more of them, than one of a stack does. From here on the pipeline's test runs at three
hundred sequences of up to sixty steps.

## Renames

The last piece of scope, and the one that found what the whole exercise was for.

A rename takes effect from a day. The contract is the one most kdb+ shops live with. An event is stored under the
name that is current when it arrives, so a closed day keeps the names it had, and nothing on disk is ever
rewritten. The live state, which is the quote cache and the positions, follows the rename at the close that rolls
into the effective day: the old name's entry is merged into the new name's. The stateful test gains a `rename`
command. The feed goes on using every name it has ever seen, so old names keep arriving after their rename.

The merge of two positions was written the way one writes it first. Add the quantities, average the costs, add
the realised PnL:

```q
/ examples/mdp/steps/20_rename.q
mergepos:{[o;n] a:pos o; b:pos n; q:(0^b`qty)+a`qty;
  c:$[null b`qty; a`cost; 0=q; 0f; (((abs a`qty)*a`cost)+(abs b`qty)*b`cost)%(abs a`qty)+abs b`qty];
  pos[n]:`qty`cost`real!(q;c;(0^b`real)+a`real); pos::delete from pos where sym=o;}
```

```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/17_amend.q"
q)system"l examples/mdp/steps/20_rename.q"
q)system"l examples/mdp/steps/21_sm.q"
q).qc.chk[300;.qc.sm[.mdp.hooks,enlist[`steps]!enlist 0 60] .mdp.cmds; ::];
FAIL falsified after 117 tests, 24 shrinks (188 attempts, seed 7)
qc.inv
step cmd    arg                 res ok
--------------------------------------
0    fill   (`A;`buy;1;1f)      ::  1
1    rename (`A;`N0;2024.01.03) ::  1
2    fill   (`N0;`sell;1;2f)    ::  1
3    eod    ::                  ::  1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 3 0 0 0 0 0 1 1 7 0 0 0 1 3 3 1 0 0 0 2 1 4]
```

Four steps.

1. Buy one `A` at 1.
2. Rename `A` to `N0`, from tomorrow.
3. Sell one `N0` at 2. It is the same instrument under its new name, which is not yet in effect, so the system
   now holds a long position in `A` and a short position in `N0`.
4. Close the day. The roll merges `A` into `N0`: the quantities add up to zero, the cost of a flat position is
   zero, and the realised PnL is the sum of the two, which is zero.

But the book bought at 1 and sold at 2. It made 1, and the system says it made nothing. `qc.inv` is the
invariant, and the part of it that failed is the balance of the book from piece 4. There is no diff because that
part is a single boolean.

Every piece is right on its own. Positions realise PnL correctly on every fill log. Renames to a fresh name,
which are the ones the stateful test makes, resolve correctly.
The close writes and clears correctly. The merge is a *new* operation, which exists only because renames and
positions and the day boundary meet, and as written it is right when the two positions point the same way and
wrong when they do not. An opposite position under the new name is a partial close, and a close realises PnL.

No rule of piece 4 could have seen this, because piece 4 has no renames. No rule of piece 1 could, because
piece 1 has no positions. The stateful test reached it in the 118th sequence and shrank it to the four steps that
define it.

```q
/ examples/mdp/steps/22_rename.q
mergepos:{[o;n] a:pos o; b:pos n; if[null b`qty; b:`qty`cost`real!(0;0f;0f)]; qa:a`qty; qb:b`qty; q:qa+qb; r:(a`real)+b`real;
  c:$[0=q; 0f; (sgn[qa]=sgn qb) or 0 in (qa;qb); (((abs qa)*a`cost)+(abs qb)*b`cost)%(abs qa)+abs qb;   / same way, or one flat: average in
    (abs qa)>abs qb; a`cost; b`cost];                                                                    / opposite ways: the larger side remains, at its cost
  if[(qa*qb)<0; k:(abs qa)&abs qb; lc:$[qa>0; a`cost; b`cost]; sc:$[qa>0; b`cost; a`cost]; r+:inst[n;`mult]*k*sc-lc];   / and the overlap is closed: sold at sc, bought at lc
  pos[n]:`qty`cost`real!(q;c;r); pos::delete from pos where sym=o;}
```

### The oracle can be wrong as well

```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/17_amend.q"
q)system"l examples/mdp/steps/22_rename.q"
q)system"l examples/mdp/steps/21_sm.q"
q).qc.chk[300;.qc.sm[.mdp.hooks,enlist[`steps]!enlist 0 60] .mdp.cmds; ::];
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
```

With the merge fixed the stateful test ran further and stopped on enrichment. On the first day, a quote for `A`,
and a rename of `A` to `N0` in effect from the second. After the close, on the second day, a trade under the old
name `A`. The system stores it as `N0` and enriches it from the cache, whose entry for `A` was rolled into `N0` at
the close, as the contract says. The oracle's batch join went by the names the events were stored under, found no
quote for `N0`, and said null.

The system did what the contract says: the cache follows the rename, so an instrument's last quote is its last
quote whatever it was called at the time. The oracle had been written to a different reading of the same
contract. This one was settled for the system, and the oracle now enriches a day's trades from the instrument's
quotes under that day's names.

It happened once more. Run with seeds taken from the clock, as a CI run would be, the stateful test stopped on a
late trade. A quote under `A`; a rename of `A` to `N0` from tomorrow; the close; a late trade under `A`, timed
yesterday. The system enriched it with the names in force when it *arrived*. The oracle used the names of the day
the trade was *timed*. For a trade that arrives on its own day the two are the same, which is why the runs at seed
7 had agreed. The model now records the day each trade arrived.

The same run failed a rule of piece 1 as well, the one that says rounding moves a price by no more than half a
tick. At a price of 117.625 the distance came out a hair over half a tick, as it will with floats. The rule in
`props.q` allows `1e-9`, and so does the rule that a round trip realises nothing. A comparison of floats that
passed at one seed had simply not yet met the price that breaks it.

A disagreement between the system and the oracle is a question, and the answer is not always that the system
is wrong. Both of these were cases that the contract, as first written down, had not covered. Finding the
questions nobody asked is the other thing a stateful test is for.

## What the tests could not find

With everything passing, the finished code was read through, and the reading found things no test had. None of
them is a *wrong answer*, which is why no rule that compares answers could see them:

- a trade timed after today was enriched and returned, and stored nowhere;
- a rename of a name that is not an instrument inserted an instrument of nulls;
- a fill for an unknown instrument booked a position with a null multiplier;
- "is this day on disk?" was answered by "is there a table called `trade`?", the test that the stale map had
  already fooled once.

The generators only ever drew names that exist and times that are not in the future, so the stateful test never
asked these questions. The system now refuses the first three, and asks the HDB which days it holds:

```q
q)system"l examples/mdp/steps/load_pieces.q"
q)system"l examples/mdp/steps/16_upd.q"
q)system"l examples/mdp/steps/17_amend.q"
q)system"l examples/mdp/steps/22_rename.q"
q)system"l examples/mdp/steps/25_final.q"
q)system"l examples/mdp/steps/25_sm.q"
q).mdp.init[]
q).mdp.rename[`Q;`N0;.mdp.today]
'mdp: rename: unknown name Q
q).mdp.upd[`fill; ([]sym:enlist `Q; side:enlist `buy; qty:enlist 1; px:enlist 1f)]
'mdp: fill for an unknown instrument: Q
q).mdp.upd[`trade; ([]time:enlist .mdp.opn[.mdp.today+1]; sym:enlist `A; px:enlist 1f; qty:enlist 1)]
'mdp: a trade timed after today: +`seq`time`sym`px`qty`bid`ask!(,0;,2024.01.03D09:30:00.000000000;,`A;,1f;,1;,..
```

The stateful test's postconditions were made stronger at the same time. A fill must move the position by its signed
quantity. A trade must carry both bid and ask, at a price on the tick. A busted trade must be gone from wherever
its day lives. The invariant checks yesterday on disk as well as today in memory, and the disk itself: `sym` parted
in every partition, every partition holding every table, a `sym` file without duplicates. The stronger test found
nothing that the weaker one had missed, which is what one hopes for and cannot know without asking.

## The finished suite

`examples/mdp/run.q` runs sixteen of the rules above (the sanity check on the bars is left out) and the stateful
test, each three hundred times, with seeds from the clock, and exits with the number of failures:

```
$ q examples/mdp/run.q
...
--- stateful_60_steps
ok 300 tests (seed 1970363203)
label                                 n  pct      req lo       hi       ok bar
---------------------------------------------------------------------------------
rename_in_effect                      97 32.33333     27.29245 37.82095 1  ######
bust_of_a_past_day                    75 25           20.43691 30.19526 1  #####
late_trade_then_query_of_its_day      41 13.66667     10.23646 18.01563 1  ##
old_name_used_after_its_rename        80 26.66667     21.98052 31.94284 1  #####
positions_merged_at_a_close           54 18           14.06577 22.74341 1  ###
query_of_a_past_day_by_a_renamed_name 25 8.333333     5.708048 12.01224 1  #
name                            ok why stop n   shrinks seed
------------------------------------------------------------------
round_idempotent                1  ok  n    300 0       1662089017
round_within_half_a_tick        1  ok  n    300 0       1807801017
lots                            1  ok  n    300 0       1953966017
canon_idempotent                1  ok  n    300 0       2104836017
canon_is_a_name_or_a_rename     1  ok  n    300 0       176369371
enrich_incremental_equals_batch 1  ok  n    300 0       410849371
bid_le_ask                      1  ok  n    300 0       1371630371
bars_fold_equals_batch          1  ok  n    300 0       211330725
bars_split_anywhere             1  ok  n    300 0       841756725
position_is_the_signed_sum      1  ok  n    300 0       1488150725
book_balances                   1  ok  n    300 0       1943353725
cost_within_the_fills           1  ok  n    300 0       254264079
round_trip_realises_nothing     1  ok  n    300 0       700556079
queries_memory_equals_disk      1  ok  n    300 0       722890079
two_days_on_disk                1  ok  n    300 0       472608787
the_cache_survives_the_close    1  ok  n    300 0       1156884849
stateful_60_steps               1  ok  n    300 0       1970363203
```

The stateful test's entry carries its labels, so that every passing run says what it reached.

## What happened

Twelve findings in the system and its oracle:

| where | found by | what |
|---|---|---|
| piece 1 | writing the generator | `canon` loops on a cycle of renames |
| piece 2 | a property | the as-of tie: a quote and a trade at one timestamp |
| piece 2 | a property | `seq` added as the last column where the tables declare it first |
| piece 2 | a property | `aj` brought the quote's `time` across |
| piece 4 | a property | a name inside q-SQL, in a namespace |
| piece 4 | a property | precedence in the average cost |
| piece 5 | a property | `exec` over a partitioned table |
| piece 5 | a property | enumerated symbols from disk |
| the assembly | the stateful test | a name inside q-SQL, again |
| renames, positions and the close | the stateful test | merging opposite positions loses the realised PnL |
| renames and enrichment | the stateful test | the oracle joined by the names events were stored under |
| renames, late trades and enrichment | the stateful test | the oracle used the names of the trade's day, not of the day it arrived |

Beside them were about as many mistakes in the tests: properties with the wrong number of parameters, a vector
compared with a dict, a function reaching for a local it could not see, keywords used as parameter names, a
tolerance missing from a comparison of floats, a reset that left a stale map, and a delete that removed
everything.

### What to take from it

**The simplest input is the diagnosis.** A fill log of one row, two trades in one minute, a quote and a trade a
nanosecond apart, four commands. Every time, reading the counterexample was most of understanding the bug.

**Properties over a piece find most of the bugs, cheaply.** Eight of the twelve were found in a single piece:
one while writing a generator, and seven by a rule, four of those on an empty input and three on an input of one
or two rows. When there are two ways to compute something, say that they agree.

**The stateful test finds what lives between the pieces.** The bug that mattered most could not have been found
by a rule about any piece, because it was in an operation that did not exist until three pieces met. It was
found by a rule written for piece 4, the balance of the book, carried into the stateful test as an invariant. An
identity that holds whatever happens is worth more than it looks.

**Test code is code.** Expect to fix the test about as often as the system. When a rule fails on the simplest
input, suspect the rule first.

**A pass says what was tried, so count what was tried.** `classify` showed that the first stateful test could never
produce a late trade for a closed day. A sabotage showed that a hundred short sequences were not enough. Breaking
the system on purpose, to check that the test notices, is cheap and worth doing before trusting a pass.

**The generator decides what can be found.** The cycle of renames was found by deciding what a rename could be.
The unknown instrument was never found, because no generator drew one.

**A disagreement is a question.** Twice the oracle was the one that was wrong, and both times the real finding
was a case the contract had not covered.

**What the stateful test cannot see.** Its oracle borrows from the system: the batch join, the batch bars, `canon`,
`round`. A bug in one of those is on both sides of every comparison, and passes. That is defensible only because
the rules of the pieces test each of them against something else. The stateful test checks the seams between
incremental and batch and between live and closed. It does not check the batch definitions themselves.

**Three choices of shape** a kdb+ programmer may find unusual. Trades carry their bid and ask, joined on the
way in, where the more common arrangement keeps quotes apart and joins them at query time with `aj`; the bar
table's key is a column named `minute` typed as a timestamp; and within a symbol, a day's trades keep the order
they arrived in, on disk too, so a bar's open is the first trade to arrive in its minute, not the earliest
timed. Each was a choice made as its piece was written, and the rules test the piece as chosen.

**And some things are not wrong answers.** A trade that is stored nowhere and an instrument made of nulls were
found by reading the code. A property-based test does not replace that.
