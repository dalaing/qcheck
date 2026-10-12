# Building an execution and positions system with qcheck — the log

A worked example, kept as it happened: an order management system for a desk that trades instruments in several
currencies. Six pieces — reference data and FX, quotes and benchmark prices, orders and fills, positions and PnL in
the base currency, corporate actions, end of day to a partitioned database — are written one at a time, each with
properties as it is written, then assembled and driven by a stateful test whose model is the event log and whose
oracle recomputes everything from it. Every code change is a file under `steps/`, so every transcript below still
runs: `t/doctest.q` executes each `q)` block in a fresh q from the repository root (seed 7, `\c 25 80`) and requires
the output shown. Nothing here is planted; a bug appears in the log when it appeared in the work, and where a piece
came out too clean and its scope was widened, the entry says so.

## 0. The shape, decided first

Before any code, the shape a kdb+ programmer would expect, so that the pieces are not fighting it later:

- Reference data is a keyed table, `inst`, keyed on `sym`, and the tables of events carry `sym` as a plain symbol in
  memory (a foreign key would not survive the end-of-day write, where `sym` is enumerated over the database's `sym`
  file). Lookups into `inst` are keyed-table lookups.
- Quotes are their own table and are never copied onto other events. A price "as of" a time is an as-of join at
  the time it is asked for, `aj`, against the quotes in time order.
- FX rates are a time series too, USD per unit of the currency, and a conversion to the base currency takes the rate
  as of the time of the thing converted, by the same join.
- Orders are a keyed table, keyed on the order id; fills are events against an id. An order's state follows a
  transition table that is written down as a table and is the specification.
- On disk, every day's tables are partitioned by date with `.Q.dpft`, `sym` parted, and within a symbol the rows are
  in time order. Anything that arrives after its day has closed is a correction to a closed day, and the log will
  say what the system does with it when the piece comes.
- Positions and PnL are computed in the instrument's currency and converted to the base; the rule for *which*
  rate converts what is the business of piece 4, and is the kind of thing the stateful test is for.

## 1. Piece 1: reference data and FX

The first piece is small: the instruments, the rates and a conversion. `rate[t;c]` is an as-of join of `(ccy; time)`
against the rates seen so far, sorted, with the base currency's rate fixed at 1; `tobase[t;c;amt]` multiplies. The
generators draw a session of rates in time order (`mono` over timestamps, with a `dep` that keeps each rate in its
currency's range), a time in the session, and an amount.

```q
q)system"l examples/oms/steps/01_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q).qc.draw .oms.g.fx
time                          ccy rate
---------------------------------------------
2024.01.02D16:00:00.000000000 GBP 1.278356
2024.01.02D16:00:00.027621806 EUR 1.120991
2024.01.02D16:00:00.039225094 JPY 0.006835938
2024.01.02D16:05:00.039225094 GBP 1.288785
2024.01.02D16:05:00.054941157 JPY 0.00625062
q).qc.check[(.oms.g.t;.oms.g.amt); {[t;a] a=.oms.tobase[t;`USD;a]}];
FAIL falsified after 0 tests, 0 shrinks (5 attempts, seed 7)
t: 2024.01.02D09:30:00.000000000
a: 0f
rank
rerun: .qc.again[]  or  .qc.recheck[gen;prop;757503000000000000 0 0 0]
```

## 2. `'rank` before the first test ran

The first rule, that a USD amount is its own conversion, could not run: `rate` raised `rank` on the first example.
`([]ccy:c; time:t)` builds a table from two atoms, and q refuses that; a table's columns are lists. The fix takes
atoms or lists, `(),c` and `(),t`, and gives an atom back for an atom asked. Three rules then pass: the base is the
identity; the rate as of a time is the last one seen at or before it for that currency, against a loop that looks;
and converting to the base and dividing by the rate gives the amount back.

```q
q)system"l examples/oms/steps/02_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q).qc.check[(.oms.g.t;.oms.g.amt); {[t;a] a=.oms.tobase[t;`USD;a]}];
ok 100 tests (seed 7)
q)naive:{[f;t;c] $[count r:exec rate from f where ccy=c,time<=t; last r; 0n]}
q).qc.check[(.oms.g.fx;.oms.g.t;.qc.elem .oms.g.ccys); {[f;t;c] .oms.fxr::f; .qc.eq[.oms.rate[t;c]; naive[f;t;c]]}];
ok 100 tests (seed 7)
q).qc.check[(.oms.g.fx;.oms.g.t;.qc.elem .oms.g.ccys;.oms.g.amt); {[f;t;c;a] .oms.fxr::f; r:.oms.rate[t;c]; $[null r; 1b; 1e-9>abs a-.oms.tobase[t;c;a]%r]}];
ok 100 tests (seed 7)
```

The third rule steps around the case where there is no rate yet, `$[null r; 1b; ...]`, and that is the question
the piece has not answered.

## 3. No rate is a refusal, not a null

A conversion before any rate has been seen for the currency gives a null amount, and a null amount would flow on
into a position's PnL and print as a blank. The rule that decides it: a conversion with no rate is refused, and one
with a rate is a number. The rule fails on the first example, an empty rate table.

```q
q)system"l examples/oms/steps/02_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)call:{[f;x] @[{(1b;y . x)}[;f];x;{(0b;x)}]}
q).qc.check[(.oms.g.fx;.oms.g.t;.qc.elem .oms.g.ccys;.oms.g.amt); {[f;t;c;a] .oms.fxr::f; r:call[.oms.tobase;(t;c;a)]; $[null .oms.rate[t;c]; not r 0; (r 0) and not null r 1]}];
FAIL falsified after 0 tests, 0 shrinks (6 attempts, seed 7)
f:
  time ccy rate
  -------------
t: 2024.01.02D09:30:00.000000000
c: `EUR
a: 0f
rerun: .qc.again[]  or  .qc.recheck[gen;prop;0 757503000000000000 0 0 0 0]
```

The fix: `tobase` signals where the rate is null, naming the currency and the time. `rate` itself still answers a
null, since callers that want to know whether a rate exists ask it. The rule passes, and then a call by hand shows
that it passed for the wrong reason:

```q
q)system"l examples/oms/steps/03_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)call:{[f;x] @[{(1b;y . x)}[;f];x;{(0b;x)}]}
q).qc.check[(.oms.g.fx;.oms.g.t;.qc.elem .oms.g.ccys;.oms.g.amt); {[f;t;c;a] .oms.fxr::f; r:call[.oms.tobase;(t;c;a)]; $[null .oms.rate[t;c]; not r 0; (r 0) and not null r 1]}];
ok 100 tests (seed 7)
q).oms.fxr:0#.oms.fxr
q).oms.tobase[2024.01.02D10:00;`EUR;100f]
'type
```

`'type`, not the message: `where null r` on the atom that `rate` returns for an atom asked fails, since `where`
takes a list *(corrected: this said `where` gave an index into a list and `distinct` failed on what it picked out;
`where` on a boolean atom is itself the `type` error)*. The rule said "refused", and any error is a refusal, so the
rule was happy. The rule that would have caught it says what the refusal must say:

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)call:{[f;x] @[{(1b;y . x)}[;f];x;{(0b;x)}]}
q).qc.check[(.oms.g.fx;.oms.g.t;.qc.elem .oms.g.ccys;.oms.g.amt); {[f;t;c;a] .oms.fxr::f; r:call[.oms.tobase;(t;c;a)]; $[null .oms.rate[t;c]; (not r 0) and (r 1) like "oms: no rate for *"; (r 0) and not null r 1]}];
ok 100 tests (seed 7)
q).oms.fxr:0#.oms.fxr
q).oms.tobase[2024.01.02D10:00;`EUR;100f]
'oms: no rate for EUR at 2024.01.02D10:00:00.000000000
```

## 4. Piece 2: quotes and a price as of a time

Quotes arrive and are appended; a benchmark price, the mid as of a time, is an as-of join of `(sym; time)` against
the quotes in time order. A cache of the last quote per instrument, `lq`, is kept as quotes arrive, for the callers
that want the price now without a join. The generator draws a session of quotes in time order, each instrument in
its own price range with the ask at or above the bid (`dep`, drawing the pair from the row's `sym`). Two rules:
the mid as of a time against a loop that looks through the quotes, and the cache against the join at the latest
time.

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/05_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)feed:{[t] .oms.quote::0#.oms.quote; .oms.lq::0#.oms.lq; .oms.onquote'[t`time;t`sym;t`bid;t`ask];}
q)naive:{[q;t;s] $[count r:select from q where sym=s,time<=t; .oms.midof[last r`bid;last r`ask]; 0n]}
q).qc.check[(.oms.g.quotes;.oms.g.t;.qc.elem .oms.g.syms); {[q;t;s] q:.oms.g.qs q; feed q; .qc.eq[.oms.mid[t;s]; naive[q;t;s]]}];
ok 100 tests (seed 7)
q).qc.check[(.oms.g.quotes;.qc.elem .oms.g.syms); {[q;s] q:.oms.g.qs q; feed q; .qc.eq[.oms.now s; .oms.mid[max .oms.g.close,q`time;s]]}];
ok 100 tests (seed 7)
```

## 5. The cache as a stateful test

Both rules pass, and both feed the quotes in time order, which is how the generator draws them. A feed does not
always: a tick can arrive after one timed later than it. The cache is a piece of state that every quote changes,
which is what a stateful test is for: the model is the quotes seen so far and the clock; a `quote` command is timed
at or after the clock, a `late` one before it; and after either, the cache's mid for that instrument must be the
mid as of the latest time seen, which is the join.

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/05_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/06_sm.q"
q).qc.check[.qc.sm[.oms.q.hooks] .oms.q.cmds; ::];
FAIL falsified after 6 tests, 27 shrinks (96 attempts, seed 7)
qc.post
step cmd   arg                                 res                                      ok
------------------------------------------------------------------------------------------
0    quote 2024.01.02D09:30:00.000000001 `A `A 2024.01.02D09:30:00.000000001 `A 10f 10f 1
1    late  2024.01.02D09:30:00.000000000 `A `A 2024.01.02D09:30:00.000000000 `A 10f 11f 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 757503000000000001 0 0 0 0 10 0 0 0 1 1 757503000000000000 0 0 0 0 10 0 0 1]
```

Two steps: a quote for `A` a nanosecond after the open, then one timed at the open. The cache holds the late one,
the join the earlier-arrived one, and they disagree in the ask. `onquote` took every quote as the last.

## 6. The cache keeps the latest time, not the latest arrival

`onquote` now updates the cache only when the quote's time is not before the cached one (a cache with no entry has a
null time, which compares low). The same test, and five hundred sequences:

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/07_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/06_sm.q"
q).qc.chk[500;.qc.sm[.oms.q.hooks] .oms.q.cmds; ::];
ok 500 tests (seed 7)
```

Left as it is: the command generators draw a third value that `run` never uses (a slip in writing the table).
It costs a choice per step and nothing else, and the step files are the record.

## 7. Piece 3: orders and fills

An order is a row of a keyed table, keyed on its id, with its state and what is left to fill; its life follows a
transition table, `T`, written down as the specification, and `D` is the same table as a dictionary of
dictionaries so that `D[state;event]` is the next state and a null where the event is not allowed. On the way in an
order is checked against the reference data: the instrument exists, the quantity is a multiple of its lot, the
limit price is on its tick; and its arrival price, the mid as of its time, is kept for the execution analysis to
come. Three rules for the piece on its own: an order comes out as it went in; a quantity off the lot or a price
off the tick is refused; and after any run of fills, the fills sum to what was filled and the state says whether
anything is left.

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/07_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/08_orders.q"
q)system"l examples/oms/steps/08_gen.q"
q).oms.inst:.oms.g.inst
q)reset:{.oms.order::0#.oms.order; .oms.fill::0#.oms.fill; .oms.seq::0}
q).qc.check[(.oms.g.t;.oms.g.order); {[t;a] reset[]; id:.oms.neworder[t;a 0;a 1;a 2;a 3]; o:.oms.order id; (o[`st]=`new) and (o[`leaves]=a 2) and (o[`sym]=a 0) and o[`px]=a 3}];
ok 100 tests (seed 7)
q).qc.check[(.oms.g.t;.oms.g.order;.qc.int 1 9;.qc.flt 0 0.009); {[t;a;dq;dp] reset[]; r:@[{.oms.neworder . x; 1b};(t;a 0;a 1;(a 2)+dq;a 3);{0b}]; s:@[{.oms.neworder . x; 1b};(t;a 0;a 1;a 2;(a 3)+dp);{0b}]; (r=0=dq mod .oms.g.inst[a 0;`lot]) and s=.oms.ontick[a 0;(a 3)+dp]}];
ok 100 tests (seed 7)
q)fq:.qc.lst[0 5] .qc.int 1 5
q).qc.check[(.oms.g.t;.oms.g.order;fq); {[t;a;fs] reset[]; id:.oms.neworder[t;a 0;a 1;a 2;a 3]; .oms.ack id; lot:.oms.g.inst[a 0;`lot]; {[t;id;lot;q] o:.oms.order id; if[(o[`leaves]>0) and (q*lot)<=o`leaves; .oms.onfill[t;id;q*lot;o`px]]}[t;id;lot] each fs; o:.oms.order id; f:select from .oms.fill where id=id; ((o[`qty]-o`leaves)=sum f`qty) and (o[`st]=$[o[`leaves]=0; `filled; count[f]>0; `part; `ack])}];
ok 100 tests (seed 7)
```

Two things went wrong before these ran, both in the test and not the piece. *(corrected: a third, found when the
walkthrough was written from this log: the third rule's `select from .oms.fill where id=id` compares the column
with itself, the column shadowing the local, and so selects every fill; with one order per run it made no
difference, and the walkthrough's version of the rule names the order `oid`.)* The generators for a quantity and a
limit price multiplied a generator by a number, `.qc.int[1 20]*lot`, which is a function times a long; a generator
of your own that needs arithmetic on what it draws is a function that draws and then computes. And `fills` is a
keyword (the forward fill), so a list of fills cannot be called that: `fq`.

## 8. The lifecycle as a stateful test

The rules above run a fixed shape of sequence. The lifecycle is a state machine in the plain sense, and the
stateful test is the tool: the model is a table of the orders placed, with the state and the leaves each ought to
have; the commands are the events, each choosing an order from the model on which the table allows it; a partial
fill draws a part of what is left; and an over-fill, more than is left, must be refused and change nothing.

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/07_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/08_orders.q"
q)system"l examples/oms/steps/08_gen.q"
q)system"l examples/oms/steps/09_sm.q"
q).oms.inst:.oms.g.inst
q).qc.check[.qc.sm[.oms.o.hooks] .oms.o.cmds; ::];
FAIL error after 0 tests, 0 shrinks (0 attempts, seed 7)
D
rerun: .qc.again[]  or  .qc.recheck[gen;prop;`long$()]
```

`'D`: the test's `o.can` asks, in q-sql, which orders allow an event, and q-sql resolves a bare name in the root
namespace, not in `.oms`, so `D` had to be spelled `.oms.D`. With that, the run gets further:

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/07_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/08_orders.q"
q)system"l examples/oms/steps/08_gen.q"
q)system"l examples/oms/steps/10_sm.q"
q).oms.inst:.oms.g.inst
q).qc.check[.qc.sm[.oms.o.hooks] .oms.o.cmds; ::];
FAIL error after 5 tests, 7 shrinks (90 attempts, seed 7)
length
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 1000 1 0 757503000000000000 1 2 0]
q).oms.D[`new`part;`ack]
`ack`
q).oms.D[`new`rej;`ack]
'length
```

An order is placed and rejected; the next step asks which orders allow an ack, and `D[st;ev]` over the list of
states raises `length`: a state with no row in `D` (the terminal ones, `rej` here) indexes to an empty dictionary,
and q cannot index a list of dictionaries of different shapes at depth, as the two calls by hand show. Looked up
one order at a time, `{D[x;y]}'[st;ev]`, the missing state is a null:

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/07_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/08_orders.q"
q)system"l examples/oms/steps/08_gen.q"
q)system"l examples/oms/steps/11_sm.q"
q).oms.inst:.oms.g.inst
q).qc.check[.qc.sm[.oms.o.hooks] .oms.o.cmds; ::];
FAIL error after 18 tests, 7 shrinks (106 attempts, seed 7)
qc: range: lo exceeds hi in 1 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 1000 1 0 757503000000000000 1 1 0 1 5 0]
```

The run now reaches a generator error of the test's own: a partial fill of an order with one left has no part to
draw (`.qc.int (1;0)`), so a partial fill needs at least two left. With that:

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/07_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/08_orders.q"
q)system"l examples/oms/steps/08_gen.q"
q)system"l examples/oms/steps/12_sm.q"
q).oms.inst:.oms.g.inst
q).qc.chk[500;.qc.sm[.oms.o.hooks,enlist[`steps]!enlist 0 40] .oms.o.cmds; ::];
ok 500 tests (seed 7)
```

Five hundred sequences of up to forty steps and the piece holds. Everything found so far in this piece was in the
test; the system's checks and the transition table were right first time, which is what a table as the
specification buys. One library note: the error's backtrace stopped at the stateful test's own frame, since the
runner re-raises an error from a hook after running `fini`, so the place of the `length` had to be found by hand.

## 9. Piece 4: positions and PnL

A position per instrument: the signed quantity, the average cost of the open quantity in the instrument's
currency, and the realised PnL in the base. A fill on the same side moves the average; one on the other side
realises `(px - cost)` on what it closes, converted at the rate as of the fill; one that goes through zero closes
and reopens. Unrealised PnL marks the open quantity at the mid as of the time asked, converted at the rate as of
then. The generator is a run of fills for one instrument, each a side, a number of lots and a price, made into an
order acked and filled in full; the rates are one per currency, at the open. Two rules: the position is the signed
sum of the fills, and realised plus unrealised is what the desk would count by hand, the cash flows plus the open
quantity marked, converted at the one rate.

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/07_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/08_orders.q"
q)system"l examples/oms/steps/08_gen.q"
q)system"l examples/oms/steps/13_pos.q"
q)system"l examples/oms/steps/13_gen.q"
q).oms.inst:.oms.g.inst
q)reset:{[fx] .oms.order::0#.oms.order; .oms.fill::0#.oms.fill; .oms.seq::0; .oms.pos::0#.oms.pos; .oms.fxr::fx; .oms.quote::0#.oms.quote; .oms.lq::0#.oms.lq}
q)run:{[t;s;fs] {[t;s;f] lot:.oms.inst[s;`lot]; id:.oms.neworder[t;s;f 0;lot*f 1;.oms.g.inst[s;`tick]]; .oms.ack id; .oms.onfill[t;id;lot*f 1;f 2]}[t;s] each fs;}
q).qc.check[(.oms.g.fx1;.qc.elem .oms.g.syms;.oms.g.fillrun `A); {[fx;s;fs] reset fx; run[.oms.g.open;s;fs]; q:0^.oms.pos[s;`qty]; q=sum .oms.sgn'[fs[;0]]*.oms.inst[s;`lot]*fs[;1]}];
ok 100 tests (seed 7)
q).qc.check[(.oms.g.fx1;.qc.elem .oms.g.syms;.oms.g.fillrun `A;.qc.flt 10 20); {[fx;s;fs;m] reset fx; run[.oms.g.open;s;fs]; .oms.onquote[.oms.g.open;s;m;m]; r:.oms.rate[.oms.g.open;.oms.inst[s;`ccy]]; lot:.oms.inst[s;`lot]; cash:sum neg .oms.sgn'[fs[;0]]*lot*fs[;1]*fs[;2]; q:0^.oms.pos[s;`qty]; want:r*cash+q*m; got:(0^.oms.pos[s;`real])+.oms.unreal[.oms.g.open;s]; 1e-6>abs want-got}];
ok 100 tests (seed 7)
```

Both hold, and the second covers every branch of `onpos` (adding, reducing, through zero), since a run of eight
fills of either side does all three. One rate is a choice of the test: what realised and unrealised should add up
to when the rate moves between a fill and the mark is a question about the whole system, not this piece, and the
place to ask it is the stateful test over the assembled system, whose oracle will count the cash in the base
currency as the desk does. It is noted here so that it is not forgotten.

## 10. Piece 5: a split

A split, `r` new shares for each old one, arrives before the open on its day. Everything that is a quantity of the
instrument is multiplied and everything that is a price is divided: the position and its average cost, and the open
orders, their quantity, what is left, their limit and their arrival price. Fills already made and quotes already
seen are history and stay as traded. Whole ratios only: what the desk does with a fraction of a share is not
decided here. Two rules: the position's unrealised PnL is where it was once the market quotes at the new level, and
an open order is worth what it was, still a whole number of lots.

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/07_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/08_orders.q"
q)system"l examples/oms/steps/08_gen.q"
q)system"l examples/oms/steps/13_pos.q"
q)system"l examples/oms/steps/13_gen.q"
q)system"l examples/oms/steps/14_ca.q"
q).oms.inst:.oms.g.inst
q)reset:{[fx] .oms.order::0#.oms.order; .oms.fill::0#.oms.fill; .oms.seq::0; .oms.pos::0#.oms.pos; .oms.fxr::fx; .oms.quote::0#.oms.quote; .oms.lq::0#.oms.lq; .oms.ca::0#.oms.ca}
q)run:{[t;s;fs] {[t;s;f] lot:.oms.inst[s;`lot]; id:.oms.neworder[t;s;f 0;lot*f 1;.oms.g.inst[s;`tick]]; .oms.ack id; .oms.onfill[t;id;lot*f 1;f 2]}[t;s] each fs;}
q).qc.check[(.oms.g.fx1;.qc.elem .oms.g.syms;.oms.g.fillrun `A;.qc.flt 10 20;.qc.int 2 4); {[fx;s;fs;m;r] reset fx; run[.oms.g.open;s;fs]; .oms.onquote[.oms.g.open;s;m;m]; u0:.oms.unreal[.oms.g.open;s]; .oms.split[.oms.g.open;s;r]; .oms.onquote[.oms.g.open+1;s;m%r;m%r]; u1:.oms.unreal[.oms.g.open+1;s]; 1e-6>abs u0-u1}];
FAIL falsified after 0 tests, 0 shrinks (47 attempts, seed 7)
fx:
  time                          ccy rate
  -------------------------------------------
  2024.01.02D09:30:00.000000000 EUR 1.125
  2024.01.02D09:30:00.000000000 GBP 1.25
  2024.01.02D09:30:00.000000000 JPY 0.0078125
s: `A
fs: ()
m: 10f
r: 2
length
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 3 9 1 0 0 2 5 1 0 0 7 1 0 0 0 0 0 10 2]
```

`length` on the first example, an instrument with no orders: the split amended four columns of the keyed order table
at once by index, `order[ids;`qty`leaves`px`arr]:...`, which q does not do. A functional update over the table's
value does, `order::![order;...]`, with one thing to get right: the assignment is `::`, since `order:` anywhere in
the function would make `order` a local and the read on the right a read of nothing. *(corrected: this said the
update had to be functional because q-sql on the bare name `order` would look for it in the root. It would not: a
table named in `from` is found in the namespace; it is a variable or function named inside the query, `totick`
here, that is looked up in the root, and `update ... from order` with `.oms.totick` spelled out would have done.)*

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/07_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/08_orders.q"
q)system"l examples/oms/steps/08_gen.q"
q)system"l examples/oms/steps/13_pos.q"
q)system"l examples/oms/steps/13_gen.q"
q)system"l examples/oms/steps/15_ca.q"
q).oms.inst:.oms.g.inst
q)reset:{[fx] .oms.order::0#.oms.order; .oms.fill::0#.oms.fill; .oms.seq::0; .oms.pos::0#.oms.pos; .oms.fxr::fx; .oms.quote::0#.oms.quote; .oms.lq::0#.oms.lq; .oms.ca::0#.oms.ca}
q)run:{[t;s;fs] {[t;s;f] lot:.oms.inst[s;`lot]; id:.oms.neworder[t;s;f 0;lot*f 1;.oms.g.inst[s;`tick]]; .oms.ack id; .oms.onfill[t;id;lot*f 1;f 2]}[t;s] each fs;}
q).qc.check[(.oms.g.fx1;.qc.elem .oms.g.syms;.oms.g.fillrun `A;.qc.flt 10 20;.qc.int 2 4); {[fx;s;fs;m;r] reset fx; run[.oms.g.open;s;fs]; .oms.onquote[.oms.g.open;s;m;m]; u0:.oms.unreal[.oms.g.open;s]; .oms.split[.oms.g.open;s;r]; .oms.onquote[.oms.g.open+1;s;m%r;m%r]; u1:.oms.unreal[.oms.g.open+1;s]; 1e-6>abs u0-u1}];
ok 100 tests (seed 7)
q).qc.check[(.oms.g.fx1;.oms.g.order;.qc.int 2 4); {[fx;a;r] reset fx; id:.oms.neworder[.oms.g.open;a 0;a 1;a 2;a 3]; .oms.ack id; o0:.oms.order id; .oms.split[.oms.g.open;a 0;r]; o1:.oms.order id; (1e-6>abs (o0[`leaves]*o0`px)-o1[`leaves]*o1`px) and (o1[`qty]=r*o0`qty) and 0=o1[`leaves] mod .oms.inst[a 0;`lot]}];
ok 100 tests (seed 7)
q).qc.check[(.oms.g.fx1;.oms.g.order;.qc.int 2 4); {[fx;a;r] reset fx; id:.oms.neworder[.oms.g.open;a 0;a 1;a 2;a 3]; .oms.split[.oms.g.open;a 0;r]; .oms.ontick[a 0;.oms.order[id;`px]]}];
FAIL falsified after 1 tests, 4 shrinks (76 attempts, seed 7)
fx:
  time                          ccy rate
  -------------------------------------------
  2024.01.02D09:30:00.000000000 EUR 1.125
  2024.01.02D09:30:00.000000000 GBP 1.25
  2024.01.02D09:30:00.000000000 JPY 0.0078125
a: (`A;`buy;1;10.01)
r: 2
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 3 9 1 0 0 2 5 1 0 0 7 1 0 0 1001 1 0 2]
```

Both rules hold, and a third, added because the piece was going too well, does not: an open order's limit should
still be on the tick after the split, and a buy of `A` at 10.01 halved is at 5.005, which is not a price the market
takes. The exchanges' answer is to round the adjusted limit against the order, a buy down and a sell up. With
that, the "worth the same" rule is loosened by one tick on what is left, which is what the rounding can cost:

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/07_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/08_orders.q"
q)system"l examples/oms/steps/08_gen.q"
q)system"l examples/oms/steps/13_pos.q"
q)system"l examples/oms/steps/13_gen.q"
q)system"l examples/oms/steps/16_ca.q"
q).oms.inst:.oms.g.inst
q)reset:{[fx] .oms.order::0#.oms.order; .oms.fill::0#.oms.fill; .oms.seq::0; .oms.pos::0#.oms.pos; .oms.fxr::fx; .oms.quote::0#.oms.quote; .oms.lq::0#.oms.lq; .oms.ca::0#.oms.ca}
q).qc.check[(.oms.g.fx1;.oms.g.order;.qc.int 2 4); {[fx;a;r] reset fx; id:.oms.neworder[.oms.g.open;a 0;a 1;a 2;a 3]; .oms.ack id; o0:.oms.order id; .oms.split[.oms.g.open;a 0;r]; o1:.oms.order id; (1e-6>abs[(o0[`leaves]*o0`px)-o1[`leaves]*o1`px]-o1[`leaves]*.oms.inst[a 0;`tick]) and (o1[`qty]=r*o0`qty) and 0=o1[`leaves] mod .oms.inst[a 0;`lot]}];
ok 100 tests (seed 7)
q).qc.check[(.oms.g.fx1;.oms.g.order;.qc.int 2 4); {[fx;a;r] reset fx; id:.oms.neworder[.oms.g.open;a 0;a 1;a 2;a 3]; .oms.split[.oms.g.open;a 0;r]; .oms.ontick[a 0;.oms.order[id;`px]]}];
ok 100 tests (seed 7)
```

The first version of the rounding failed with `type` before it ran: written with `$[`buy=side; floor; ceiling]`, it
took the side as an atom, and inside a functional update the side is a column. The vector conditional, `?[...]`,
takes both.

## 11. Piece 6: end of day

At the close the day's fills, quotes and rates are written as a partition for the day, `sym` parted and in time
order within each `sym`, and the memory tables are emptied for the next day. Two things carry over: the last quote of
each instrument and the last rate of each currency stay in memory, timestamped as they were, so that "as of" the
first minutes of the next day still has something to find. Orders live in memory across days. Queries that span
days read today from memory and the rest from disk; the day's fills come with their slippage against the order's
arrival price, in basis points. `fill` is a keyword, so on disk the fills are `execs`; and the function that reads
the disk is defined at the root, because inside `.oms` the name `execs` would mean `.oms.execs`.

The generator is a day: one rate per currency, a session of quotes, a run of fills for each instrument. Three rules:
a day written comes back as it was; the rate and the mid as of the next day's open are the last of the day; and
slippage is what the arithmetic says.

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/07_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/08_orders.q"
q)system"l examples/oms/steps/08_gen.q"
q)system"l examples/oms/steps/13_pos.q"
q)system"l examples/oms/steps/13_gen.q"
q)system"l examples/oms/steps/16_ca.q"
q).oms.hdb:hsym `$first system"mktemp -d"
q)system"l examples/oms/steps/17_eod.q"
q).oms.inst:.oms.g.inst
q)reset:{.oms.order::0#.oms.order; .oms.fill::0#.oms.fill; .oms.seq::0; .oms.pos::0#.oms.pos; .oms.fxr::0#.oms.fxr; .oms.quote::0#.oms.quote; .oms.lq::0#.oms.lq; .oms.ca::0#.oms.ca; .oms.today::.oms.day0; system"rm -rf ",(1_string .oms.hdb),"/*"; if[count k:`execs`quote`fxr`order inter key `.; ![`.;();0b;k]]}
q)day:{[fx;qs;fs] .oms.onfx'[fx`time;fx`ccy;fx`rate]; qs:.oms.g.qs qs; .oms.onquote'[qs`time;qs`sym;qs`bid;qs`ask]; {[s;fl] {[s;f] lot:.oms.inst[s;`lot]; id:.oms.neworder[.oms.g.open+0D01;s;f 0;lot*f 1;.oms.g.inst[s;`tick]]; .oms.ack id; .oms.onfill[.oms.g.open+0D02;id;lot*f 1;f 2]}[s] each fl}'[.oms.g.syms;fs];}
q)g:(.oms.g.fx1;.oms.g.quotes;.oms.g.fillrun each .oms.g.syms)
q).qc.check[g; {[fx;qs;fs] reset[]; day[fx;qs;fs]; f0:`sym`time xasc .oms.fill; .oms.eod .oms.day0; .qc.eq[f0; `sym`time xasc raze .oms.fillsof[.oms.day0] each .oms.g.syms]}];
FAIL falsified after 1 tests, 3 shrinks (63 attempts, seed 7)
fx:
  time                          ccy rate
  -------------------------------------------
  2024.01.02D09:30:00.000000000 EUR 1.125
  2024.01.02D09:30:00.000000000 GBP 1.25
  2024.01.02D09:30:00.000000000 JPY 0.0078125
qs:
  time sym q
  ----------
fs: (();();())
type
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 3 9 1 0 0 2 5 1 0 0 7 1 0 0 0 0 0]
q).oms.onfx[.oms.g.open;`EUR;1.1]
'type
q)cols .oms.fxr
`ccy`time`rate
q)system"rm -rf ",1_string .oms.hdb

```

`type` on the second test, and the first rate of the new day raises it by hand: the carry-over rebuilt `fxr` with
`select by ccy`, which puts the key column first, and the next `insert` met the columns in the wrong order. `xcols`
puts them back.

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/07_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/08_orders.q"
q)system"l examples/oms/steps/08_gen.q"
q)system"l examples/oms/steps/13_pos.q"
q)system"l examples/oms/steps/13_gen.q"
q)system"l examples/oms/steps/16_ca.q"
q).oms.hdb:hsym `$first system"mktemp -d"
q)system"l examples/oms/steps/18_eod.q"
q).oms.inst:.oms.g.inst
q)reset:{.oms.order::0#.oms.order; .oms.fill::0#.oms.fill; .oms.seq::0; .oms.pos::0#.oms.pos; .oms.fxr::0#.oms.fxr; .oms.quote::0#.oms.quote; .oms.lq::0#.oms.lq; .oms.ca::0#.oms.ca; .oms.today::.oms.day0; system"rm -rf ",(1_string .oms.hdb),"/*"; if[count k:`execs`quote`fxr`order inter key `.; ![`.;();0b;k]]}
q)day:{[fx;qs;fs] .oms.onfx'[fx`time;fx`ccy;fx`rate]; qs:.oms.g.qs qs; .oms.onquote'[qs`time;qs`sym;qs`bid;qs`ask]; {[s;fl] {[s;f] lot:.oms.inst[s;`lot]; id:.oms.neworder[.oms.g.open+0D01;s;f 0;lot*f 1;.oms.g.inst[s;`tick]]; .oms.ack id; .oms.onfill[.oms.g.open+0D02;id;lot*f 1;f 2]}[s] each fl}'[.oms.g.syms;fs];}
q)g:(.oms.g.fx1;.oms.g.quotes;.oms.g.fillrun each .oms.g.syms)
q).qc.check[g; {[fx;qs;fs] reset[]; day[fx;qs;fs]; f0:`sym`time xasc .oms.fill; .oms.eod .oms.day0; .qc.eq[f0; `sym`time xasc raze .oms.fillsof[.oms.day0] each .oms.g.syms]}];
ok 100 tests (seed 7)
q).qc.check[g; {[fx;qs;fs] reset[]; day[fx;qs;fs]; r0:.oms.rate[.oms.g.close;] each .oms.g.ccys; m0:.oms.mid[.oms.g.close;] each .oms.g.syms; .oms.eod .oms.day0; t:.oms.opn .oms.today; .qc.eq[(r0;m0); (.oms.rate[t;] each .oms.g.ccys; .oms.mid[t;] each .oms.g.syms)]}];
FAIL falsified after 86 tests, 30 shrinks (372 attempts, seed 7)
fx:
  time                          ccy rate
  -------------------------------------------
  2024.01.02D09:30:00.000000000 EUR 1.125
  2024.01.02D09:30:00.000000000 GBP 1.25
  2024.01.02D09:30:00.000000000 JPY 0.0078125
qs:
  time                          sym q
  ---------------------------------------
  2024.01.02D15:59:59.999997087 A   10 10
  2024.01.02D16:00:00.000000001 A   10 11
fs: (();();())
qc.eq
path why   a  b
------------------
1 0  value 10 10.5
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 3 9 1 0 0 2 5 1 0 0 7 1 0 1 757526399999997087 0 0 0 10 0 0 0 1 2914 0 0 0 10 0 0 1 0 0 0 0]
q).qc.check[g; {[fx;qs;fs] reset[]; day[fx;qs;fs]; s:raze .oms.slip[.oms.day0] each .oms.g.syms; o:.oms.order s`id; all 1e-6>abs s[`bps]-1e4*.oms.sgn'[o`side]*(s[`px]-o`arr)%o`arr}];
FAIL falsified after 0 tests, 0 shrinks (43 attempts, seed 7)
fx:
  time                          ccy rate
  -------------------------------------------
  2024.01.02D09:30:00.000000000 EUR 1.125
  2024.01.02D09:30:00.000000000 GBP 1.25
  2024.01.02D09:30:00.000000000 JPY 0.0078125
qs:
  time sym q
  ----------
fs: (();();())
length
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 3 9 1 0 0 2 5 1 0 0 7 1 0 0 0 0 0]
q)system"rm -rf ",1_string .oms.hdb

```

The round trip holds. The carry-over rule fails on a quote timed a nanosecond after the close: the generator's
session runs a little past 16:00, the rule compared with the mid *as of the close*, and the carry-over keeps the
last quote *seen*, which is later. The system is right and the rule was asking the wrong question; a quote after
the close is still the latest quote, and the rule now compares with the mid as of the latest time seen. The
slippage rule raises `length` on the first example, a day with no fills: `order f`id` indexes the keyed order table
with a list of ids, and a keyed table indexed by an empty list of keys raises `length` (a list of one key gives one
row; a table of keys, `order ([]id:f`id)`, gives a row for each and none for none). That was in `slip` and in the
rule, which used the same idiom.

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/07_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/08_orders.q"
q)system"l examples/oms/steps/08_gen.q"
q)system"l examples/oms/steps/13_pos.q"
q)system"l examples/oms/steps/13_gen.q"
q)system"l examples/oms/steps/16_ca.q"
q).oms.hdb:hsym `$first system"mktemp -d"
q)system"l examples/oms/steps/19_eod.q"
q).oms.inst:.oms.g.inst
q)reset:{.oms.order::0#.oms.order; .oms.fill::0#.oms.fill; .oms.seq::0; .oms.pos::0#.oms.pos; .oms.fxr::0#.oms.fxr; .oms.quote::0#.oms.quote; .oms.lq::0#.oms.lq; .oms.ca::0#.oms.ca; .oms.today::.oms.day0; system"rm -rf ",(1_string .oms.hdb),"/*"; if[count k:`execs`quote`fxr`order inter key `.; ![`.;();0b;k]]}
q)day:{[fx;qs;fs] .oms.onfx'[fx`time;fx`ccy;fx`rate]; qs:.oms.g.qs qs; .oms.onquote'[qs`time;qs`sym;qs`bid;qs`ask]; {[s;fl] {[s;f] lot:.oms.inst[s;`lot]; id:.oms.neworder[.oms.g.open+0D01;s;f 0;lot*f 1;.oms.g.inst[s;`tick]]; .oms.ack id; .oms.onfill[.oms.g.open+0D02;id;lot*f 1;f 2]}[s] each fl}'[.oms.g.syms;fs];}
q)g:(.oms.g.fx1;.oms.g.quotes;.oms.g.fillrun each .oms.g.syms)
q).qc.check[g; {[fx;qs;fs] reset[]; day[fx;qs;fs]; e:max .oms.g.close,.oms.quote`time; r0:.oms.rate[e;] each .oms.g.ccys; m0:.oms.mid[e;] each .oms.g.syms; .oms.eod .oms.day0; t:.oms.opn .oms.today; .qc.eq[(r0;m0); (.oms.rate[t;] each .oms.g.ccys; .oms.mid[t;] each .oms.g.syms)]}];
ok 100 tests (seed 7)
q).qc.check[g; {[fx;qs;fs] reset[]; day[fx;qs;fs]; s:raze .oms.slip[.oms.day0] each .oms.g.syms; o:.oms.order ([]id:s`id); all 1e-6>abs s[`bps]-1e4*.oms.sgn'[o`side]*(s[`px]-o`arr)%o`arr}];
FAIL falsified after 0 tests, 0 shrinks (43 attempts, seed 7)
fx:
  time                          ccy rate
  -------------------------------------------
  2024.01.02D09:30:00.000000000 EUR 1.125
  2024.01.02D09:30:00.000000000 GBP 1.25
  2024.01.02D09:30:00.000000000 JPY 0.0078125
qs:
  time sym q
  ----------
fs: (();();())
sgn
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 3 9 1 0 0 2 5 1 0 0 7 1 0 0 0 0 0]
q)system"rm -rf ",1_string .oms.hdb

```

`sgn`, for the third time in this log: `slip` computes the basis points in an `update`, and q-sql resolves a bare
name in the root. `.oms.sgn`, and the piece holds:

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/07_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/08_orders.q"
q)system"l examples/oms/steps/08_gen.q"
q)system"l examples/oms/steps/13_pos.q"
q)system"l examples/oms/steps/13_gen.q"
q)system"l examples/oms/steps/16_ca.q"
q).oms.hdb:hsym `$first system"mktemp -d"
q)system"l examples/oms/steps/20_eod.q"
q).oms.inst:.oms.g.inst
q)reset:{.oms.order::0#.oms.order; .oms.fill::0#.oms.fill; .oms.seq::0; .oms.pos::0#.oms.pos; .oms.fxr::0#.oms.fxr; .oms.quote::0#.oms.quote; .oms.lq::0#.oms.lq; .oms.ca::0#.oms.ca; .oms.today::.oms.day0; system"rm -rf ",(1_string .oms.hdb),"/*"; if[count k:`execs`quote`fxr`order inter key `.; ![`.;();0b;k]]}
q)day:{[fx;qs;fs] .oms.onfx'[fx`time;fx`ccy;fx`rate]; qs:.oms.g.qs qs; .oms.onquote'[qs`time;qs`sym;qs`bid;qs`ask]; {[s;fl] {[s;f] lot:.oms.inst[s;`lot]; id:.oms.neworder[.oms.g.open+0D01;s;f 0;lot*f 1;.oms.g.inst[s;`tick]]; .oms.ack id; .oms.onfill[.oms.g.open+0D02;id;lot*f 1;f 2]}[s] each fl}'[.oms.g.syms;fs];}
q)g:(.oms.g.fx1;.oms.g.quotes;.oms.g.fillrun each .oms.g.syms)
q).qc.check[g; {[fx;qs;fs] reset[]; day[fx;qs;fs]; s:raze .oms.slip[.oms.day0] each .oms.g.syms; o:.oms.order ([]id:s`id); all 1e-6>abs s[`bps]-1e4*.oms.sgn'[o`side]*(s[`px]-o`arr)%o`arr}];
ok 100 tests (seed 7)
q)system"rm -rf ",1_string .oms.hdb

```

## 12. Piece 7: the system as a whole, as a stateful test

The six pieces are assembled and driven by one stateful test. The model is the event log: the rates and quotes
seen, the orders placed with the arrival price each was given, the fills with the arrival price as it stood when
each was made, the clock and the day. The commands are a day's events: a rate, a quote, an order, an ack, a cancel,
a fill of some or all of what is left, a split before the first event of a day, and the close. The oracle
recomputes from the log, in the plainest way, what the system reports: the position of an instrument is the signed
sum of its fills; its profit in the base currency is what the fills cost or brought in, each converted as of its
time, plus the open quantity marked at the mid and the rate as of now, which is the cash the desk would count and
the question entry 9 left for here; a fill's slippage is against the arrival price its order had when the fill was
made. The invariant asks all three after every step, today from memory and every closed day from disk.

Writing the test met the trap of entry 11 again before it ran: `inst[sym;`ccy]` over the model's orders is
a keyed table indexed by a list, and raises `length` when the list is empty. And `sum` of nothing is `()`, not `0`,
so the oracle's sums are guarded; `ss`, a first name for the list of instruments, is a keyword. Then the first run:

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/07_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/08_orders.q"
q)system"l examples/oms/steps/08_gen.q"
q)system"l examples/oms/steps/12_sm.q"
q)system"l examples/oms/steps/13_pos.q"
q)system"l examples/oms/steps/13_gen.q"
q)system"l examples/oms/steps/16_ca.q"
q).oms.hdb:hsym `$first system"mktemp -d"
q)system"l examples/oms/steps/20_eod.q"
q)system"l examples/oms/steps/21_sm.q"
q).qc.check[.qc.sm[.oms.sys.hooks] .oms.sys.cmds; ::];
FAIL falsified after 1 tests, 0 shrinks (13 attempts, seed 7)
qc.inv length
step cmd arg                                res                                 ok
----------------------------------------------------------------------------------
0    fx  2024.01.02D09:30:00.000000000 `EUR 2024.01.02D09:30:00.000000000 1.125 1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 757503000000000000 0 0 3 9]
q).oms.pnl .oms.g.open
'length
q)system"rm -rf ",1_string .oms.hdb

```
The invariant raises `length` at the very first step, in `pnl`, asked before anything has been filled: `pos[s;`real]`
over an empty `s` is the same trap, in code from entry 9 whose rules always had fills to make positions from. A
table of keys, and `unreal` cast so that an empty report has typed columns:

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/07_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/08_orders.q"
q)system"l examples/oms/steps/08_gen.q"
q)system"l examples/oms/steps/12_sm.q"
q)system"l examples/oms/steps/22_pos.q"
q)system"l examples/oms/steps/13_gen.q"
q)system"l examples/oms/steps/16_ca.q"
q).oms.hdb:hsym `$first system"mktemp -d"
q)system"l examples/oms/steps/20_eod.q"
q)system"l examples/oms/steps/21_sm.q"
q).qc.check[.qc.sm[.oms.sys.hooks] .oms.sys.cmds; ::];
FAIL falsified after 12 tests, 13 shrinks (151 attempts, seed 7)
qc.inv qc.eq
path why   a b
--------------
0    value 0
0:
  step cmd   arg                                             res                                         ok
  ---------------------------------------------------------------------------------------------------------
  0    quote (2024.01.02D09:30:00.000000000;`A)              (2024.01.02D09:30:00.000000000;10f;10f)     1
  1    new   (2024.01.02D09:30:00.000000000;(`A;`buy;1;10f)) (2024.01.02D09:30:00.000000000;0;10f)       1
  2    ack   0                                               `ack                                        1
  3    fill  (2024.01.02D09:30:00.000000000;0;1;10f)         (2024.01.02D09:30:00.000000000;(`filled;0)) 1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 757503000000000000 0 0 0 10 0 0 0 1 2 0 1000 1 0 757503000000000000 1 3 0 1 5 0 757503000000000000 1 0 0 10]
q)system"rm -rf ",1_string .oms.hdb

```
The first fill of an instrument leaves its realised PnL null, the blank in the diff: `0^pos s` gave `onpos` zeros to
do arithmetic with, and the row it then made had a null in `real`. Piece 4's second rule had `0^` around `real`
because the position might not exist, and that forgave a null in one that did. The position is opened with zeros
before the first fill touches it:

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/07_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/08_orders.q"
q)system"l examples/oms/steps/08_gen.q"
q)system"l examples/oms/steps/12_sm.q"
q)system"l examples/oms/steps/23_pos.q"
q)system"l examples/oms/steps/13_gen.q"
q)system"l examples/oms/steps/16_ca.q"
q).oms.hdb:hsym `$first system"mktemp -d"
q)system"l examples/oms/steps/20_eod.q"
q)system"l examples/oms/steps/21_sm.q"
q).qc.check[.qc.sm[.oms.sys.hooks] .oms.sys.cmds; ::];
FAIL falsified after 33 tests, 71 shrinks (358 attempts, seed 7)
qc.inv qc.eq
path why   a     b
------------------
0    value -6.25 0
0:
  step cmd   arg                                               res                                       ok
  ---------------------------------------------------------------------------------------------------------
  0    fx    (2024.01.02D09:30:00.000000000;`EUR)              (2024.01.02D09:30:00.000000000;1.125)     1
  1    quote (2024.01.02D09:30:00.000000000;`B)                (2024.01.02D09:30:00.000000000;100f;100f) 1
  2    new   (2024.01.02D09:30:00.000000000;(`B;`buy;10;100f)) (2024.01.02D09:30:00.000000000;0;100f)    1
  3    ack   0                                                 `ack                                      1
  4    fill  (2024.01.02D09:30:00.000000000;0;1;100f)          (2024.01.02D09:30:00.000000000;(`part;9)) 1
  5    fx    (2024.01.02D09:30:00.000000001;`EUR)              (2024.01.02D09:30:00.000000001;1.0625)    1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 757503000000000000 0 0 3 9 1 1 757503000000000000 1 0 0 100 0 0 0 1 2 0 2000 1 0 757503000000000000 1 3 0 1 5 0 757503000000000000 1 0 0 100 1 0 757503000000000001 0 0 6 68]
q)system"rm -rf ",1_string .oms.hdb

```
The failure entry 9 predicted. `B` is in euros: a buy of one at 100 with the euro at 1.125 costs 112.50 dollars;
the euro falls to 1.0625 and the desk holds 106.25 dollars of stock, a loss of 6.25; the system marks in euros,
finds nothing to convert, and says 0. Six steps, and one thing to put right in the test before going on: the `fx`
and `quote` commands draw their values in `run`, `.qc.draw g.rate a 1`, so the model learns what a step did only
from the result, and `post` and `upd` are written backwards to read it. A step's inputs are what `gen` draws, where
the model can see them:

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/07_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/08_orders.q"
q)system"l examples/oms/steps/08_gen.q"
q)system"l examples/oms/steps/12_sm.q"
q)system"l examples/oms/steps/23_pos.q"
q)system"l examples/oms/steps/13_gen.q"
q)system"l examples/oms/steps/16_ca.q"
q).oms.hdb:hsym `$first system"mktemp -d"
q)system"l examples/oms/steps/20_eod.q"
q)system"l examples/oms/steps/24_sm.q"
q).qc.check[.qc.sm[.oms.sys.hooks] .oms.sys.cmds; ::];
FAIL falsified after 35 tests, 64 shrinks (345 attempts, seed 7)
qc.inv qc.eq
path why   a     b
------------------
0    value -6.25 0
0:
  step cmd   arg                                               res                                       ok
  ---------------------------------------------------------------------------------------------------------
  0    fx    (2024.01.02D09:30:00.000000000;`EUR;1.125)        1.125                                     1
  1    quote (2024.01.02D09:30:00.000000000;`B;100 100f)       100 100f                                  1
  2    new   (2024.01.02D09:30:00.000000000;(`B;`buy;10;100f)) (2024.01.02D09:30:00.000000000;0;100f)    1
  3    ack   0                                                 `ack                                      1
  4    fill  (2024.01.02D09:30:00.000000000;0;1;100f)          (2024.01.02D09:30:00.000000000;(`part;9)) 1
  5    fx    (2024.01.02D09:30:00.000000001;`EUR;1.0625)       1.0625                                    1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 757503000000000000 0 3 9 1 1 1 0 0 100 0 0 0 757503000000000000 1 2 0 2000 1 0 757503000000000000 1 3 0 1 5 0 757503000000000000 1 0 0 100 1 0 0 757503000000000001 0 6 68]
q)system"rm -rf ",1_string .oms.hdb

```
The same six steps. Now the decision the whole-system test was kept for. The rule the desk counts by is
cash: what was paid, at the rate of the day it was paid, against what the position is worth now. So the position
keeps `costb`, what its open quantity cost in the base, converted as of each fill; a fill that reduces it realises
what it brings in, less the share of `costb` it releases; unrealised is the open quantity marked and converted,
less `costb`. The average cost in the instrument's currency stays, for the desk to see.

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/07_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/08_orders.q"
q)system"l examples/oms/steps/08_gen.q"
q)system"l examples/oms/steps/12_sm.q"
q)system"l examples/oms/steps/25_pos.q"
q)system"l examples/oms/steps/13_gen.q"
q)system"l examples/oms/steps/16_ca.q"
q).oms.hdb:hsym `$first system"mktemp -d"
q)system"l examples/oms/steps/20_eod.q"
q)system"l examples/oms/steps/24_sm.q"
q).qc.check[.qc.sm[.oms.sys.hooks] .oms.sys.cmds; ::];
FAIL falsified after 53 tests, 69 shrinks (1415 attempts, seed 7)
qc.inv qc.eq
path why   a b
------------------
0    value 0 -6.25
0:
  step cmd   arg                                               res                                       ok
  ---------------------------------------------------------------------------------------------------------
  0    quote (2024.01.02D09:30:00.000000000;`B;100 100f)       100 100f                                  1
  1    eod   2024.01.02                                        1b                                        1
  2    fx    (2024.01.03D09:30:00.000000000;`EUR;1.125)        1.125                                     1
  3    eod   2024.01.03                                        1b                                        1
  4    fx    (2024.01.04D09:30:00.000000000;`EUR;1.125)        1.125                                     1
  5    eod   2024.01.04                                        1b                                        1
  6    new   (2024.01.05D09:30:00.000000000;(`B;`buy;10;100f)) (2024.01.05D09:30:00.000000000;0;100f)    1
  7    ack   0                                                 `ack                                      1
  8    eod   2024.01.05                                        1b                                        1
  9    fill  (2024.01.06D09:30:00.000000000;0;1;100f)          (2024.01.06D09:30:00.000000000;(`part;9)) 1
  10   fx    (2024.01.06D09:30:00.000000000;`EUR;1.0625)       1.0625                                    1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 0 0 100 0 0 0 757503000000000000 1 7 1 0 0 757589400000000000 0 3 9 1 7 1 0 0 757675800000000000 0 3 9 1 7 1 2 0 2000 1 0 757762200000000000 1 3 0 1 7 1 5 0 757848600000000000 1 0 0 100 1 0 0 757848600000000000 0 6 68]
q)system"rm -rf ",1_string .oms.hdb

```
The other way round now: the oracle says 0 and the system 6.25 down. The rate at step 10 arrives after the fill
but timed at the same instant, so "as of the fill" means one thing to the system when it books the fill and
another to an oracle that looks at the whole log afterwards. A fill is booked at the rate known when it is made,
and a rate that arrives later, timed at or before it, does not re-book it; that is a decision about the system, and
the oracle now records on each fill the rate it was booked at.

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/07_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/08_orders.q"
q)system"l examples/oms/steps/08_gen.q"
q)system"l examples/oms/steps/12_sm.q"
q)system"l examples/oms/steps/25_pos.q"
q)system"l examples/oms/steps/13_gen.q"
q)system"l examples/oms/steps/16_ca.q"
q).oms.hdb:hsym `$first system"mktemp -d"
q)system"l examples/oms/steps/20_eod.q"
q)system"l examples/oms/steps/26_sm.q"
q).qc.check[.qc.sm[.oms.sys.hooks] .oms.sys.cmds; ::];
FAIL falsified after 53 tests, 145 shrinks (1517 attempts, seed 7)
qc.inv qc.eq
path why   a b
---------------
0    value 0 20
0:
  step cmd    arg                                              res                                         ok
  -----------------------------------------------------------------------------------------------------------
  0    quote  (2024.01.02D09:30:00.000000000;`A;10 10f)        10 10f                                      1
  1    new    (2024.01.02D09:30:00.000000000;(`A;`buy;1;10f))  (2024.01.02D09:30:00.000000000;0;10f)       1
  2    new    (2024.01.02D09:30:00.000000000;(`A;`buy;2;10f))  (2024.01.02D09:30:00.000000000;1;10f)       1
  3    new    (2024.01.02D09:30:00.000000000;(`A;`sell;1;10f)) (2024.01.02D09:30:00.000000000;2;10f)       1
  4    cancel 0                                                `cxl                                        1
  5    ack    1                                                `ack                                        1
  6    ack    2                                                `ack                                        1
  7    fill   (2024.01.02D09:30:00.000000000;2;1;10f)          (2024.01.02D09:30:00.000000000;(`filled;0)) 1
  8    fill   (2024.01.02D09:30:00.000000000;1;2;10f)          (2024.01.02D09:30:00.000000000;(`filled;0)) 1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 0 0 0 10 0 0 0 757503000000000000 1 2 0 1000 1 0 757503000000000000 1 2 0 1000 2 0 757503000000000000 1 2 0 1000 1 1 757503000000000000 1 4 0 1 3 0 1 3 0 1 5 1 757503000000000000 1 0 0 10 1 5 0 757503000000000000 2 0 0 10]
q)system"rm -rf ",1_string .oms.hdb

```
Sell one `A` at 10, buy two at 10: no profit, and the system says 20. That is my arithmetic in the branch that goes
through zero: closing a short *costs*, so what closing the whole position brings in is `cur*pb`, negative for a
short, where I had written `neg[cur]*pb`.

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/07_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/08_orders.q"
q)system"l examples/oms/steps/08_gen.q"
q)system"l examples/oms/steps/12_sm.q"
q)system"l examples/oms/steps/27_pos.q"
q)system"l examples/oms/steps/13_gen.q"
q)system"l examples/oms/steps/16_ca.q"
q).oms.hdb:hsym `$first system"mktemp -d"
q)system"l examples/oms/steps/20_eod.q"
q)system"l examples/oms/steps/26_sm.q"
q).qc.check[.qc.sm[.oms.sys.hooks] .oms.sys.cmds; ::];
FAIL falsified after 69 tests, 39 shrinks (500 attempts, seed 7)
qc.inv qc.eq
path                 why   a b
----------------------------------
2024.01.02 `B `bps 0 value 0 10000
0:
  step cmd   arg                                               res                                       ok
  ---------------------------------------------------------------------------------------------------------
  0    fx    (2024.01.02D09:30:00.000000000;`EUR;1.125)        1.125                                     1
  1    quote (2024.01.02D09:30:00.000000000;`B;100 100f)       100 100f                                  1
  2    new   (2024.01.02D09:30:00.000000000;(`B;`buy;10;100f)) (2024.01.02D09:30:00.000000000;0;100f)    1
  3    ack   0                                                 `ack                                      1
  4    fill  (2024.01.02D09:30:00.000000000;0;1;100f)          (2024.01.02D09:30:00.000000000;(`part;9)) 1
  5    eod   2024.01.02                                        1b                                        1
  6    split (2024.01.03D09:30:00.000000000;`B;2)              2                                         1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 757503000000000000 0 3 9 1 1 1 0 0 100 0 0 0 757503000000000000 1 2 0 2000 1 0 757503000000000000 1 3 0 1 5 0 757503000000000000 1 0 0 100 1 7 1 6 1 2]
q)system"rm -rf ",1_string .oms.hdb

```
The bug that needs three pieces. A fill on the second at 100, the arrival price 100: no slippage. The next
morning `B` splits two for one, and piece 5 halves the open order's arrival price, as it should. Now the second's
slippage, read from disk, is 10,000 basis points: the fill is history and stays at 100, the order it is measured
against has moved. Pieces 3, 5 and 6 are each right alone; it took a fill, a close and a split, in that order, and
an invariant that asks about closed days after every step, not only at the close. The fill records the arrival
price its order had when it was made, on disk too, and slippage is against that:

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/07_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/28_orders.q"
q)system"l examples/oms/steps/08_gen.q"
q)system"l examples/oms/steps/12_sm.q"
q)system"l examples/oms/steps/27_pos.q"
q)system"l examples/oms/steps/13_gen.q"
q)system"l examples/oms/steps/16_ca.q"
q).oms.hdb:hsym `$first system"mktemp -d"
q)system"l examples/oms/steps/29_eod.q"
q)system"l examples/oms/steps/26_sm.q"
q).qc.check[.qc.sm[.oms.sys.hooks] .oms.sys.cmds; ::];
ok 100 tests (seed 7)
q).qc.chk[500;.qc.sm[.oms.sys.hooks] .oms.sys.cmds; ::];
FAIL falsified after 153 tests, 155 shrinks (2000 attempts, seed 7)
qc.inv qc.eq
path why   a                     b
------------------------------------------------------
0    value "0.49967586455335322" "0.49967586455329638"
0:
  step cmd   arg                                                  res                                        ok
  -------------------------------------------------------------------------------------------------------------
  0    fx    (2024.01.02D09:30:00.000000000;`JPY;0.007612151)     0.007612151                                1
  1    quote (2024.01.02D09:30:00.000000000;`C;1051.015 1051.015) 1051.015 1051.015                          1
  2    new   (2024.01.02D09:30:00.000000000;(`C;`buy;100;1000f))  (2024.01.02D09:30:00.000000000;0;1051.015) 1
  3    ack   0                                                    `ack                                       1
  4    fill  (2024.01.02D09:30:00.000000000;0;18;1002.5)          (2024.01.02D09:30:00.000000000;(`part;82)) 1
  5    fill  (2024.01.02D09:30:00.000000000;0;24;1084.666)        (2024.01.02D09:30:00.000000000;(`part;58)) 1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 2 757503000000000000 0 34 130775753 1 1 2 0 16 68879327 0 0 0 757503000000000000 1 2 0 1000 1 0 757503000000000000 1 3 0 1 5 0 757503000000000000 18 0 1 2005 1 5 0 757503000000000000 24 0 32 4658606647710]
q)system"rm -rf ",1_string .oms.hdb

```
A hundred sequences hold and five hundred do not: two partial fills in yen, and the oracle's profit and the
system's differ in the thirteenth decimal place. The oracle adds the fills up in one order and the system books them one
at a time; a profit in the base currency is compared to a millionth. With that, five hundred sequences, and a
count of what they reach:

```q
q)system"l examples/oms/steps/04_ref.q"
q)system"l examples/oms/steps/01_gen.q"
q)system"l examples/oms/steps/07_quotes.q"
q)system"l examples/oms/steps/05_gen.q"
q)system"l examples/oms/steps/28_orders.q"
q)system"l examples/oms/steps/08_gen.q"
q)system"l examples/oms/steps/12_sm.q"
q)system"l examples/oms/steps/27_pos.q"
q)system"l examples/oms/steps/13_gen.q"
q)system"l examples/oms/steps/16_ca.q"
q).oms.hdb:hsym `$first system"mktemp -d"
q)system"l examples/oms/steps/29_eod.q"
q)system"l examples/oms/steps/30_sm.q"
q).qc.chk[`v`n!(1;500); .qc.sm[.oms.sys.hooks] .oms.sys.cmds; {c:x`cmd; .qc.classify[`fill;`fill in c]; .qc.classify[`eod;`eod in c]; .qc.classify[`split;`split in c]; .qc.classify[`two_days;1<sum c=`eod]; .qc.classify[`fill_then_split;(`fill in c) and (`split in c) and first[where c=`fill]<last where c=`split]; .qc.classify[`split_then_fill;(`fill in c) and (`split in c) and last[where c=`fill]>first where c=`split]; 1b}];
ok 500 tests (seed 7)
label           n   pct  req lo       hi       ok bar
--------------------------------------------------------------
split           123 24.6     21.02804 28.55929 1  ####
eod             317 63.4     59.09035 67.50531 1  ############
fill            245 49       44.64254 53.37271 1  #########
two_days        204 40.8     36.57816 45.16213 1  ########
split_then_fill 76  15.2     12.31919 18.61148 1  ###
fill_then_split 23  4.6      3.084488 6.807827 1
q)system"rm -rf ",1_string .oms.hdb

```
Half the sequences fill something, a quarter split, two in five span more than one day, and one in twenty puts a
split after a fill, which is what found the last bug: in a hundred sequences, about five chances, and it was found
at the seventieth.

Two of the four bugs of this entry were in one piece each and were missed by that piece's own rules, `pnl` on no
positions and the null `real`, each hidden by a rule that started from a state the system does not start from, or
forgave a null. The third, the sign through zero, was in code written here, and piece 4's rule would have caught it
had it been run again; the whole-system test ran it for me. The fourth, the split that re-prices a closed day's
slippage, is in no piece. The stateful test asked the plain questions after every step, and the plain questions
found all four.
