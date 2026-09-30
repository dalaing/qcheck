# Building an order management system with qcheck

A small execution and positions system, of the kind a kdb+ desk has built before, is written a piece at a time and
tested with qcheck as it is written. There are six pieces, then the system as a whole. It is told in the order it
happened, wrong turns included: several of the failures below are mistakes in the tests rather than in the system,
and two of the bugs that matter most are found only when the pieces are put together.

You need q and nothing else. `README.md` explains the library in general; this document explains each idea from
the library at the point where the work first needs it, and no earlier. Each idea is named in **bold** the first
time it appears, and all of them are collected in a glossary at the end. If a section goes too fast, the glossary is
the place to look.

**The code.** Every change made along the way is kept as a file under `examples/oms/steps/`, numbered in the
order of the changes: `01_ref.q` is the reference data as first written and `02_ref.q` as first corrected. The
versions with bugs are kept on purpose, so that every session below still runs and still fails as shown. The
finished system is `examples/oms/oms.q`, its rules `examples/oms/props.q`, its whole-system test
`examples/oms/sm.q`, and `q examples/oms/run.q` runs them all. `examples/oms/LOG.md` is the log kept during the
work; this document is the same story, told for a reader who is new to this kind of testing.

**The sessions.** A block that shows a `q)` prompt is a q session of its own. To follow one at the keyboard, start
q in the repository root and type these two lines first:

```
\l qc.q
.qc.cfg[`db`seed]:(`;7i)
```

(The first line loads the library; the second turns off its memory of past failures, `db`, which the sessions do
not use, and fixes the seed, of which more in a moment.) What follows each `q)` line in a block is what q printed.
The library's own test suite runs every one of these sessions and requires the output shown, so nothing below is
retyped from memory. Each session begins by loading
`examples/oms/walk.q`, a file of helpers and of the rules themselves (each rule is a named function, shown in this
document where it is first used), and then `.oms.walk` with the names of the steps it needs, in order. A block that
begins with a comment naming a file is an excerpt of that file, and the suite checks that too, line for line.

## Property-based testing in two minutes

A test you have written before says: *for this input, expect this output*. A property-based test says something
more general: *for any input of this shape, this statement holds*. The library draws inputs of the shape, many of
them, runs the statement on each, and reports the first input for which it fails.

Two things are needed. A **generator** describes the shape of an input and knows how to draw one: `.qc.int 0 100`
is a generator of whole numbers from 0 to 100. A **property** is a function of the input that returns `1b` when
the statement holds. `.qc.check` puts them together:

```q
q).qc.check[.qc.int 0 100; {x<=100}];
ok 100 tests (seed 7)
```

A hundred draws, a hundred `1b`s, one line of report. Now a statement that is false for some inputs:

```q
q).qc.check[.qc.int 0 100; {x<90}];
FAIL falsified after 32 tests, 2 shrinks (13 attempts, seed 7)
x: 90
rerun: .qc.again[]  or  .qc.recheck[gen;prop;90]
```

Read the report line by line, because every report in this document has this shape.

- The first line says the property was *falsified*: some input made it return `0b`. "After 32 tests" means 32
  inputs passed before one failed. The library does not stop there: it looks for a *simpler* input that also
  fails, and again, until it cannot; "2 shrinks (13 attempts)" says it tried 13 simpler inputs and two of them
  still failed. This is **shrinking**.
- The next lines are the input that failed, after shrinking, named as the property's parameter: `x: 90`. This is
  the **counterexample**. The first failing input was some number of 90 or more; the smallest that fails is 90,
  and that is what is reported. Shrinking is what turns a failure into a diagnosis: the smallest input that fails
  is usually the one that explains the bug, and here it says, as plainly as a number can, that the statement
  stops holding at 90.
- An error inside the property counts as a failure too. The report still says `FAIL falsified`, the input is
  still shown, and the error's name stands where a message about the result would be. We will see that in the
  first piece.
- The last line is for the reader at the keyboard. Every run is driven by a **seed**; the sessions in this
  document all use seed 7, so their reports come out the same every time. After a failure, `.qc.again[]` runs the
  failing input once more, which is how you see that a fix worked. The line adds nothing for a reader, so the
  sessions from here on leave it out (`walk.q` sets ``.qc.cfg[`rerun]:0b``).

That is the whole idea. Everything else in this document is what it looks like when the inputs are tables of
quotes and rates, the statements are about a trading system, and the system is being written at the same time.

## The system

An order management system for a desk that trades a few instruments in several currencies. Six pieces:

| piece | what it does |
|---|---|
| 1. reference data and FX | the instruments with their currency, lot and tick; rates as a time series; a conversion to the base currency as of a time |
| 2. quotes | quotes as they arrive; the mid as of a time; a cache of the latest quote |
| 3. orders and fills | an order's life follows a transition table; fills reduce what is left |
| 4. positions and PnL | signed quantity and average cost per instrument; realised and unrealised profit in the base currency |
| 5. corporate actions | a stock split adjusts positions and open orders |
| 6. end of day | the day is written to a partitioned database; queries span memory and disk; slippage per fill |

Some of the shape was decided before any code, so that the pieces would not fight it later:

- the instruments are a keyed table `inst`, keyed on `sym`, and event tables carry `sym` as a plain symbol;
- quotes are their own table, and a price "as of" a time is an as-of join (`aj`) against them at the time it is
  asked for, never a column copied onto other events;
- FX rates are a time series, and a conversion uses the rate as of the time of the thing converted;
- orders are a keyed table keyed on the order id, and follow a transition table that is written down *as a table*;
- on disk each day is a date partition, `sym` parted, rows in time order within a symbol.

One thing was left open on purpose. Profit is computed in the instrument's currency and converted to the base.
Suppose the desk buys a stock priced in euros, the euro then falls against the dollar, and the stock's euro price
does not move: has the desk lost money? In dollars it has; in euros it has not; and *which rate converts what* was
called a question for the test of the whole system rather than for any piece. Remember that; it comes back in the
last part.

Everything lives in the `.oms` namespace. The base currency is USD, held in the variable `base`.

## Piece 1: reference data and FX

### What the piece does

Two tables and three functions. `inst` holds the instruments, keyed on `sym`, with the currency each trades in,
its lot size and its tick. `fxr` holds the rates as they arrive, a time series of USD per unit of currency.
`rate[t;c]` answers the rate of currency `c` as of time `t`, meaning the last rate seen at or before `t`; it is an
as-of join of the `(ccy; time)` asked for against the rates in time order, with the base currency's rate fixed at 1.
`tobase[t;c;amt]` converts an amount.

```q
/ examples/oms/steps/01_ref.q
inst:([sym:`symbol$()] ccy:`symbol$(); lot:`long$(); tick:`float$())
fxr:([]time:`timestamp$(); ccy:`symbol$(); rate:`float$())
onfx:{[t;c;r] `.oms.fxr insert (t;c;r);}                                              / a rate seen: appended, in arrival order
rate:{[t;c] r:aj[`ccy`time; ([]ccy:c; time:t); `ccy`time xasc fxr]; @[r`rate; where c=base; :; 1f]}   / the rate as of each time asked for; the base is 1
tobase:{[t;c;amt] amt*rate[t;c]}                                                       / an amount in ccy at time t, in USD
```

### Generators for the inputs

To test this we need rates. Not one rate table, but *rate tables in general*: any number of rows, in time order,
each currency's rate somewhere sensible. That is a generator, and here is what one draw of it looks like:

```q
q)system"l examples/oms/walk.q"
q).oms.walk`01_ref`01_gen
q).qc.draw .oms.g.fx
time                          ccy rate
---------------------------------------------
2024.01.02D16:00:00.000000000 GBP 1.278356
2024.01.02D16:00:00.027621806 EUR 1.120991
2024.01.02D16:00:00.039225094 JPY 0.006835938
2024.01.02D16:05:00.039225094 GBP 1.288785
2024.01.02D16:05:00.054941157 JPY 0.00625062
```

`.qc.draw g` draws one value from a generator, which is the quickest way to see what a generator makes. This one,
`g.fx`, is built from smaller generators:

```q
/ examples/oms/steps/01_gen.q
g.day:2024.01.02
g.open:g.day+0D09:30; g.close:g.day+0D16:00
g.ccys:`EUR`GBP`JPY
g.rates:`EUR`GBP`JPY!(1.05 1.15; 1.2 1.35; 0.006 0.008)                               / USD per unit, roughly where they were
g.rate:{[c] .qc.flt g.rates c}
g.fx:.qc.tabr[0 20] `time`ccy`rate!(.qc.mono[.qc.ts[g.open;g.close];.qc.int (0;"j"$0D00:05)]; .qc.elem g.ccys; .qc.dep {[r] .oms.g.rate r`ccy})   / rates in time order, each in its currency's range
g.t:.qc.ts[g.open;g.close]
g.amt:.qc.flt -1000 1000
```

Take `g.fx` a part at a time. `.qc.tabr[0 20] cols` makes a generator of a table with 0 to 20 rows, given a
generator for each column. For the `ccy` column, `.qc.elem g.ccys` draws one of the three currencies. For `time`,
`.qc.ts[g.open;g.close]` would draw any timestamp in the session, and `.qc.mono[...; step]` wraps it so that the
column never goes backwards: each row's time is the previous one plus a step of up to five minutes (`.qc.int` with
a pair is a generator of whole numbers in that range, here of nanoseconds). For `rate`, `.qc.dep f` says the
column depends on the rest of its row: `f` is given the row so far and returns what to draw the column from,
here `g.rate` of the row's currency, which is `.qc.flt` over that currency's range, a float between two bounds. So
a draw is a table of rates in time order with each rate where its currency lives, which is what the printed table
shows. `g.t` is a time in the session and `g.amt` an amount.

One definition to carry forward, since the generators from here on are increasingly written by hand. A generator
is anything the library can apply to no arguments to get a value. Its own, like `.qc.flt 1.05 1.15`, are functions
built to be used that way. A function of your own that draws with `.qc.draw` and computes is one too: applied to
nothing it returns a value, and the draws it made on the way are recorded with the rest and shrink with the rest.
Even a plain value serves, since a list applied to nothing is itself.

### The first rule, and a failure that was not a bug

The simplest statement about the piece: a USD amount is its own conversion. It needs a time and an amount, so
there are two generators in a list, and the property takes two parameters, filled in the same order.

```q
q)system"l examples/oms/walk.q"
q).oms.walk`01_ref`01_gen
q).qc.check[(.oms.g.t;.oms.g.amt); {[t;a] a=.oms.tobase[t;`USD;a]}];
FAIL falsified after 0 tests, 0 shrinks (5 attempts, seed 7)
t: 2024.01.02D09:30:00.000000000
a: 0f
rank
```

The property did not return `0b`; it did not return at all. `rate` raised `rank` on the very first input (the
report says "after 0 tests"), and the report shows the input and, where a result would be, the error. The input is
`t` at the open and `a` of `0f`, the simplest values of their generators: the library draws small inputs first
and larger ones as the run goes on, so the first failure is often the simplest.

`([]ccy:c; time:t)` builds a table from two atoms, and q refuses: a table's columns are lists. So the first thing
the property found was that `rate` had never been called with an atom. The fix accepts atoms or lists, `(),c` and
`(),t`, and gives an atom back when an atom was asked. This is worth noticing early: the first thing a property
finds is very often a mistake in the code's assumptions about its inputs, not in its logic, and a property that
cannot even run is still telling you something.

```q
/ examples/oms/steps/02_ref.q
rate:{[t;c] r:aj[`ccy`time; ([]ccy:(),c; time:(),t); `ccy`time xasc fxr]; r:@[r`rate; where base=(),c; :; 1f]; $[0>type t; first r; r]}   / the rate as of each time asked for, atoms or lists; the base is 1
```

### An oracle

Three rules then pass. The second is the important one, and it introduces a habit that runs through the whole
document. `rate` is an as-of join, which is fast and easy to get subtly wrong, so it is compared with a slow and
obvious way of asking the same question: `lastrate`, an `exec` that finds the last rate at or before the time. The
obvious version is called an **oracle**: a second way of computing the answer, plain enough to be trusted, against
which the real code is checked. `.qc.eq[a;b]` compares two values and returns `1b` when they match; when they do
not, it fails the property and adds a small table to the report saying where they differ.

From here on the rules are named functions in `walk.q`, written over a few lines so that they can be read, and a
session calls them by name. Here are the two:

```q
/ examples/oms/walk.q
lastrate:{[f;t;c] $[count r:exec rate from f where ccy=c,time<=t; last r; 0n]}   / the rate as of t by the obvious exec: the last one at or before t, null if none
rate_is_last_seen:{[f;t;c] .oms.fxr::f;                                       / the drawn rates become the system's
  .qc.eq[.oms.rate[t;c]; lastrate[f;t;c]]}
there_and_back:{[f;t;c;a] .oms.fxr::f; r:.oms.rate[t;c];
  $[null r; 1b; 1e-9>abs a-.oms.tobase[t;c;a]%r]}                            / (no rate yet: the rule steps around it)
```

```q
q)system"l examples/oms/walk.q"
q).oms.walk`02_ref`01_gen
q).qc.check[(.oms.g.t;.oms.g.amt); {[t;a] a=.oms.tobase[t;`USD;a]}];
ok 100 tests (seed 7)
q).qc.check[(.oms.g.fx;.oms.g.t;.qc.elem .oms.g.ccys); rate_is_last_seen];
ok 100 tests (seed 7)
q).qc.check[(.oms.g.fx;.oms.g.t;.qc.elem .oms.g.ccys;.oms.g.amt); there_and_back];
ok 100 tests (seed 7)
```

Two things to notice in the rules. They install the drawn rate table as the piece's own, `.oms.fxr::f`, before
asking, because that is how the system will see it (a rule that tests a piece of state has to put the state in
place). And `there_and_back` steps around the case where there is no rate yet: `$[null r; 1b; ...]`. That is a
question the piece has not answered, and stepping around a case in a test is a reliable sign that the code has
not decided it either.

### A rule about refusing, and a rule that passed for the wrong reason

What should a conversion do before any rate has been seen for the currency? As written, it returns a null, and a
null amount would flow on into a position's profit and print as a blank. The decision: a conversion with no rate is
*refused*, with an error, and one with a rate is a number. A property can say that, with a small helper `call`
that runs a function and reports either `(1b; result)` or `(0b; error message)`:

```q
/ examples/oms/walk.q
call:{[f;x] @[{(1b;y . x)}[;f];x;{(0b;x)}]}                                   / (1b; result) if f . x returns, (0b; message) if it signals
refused_without_a_rate:{[f;t;c;a] .oms.fxr::f; r:call[.oms.tobase;(t;c;a)];
  $[null .oms.rate[t;c]; not r 0; (r 0) and not null r 1]}                     / no rate: refused, any error counting; a rate: a number
```

```q
q)system"l examples/oms/walk.q"
q).oms.walk`02_ref`01_gen
q).qc.check[(.oms.g.fx;.oms.g.t;.qc.elem .oms.g.ccys;.oms.g.amt); refused_without_a_rate];
FAIL falsified after 0 tests, 0 shrinks (6 attempts, seed 7)
f:
  time ccy rate
  -------------
t: 2024.01.02D09:30:00.000000000
c: `EUR
a: 0f
```

It fails on the first input, the empty rate table (`f:` with no rows under it), which is exactly the case: no
rate, and the conversion did not refuse. `tobase` now signals where the rate is null, naming the currency and the
time. The rule passes. Then a call by hand, to see the message:

```q
q)system"l examples/oms/walk.q"
q).oms.walk`03_ref`01_gen
q).qc.check[(.oms.g.fx;.oms.g.t;.qc.elem .oms.g.ccys;.oms.g.amt); refused_without_a_rate];
ok 100 tests (seed 7)
q).oms.fxr:0#.oms.fxr
q).oms.tobase[2024.01.02D10:00;`EUR;100f]
'type
```

`'type`, not the message. Building the message does `where null r`, and `r` is the atom that `rate` returns when
an atom was asked; `where` takes a list, and the code falls over before it can say anything. The rule said
"refused", any error counts as a refusal, so the rule was satisfied by a crash. This is the second lesson of the
piece, and it is about writing properties rather than about q: **say what the answer must be, not only that there
is one**. The rule that would have caught it checks the message:

```q
/ examples/oms/walk.q
refused_by_name:{[f;t;c;a] .oms.fxr::f; r:call[.oms.tobase;(t;c;a)];
  $[null .oms.rate[t;c]; (not r 0) and (r 1) like "oms: no rate for *"; (r 0) and not null r 1]}   / no rate: refused, and the message says so
```

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen
q).qc.check[(.oms.g.fx;.oms.g.t;.qc.elem .oms.g.ccys;.oms.g.amt); refused_by_name];
ok 100 tests (seed 7)
q).oms.fxr:0#.oms.fxr
q).oms.tobase[2024.01.02D10:00;`EUR;100f]
'oms: no rate for EUR at 2024.01.02D10:00:00.000000000
```

Piece 1 is done: five rules, and three steps of the code changed under them. Everything so far was a generator,
a property and `.qc.check`, with an oracle inside one of the properties.

## Piece 2: quotes, and a price as of a time

### What the piece does

Quotes arrive and are appended to `quote`. The benchmark price of an instrument as of a time is its *mid*, half
of bid plus ask, taken from the last quote at or before that time: `mid[t;s]` is an as-of join against the quotes
in time order, the same shape as `rate`. Because callers often want the price *now* and would rather not join for
it, the piece also keeps a cache `lq` of the latest quote per instrument, updated as quotes arrive, and `now[s]`
reads it.

```q
/ examples/oms/steps/05_quotes.q
quote:([]time:`timestamp$(); sym:`symbol$(); bid:`float$(); ask:`float$())
lq:([sym:`symbol$()] time:`timestamp$(); bid:`float$(); ask:`float$())
onquote:{[t;s;b;a] `.oms.quote insert (t;s;b;a); `.oms.lq upsert (s;t;b;a);}       / appended, and the cache takes it as the last
midof:{[b;a] 0.5*b+a}
mid:{[t;s] r:aj[`sym`time; ([]sym:(),s; time:(),t); `sym`time xasc quote]; m:midof[r`bid;r`ask]; $[0>type t; first m; m]}   / the mid as of each time asked, null before the first quote
now:{[s] midof[lq[s;`bid];lq[s;`ask]]}                                                / the mid of the last quote seen
```

The generator draws a session of quotes in time order for three instruments, `A`, `B` and `C`, each in its own
price range and with the ask at or above the bid. `g.quote` draws the `(bid; ask)` pair for one instrument and
returns it as a value, which is all `.qc.dep` needs; `g.qs` turns the drawn rows into a table shaped like `quote`.

```q
/ examples/oms/steps/05_gen.q
g.syms:`A`B`C
g.px:`A`B`C!(10 20; 100 110; 1000 1100)
g.quote:{[s] b:.qc.draw .qc.flt g.px s; (b; b+.qc.draw .qc.flt 0 1)}                  / a bid in the instrument's range and an ask at or above it
g.quotes:.qc.tabr[0 20] `time`sym`q!(.qc.mono[.qc.ts[g.open;g.close];.qc.int (0;"j"$0D00:01)]; .qc.elem g.syms; .qc.dep {[r] .oms.g.quote r`sym})
g.qs:{[t] select time, sym, bid:q[;0], ask:q[;1] from t}                              / the quote table from a draw
```

Two rules, both against an oracle: the mid as of a time agrees with the obvious `select`, and the cache agrees
with the join as of the latest time in the session (the close, or the last quote's time if the session ran past
it). `feed` empties the tables and sends the quotes through `onquote` one at a time, which is how the system will
receive them.

```q
/ examples/oms/walk.q
feed:{[t] .oms.quote::0#.oms.quote; .oms.lq::0#.oms.lq; .oms.onquote'[t`time;t`sym;t`bid;t`ask];}   / a session of quotes, from empty, one at a time
naive:{[q;t;s] $[count r:select from q where sym=s,time<=t; .oms.midof[last r`bid;last r`ask]; 0n]}   / the mid as of t by the obvious select
mid_is_naive:{[q;t;s] q:.oms.g.qs q; feed q;                                   / (g.qs turns the drawn rows, with their (bid;ask) pair, into a quote table)
  .qc.eq[.oms.mid[t;s]; naive[q;t;s]]}
cache_is_latest:{[q;s] q:.oms.g.qs q; feed q;
  .qc.eq[.oms.now s; .oms.mid[max .oms.g.close,q`time;s]]}                    / the cache is the mid as of the latest time in the session
```

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen`05_quotes`05_gen
q).qc.check[(.oms.g.quotes;.oms.g.t;.qc.elem .oms.g.syms); mid_is_naive];
ok 100 tests (seed 7)
q).qc.check[(.oms.g.quotes;.qc.elem .oms.g.syms); cache_is_latest];
ok 100 tests (seed 7)
```

Both pass. And both are weaker than they look, for a reason that is worth slowing down for.

### Why a second kind of test is needed

Both rules feed the quotes *in time order*, because that is the order the generator draws them in. A real feed
does not always: a tick can arrive after one that was timed later than it. The cache is a piece of state, every
quote changes it, and whether it is right depends on the *sequence* of quotes that reached it, not on any one of
them. A property that draws one table and asks one question cannot easily say "for any sequence of events, in
any order, after each one the cache is right".

That is what a **stateful test** is for. Instead of one input and one question, the library draws a *sequence of
commands*, runs them one at a time against the system, and after each one checks that the system agrees with a
**model**: a plain description of what the system's state ought to be, kept by the test itself and updated by the
test after every command. For the cache, the model is simply the quotes seen so far and the clock.

Before the code, the shape of it in words. A command is described in five parts, each a function. Given the
model: *may this command run now?* (`pre`); *what input shall it have?* (`gen`, which answers with a generator).
Given the input: *do it to the system* (`run`). Given the model, the input and what `run` returned: *was the
result right?* (`post`); *what is the model now?* (`upd`). The library draws a sequence by repeatedly picking a
command whose `pre` holds, drawing its input, running it, checking `post` and applying `upd`. If that reads like a
description of how you would test the cache by hand, one quote at a time, that is the point.

The five parts of each command are the columns of a **command table**, one row per command. Here is the one for
the cache; read it a column at a time, with the notes below.

```q
/ examples/oms/steps/06_sm.q
q.m0:`now`q!(g.open; 0#quote)
q.init:{quote::0#quote; lq::0#lq}
q.cmds:([cmd:`quote`late]
  w:   4 1f;
  pre: ({[m] 1b}; {[m] 0<count m`q});
  gen: ({[m] (.qc.ts[m`now;m[`now]+0D00:01]; .qc.elem g.syms; .qc.elem g.syms)};   / time sym (the third is unused: see g.quote)
        {[m] (.qc.ts[g.open;m`now]; .qc.elem g.syms; .qc.elem g.syms)});
  run: ({[a] q:g.quote a 1; onquote[a 0;a 1;q 0;q 1]; (a 0;a 1;q 0;q 1)};
        {[a] q:g.quote a 1; onquote[a 0;a 1;q 0;q 1]; (a 0;a 1;q 0;q 1)});
  post:({[m;a;o] now[o 1]=mid[max m[`now],o 0; o 1]};
        {[m;a;o] now[o 1]=mid[m`now; o 1]});
  upd: ({[m;a;o] m[`now]:o 0; m[`q],:enlist `time`sym`bid`ask!o; m};
        {[m;a;o] m[`q],:enlist `time`sym`bid`ask!o; m}))
q.hooks:`m0`init!(q.m0;q.init)
```

- There are two commands, `quote` and `late`, one row each. `w` weights them: four quotes for every late one.
- `pre`: a late quote needs something to be late *after*, so `late` waits until the model has seen a quote.
- `gen`: a list of generators is itself a generator, of a list of values, so `quote`'s input is a time at or
  after the clock and an instrument, and `late`'s a time at or before the clock and an instrument. (The third
  value drawn is never used; it was a slip in writing the table, left as it was.)
- `run` sends the input to the system and returns what it sent. Here it also draws the bid and ask, with
  `g.quote`; that is allowed, but the model can only learn of a value drawn in `run` from what `run` returns,
  which is why `run` returns the whole quote. The finished tests draw everything in `gen`, where the model sees it.
- `post`: the cache's mid for the instrument equals the mid as of the latest time seen, which is what the join
  gives. `post` sees the model *before* the step, the input, and what `run` returned. (For `late` the latest time
  is the clock; for `quote` it may be the new quote's time, hence the `max`.)
- `upd` moves the model forward: the clock, and the quote appended.

Two more things sit outside the table. `q.m0` is the model to start from, the clock at the open and no quotes, and
`q.init` is a function that resets the system to match; the library runs `init` before every sequence, so that
every sequence starts from the same place. Values and functions like these, which are not commands but which the
library uses around them, are the test's **hooks**, given as a dictionary; a third kind, checked after every step,
arrives in the last part.

`.qc.sm[hooks] cmds` turns the table into a generator whose value is the sequence that ran, and `.qc.check` runs it
like any other generator. The property given to `.qc.check` is `::`, meaning "nothing further to check": the
checks are in `post`, and the library treats a failed `post` as a failed property. A sequence that fails is
reported as a **trace**: the steps it took, in order, with the one that failed marked.

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen`05_quotes`05_gen`06_sm
q).qc.check[.qc.sm[.oms.q.hooks] .oms.q.cmds; ::];
FAIL falsified after 6 tests, 27 shrinks (96 attempts, seed 7)
qc.post
step cmd   arg                                 res                                      ok
------------------------------------------------------------------------------------------
0    quote 2024.01.02D09:30:00.000000001 `A `A 2024.01.02D09:30:00.000000001 `A 10f 10f 1
1    late  2024.01.02D09:30:00.000000000 `A `A 2024.01.02D09:30:00.000000000 `A 10f 11f 0
```

Read the report the same way as before. `FAIL falsified`, six sequences passed, and the failing one was shrunk 27
times. The line under it, `qc.post`, says *which check* failed: a postcondition. Then the trace. Two steps, after
shrinking: a quote for `A` a nanosecond after the open, then a quote for `A` timed *at* the open, arriving second.
The cache holds the late one, because `onquote` takes every quote as the latest; the join holds the one timed
later; they disagree in the ask, and `ok` is `0` on the second step. Nothing shorter can show it, and that is what
a shrunk trace is: the smallest sequence of events that reproduces the bug.

The fix is one condition: the cache takes a quote only if its time is not before the cached one. Then five
hundred sequences, to be sure; `.qc.chk[n; g; p]` is `.qc.check` with the number of tests given.

```q
/ examples/oms/steps/07_quotes.q
onquote:{[t;s;b;a] `.oms.quote insert (t;s;b;a); if[t>=lq[s;`time]; `.oms.lq upsert (s;t;b;a)];}   / appended; the cache takes it unless an earlier-timed one arrived late (a null time in the cache compares low)
```

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen`07_quotes`05_gen`06_sm
q).qc.chk[500;.qc.sm[.oms.q.hooks] .oms.q.cmds; ::];
ok 500 tests (seed 7)
```

What to take from piece 2: a property with a table for input tests a *result*; a stateful test tests a piece of
*state* through a sequence of events. The second is more work to set up, and the trace it gives back is
correspondingly more useful. We will meet it twice more.

## Piece 3: orders and fills

### What the piece does

An order is a row of a keyed table `order`, keyed on its id, with its side, quantity, limit price, state and
`leaves`, what is left to fill. Its life follows a **transition table**, `T`: a state and an event give the next
state, and an event with no row is refused. This table is the specification, written down as data, and `D` is
the same table as a dictionary of dictionaries so that `D[state;event]` is the next state, or a null.

```q
/ examples/oms/steps/08_orders.q
T:([st:`new`new`new`ack`ack`ack`part`part`part; ev:`ack`rej`cxl`fill`part`cxl`fill`part`cxl] nx:`ack`rej`cxl`filled`part`cxl`filled`part`cxl)
D:exec ev!nx by st from T
order:([id:`long$()] time:`timestamp$(); sym:`symbol$(); side:`symbol$(); qty:`long$(); px:`float$(); st:`symbol$(); leaves:`long$(); arr:`float$())
fill:([]time:`timestamp$(); id:`long$(); sym:`symbol$(); qty:`long$(); px:`float$())
```

A new order is checked against the reference data on the way in (the instrument exists, the quantity is a
multiple of its lot, the limit is on its tick), and its *arrival price*, the mid as of its time, is kept for the
execution analysis in piece 6. `ack`, `reject` and `cancel` move it through the table; `onfill` reduces `leaves`,
moves it to `part` or `filled`, and appends a row to `fill`.

Three rules for the piece on its own: an order comes out as it went in; a quantity off the lot or a price off the
tick is refused; and after any run of fills, the fills sum to what was filled and the state says whether anything
is left. The generators draw an order for one of the three instruments of a small reference table of the test's
own, `g.inst`, which `.oms.walk` installs as the system's `inst`.

```q
/ examples/oms/steps/08_gen.q
g.inst:([sym:`A`B`C] ccy:`USD`EUR`JPY; lot:1 10 100; tick:0.01 0.05 1f)
g.side:.qc.elem `buy`sell
g.qty:{[s] g.inst[s;`lot]*.qc.draw .qc.int 1 20}                                       / draws lots of the instrument
g.lim:{[s] t:g.inst[s;`tick]; t*.qc.draw .qc.int "j"$(g.px s)%t}                        / draws a limit price on the tick, in the instrument's range
g.order:{s:.qc.draw .qc.elem g.syms; (s; .qc.draw g.side; g.qty s; g.lim s)}            / sym side qty px
```

`g.qty` and `g.lim` are generators written as functions, in the sense of piece 1: a quantity that must be a
multiple of the lot is a number of lots drawn, with `.qc.draw`, and then multiplied. (The first version multiplied
the *generator* by the lot, `.qc.int[1 20]*lot`, and q duly tried to multiply a function by a number.)

```q
/ examples/oms/walk.q
fx0:([]time:3#2024.01.02D09:30; ccy:`EUR`GBP`JPY; rate:1.1 1.3 0.007)          / one rate per currency, at the open: piece 1 tested the rates, these pieces only need some
reset:{{[n] if[n in key `.oms; (` sv `.oms,n) set 0#get ` sv `.oms,n]} each `order`fill`pos`quote`lq`ca; .oms.seq::0; .oms.fxr::fx0}   / every table the loaded pieces have, empty; the rates fx0
new_is_new:{[t;a] reset[]; id:.oms.neworder[t;a 0;a 1;a 2;a 3]; o:.oms.order id;   / a is (sym; side; qty; px)
  (o[`st]=`new) and (o[`leaves]=a 2) and (o[`sym]=a 0) and o[`px]=a 3}
lot_and_tick:{[t;a;dq;dp] reset[];                                             / dq shares more, dp more on the price
  r:@[{.oms.neworder . x; 1b};(t;a 0;a 1;(a 2)+dq;a 3);{0b}];                  / accepted?
  s:@[{.oms.neworder . x; 1b};(t;a 0;a 1;a 2;(a 3)+dp);{0b}];
  (r=0=dq mod .oms.g.inst[a 0;`lot]) and s=.oms.ontick[a 0;(a 3)+dp]}          / accepted exactly when on the lot, exactly when on the tick
fq:.qc.lst[0 5] .qc.int 1 5                                                    / a run of fills, in lots
fills_add_up:{[t;a;fs] reset[]; oid:.oms.neworder[t;a 0;a 1;a 2;a 3]; .oms.ack oid; lot:.oms.g.inst[a 0;`lot];
  {[t;oid;lot;q] o:.oms.order oid; if[(o[`leaves]>0) and (q*lot)<=o`leaves; .oms.onfill[t;oid;q*lot;o`px]]}[t;oid;lot] each fs;   / each fill that fits
  o:.oms.order oid; f:select from .oms.fill where id=oid;
  ((o[`qty]-o`leaves)=sum f`qty) and o[`st]=$[o[`leaves]=0; `filled; count[f]>0; `part; `ack]}
```

`reset` empties every table the loaded pieces have (`seq` is the order id counter, `ca` the record of splits, from
piece 5) and gives the system one rate per currency, `fx0`: piece 1
tested the rates, and from here on the rules only need some. `neworder`, `ack` and `onfill` are the piece's
functions; `ontick` is its check that a price is on the instrument's tick. `fq`, a run of one to five fills each of
one to five lots, is `.qc.lst[0 5] g`, a list of zero to five draws of `g` (`fills` is a keyword, the forward
fill, so it could not be called that).

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen`07_quotes`05_gen`08_orders`08_gen
q).qc.check[(.oms.g.t;.oms.g.order); new_is_new];
ok 100 tests (seed 7)
q).qc.check[(.oms.g.t;.oms.g.order;.qc.int 1 9;.qc.flt 0 0.009); lot_and_tick];
ok 100 tests (seed 7)
q).qc.check[(.oms.g.t;.oms.g.order;fq); fills_add_up];
ok 100 tests (seed 7)
```

All three pass first time. That is pleasant but not very informative: each rule runs one fixed shape of sequence
(place, ack, fill some). The lifecycle is a state machine in the plain sense of the words, and a stateful test is
the tool that fits it.

### The lifecycle as a stateful test

The model this time is a table: the orders the test has placed, with the state and the `leaves` each ought to
have. The commands are the events. Each chooses, from the model, an order on which `T` allows the event; that is
what `pre` asks, so a command whose event no order can take does not run. `post` asks the system whether the
order's state is now what `D` says, and whether `leaves` is what the arithmetic says. Three commands are about
fills: `fill` fills all of what is left, `part` some of it, and `over` tries to fill more than is left, which must
be refused and change nothing. The full table is in `12_sm.q` and is shaped like piece 2's; shown here are its
helpers, its header, its `gen` column and its hooks, not the whole file.

```q
/ examples/oms/steps/12_sm.q
o.m0:([id:`long$()] st:`symbol$(); leaves:`long$(); qty:`long$())
o.init:{order::0#order; fill::0#fill; seq::0}
o.nx:{[st;ev] {.oms.D[x;y]}'[st;ev]}                                                / the next state of each, one at a time: D[st;ev] over a list fails where a state has no row
o.can:{[m;ev] exec id from m where not null .oms.o.nx[st;ev]}                        / the orders the event is allowed on (q-sql resolves a bare name in the root, so the names are spelled out)
o.canp:{[m] exec id from m where not null .oms.o.nx[st;`part], leaves>1}            / and a partial fill needs something left after it
o.pick:{[m;ev] .qc.elem o.can[m;ev]}
o.cmds:([cmd:`new`ack`reject`cancel`fill`part`over]
  w:   3 3 1 1 2 2 1f;
  pre: ({[m] 1b}; {[m] 0<count o.can[m;`ack]}; {[m] 0<count o.can[m;`rej]}; {[m] 0<count o.can[m;`cxl]}; {[m] 0<count o.can[m;`fill]}; {[m] 0<count o.canp m}; {[m] 0<count o.can[m;`fill]});
  gen: ({[m] (.qc.const g.order[]; g.t)};                                              / (the tuple is drawn as the generator is built: one order per step)
        {[m] o.pick[m;`ack]}; {[m] o.pick[m;`rej]}; {[m] o.pick[m;`cxl]};
        {[m] o.pick[m;`fill]};
        {[m] id:.qc.draw .qc.elem o.canp m; (id; .qc.draw .qc.int (1;-1+m[id;`leaves]))};                / an id that can take a partial fill, and a part of what is left
        {[m] id:.qc.draw o.pick[m;`fill]; (id; .qc.draw .qc.int (1+m[id;`leaves];2*m[id;`leaves]))});   / more than is left
o.hooks:`m0`init!(o.m0;o.init)
```

`o.pick`, `.qc.elem` over the orders that can take the event, is how a command chooses one. In `new`'s `gen`,
`g.order[]` is called at once, so the order is already decided, and `.qc.const` wraps the decided value as a
generator that always gives it; `g.t` beside it draws the time.

The three helper lines with the long comments are the record of three false starts, all in the test and none in
the system, and they are typical of writing a stateful test the first time:

- `o.can` was first written with `D[st;ev]` and failed with `'D`. Inside a function in a namespace, a name used in
  a q-SQL expression is looked up in the *root*, not in `.oms` (the table named in `from` is found in the
  namespace; a function or variable named in a `where` or `select` clause is not). The names had to be spelled
  out, `.oms.D`, `.oms.o.nx`. This trap returns in piece 6.
- With that, a run got as far as an order placed and rejected, and the next `pre` raised `'length`: `D[st;ev]`
  over a list of states fails when one of them has no row in `D`. Looked up one order at a time, in `o.nx`, a
  missing state is a null, which is what `pre` wants.
- Then a **generator error**: a partial fill of an order with one share left has no part to draw, `.qc.int (1;0)`,
  and the library refuses a range whose low end exceeds its high. A partial fill needs at least two left, which
  is `o.canp`.

Where an error is raised matters when you read a report. An error in `pre` or `gen` is in the test's own code, and
the report says `FAIL error`, with the error and no trace, as the first session below shows. An error in `run` is
the system's, and one in `post` may be either; both are reported with the trace, so you can see the step that
raised. The second session is the test as it stands, over five hundred sequences of up to forty steps (`steps` is a
hook, a range for a sequence's length).

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen`07_quotes`05_gen`08_orders`08_gen`09_sm
q).qc.check[.qc.sm[.oms.o.hooks] .oms.o.cmds; ::];
FAIL error after 0 tests, 0 shrinks (0 attempts, seed 7)
D
```

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen`07_quotes`05_gen`08_orders`08_gen`12_sm
q).qc.chk[500;.qc.sm[.oms.o.hooks,enlist[`steps]!enlist 0 40] .oms.o.cmds; ::];
ok 500 tests (seed 7)
```

Everything found in this piece was in the test. The system's checks and its transition table were right first
time, which is what writing the specification down as a table buys: `pre` and `post` read the same table the
code does, so the test is not a second opinion about the lifecycle, it is a check that the code follows the
opinion already written down. The whole-system test in the last part borrows `o.nx` from this one, which is why
`12_sm` is in its load list.

## Piece 4: positions and PnL

### What the piece does

A position per instrument: the signed quantity, the average cost of what is open in the instrument's currency,
and the realised profit in the base currency. A fill on the same side as the position moves the average; one on
the other side realises `(px - cost)` on what it closes, converted at the rate as of the fill; one that goes
through zero closes everything and reopens the rest at its price. Unrealised profit marks the open quantity at
the mid as of the time asked, converted at the rate as of then.

```q
/ examples/oms/steps/13_pos.q
pos:([sym:`symbol$()] qty:`long$(); cost:`float$(); real:`float$())
sgn:{[side] $[`buy=side; 1; -1]}
onpos:{[t;s;side;q;p] o:0^pos s; d:sgn[side]*q; cur:o`qty; cc:inst[s;`ccy];
  $[(cur=0) or (signum cur)=signum d; [pos[s;`qty`cost]:(cur+d; ((cur*o`cost)+d*p)%cur+d)];   / adding: the average moves
    abs[d]<=abs cur; [pos[s;`real]:o[`real]+tobase[t;cc;(cur-cur+d)*p-o`cost]; pos[s;`qty]:cur+d; if[0=cur+d; pos[s;`cost]:0f]];   / reducing: realise on what is closed
    [pos[s;`real]:o[`real]+tobase[t;cc;cur*p-o`cost]; pos[s;`qty`cost]:(cur+d;p)]]}     / through zero: close it all, open the rest at p
onfill:{[t;id;q;p] onfill0[t;id;q;p]; o:order id; onpos[t;o`sym;o`side;q;p]}
unreal:{[t;s] o:pos s; $[0=o`qty; 0f; tobase[t;inst[s;`ccy];o[`qty]*mid[t;s]-o`cost]]}   / the open quantity marked at the mid as of t
pnl:{[t] s:exec sym from pos; ([sym:s] real:pos[s;`real]; unreal:unreal[t] each s)}
```

Piece 3's `onfill` is kept as `onfill0` and wrapped, so that every fill books a position. The generator is a run
of up to eight fills, each a side, a number of lots and a price: `g.fillrun `A` draws prices in `A`'s range, which
is fine for any instrument since these rules do not care about the level. `book` in `walk.q` makes each fill into
an order that is acked and filled in full.

### Two rules, and two things written down for later

The position is the signed sum of the fills. And realised plus unrealised is what the desk would count by hand:
the cash the fills cost or brought in, plus the open quantity marked at the mid, all converted at the one rate.
That second rule is another oracle.

```q
/ examples/oms/walk.q
book:{[t;s;fs] {[t;s;f] lot:.oms.inst[s;`lot]; id:.oms.neworder[t;s;f 0;lot*f 1;.oms.g.inst[s;`tick]]; .oms.ack id; .oms.onfill[t;id;lot*f 1;f 2]}[t;s] each fs;}   / each fill (side; lots; px) as an order acked and filled in full
position_is_sum:{[s;fs] reset[]; book[.oms.g.open;s;fs];
  (0^.oms.pos[s;`qty])=sum .oms.sgn'[fs[;0]]*.oms.inst[s;`lot]*fs[;1]}         / the signed sum of the fills, in shares
pnl_is_cash:{[s;fs;m] reset[]; book[.oms.g.open;s;fs]; .oms.onquote[.oms.g.open;s;m;m];   / m: the mid the position is marked at
  r:.oms.rate[.oms.g.open;.oms.inst[s;`ccy]]; lot:.oms.inst[s;`lot];
  cash:sum neg .oms.sgn'[fs[;0]]*lot*fs[;1]*fs[;2];                            / what the fills brought in, in the instrument's currency
  want:r*cash+m*0^.oms.pos[s;`qty];                                            / plus the open quantity marked, all at the one rate
  got:(0^.oms.pos[s;`real])+.oms.unreal[.oms.g.open;s];
  1e-6>abs want-got}
```

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen`07_quotes`05_gen`08_orders`08_gen`13_pos`13_gen
q).qc.check[(.qc.elem .oms.g.syms;.oms.g.fillrun `A); position_is_sum];
ok 100 tests (seed 7)
q).qc.check[(.qc.elem .oms.g.syms;.oms.g.fillrun `A;.qc.flt 10 20); pnl_is_cash];
ok 100 tests (seed 7)
```

Both hold. A run of up to eight fills of either side will add to a position, reduce it and go through zero, so
the three branches of `onpos` are all in play. Two things about the second rule are worth writing down now,
because both come back.

First, *one rate* is a choice of the test. What realised and unrealised should add up to when the rate moves
between a fill and the mark is the question from the opening section, and it was deferred here on purpose: the
test of the whole system will count cash in the base currency as the desk does, and we will see what it says.

Second, look at `0^.oms.pos[s;`real]` in `pnl_is_cash`. The `0^` is there because the instrument might have no
position at all, in which case the lookup is a null. It is a small convenience. It is also a hole, and something
falls through it later.

## Piece 5: a split

### What the piece does

A stock split, `r` new shares for each old one, arrives before the market opens on its day. Everything that is a
*quantity* of the instrument is multiplied and everything that is a *price* is divided: the position and its
average cost, and each open order's quantity, `leaves`, limit and arrival price. Fills already made and quotes
already seen are history and stay as they were.

Two rules: the position's unrealised profit is unchanged once the market quotes at the new level; and an open
order is worth what it was and is still a whole number of lots.

```q
/ examples/oms/walk.q
split_keeps_value:{[s;fs;m;r] reset[]; book[.oms.g.open;s;fs]; .oms.onquote[.oms.g.open;s;m;m]; u0:.oms.unreal[.oms.g.open;s];
  .oms.split[.oms.g.open;s;r]; .oms.onquote[.oms.g.open+1;s;m%r;m%r]; u1:.oms.unreal[.oms.g.open+1;s];   / the market quotes at the new level
  1e-6>abs u0-u1}
split_keeps_order_exactly:{[a;r] reset[]; id:.oms.neworder[.oms.g.open;a 0;a 1;a 2;a 3]; .oms.ack id; o0:.oms.order id;
  .oms.split[.oms.g.open;a 0;r]; o1:.oms.order id;
  (1e-6>abs (o0[`leaves]*o0`px)-o1[`leaves]*o1`px) and (o1[`qty]=r*o0`qty) and 0=o1[`leaves] mod .oms.inst[a 0;`lot]}
```

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen`07_quotes`05_gen`08_orders`08_gen`13_pos`13_gen`14_ca
q).qc.check[(.qc.elem .oms.g.syms;.oms.g.fillrun `A;.qc.flt 10 20;.qc.int 2 4); split_keeps_value];
FAIL falsified after 0 tests, 0 shrinks (7 attempts, seed 7)
s: `A
fs: ()
m: 10f
r: 2
length
```

`'length` on the very first input, an instrument with no orders. The split amended four columns of the keyed
order table at once by index, `order[ids;`qty`leaves`px`arr]:...`, which q does not do. The corrected version
updates the whole table in one statement instead (a functional update, `order::![order;...]`), and the assignment
is `::`, since `order:` anywhere in the function would make `order` a local.

### A rule that said too little, and a rule that said too much

Both rules hold with the fix. The piece was going well, so a third rule was added, the kind of small statement
that costs nothing to write: an open order's limit should still be *on the tick* after the split.

```q
/ examples/oms/walk.q
split_on_tick:{[a;r] reset[]; id:.oms.neworder[.oms.g.open;a 0;a 1;a 2;a 3]; .oms.split[.oms.g.open;a 0;r];
  .oms.ontick[a 0;.oms.order[id;`px]]}
```

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen`07_quotes`05_gen`08_orders`08_gen`13_pos`13_gen`15_ca
q).qc.check[(.qc.elem .oms.g.syms;.oms.g.fillrun `A;.qc.flt 10 20;.qc.int 2 4); split_keeps_value];
ok 100 tests (seed 7)
q).qc.check[(.oms.g.order;.qc.int 2 4); split_keeps_order_exactly];
ok 100 tests (seed 7)
q).qc.check[(.oms.g.order;.qc.int 2 4); split_on_tick];
FAIL falsified after 3 tests, 2 shrinks (18 attempts, seed 7)
a: (`A;`buy;1;10f)
r: 3
```

A buy of `A` at 10, split three for one, has a limit of 3.333..., and `A` ticks in cents: that is not a price the
market takes. Look at what shrinking did with two inputs at once: it kept the simplest order, one share at 10, and
the one ratio of the three that takes 10 off the cent, 3 (halving gives 5.00, quartering 2.50). The exchanges'
convention is to round the adjusted limit *against* the order, a buy down and a sell up, and that is what `totick`
does.

```q
/ examples/oms/steps/16_ca.q
totick:{[side;p;tk] r:tk*?[(),`buy=side; (),floor p%tk; (),ceiling p%tk]; $[0>type p; first r; r]}   / a price put on the tick against the side, a buy down and a sell up; atoms or lists
```

But now the "worth the same" rule is wrong: rounding can cost up to one tick on every share left, so an order is
worth what it was *to within a tick times its leaves*. The rule is loosened by exactly that.

```q
/ examples/oms/walk.q
split_keeps_order:{[a;r] reset[]; id:.oms.neworder[.oms.g.open;a 0;a 1;a 2;a 3]; .oms.ack id; o0:.oms.order id;
  .oms.split[.oms.g.open;a 0;r]; o1:.oms.order id;
  (1e-6>abs[(o0[`leaves]*o0`px)-o1[`leaves]*o1`px]-o1[`leaves]*.oms.inst[a 0;`tick]) and (o1[`qty]=r*o0`qty) and 0=o1[`leaves] mod .oms.inst[a 0;`lot]}   / worth the same to within a tick on what is left
```

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen`07_quotes`05_gen`08_orders`08_gen`13_pos`13_gen`16_ca
q).qc.check[(.oms.g.order;.qc.int 2 4); split_keeps_order];
ok 100 tests (seed 7)
q).qc.check[(.oms.g.order;.qc.int 2 4); split_on_tick];
ok 100 tests (seed 7)
```

This is the ordinary rhythm of the work: a rule fails; sometimes the code was wrong (the limit off the tick),
sometimes the rule was (worth exactly the same), and the counterexample is what tells you which. A property is a
statement about the code, and statements can be false.

## Piece 6: end of day

### What the piece does

At the close the day's fills, quotes and rates, and a copy of the orders, are written to the database as a
partition for the day, `sym` parted and in time order within each symbol, and the memory tables are emptied. Two things carry over: the last
quote of each instrument and the last rate of each currency stay in memory, timestamped as they were, so that "as
of" the first minutes of the next day still finds something. Orders live in memory across days. Queries that span
days read today from memory and the rest from disk: `fillsof[d;s]` is the fills of a day, and `slip[d;s]` gives
each of them its slippage against the order's arrival price, in basis points.

```q
/ examples/oms/steps/17_eod.q
eod:{[d] if[not d=today; '"oms: eod for ",string[d]," when today is ",string today];
  save1[d]'[`execs`quote`fxr`order;(fill;quote;fxr;0!order)];                        / (fill is a keyword: on disk the fills are execs)
  quote::0!select by sym from `time xasc quote; fxr::0!select by ccy from `time xasc fxr; fill::0#fill;   / the carry-over: the last quote and the last rate stay
  remap[]; today::d+1;}
```

`save1` writes one table of one day and `remap` loads the database back (`\l dir`, which also makes `dir` the
working directory, so a session of this piece loads everything it needs before its first close); `today` is the
day in memory, `day0` the first, `opn` a day's open. `fill` is a keyword, so on disk the fills are `execs`. Every
session here ends with `.oms.clean[]`, which removes the temporary database.

The generator is a whole day: one rate per currency at the open (`g.fx1`), a session of quotes, and a run of
fills for each instrument. `day` feeds it to the system and `wipe` gives a fresh day and a fresh database. Three rules: a day written comes
back as it was; the rate and the mid as of the next day's open are the last of the day; and slippage is what the
arithmetic says.

```q
/ examples/oms/walk.q
wipe:{reset[]; .oms.fxr::0#.oms.fxr; .oms.today::.oms.day0; system"rm -rf ",(1_string .oms.hdb),"/*"; if[count k:`execs`quote`fxr`order inter key `.; ![`.;();0b;k]]}   / a fresh day and a fresh database
day:{[fx;qs;fs] .oms.onfx'[fx`time;fx`ccy;fx`rate]; qs:.oms.g.qs qs; .oms.onquote'[qs`time;qs`sym;qs`bid;qs`ask];   / one day: the rates, the quotes,
  {[s;fl] {[s;f] lot:.oms.inst[s;`lot]; id:.oms.neworder[.oms.g.open+0D01;s;f 0;lot*f 1;.oms.g.inst[s;`tick]]; .oms.ack id; .oms.onfill[.oms.g.open+0D02;id;lot*f 1;f 2]}[s] each fl}'[.oms.g.syms;fs];}   / then a run of fills per instrument
gday:{(.oms.g.fx1;.oms.g.quotes;.oms.g.fillrun each .oms.g.syms)}             / what a day is drawn from (a function, since the generators load after this file)
day_comes_back:{[fx;qs;fs] wipe[]; day[fx;qs;fs]; f0:`sym`time xasc .oms.fill;
  .oms.eod .oms.day0;
  .qc.eq[f0; `sym`time xasc raze .oms.fillsof[.oms.day0] each .oms.g.syms]}   / read back from disk
carry_over_at_close:{[fx;qs;fs] wipe[]; day[fx;qs;fs];
  r0:.oms.rate[.oms.g.close;] each .oms.g.ccys; m0:.oms.mid[.oms.g.close;] each .oms.g.syms;   / as of the close
  .oms.eod .oms.day0; t:.oms.opn .oms.today;
  .qc.eq[(r0;m0); (.oms.rate[t;] each .oms.g.ccys; .oms.mid[t;] each .oms.g.syms)]}   / as of the next open
slippage_bps:{[fx;qs;fs] wipe[]; day[fx;qs;fs]; s:raze .oms.slip[.oms.day0] each .oms.g.syms;
  o:.oms.order ([]id:s`id);                                                    / the fills' orders, a table of keys
  all 1e-6>abs s[`bps]-1e4*.oms.sgn'[o`side]*(s[`px]-o`arr)%o`arr}
```

### A system with history

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen`07_quotes`05_gen`08_orders`08_gen`13_pos`13_gen`16_ca`17_eod
q).qc.check[gday[]; day_comes_back];
FAIL falsified after 2 tests, 7 shrinks (87 attempts, seed 7)
fx:
  time                          ccy rate
  -------------------------------------------
  2024.01.02D09:30:00.000000000 EUR 1.125
  2024.01.02D09:30:00.000000000 GBP 1.25
  2024.01.02D09:30:00.000000000 JPY 0.0078125
qs:
  time                          sym q
  ---------------------------------------
  2024.01.02D09:30:00.000000000 A   10 10
fs: (();();())
type
q).oms.onquote[.oms.g.open;`A;10f;10f]
'type
q)cols .oms.quote
`sym`time`bid`ask
q).oms.clean[]
```

The first rule fails on the *third* test ("after 2 tests"), with `'type`, and a quote sent by hand raises it
again. The carry-over rebuilt `quote` and `fxr` with `select by`, and `select by` puts the key column first: the
next `insert` met the columns in the wrong order. (`wipe` happens to put the rate table right, since it gives the
system its rates afresh, so here it is the quote table that trips; the log that this document retells hit the
rate table first.) `xcols` puts the columns back. It is not the first test that finds this, because a test's close
is what leaves the tables reordered for the tests after it, and the first two happened to draw days with no
quote. A rule that resets the system before each test still runs against a system that has *history*; that is why
`wipe` exists, and why it was not enough.

### A rule that asked the wrong question

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen`07_quotes`05_gen`08_orders`08_gen`13_pos`13_gen`16_ca`18_eod
q).qc.check[gday[]; day_comes_back];
ok 100 tests (seed 7)
q).qc.check[gday[]; carry_over_at_close];
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
q).oms.clean[]
```

The round trip holds. The carry-over rule fails on a quote timed a nanosecond after the close. The generator's
session runs a little past 16:00, the rule compared with the mid *as of the close*, and the carry-over keeps the
last quote *seen*, which is later. This is the first time `.qc.eq`'s diff table appears: `path 1 0` is the second
thing compared (the mids), first instrument; `a` is the rule's value, 10, and `b` the system's, 10.5. The system
is right. A quote after the close is still the latest quote, and the rule was asking the wrong question; the
corrected rule compares with the mid as of the latest time seen.

```q
/ examples/oms/walk.q
carry_over:{[fx;qs;fs] wipe[]; day[fx;qs;fs]; e:max .oms.g.close,.oms.quote`time;   / as of the latest time seen, which may be after the close
  r0:.oms.rate[e;] each .oms.g.ccys; m0:.oms.mid[e;] each .oms.g.syms;
  .oms.eod .oms.day0; t:.oms.opn .oms.today;
  .qc.eq[(r0;m0); (.oms.rate[t;] each .oms.g.ccys; .oms.mid[t;] each .oms.g.syms)]}
```

### The same trap, twice

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen`07_quotes`05_gen`08_orders`08_gen`13_pos`13_gen`16_ca`18_eod
q).qc.check[gday[]; carry_over];
ok 100 tests (seed 7)
q).qc.check[gday[]; slippage_bps];
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
q).oms.clean[]
```

The slippage rule raises `'length` on the first input, a day with no fills. `slip` looked the fills' orders up
with `order f`id`, a keyed table indexed by a *list* of ids, and that raises `length` for any list but one of a
single key: an empty list here, and a list of two on any day with two fills. The idiom that works for any number
of keys is a *table of keys*, `order ([]id:f`id)`, which is how the rule itself does it.

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen`07_quotes`05_gen`08_orders`08_gen`13_pos`13_gen`16_ca`19_eod
q).qc.check[gday[]; slippage_bps];
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
q).oms.clean[]
```

`'sgn`: a function named inside `slip`'s `update`, looked up in the root, the trap from piece 3. Spelled
`.oms.sgn`, the piece holds:

```q
/ examples/oms/steps/20_eod.q
slip:{[d;s] f:fillsof[d;s]; o:order ([]id:f`id); update bps:1e4*.oms.sgn'[o`side]*(px-o`arr)%o`arr from f}      / each fill's cost against its order's arrival price, in bps (positive is worse)
```

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen`07_quotes`05_gen`08_orders`08_gen`13_pos`13_gen`16_ca`20_eod
q).qc.check[gday[]; slippage_bps];
ok 100 tests (seed 7)
q).oms.clean[]
```

## Where things stand

Six pieces, each with rules that pass, two of them with a stateful test of their own. The rules found eight
things in the code along the way: the atom in `rate`, the crash where a refusal should have been, the cache that
took a late tick, the split's amend, the limit off the tick, the carry-over's columns, and `slip`'s indexing and
its bare name (seven by a rule, one by the cache's stateful test). They found six things in the tests themselves:
a refusal that any error satisfied, a value that was not worth exactly the same, a question asked as of the wrong
time, and the three false starts of the lifecycle test.

If the story stopped here it would be a reasonable account of testing a system piece by piece. It would also have
missed the bugs that matter most, because every rule so far starts from an empty system, runs one shape of day,
and asks one question at the end.

## The system as a whole

### What the test is

Bolt the pieces together and a new kind of question appears: does a fill, then a close, then a split, then a
query about yesterday, give the right answer? No piece owns that question. The tool for it is the one from
pieces 2 and 3, a stateful test, but now over the whole system, with every kind of event as a command.

The model is the **event log**: the rates and quotes seen (`fx`, `q`), the orders placed with the arrival price
each was given (`o`), the fills with the arrival price as it stood when each was made (`f`), the clock and the day,
and a flag `fresh` for "nothing has happened today yet", which is when a split may arrive. The commands are a
day's events: a rate, a quote, an order, an ack, a cancel, a fill of some or all of what is left, a split before
the first event of a day, and the close. The model is a record of what happened, not a computation; the only
arithmetic in it is a split factor kept on each fill. As with piece 3, the table is shaped like piece 2's and the
file has the whole of it; shown here are the model, the header and the hooks. (`sys.qs`, `sys.can` and `sys.canf`
are the helpers `pre` uses: the instruments with a quote, the orders that can take an event, the orders that can
take a fill and have a rate to book it at.)

```q
/ examples/oms/steps/21_sm.q
sys.o0:([id:`long$()] sym:`symbol$(); side:`symbol$(); qty:`long$(); px:`float$(); st:`symbol$(); leaves:`long$(); arr:`float$())
sys.f0:([]day:`date$(); time:`timestamp$(); id:`long$(); sym:`symbol$(); side:`symbol$(); qty:`long$(); px:`float$(); arr:`float$(); adj:`long$())   / adj: the split factor applied since
sys.m0:`day`now`fresh`fx`q`o`f!(day0; opn day0; 1b; 0#fxr; 0#quote; sys.o0; sys.f0)
sys.tg:{[m] .qc.ts[m`now; m[`now]+0D00:05]}                                                 / a time for an event: the clock, or up to five minutes after it
sys.cmds:([cmd:`fx`quote`new`ack`cancel`fill`split`eod]
  w:   2 4 3 3 1 3 1 1f;
  pre: ({[m] 1b}; {[m] 1b}; {[m] 0<count sys.qs m}; {[m] 0<count sys.can[m;`ack]}; {[m] 0<count sys.can[m;`cxl]}; {[m] 0<count sys.canf m}; {[m] m`fresh}; {[m] not m`fresh});
sys.hooks:`m0`init`inv!(sys.m0;sys.init;sys.inv)
```

The checking is done by an oracle that recomputes from the log, in the plainest way it can, what the system
reports. It is written apart from the system: it uses the system's two constants (`base`, `inst`) and two one-line
helpers (`sgn`, `midof`) and none of its logic, so that a mistake in the system's logic cannot be mirrored on both
sides. The position of an instrument is the signed sum of its fills. Its profit in the base currency is what the
fills cost or brought in, each converted as of its time, plus the open quantity marked at the mid and the rate as
of now: the cash the desk would count. And a fill's slippage is against the arrival price its order had when the
fill was made.

```q
/ examples/oms/steps/21_sm.q
sys.rat:{[m;t;c] $[c=base; 1f; exec last rate from m[`fx] where ccy=c, time<=t]}     / the last rate at or before t; null if none
sys.mid:{[m;t;sy] r:select from m[`q] where sym=sy, time<=t; $[count r; midof[last r`bid; last r`ask]; 0n]}
sys.qty:{[m;sy] f:select from m[`f] where sym=sy; $[count f; sum (sgn each f`side)*(f`qty)*f`adj; 0]}   / (sum of nothing is (), not 0)
sys.cash:{[m;sy] f:select from m[`f] where sym=sy; $[count f; neg sum (sgn each f`side)*(f`qty)*(f`px)*sys.rat[m;;inst[sy;`ccy]] each f`time; 0f]}
sys.val:{[m;sy] q:sys.qty[m;sy]; $[q=0; 0f; q*sys.mid[m;m`now;sy]*sys.rat[m;m`now;inst[sy;`ccy]]]}
sys.pnl:{[m;sy] sys.cash[m;sy]+sys.val[m;sy]}
sys.bps:{[f] 1e4*(sgn each f`side)*((f`px)-f`arr)%f`arr}
sys.slip:{[m;d;sy] f:`time xasc select from m[`f] where day=d, sym=sy; ([]time:f`time; id:f`id; bps:sys.bps f)}
sys.inv:{[m] ks:exec distinct sym from m`f; p:pnl m`now;
  .qc.eq["j"$sys.qty[m] each ks; pos[([]sym:ks);`qty]];
  r:p ([]sym:ks); .qc.eq["f"$sys.pnl[m] each ks; (r`real)+r`unreal];
  ds:day0+til 1+(m`day)-day0;
  .qc.eq[(ds cross ks)!sys.slip[m] .' ds cross ks; (ds cross ks)!{select time,id,bps from .oms.slip[x;y]} .' ds cross ks]; 1b}
```

`sys.inv` is an **invariant**: a function of the model that the library runs after *every* step, given as the
`inv` hook (the third entry of `sys.hooks`). Where `post` checks the one thing a command just did, the invariant
asks the standing questions of the whole system, here positions, profit and slippage, for today from memory and
for every closed day from disk. A sequence of twenty commands is twenty checks of everything. The `.qc.eq`
calls inside it fail the property when the two sides differ, as they did in the rules, and a failure of the
invariant is reported as `qc.inv`, followed by what failed inside it (`qc.inv qc.eq`). The diff table then
appears under a `0:`, its place among the notes the failure carries, and the trace after it.

The fixes from here on are given by their step number, and the load line of each session shows which steps are in
play.

### The first run: two bugs in one piece

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen`07_quotes`05_gen`08_orders`08_gen`12_sm`13_pos`13_gen`16_ca`20_eod`21_sm
q).qc.check[.qc.sm[.oms.sys.hooks] .oms.sys.cmds; ::];
FAIL falsified after 1 tests, 0 shrinks (13 attempts, seed 7)
qc.inv length
step cmd arg                                res                                 ok
----------------------------------------------------------------------------------
0    fx  2024.01.02D09:30:00.000000000 `EUR 2024.01.02D09:30:00.000000000 1.125 1
q).oms.pnl .oms.g.open
'length
q).oms.clean[]
```

One sequence passed (it was empty, so the invariant was never asked); the second raises `'length` in the
invariant after its very first step, a rate, and `pnl` asked by hand does the same. It is piece 4's `pnl` on a
system with *no positions yet*: `pos[s;`real]` over an empty `s`, the same keyed-table indexing as piece 6. No rule
had ever called `pnl`: piece 4's rules asked `pos` and `unreal` directly, so the report function had never run on
an empty system. A table of keys, and a cast so that an empty report has typed columns (step 22).

```q
/ examples/oms/steps/22_pos.q
pnl:{[t] s:exec sym from pos; ([sym:s] real:pos[([]sym:s);`real]; unreal:"f"$unreal[t] each s)}   / (a table of keys: indexing pos by a list of syms fails when the list is empty)
```

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen`07_quotes`05_gen`08_orders`08_gen`12_sm`22_pos`13_gen`16_ca`20_eod`21_sm
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
q).oms.clean[]
```

Four steps: a quote, an order, an ack, a fill. The oracle says the profit is `0`, and the system's answer is the
blank in the diff table, a null. The first fill of an instrument leaves its realised profit null. Look back at
`onpos` in piece 4: `o:0^pos s` gave it zeros to do arithmetic with when there was no row, and the row it then
wrote set `qty` and `cost` but never `real`. Now look back at piece 4's second rule and its `0^.oms.pos[s;`real]`.
That `0^` was there for the position that might not exist, and it also forgave a null in one that did. The rule
ran a hundred times and never saw it; the oracle here has no `0^`, and saw it at once. The position is now opened
with zeros before the first fill touches it (step 23).

```q
/ examples/oms/steps/23_pos.q
onpos:{[t;s;side;q;p] if[null pos[s;`qty]; pos[s]:`qty`cost`real!(0;0f;0f)]; o:pos s; d:sgn[side]*q; cur:o`qty; cc:inst[s;`ccy];   / (0^pos s stood here: it gave the arithmetic zeros and left a null real in the row)
```

Two bugs, each in one piece, each missed by the piece's own rules: one because no rule asked the question, the
other because the rule forgave the answer. The whole-system test asks the plain questions after every step, from
the empty system onward, and the plain questions found both.

### The question that was deferred

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen`07_quotes`05_gen`08_orders`08_gen`12_sm`23_pos`13_gen`16_ca`20_eod`21_sm
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
q).oms.clean[]
```

Six steps, and the failure the opening section promised. `B` is in euros. A buy of one at 100 with the euro at
1.125 costs 112.50 dollars. Then the euro falls to 1.0625, and the desk holds 106.25 dollars of stock: a loss of
6.25, which is what the oracle counts. The system marks in euros, finds the mark equal to the cost, and says 0.
Its profit is the *euro* profit converted to dollars, and the dollars the desk actually spent have moved on
their own.

There is a decision here, not only a bug, and it had to be made: the desk counts cash. So the position keeps
`costb`, what its open quantity cost in the base, converted as of each fill; a fill that reduces it realises what
it brings in, less the share of `costb` it releases; and unrealised is the open quantity marked and converted,
less `costb`. The average cost in the instrument's currency stays, for the desk to see (step 25).

```q
/ examples/oms/steps/25_pos.q
pos:([sym:`symbol$()] qty:`long$(); cost:`float$(); costb:`float$(); real:`float$())   / costb: what the open quantity cost in the base, converted as of each fill
onpos:{[t;s;side;q;p] if[null pos[s;`qty]; pos[s]:`qty`cost`costb`real!(0;0f;0f;0f)]; o:pos s; d:sgn[side]*q; cur:o`qty; pb:tobase[t;inst[s;`ccy];p];   / pb: the fill's price in the base, as of the fill
  $[(cur=0) or (signum cur)=signum d; [pos[s;`qty`cost`costb]:(cur+d; ((cur*o`cost)+d*p)%cur+d; (o`costb)+d*pb)];   / adding: the average moves, the basis grows
    abs[d]<=abs cur; [f:neg[d]%cur; pos[s;`real]:o[`real]+(neg[d]*pb)-f*o`costb; pos[s;`qty`costb]:(cur+d;(1-f)*o`costb); if[0=cur+d; pos[s;`cost]:0f]];   / reducing: what it brings in, less the share of the basis it releases
    [pos[s;`real]:o[`real]+(neg[cur]*pb)-o`costb; pos[s;`qty`cost`costb]:(cur+d;p;(cur+d)*pb)]]}     / through zero: close it all, open the rest at p
unreal:{[t;s] o:pos s; $[0=o`qty; 0f; tobase[t;inst[s;`ccy];o[`qty]*mid[t;s]]-o`costb]}   / the open quantity marked at the mid as of t, less what it cost
```

Before running it, one change to the test (step 24): the `fx` and `quote` commands drew their values inside `run`,
as piece 2's test did, so `post` and `upd` had to read them back from the result. Everything a step draws is now
drawn in `gen`, where the model can see it. In the traces from here on the rate and the quote appear in the `arg`
column, `(time; currency; rate)`, where above they were in `res`; the steps are otherwise the same.

### Two more turns before it held

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen`07_quotes`05_gen`08_orders`08_gen`12_sm`25_pos`13_gen`16_ca`20_eod`24_sm
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
q).oms.clean[]
```

Now the *oracle* is the one that is wrong, and this is worth slowing down for, because it happens. Eleven steps,
and only the last two matter: the fill at step 9 and the rate at step 10, which arrives after the fill but is
timed at the same instant. (The four closes before them are there because the shrinker could not remove them
without changing the times of the steps that follow; a trace is the smallest the library could reach, not always
the smallest there is.) "The rate as of the fill" means one thing to the system, which booked the fill at the
rate it knew, and another to an oracle that looks at the whole log afterwards and finds a later-arrived rate with
the same timestamp. Which is right is a decision about the system: a fill is booked at the rate known when it is
made, and a rate that arrives later, timed at or before it, does not re-book it. The oracle now records on each
fill the rate it was booked at, taking it from its own log of rates as of the fill's time, when the fill is
recorded (step 26).

```q
/ examples/oms/steps/26_sm.q
sys.cash:{[m;sy] f:select from m[`f] where sym=sy; $[count f; neg sum (sgn each f`side)*(f`qty)*(f`px)*f`rate; 0f]}   / booked at the rate known when the fill was made: a rate that arrives later, timed at or before it, does not re-book it
```

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen`07_quotes`05_gen`08_orders`08_gen`12_sm`25_pos`13_gen`16_ca`20_eod`26_sm
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
q).oms.clean[]
```

Sell one `A` at 10, then buy two at 10: no profit, and the system says 20. That is a sign error in the new code,
in the branch of `onpos` that goes through zero (the third of its three cases). Closing a short *costs*, so what
closing the whole position brings in is `cur*pb`, the signed quantity times the fill's price in the base, negative
for a short; the code had `neg[cur]*pb`. Piece 4's own rule would have caught this had it been run again after the
change; the whole-system test ran it instead (step 27).

```q
/ examples/oms/steps/27_pos.q
    [pos[s;`real]:o[`real]+(cur*pb)-o`costb; pos[s;`qty`cost`costb]:(cur+d;p;(cur+d)*pb)]]}     / through zero: close it all (cur*pb is what closing brings in, negative for a short), open the rest at p
```

### The bug that needs three pieces

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen`07_quotes`05_gen`08_orders`08_gen`12_sm`27_pos`13_gen`16_ca`20_eod`26_sm
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
q).oms.clean[]
```

Seven steps, and read them as a story. On the second of January a buy order for `B` arrives with the price at 100,
so its arrival price is 100; one share is filled at 100, so its slippage is nothing. The day closes and the fill
goes to disk. The next morning `B` splits two for one, and piece 5 halves the open order's arrival price to 50, as
it should. Now ask for yesterday's slippage: the fill is history and stays at 100, the order it is measured against
has moved to 50, and the answer is 10,000 basis points.

Piece 3 (the order), piece 5 (the split) and piece 6 (the close, and the query across days) are each right on
their own. The bug needs a fill, a close and a split, in that order, and it needs an invariant that asks about
*closed* days after every step, not only at the close. No rule written for any one piece could have stated it.
The fix is that a fill records the arrival price its order had when it was made, on disk too, and slippage is
measured against that (steps 28 and 29).

```q
/ examples/oms/steps/28_orders.q
fill:([]time:`timestamp$(); id:`long$(); sym:`symbol$(); qty:`long$(); px:`float$(); arr:`float$())   / arr: the order's arrival price as it stood at the fill
```

```q
/ examples/oms/steps/29_eod.q
slip:{[d;s] f:fillsof[d;s]; o:order ([]id:f`id); update bps:1e4*.oms.sgn'[o`side]*(px-arr)%arr from f}      / each fill's cost against the arrival price it recorded, in bps (positive is worse)
```

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen`07_quotes`05_gen`28_orders`08_gen`12_sm`27_pos`13_gen`16_ca`29_eod`26_sm
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
q).oms.clean[]
```

A hundred sequences hold. Five hundred do not: two partial fills in yen, and the oracle's profit and the system's
differ in the thirteenth decimal place (the diff shows the two as text at full precision, since printed as numbers
they would look the same). That is not a bug in either; the oracle adds the fills up in one order and the system
books them one at a time, and floating point rounds the two differently. A profit in the base currency is compared
to a millionth, and the difference is put in the report with `.qc.note`, which adds anything to a failure's notes
(step 30).

```q
/ examples/oms/steps/30_sm.q
  r:p ([]sym:ks); a:"f"$sys.pnl[m] each ks; b:(r`real)+r`unreal; if[not all 1e-6>abs a-b; .qc.note ([]sym:ks; want:a; got:b); :0b];   / (to a millionth of the base: the oracle adds the fills in another order than the system books them, and the two round differently in the thirteenth decimal place)
```

### What a pass is worth

```q
q)system"l examples/oms/walk.q"
q).oms.walk`04_ref`01_gen`07_quotes`05_gen`28_orders`08_gen`12_sm`27_pos`13_gen`16_ca`29_eod`30_sm
q).qc.chk[500; .qc.sm[.oms.sys.hooks] .oms.sys.cmds; reach];
ok 500 tests (seed 7)
label           n   pct  req lo       hi       ok bar
--------------------------------------------------------------
split           123 24.6     21.02804 28.55929 1  ####
eod             317 63.4     59.09035 67.50531 1  ############
fill            245 49       44.64254 53.37271 1  #########
two_days        204 40.8     36.57816 45.16213 1  ########
split_then_fill 76  15.2     12.31919 18.61148 1  ###
fill_then_split 23  4.6      3.084488 6.807827 1
q).oms.clean[]
```

Five hundred sequences pass. A pass says nothing about what the sequences did *not* reach, so the last thing to
ask is what they did. The property here is not `::` but `reach`, a function of the trace, which does no checking
of its own; it puts a **label** on each sequence for what it contained, with `.qc.classify[name; boolean]`, and
the report ends with a table of the labels, on a pass as much as on a failure.

```q
/ examples/oms/walk.q
reach:{[tr] c:tr`cmd; .qc.classify[`fill;`fill in c]; .qc.classify[`eod;`eod in c]; .qc.classify[`split;`split in c]; .qc.classify[`two_days;1<sum c=`eod];
  .qc.classify[`fill_then_split;(`fill in c) and (`split in c) and first[where c=`fill]<last where c=`split];
  .qc.classify[`split_then_fill;(`fill in c) and (`split in c) and last[where c=`fill]>first where c=`split]; 1b}
```

In the table, `n` and `pct` are how many sequences carried the label and what share of the run that is, `lo` and
`hi` are a confidence interval on that share, and `req` is a minimum you could have demanded (none was). Half the
sequences filled something, a quarter split, two in five closed more than one day, and one in twenty put a
split after a fill. That last one is the shape that found the three-piece bug, so in a hundred sequences there
were about five chances, and it was found on the seventieth. Had the count been one in five hundred, a hundred
sequences would have been the wrong budget, and this table is how you would know.

## What happened

Thirteen findings in the code, in the order they came:

| where | found by | what |
|---|---|---|
| piece 1 | rule | `rate` could not take an atom (`'rank`) |
| piece 1 | rule, then a call by hand | a conversion with no rate crashed instead of refusing |
| piece 2 | stateful test | the cache took a late tick as the latest |
| piece 5 | rule | a keyed table amended in four columns at once |
| piece 5 | rule | an adjusted limit off the tick |
| piece 6 | rule | the carry-over reordered the columns of the quote and rate tables |
| piece 6 | rule | `slip` indexed the order table by a list |
| piece 6 | rule | `slip` named `sgn` inside q-SQL |
| piece 4, seen only whole | whole-system test | `pnl` on no positions raised |
| piece 4, seen only whole | whole-system test | an opening fill left the realised profit null |
| piece 4 | whole-system test | profit missed the FX move on the cost basis (the deferred question) |
| piece 4, new code | whole-system test | the sign through zero |
| pieces 3, 5 and 6 together | whole-system test | a split re-priced a closed day's slippage |

Beside them, the mistakes in the tests: two rules that said too little (any error counted as a refusal; a `0^`
that forgave a null), two that said too much (worth *exactly* the same after a split; the mid *as of the close*),
the three false starts of the lifecycle test, an oracle that used hindsight, a comparison of floats to the last
bit, and two slips of habit (a generator multiplied by a number; values drawn in `run`). The test code is code,
and the counterexamples were as good at finding its mistakes as the system's.

**What the rules could not see.** Every piece's rule feeds one shape of input and asks one question. That found
the bugs that live inside a piece, and missed the two that live in the empty system and the first fill: one
question no rule asked, one answer a rule forgave. The rules of piece 4 converted everything at
one rate, by choice, and so could not see what a moving rate does; the choice was written down and the question
handed on.

**What the whole-system test saw.** Two bugs in single pieces that their rules had forgiven, the deferred question
about FX, a sign slip in the fix for it, and the one bug that lives in no piece. Its counterexamples were between
one and eleven steps long, and each read as the diagnosis. Its oracle was written from the log with none of the
system's logic in it, and once the oracle was the one that was wrong, which is the price of an independent oracle
and a reasonable price.

**What it cannot see.** The oracle books a fill at the rate known when the fill was made, so a system that
re-booked fills on a late rate would agree with a different oracle and disagree with this one; that is the
decision, not a gap. It never sends an order that should be refused (piece 3's second rule does), never asks
about a day other than today or a closed one, and knows nothing about time zones, holidays or a split with a
fractional ratio, because the system does not either. A pass from it means the sequences it drew agree with the
log, and the reach table says what those sequences were.

### What to take from it

- **Start with a rule you can state in a sentence** and let the first failures teach you about the inputs. Most of
  the early findings were the code's assumptions about atoms, lists and empties, not its logic.
- **Compare with an oracle** where one exists: a slow `select` against a fast join, the cash a desk would count
  against a booked profit. Write the oracle without the system's logic in it.
- **Say what the answer must be**, not only that there is one. "Refused" was satisfied by a crash; "refused with
  this message" was not.
- **When a rule fails, suspect the rule too.** Several times the rule was the thing that was wrong, and the
  counterexample said so as clearly as it says anything else.
- **A stateful test is for state.** Where the answer depends on the sequence of events, a model and a table of
  commands will find what a rule over one input cannot, and the shrunk trace is the reproduction you would want.
- **Assemble, then test the whole with an invariant that asks the standing questions after every step**, from the
  empty system onward. That is where the bugs between pieces live, and where the questions a piece deferred get
  answered.
- **Read the reach table before believing a pass.**

## Glossary

- **generator** — a description of the shape of an input, which the library can draw values from: `.qc.int 0 100`,
  `.qc.flt 0 1`, `.qc.elem list`, `.qc.ts[a;b]`, `.qc.tabr[r] cols`, `.qc.const v` (always `v`), or one of your own
  written as a function that draws with `.qc.draw` and computes. `.qc.mono` makes a table column non-decreasing;
  `.qc.dep` makes a column depend on the rest of its row. A list of generators is a generator of a list.
- **a generator of your own** — a function that, applied to no arguments, draws with `.qc.draw` and returns a
  value; `.qc.lst[r] g` is a list of `g`'s, of a length in the range `r`.
- **property** — a function of the drawn input that returns `1b` when the statement it makes holds. `.qc.check[g;p]`
  draws from `g` and runs `p` a hundred times; `.qc.chk[n;g;p]` runs it `n` times, or takes a dictionary of settings.
- **counterexample** — the input for which the property failed, as reported after shrinking.
- **shrinking** — the library's search, after a failure, for a simpler input that also fails; the report says how
  many simpler inputs it tried ("attempts") and how many still failed ("shrinks"), and shows the simplest.
- **seed** — the number that determines the draws of a run; the same seed gives the same run.
- **the report** — what a failure's report carries: `FAIL falsified after N tests` (N passed first) or `FAIL error`;
  a line naming what failed (`qc.post`, `qc.run`, `qc.inv`, `qc.eq`, or an error's name); the inputs by name, or
  the trace; the notes, numbered, which
  hold a diff table from `.qc.eq` or anything added with `.qc.note`; the rerun line; and a table of labels when
  there were any.
- **oracle** — a second, plainer way of computing the answer, used to check the first. `.qc.eq[a;b]` compares two
  values and, when they differ, notes a table of `path` (where), `why`, `a` and `b`.
- **stateful test** — a test that draws a *sequence of commands*, runs them against the system one at a time, and
  checks after each one. `.qc.sm[hooks] cmds` makes a generator of such sequences; the property given to
  `.qc.check` is `::` when the checks are all in the table, or a function of the trace.
- **model** — the test's own record of what the system's state ought to be, kept alongside the system and updated
  by `upd` after each command.
- **command table** — one row per command, with `pre` (may it run now, from the model), `gen` (the generator of its
  input, from the model), `run` (send it to the system), `post` (check the result), `upd` (move the model on) and
  `w` (its weight).
- **hooks** — the dictionary given to `.qc.sm`: `m0` the model to start from, `init` a function that resets the
  system before each sequence (and `fini` one that runs after it), `steps` a range for the sequence's length, `inv`
  the invariant.
- **generator error** — an error raised by `pre` or `gen`, which is the test's own; reported as `FAIL error`, with no
  trace.
- **trace** — the report of a failed sequence: each step with its command, input, result and whether it passed.
- **invariant** — a function of the model checked after every step, given as the `inv` hook; where `post` checks
  one command, the invariant checks the whole. A failure is reported as `qc.inv`.
- **transition table** — a table of (state, event) to next state, used here both as the code's specification and
  as the test's.
- **event log** — the model of the whole-system test: a record of every event the sequence sent, from which an
  oracle recomputes what the system should report.
- **label** — `.qc.classify[name; boolean]` inside a property marks the example; the report counts how many examples
  carried each label, with a confidence interval, which says what the run reached.
