# qcheck cookbook

Recipes for things a kdb+ programmer tests: joins, an upsert, tables written to disk, a tickerplant's `upd`,
serialisation, bars, a sorted vector, an order's lifecycle, a FIFO allocation, a feed that sends the wrong type,
text that needs escaping. Most recipes have a bug planted in them, so that you see the report you would get, and
then the fix, so that you see the passing run too. In some of them the code is right and it is the rule that
gives way.

Each recipe goes the same way: what is being tested and which kind of rule fits it, the generator for the inputs,
the property, the report and how to read it, and the fix. `README.md` explains the ideas and `EXAMPLES.md` the
library a piece at a time; `WALKTHROUGH.md` follows a whole system as it is built and tested.

Every block that shows a `q)` prompt is a session of its own, started with `\l qc.q` and
``.qc.cfg[`db`seed]:(`;7i)``, and what follows each line is what q prints. The test suite runs every block and
requires the output shown.

| recipe | kind of rule | generators it shows |
|---|---|---|
| [An as-of join against a naive one](#an-as-of-join-against-a-naive-one) | an oracle | tables that share a drawn symbol list; `mono` |
| [Upsert on keyed tables](#upsert-on-keyed-tables) | an oracle | `ktab` |
| [A splayed table reads back changed](#a-splayed-table-reads-back-changed) | a round trip | `schema` |
| [A stateful test of a tickerplant handler](#a-stateful-test-of-a-tickerplant-handler) | a model and an invariant | `sm`; a table as a command's input |
| [Serialisation, over any value](#serialisation-over-any-value) | a round trip | `val`; narrowing a generator to what a rule covers |
| [Per-minute bars](#per-minute-bars) | an oracle | `ts`, `mono` over timestamps |
| [A sorted vector and its attribute](#a-sorted-vector-and-its-attribute) | an oracle, then an invariant | `atr` |
| [An order's lifecycle: a transition table as the model](#an-orders-lifecycle-a-transition-table-as-the-model) | a model that is a table | `sm` with commands built from a table |
| [FIFO allocation: an oracle from the obvious loop](#fifo-allocation-an-oracle-from-the-obvious-loop) | an oracle and two conservation laws | two lists; narrowing a rule to the inputs it is for |
| [Joins: `lj`, `ej`, `pj` and where they differ](#joins-lj-ej-pj-and-where-they-differ) | an oracle in a lookup | `ktab` beside a plain table |
| [`insert` where `upsert` was meant](#insert-where-upsert-was-meant) | a model | `sm` over a keyed table; `one` |
| [A feed that sends the wrong type](#a-feed-that-sends-the-wrong-type) | an invariant on `meta` | `one` over a cast |
| [Text that needs escaping: JSON and CSV round trips](#text-that-needs-escaping-json-and-csv-round-trips) | a round trip | `strc`, `symc` over a hostile alphabet |
| [A partitioned database: the sym file and the partitions](#a-partitioned-database-the-sym-file-and-the-partitions) | a round trip and two invariants | `mono` over timestamps; a database under `mktemp` |
| [`fby` and the order of `where` clauses](#fby-and-the-order-of-where-clauses) | two queries that should agree, then an oracle | `tabr` |
| [The first item: `deltas`, `differ` and `sums`](#the-first-item-deltas-differ-and-sums) | a round trip and two laws | `t` for nulls |
| [`sublist`, not take](#sublist-not-take) | two functions that should agree | a count beside a list |
| [Forward fill, by symbol](#forward-fill-by-symbol) | an invariant | `freq` for gaps |
| [Casts and text: what comes back is not what went in](#casts-and-text-what-comes-back-is-not-what-went-in) | round trips | `t` |
| [Integer overflow](#integer-overflow) | an invariant over a range | `int` |
| [A call that must signal](#a-call-that-must-signal) | a refusal | protected evaluation in a property |
| [Laws of the built-ins](#laws-of-the-built-ins) | one-line laws | `t` over temporal types; `strc` |
| [A functional query against its template](#a-functional-query-against-its-template) | two forms that should agree | `tabr` |
| [A pivot that loses a value](#a-pivot-that-loses-a-value) | a conservation law | `tabr` with a key that repeats |
| [Update by group, and splitting the input](#update-by-group-and-splitting-the-input) | an invariant and a split | `tabr` beside a count |
| [A view as the oracle](#a-view-as-the-oracle) | an oracle that q recomputes | `sm` with the state in a view |
| [Amend by name and by value](#amend-by-name-and-by-value) | an oracle | pairs |
| [Dictionaries: join, fill and arithmetic](#dictionaries-join-fill-and-arithmetic) | three laws | `uniq`; `t` for nulls |
| [Patterns without a default](#patterns-without-a-default) | every input is handled | `int` over the bytes |
| [Compressed files and an append log](#compressed-files-and-an-append-log) | round trips | `val` |
| [Asynchronous messages and the close of a handle](#asynchronous-messages-and-the-close-of-a-handle) | a model over two processes | `sm` with a reconnect command |

## An as-of join against a naive one

*As a script: `examples/aj.q`.*

**The rule.** You have written a join, and there is an obvious, slow way to compute the same answer: for each
trade, look through the quotes. The slow way is the *oracle*, and the rule is that the two agree on every input.
Here the roles are the other way round, so that the recipe runs as it stands: q's `aj` is taken as right, and
the hand-written join has the bug. It takes the *first* quote at or before the trade, where an as-of join takes
the last.

**The generators.** Two tables are needed, and they should share their symbols. With symbols drawn separately
for each table from any realistic universe, a trade would seldom find a quote, and the rule would pass while
testing very little. So a list of symbols is drawn first and both tables draw their `sym` from it.

```q
q)syms:.qc.lst[1 3] .qc.symc["abc";1 1]
q)tbl:{[s;nm;g] .qc.tabr[1 0W] (`sym`time,nm)!(.qc.elem s; .qc.mono[.qc.int 0 9;.qc.int 0 9]; g)}
q)pair:{[d] s:.qc.draw syms; `q`t!(.qc.draw tbl[s;`px;.qc.int 0 9]; .qc.draw tbl[s;`qty;.qc.int 0 9])}
q)naive:{[t;q] f:{[q;s;tm] $[count r:exec px from q where sym=s,time<=tm; first r; 0N]}[q]; update px:"j"$f'[sym;time] from t}
q).qc.check[pair; {.qc.eq[aj[`sym`time;x`t;x`q]; naive[x`t;x`q]]}];
FAIL falsified after 1 tests, 8 shrinks (88 attempts, seed 7)
x:
  q:
    sym time px
    -----------
    a   0    0
    a   0    1
  t:
    sym time qty
    ------------
    a   0    0
qc.eq
path  why   a b
---------------
`px 0 value 1 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 0 0 0 1 0 0 0 0 1 0 0 0 1 0 0 1 0]
```

- `syms` is a list of one to three symbols, each one letter from `"abc"`.
- `tbl[s;nm;g]` is the generator of a table of at least one row (`1 0W`). Its `sym` is an item of `s`. Its
  `time` is `mono`: it starts from a long between 0 and 9 and each row adds between 0 and 9 to the row before,
  so the column is sorted by construction, as `aj` needs, and two rows can share a time. The third column is
  named `nm` and drawn from `g`. Times are small longs and not timestamps because nothing in the rule depends
  on what kind of number a time is, and small longs are easier to read in a report.
- `pair` is a generator written as a function: it draws the symbols, then a quote table and a trade table over
  them, and returns both in a dict. (Its argument `d` is passed to every generator and is not used.)

**The property** compares the two joins with `.qc.eq`, which is `~` with an explanation when the sides differ.

**The report.** `x:` is the input, a dict of the two tables. One symbol, two quotes at one time with different
prices, and one trade at that time. Nothing can be taken away: with one quote, first and last are the same
quote; with two quotes at the same price, the wrong quote gives the right answer. The `qc.eq` table says where
the answers differ: at column `px`, row 0, where `aj` has 1 and the naive join has 0.

**The fix** is `last` for `first`, and the rule then holds over a hundred pairs of tables.

```q
q)syms:.qc.lst[1 3] .qc.symc["abc";1 1]
q)tbl:{[s;nm;g] .qc.tabr[1 0W] (`sym`time,nm)!(.qc.elem s; .qc.mono[.qc.int 0 9;.qc.int 0 9]; g)}
q)pair:{[d] s:.qc.draw syms; `q`t!(.qc.draw tbl[s;`px;.qc.int 0 9]; .qc.draw tbl[s;`qty;.qc.int 0 9])}
q)fixed:{[t;q] f:{[q;s;tm] $[count r:exec px from q where sym=s,time<=tm; last r; 0N]}[q]; update px:"j"$f'[sym;time] from t}
q).qc.check[pair; {.qc.eq[aj[`sym`time;x`t;x`q]; fixed[x`t;x`q]]}];
ok 100 tests (seed 7)
```

## Upsert on keyed tables

**The rule.** Another oracle: a hand-rolled upsert against q's `upsert`. The hand-rolled one appends the rows
of both tables and keys the result again, which looks right and keeps both copies of a key that the tables
share.

**The generator.** `.qc.ktab[k;r] cols` draws a keyed table: `k` is the key column, `r` the range for the number
of rows, and the key values within one table are distinct. The keys here come from 0 to 3, so a table has at
most four rows, and two tables drawn separately are likely to collide, which is the case the rule is about.

```q
q)kt:.qc.ktab[`k;0 4] `k`v!(.qc.int 0 3; .qc.int 0 9)
q).qc.draw kt
k| v
-| -
0| 0
3| 2
2| 1
q)bad:{[t;u] keys[t] xkey (0!t),0!u}
q).qc.check[(kt;kt); {[t;u] .qc.eq[t upsert u; bad[t;u]]}];
FAIL falsified after 4 tests, 5 shrinks (43 attempts, seed 7)
t:
  k| v
  -| -
  0| 0
u:
  k| v
  -| -
  0| 0
qc.eq
path why   a b
--------------
     count 1 2
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 0 1 0 0 0]
```

**The property** takes two tables, so the generator is a list of two, and the report names the inputs after the
property's parameters.

**The report.** One row in each table, with the same key. The diff has no path, because the difference is in the
tables as wholes: a `count` of 1 on one side and 2 on the other. The values did not matter, so they shrank to 0.

**A wider range of keys.** With keys from 0 to a million, two tables drawn at random would almost never share
a key, and you might expect the rule to pass for a long time. It does not:

```q
q)big:.qc.ktab[`k;0 4] `k`v!(.qc.int 0 1000000; .qc.int 0 9)
q)bad:{[t;u] keys[t] xkey (0!t),0!u}
q).qc.check[(big;big); {[t;u] .qc.eq[t upsert u; bad[t;u]]}];
FAIL falsified after 45 tests, 4 shrinks (34 attempts, seed 7)
t:
  k| v
  -| -
  0| 0
u:
  k| v
  -| -
  0| 0
qc.eq
path why   a b
--------------
     count 1 2
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 0 1 0 0 0]
```

It took 45 tests where the narrow range took 4, and the counterexample is the same. `.qc.int` does not draw
evenly. It draws small values, and the ends of its range, far more often than the values between, because that
is where bugs are, and so two tables soon share a key. A narrow range says what is meant, but the bug does not
hide behind a wide one.

**The fix** is to join keyed tables as keyed tables: `,` on two keyed tables is an upsert.

```q
q)kt:.qc.ktab[`k;0 4] `k`v!(.qc.int 0 3; .qc.int 0 9)
q).qc.check[(kt;kt); {[t;u] .qc.eq[t upsert u; t,u]}];
ok 100 tests (seed 7)
```

## A splayed table reads back changed

**The rule.** A *round trip*: write a value, read it back, and you should have what you started with. It is the
rule to reach for whenever two functions are meant to undo each other.

**The generator.** `.qc.schema` reads a generator off a sample table: the same columns, of the same types. It
saves writing out a generator for a table you already have.

```q
q)dir:hsym `$first system "mktemp -d"
q)trade:.qc.schema ([]sym:`a`b; px:1.5 2.5; qty:1 2)
q)saveload:{[t] (` sv dir,`trade`) set .Q.en[dir] t; select from ` sv dir,`trade`}
q).qc.check[trade; {.qc.eq[x; saveload x]}];
FAIL falsified after 0 tests, 0 shrinks (1 attempts, seed 7)
x:
  sym px qty
  ----------
qc.eq
path why  a  b
---------------
sym  type 11 20
rerun: .qc.again[]  or  .qc.recheck[gen;prop;0]
q).qc.check[trade; {.qc.eq[x; update value sym from saveload x]}];
ok 100 tests (seed 7)
q)system"rm -rf ",1_string dir

```

**The report.** The rule fails on the first example, and the counterexample is a table with no rows: the
difference is one of type, so no row is needed to show it. The `sym` column went in as symbols (type 11) and came
back as an enumeration (type 20), which is what `.Q.en` is for: it enumerates every symbol column over the
`sym` file in the database root, writing the file as it goes. The two tables look the same at the console and
join the same. They are not the same to `~`, and so not to any caller, or test, that compares what it read back
with what it wrote.

**The fix** is in the rule and not in the code. What is promised is that the *values* come back, so the property
compares against `value sym`, and the second check passes. A failing property does not always mean the code is
wrong; sometimes it means the rule said more than you meant, and finding that out is worth as much.

## A stateful test of a tickerplant handler

**The rule.** `upd` has no answer to check. It changes a table, and what matters is the table after many calls.
That calls for a stateful test (`README.md` explains these, under "Stateful testing"). The *model* is the simplest
thing that can say what the table should hold: here, a count of the rows that have been fed. The rule is an
*invariant*, checked after every call: the table has as many rows as the model has counted.

This `upd` upserts by symbol, so the table keeps one row for each symbol, and a symbol that appears twice, in
one batch or in two, loses a row.

```q
q)TBL:([]sym:`symbol$(); px:`float$())
q)upd:{[t;x] TBL::0!(`sym xkey TBL) upsert x}
q)cmds:([cmd:enlist `upd] gen:enlist {[m] .qc.tabr[1 5] `sym`px!(.qc.symc["ab";1 1]; .qc.flt 0 9)}; run:enlist {[x] upd[`trade;x]}; upd:enlist {[m;a;o] m+count a})
q).qc.check[.qc.sm[`m0`init`inv!(0; {`TBL set 0#TBL}; {[m] m=count TBL})] cmds; ::];
FAIL falsified after 4 tests, 6 shrinks (68 attempts, seed 7)
qc.inv
step cmd arg                  res model ok
------------------------------------------
0    upd +`sym`px!(`a`a;0 0f) ::  2     1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 1 1 0 0 0 0 0 1 1 0 0 0 0 0 0]
```

**The commands.** There is one, so every column is a list of one item, made with `enlist`.

- `gen` takes the model and returns the generator of the command's input, a batch of one to five rows. The
  symbols are one letter from `"ab"`, so that repeats are common.
- `run` makes the call on the real system.
- `upd` moves the model on: the count goes up by the size of the batch. (This `upd` is the column of the command
  table; the `upd` in `run` is the handler.)
- There is no `pre` column, since the command can always run, and no `post`, since there is no answer to check.

**The hooks**, the dict given to `.qc.sm`: `m0` is the model at the start; `init` empties the table before
every sequence; `inv` is the invariant, a function of the model that may look at the real system.

**The report.** `qc.inv` says the invariant was false, and the trace is one step long: one batch of two rows for
the same symbol. The `arg` column shows the batch as q prints a table on one line, as the flip (`+`) of a column dictionary, which is what a table is.
The `model` column says 2, and the table had one row.

**The fix** is to append, and the invariant then holds over every sequence of batches drawn.

```q
q)TBL:([]sym:`symbol$(); px:`float$())
q)upd:{[t;x] TBL,:x}
q)cmds:([cmd:enlist `upd] gen:enlist {[m] .qc.tabr[1 5] `sym`px!(.qc.symc["ab";1 1]; .qc.flt 0 9)}; run:enlist {[x] upd[`trade;x]}; upd:enlist {[m;a;o] m+count a})
q).qc.check[.qc.sm[`m0`init`inv!(0; {`TBL set 0#TBL}; {[m] m=count TBL})] cmds; ::];
ok 100 tests (seed 7)
```

A real handler has more tables and more calls, such as an end of day, and the model grows to match: a count for
each table, or the rows themselves. `WALKTHROUGH.md` has one of that size.

## Serialisation, over any value

**The rule.** A round trip again, over every kind of value there is. `.qc.val` draws an arbitrary q value: an
atom of any type, a list, a dict, a table.

```q
q).qc.check[.qc.val; {x~-9!-8!x}];
ok 100 tests (seed 7)
q).qc.check[.qc.val; {x~.j.k .j.j x}];
FAIL falsified after 1 tests, 7 shrinks (29 attempts, seed 7)
x: 0x00
rerun: .qc.again[]  or  .qc.recheck[gen;prop;0 2 0]
q).j.k .j.j 0x00
"00"
```

q's own serialisation is the identity on all of them. JSON is not, and the simplest value that it changes is a
byte, which goes out as a string of two characters and stays one.

**Narrowing the rule.** JSON cannot be fixed, and the rule as stated is false. What can be said is *which* values
survive, and the way to find out is to try a narrower generator and read the counterexample. Lists of floats:

```q
q).qc.check[.qc.list .qc.flt 0 1; {x~.j.k .j.j x}];
FAIL falsified after 4 tests, 52 shrinks (93 attempts, seed 7)
x: ,0.0004882812
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 11 1 0]
```

`0.0004882812` is how `2 xexp -11` prints at the console's precision of seven digits, and `.j.j` writes numbers
at that precision, so what comes back is a different float. The precision is `\P`. Then tables:

```q
q)system"P 17"
q).qc.check[.qc.list .qc.flt 0 1; {x~.j.k .j.j x}];
ok 100 tests (seed 7)
q).qc.check[.qc.tabr[0 20] `px`ok`s!(.qc.flt 0 1; .qc.bool; .qc.str); {x~.j.k .j.j x}];
FAIL falsified after 0 tests, 0 shrinks (1 attempts, seed 7)
x:
  px ok s
  -------
rerun: .qc.again[]  or  .qc.recheck[gen;prop;0]
```

With seventeen digits the floats survive. The table does not, when it is empty: it goes out as `[]`, which
comes back as an empty list and not as a table. With at least one row the rule holds:

```q
q)system"P 17"
q).qc.check[.qc.tabr[1 20] `px`ok`s!(.qc.flt 0 1; .qc.bool; .qc.str); {x~.j.k .j.j x}];
ok 100 tests (seed 7)
```

The rule that stands is a statement of what JSON carries for you: tables of floats, booleans and strings, with
at least a row, at full precision. The last two conditions came from counterexamples. The first is the set of
types that JSON has: a long comes back as a float, and a symbol as a string.

## Per-minute bars

**The rule.** An oracle once more. Bars are computed by one `select`, and the high of each bar can be checked
against a second, simpler query that computes only the high. The bug: the high is taken with `first`.

**The generator.** A table of trades that starts within one session. `.qc.ts[from;to]` draws a timestamp in a
window, and `mono` over it gives times that start somewhere in the session and move forward by up to a minute
for each row, so that some minutes hold several trades and some trades cross into the next minute.

```q
q)day:2024.01.02D09:30; close:2024.01.02D16:00
q)trades:.qc.tabr[1 50] `time`px!(.qc.mono[.qc.ts[day;close]; .qc.int (0;"j"$0D00:01)]; .qc.flt 1 100)
q)5#.qc.draw trades
time                          px
--------------------------------------
2024.01.02D09:39:27.325624832 46
2024.01.02D09:39:27.353246638 66.61908
2024.01.02D09:39:31.901451870 23.73649
2024.01.02D09:39:31.901451871 50
2024.01.02D09:39:31.901553860 9.04231
q)bars:{select o:first px, h:first px, l:min px, c:last px by 0D00:01 xbar time from x}
q).qc.check[trades; {b:0!bars x; mx:0!select mx:max px by 0D00:01 xbar time from x; .qc.eq[mx`mx; b`h]}];
FAIL falsified after 3 tests, 10 shrinks (146 attempts, seed 7)
x:
  time                          px
  --------------------------------
  2024.01.02D09:30:00.000000000 1
  2024.01.02D09:30:00.000000000 2
qc.eq
path why   a b
--------------
0    value 2 1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 757503000000000000 0 43 8796093022208 1 0 0 0 2 0]
```

**The report.** Two trades in one minute, the second at a higher price. One trade could not show the bug, since
the first price of a bar of one trade is its highest, and two trades at falling prices could not either. The
time shrank to the start of the session and the prices to 1 and 2, the simplest floats in the range that differ
in the right direction. The diff says that the high of the first bar should be 2 and is 1.

**The fix** is `max` for `first`.

```q
q)day:2024.01.02D09:30; close:2024.01.02D16:00
q)trades:.qc.tabr[1 50] `time`px!(.qc.mono[.qc.ts[day;close]; .qc.int (0;"j"$0D00:01)]; .qc.flt 1 100)
q)bars:{select o:first px, h:max px, l:min px, c:last px by 0D00:01 xbar time from x}
q).qc.check[trades; {b:0!bars x; mx:0!select mx:max px by 0D00:01 xbar time from x; .qc.eq[mx`mx; b`h]}];
ok 100 tests (seed 7)
```

A rule that needs no oracle at all would have caught the same bug: in every bar the high is at least the open
and the close, and the low at most. Rules of that kind, true of every right answer, are cheap to write and worth
keeping beside the oracle. They are weaker than it, since a high that is too high would pass this one:

```q
q)day:2024.01.02D09:30; close:2024.01.02D16:00
q)trades:.qc.tabr[1 50] `time`px!(.qc.mono[.qc.ts[day;close]; .qc.int (0;"j"$0D00:01)]; .qc.flt 1 100)
q)bars:{select o:first px, h:first px, l:min px, c:last px by 0D00:01 xbar time from x}
q).qc.check[trades; {b:0!bars x; all (b[`h]>=b`o) and (b[`h]>=b`c) and (b[`l]<=b`o) and b[`l]<=b`c}];
FAIL falsified after 3 tests, 12 shrinks (144 attempts, seed 7)
x:
  time                          px
  --------------------------------
  2024.01.02D09:30:00.000000000 1
  2024.01.02D09:30:00.000000000 2
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 757503000000000000 0 24 16777216 1 0 0 0 2 0]
```

## A sorted vector and its attribute

**The rule.** Code that works on sorted data has two things to get right: the answer, and the `s#` attribute that
lets q search the result quickly. Losing the attribute breaks nothing that a test of values would notice. The
answers stay right and the queries get slow.

**The generator.** `.qc.atr[a] g` draws from `g` and gives the value the attribute `a`, one of `s`, `u`, `p` and
`g`. It makes the value fit first: for `s` and `p` it sorts, and for `u` it removes repeats. So a function that
requires sorted input can be given nothing else.

```q
q)ts:.qc.atr[`s] .qc.lst[1 10] .qc.int 0 20
q).qc.draw ts
`s#0 0 1 1 2 2 6 8 16
q).qc.minimal ts
`s#,0
q)at:{[ts;t] ts binr t}
q).qc.check[(ts;.qc.int 0 20); {[ts;t] .qc.eq[-1+sum ts<=t; at[ts;t]]}];
FAIL falsified after 1 tests, 1 shrinks (10 attempts, seed 7)
ts: `s#,0
t: 1
qc.eq
path why   a b
--------------
     value 0 1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 1]
```

`at[ts;t]` is meant to be the index of the last item of `ts` at or before `t`. The oracle counts the items at or
before `t` and takes one off. The bug is `binr` where `bin` was meant.

**The report.** The times are the single item 0 and `t` is 1. The last item at or before 1 is at index 0, and
`binr` says 1: it looks for the first item at or *after* `t`. With `t` equal to the item the two agree, so the
counterexample has `t` one more than it.

**The fix** is `bin`, and then a second function, which puts a time into the vector where it belongs:

```q
q)ts:.qc.atr[`s] .qc.lst[1 10] .qc.int 0 20
q)at:{[ts;t] ts bin t}
q).qc.check[(ts;.qc.int 0 20); {[ts;t] .qc.eq[-1+sum ts<=t; at[ts;t]]}];
ok 100 tests (seed 7)
q)ins:{[ts;t] (ts where ts<=t),t,ts where ts>t}
q).qc.check[(ts;.qc.int 0 20); {[ts;t] ins[ts;t]~asc ts,t}];
ok 100 tests (seed 7)
q).qc.check[(ts;.qc.int 0 20); {[ts;t] .qc.eq[`s; attr ins[ts;t]]}];
FAIL falsified after 0 tests, 0 shrinks (6 attempts, seed 7)
ts: `s#,0
t: 0
qc.eq
path why   a b
--------------
     value s
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 0]
```

The values are right: the second check passes. The third says that the result still has the attribute, and it
fails on the first example. `~` does not look at attributes, so the rule about values could never have seen
this. The pieces that `ins` joins are sorted, and their join has no attribute, because q does not check that a
join of sorted vectors is sorted.

**The fix** is to say so, with `` `s# ``, which checks the order as it sets the attribute:

```q
q)ts:.qc.atr[`s] .qc.lst[1 10] .qc.int 0 20
q)ins:{[ts;t] `s#(ts where ts<=t),t,ts where ts>t}
q).qc.check[(ts;.qc.int 0 20); {[ts;t] r:ins[ts;t]; (r~asc ts,t) and `s=attr r}];
ok 100 tests (seed 7)
```

The same two rules fit a table with a sorted or a parted column. `.qc.schema` reads the attributes of a sample
table, so a generated table with rows carries them as the sample does. The empty table carries none, and it is
the first example a check tries, so a rule that says "the result keeps the attribute" has to allow for it.

## An order's lifecycle: a transition table as the model

*As a script: `examples/order.q`.*

**The rule.** Some systems are state machines in the plain sense: an order is `new`, then acknowledged, then
partly or wholly filled, or cancelled, or rejected, and the specification says which event may follow which
state. A q programmer writes that specification down as a table, and the natural rule is that the system
follows the table. A stateful test says exactly that when the table drives it: the model is one symbol, the
state the order ought to be in; each event is a command; and the three hooks are the table read three ways:
`pre` asks it whether the event may happen in that state, `post` whether the system moved to the state it
names, `upd` moves the model there.

**The system.** An order that keeps its state in a global and moves on an event. The bug is planted in the
branch for a fill of a partly filled order, which leaves the order partly filled.

```q
q)T:([st:`new`new`new`ack`ack`ack`part`part`part; ev:`ack`rej`cxl`part`fill`cxl`part`fill`cxl] nx:`ack`rej`cxl`part`fill`cxl`part`fill`cxl)
q)D:exec ev!nx by st from T
q)D[`ack;`part]
`part
q)ORD:`new
q)on:{[e] s:ORD; n:$[(s=`new) and e=`ack; `ack; (s=`ack) and e=`rej; `rej; (s=`ack) and e=`cxl; `cxl; (s=`ack) and e=`part; `part; (s=`ack) and e=`fill; `fill; (s=`part) and e=`part; `part; (s=`part) and e=`fill; `part; (s=`part) and e=`cxl; `cxl; (s=`new) and e in `rej`cxl; e; '"order: ",string[e]," not allowed in ",string s]; ORD::n; n}
q)evs:exec distinct ev from T
q)cmds:([cmd:evs] pre:{[e;m] not null D[m;e]}@/:evs; run:{[e;a] on e}@/:evs; post:{[e;m;a;o] o~D[m;e]}@/:evs; upd:{[e;m;a;o] D[m;e]}@/:evs)
q).qc.check[.qc.sm[`m0`init!(`new;{`ORD set `new})] cmds; ::];
FAIL falsified after 21 tests, 0 shrinks (26 attempts, seed 7)
qc.post
step cmd  arg res  model ok
---------------------------
0    ack  ::  ack  ack   1
1    part ::  part part  1
2    fill ::  part fill  0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 1 3 1 4]
```

`T` is the keyed table of the specification, and `D` the same table as a dictionary of dictionaries: `by st`
groups the rows by state, and `ev!nx` makes each group a dictionary from event to next state, so that
`D[state;event]` is the next state, and a null symbol where the table has no row (a terminal state has no
rows, so it indexes to an empty dictionary, and that to a null). Both are the table; `D` is the shape that
reads as a function. The commands are one per event, and their functions are built from the table with a
projection over the event: `{[e;m] ...}@/:evs` is a two-argument function fixed on each event in turn, leaving
the argument the stateful test supplies (the model for `pre`, the input for `run`, and so on). The command
table is one line and holds no knowledge of its own: `pre` asks the table, `post` compares with it, `upd`
follows it.

**The report.** Three steps, the shortest sequence that reaches the bug: the system says `part` where the
table says `fill`. The bug needs an order that is partly filled, and the only way there is `ack` then `part`,
so nothing shorter fails.

**The fix** is `` `fill `` for `` `part `` in that branch of `on`:

```q
q)T:([st:`new`new`new`ack`ack`ack`part`part`part; ev:`ack`rej`cxl`part`fill`cxl`part`fill`cxl] nx:`ack`rej`cxl`part`fill`cxl`part`fill`cxl)
q)D:exec ev!nx by st from T
q)ORD:`new
q)on:{[e] s:ORD; n:$[(s=`new) and e=`ack; `ack; (s=`ack) and e=`rej; `rej; (s=`ack) and e=`cxl; `cxl; (s=`ack) and e=`part; `part; (s=`ack) and e=`fill; `fill; (s=`part) and e=`part; `part; (s=`part) and e=`fill; `fill; (s=`part) and e=`cxl; `cxl; (s=`new) and e in `rej`cxl; e; '"order: ",string[e]," not allowed in ",string s]; ORD::n; n}
q)evs:exec distinct ev from T
q)cmds:([cmd:evs] pre:{[e;m] not null D[m;e]}@/:evs; run:{[e;a] on e}@/:evs; post:{[e;m;a;o] o~D[m;e]}@/:evs; upd:{[e;m;a;o] D[m;e]}@/:evs)
q).qc.check[.qc.sm[`m0`init!(`new;{`ORD set `new})] cmds; ::];
ok 100 tests (seed 7)
```

Two rules about the table itself need no system at all. The trace of states an event sequence produces is a
scan over the table, an event the table does not allow leaving the state where it is; once an order is filled,
cancelled or rejected, it stays in that state; and the table allows no event in a terminal state:

```q
q)T:([st:`new`new`new`ack`ack`ack`part`part`part; ev:`ack`rej`cxl`part`fill`cxl`part`fill`cxl] nx:`ack`rej`cxl`part`fill`cxl`part`fill`cxl)
q)D:exec ev!nx by st from T
q)walk:{[s;e] $[null n:D[s;e]; s; n]}
q)walk\[`new;`ack`part`fill`cxl]
`ack`part`fill`fill
q)END:`rej`cxl`fill
q).qc.check[.qc.list .qc.elem exec distinct ev from T; {w:walk\[`new;x]; all (-1_w in END)<=(1_w)=-1_w}];
ok 100 tests (seed 7)
q).qc.check[(.qc.elem END; .qc.elem exec distinct ev from T); {[s;e] null D[s;e]}];
ok 15 tests, exhausted (seed 7)
```

The second is a proof, not a sample: three terminal states and five events are fifteen inputs, and the run
tried them all.

## FIFO allocation: an oracle from the obvious loop

**The rule.** Sells are filled from buys in order: the first sell takes from the first buys until it is filled,
the next sell carries on from there. q does it in one line without a loop, `deltas each deltas sums[sells]&\:sums
buys`, which is fast and hard to read. The obvious loop is slow and easy to believe, and the rule is that the
two agree. Two conservation laws come with it: each sell gets what was left for it and no more, and no buy
gives more than it has.

```q
q)alloc:{[buys;sells] deltas each deltas sums[sells]&\:sums buys}
q)slow:{[buys;sells] r:(count[sells];count buys)#0; i:0; while[i<count sells; need:sells i; j:0; while[(need>0) and j<count buys; k:need&buys j; r[i;j]:k; buys[j]-:k; need-:k; j+:1]; i+:1]; r}
q)alloc[10 5;7 8]
7 0
3 5
q)g:(.qc.lst[0 5] .qc.int 0 9; .qc.lst[0 5] .qc.int 0 9)
q).qc.check[g; {[b;s] .qc.eq[alloc[b;s]; slow[b;s]]}];
FAIL falsified after 0 tests, 0 shrinks (2 attempts, seed 7)
b: ()
s: ()
length
rerun: .qc.again[]  or  .qc.recheck[gen;prop;0 0]
```

**The report.** The first example is two empty lists, and it is the loop that fails with `length`: `(0;0)#0`,
a matrix with no rows and no columns, is a shape q will not take. The one-liner returns an empty list. Whether
an order book with nothing in it is an input the code must take is a question for the system; here the rule is
narrowed to books with at least a buy and a sell, and the laws are added:

```q
q)alloc:{[buys;sells] deltas each deltas sums[sells]&\:sums buys}
q)slow:{[buys;sells] r:(count[sells];count buys)#0; i:0; while[i<count sells; need:sells i; j:0; while[(need>0) and j<count buys; k:need&buys j; r[i;j]:k; buys[j]-:k; need-:k; j+:1]; i+:1]; r}
q)g:(.qc.lst[1 5] .qc.int 0 9; .qc.lst[1 5] .qc.int 0 9)
q).qc.check[g; {[b;s] .qc.eq[alloc[b;s]; slow[b;s]]}];
ok 100 tests (seed 7)
q).qc.check[g; {[b;s] (sum each alloc[b;s])~deltas (sums s)&sum b}];
ok 100 tests (seed 7)
q).qc.check[g; {[b;s] all (sum alloc[b;s])<=b}];
ok 100 tests (seed 7)
q)bug:{[buys;sells] deltas sums[sells]&\:sums buys}
q).qc.check[g; {[b;s] .qc.eq[bug[b;s]; slow[b;s]]}];
FAIL falsified after 1 tests, 3 shrinks (56 attempts, seed 7)
b: 1 0
s: ,1
qc.eq
path why   a b
--------------
0 1  value 1 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 0 0 1 1 0]
```

The planted bug drops the inner `deltas each`, so each row is a running total instead of an allocation, and
the report shows the smallest book that tells them apart.

## Joins: `lj`, `ej`, `pj` and where they differ

**The rule.** Every join has an oracle in a lookup: for each row of the left table, find its key in the right
one. `lj` against that lookup is the first rule. The others are about what a join does when the right side has
a key twice, and which side wins a column both have.

```q
q)kt:.qc.ktab[`k;0 4] `k`v!(.qc.int 0 3; .qc.int 0 9)
q)t:.qc.tabr[0 5] `k`c!(.qc.int 0 4; .qc.int 0 9)
q)slow:{[t;kt] r:kt ([]k:t`k); t,'$[count t; r; 0#value kt]}
q).qc.check[(t;kt); {[t;kt] .qc.eq[t lj kt; slow[t;kt]]}];
ok 100 tests (seed 7)
q)t2:.qc.tabr[0 5] `k`v!(.qc.int 0 4; .qc.int 0 9)
q).qc.check[(t2;kt); {[t;kt] u:t lj kt; m:t[`k] in exec k from kt; all (u[`v] where m)=(kt ([]k:t`k))[`v] where m}];
ok 100 tests (seed 7)
q).qc.check[(t2;kt); {[t;kt] w:0^(kt ([]k:t`k))`v; .qc.eq[t pj kt; @[t;`v;+;w]]}];
ok 100 tests (seed 7)
```

The lookup `kt ([]k:t`k)` is a keyed table applied to a table of keys, one row for each, nulls where the key
is missing, which is what `lj` does. Where both tables have `v`, the right side's value wins on a match and the
left's stays otherwise; `pj` adds instead, with a missing key counting as zero.

**The join that is not what it looks like.** A right side made with `xkey` over a column that repeats is a
keyed table whose duplicate keys can never be reached: only the first row of each is. `ij` on such a table
keeps one match; `ej`, the equi-join over a plain table, keeps them all. The two agree until the right side
repeats a key:

```q
q)t:.qc.tabr[0 5] `k`c!(.qc.int 0 4; .qc.int 0 9)
q)r:.qc.tabr[1 5] `k`v!(.qc.int 0 3; .qc.int 0 9)
q).qc.check[(t;r); {[t;r] .qc.eq[ej[`k;t;r]; t ij `k xkey r]}];
FAIL falsified after 6 tests, 5 shrinks (56 attempts, seed 7)
t:
  k c
  ---
  0 0
r:
  k v
  ---
  0 0
  0 0
qc.eq
path why   a b
--------------
     count 2 1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 0 1 0 0 1 0 0 0]
```

**The report.** One row on the left, two on the right with the same key: `ej` gives two rows and `ij` one.
Which is right depends on what the right table is: a table of keys, in which case a repeated one is a bug to
find with `.qc.uniq` on the generator that makes it, or a table of events, in which case `ej` is the join.

## `insert` where `upsert` was meant

**The rule.** A table of the last quote for each instrument, keyed on `sym`, fed by a handler. The handler
uses `insert`. A stateful test of the handler whose model is the same keyed table kept by `upsert` says what
`insert` does on the second quote for an instrument:

```q
q)LQ0:([sym:`symbol$()] bid:`float$(); ask:`float$())
q)upd:{[q] `LQ insert q;}
q)cmds:([cmd:enlist `quote] gen:enlist {[m] `sym`bid`ask!(.qc.elem `a`b; .qc.flt 1 9; .qc.flt 1 9)}; run:enlist {[q] upd q; LQ[q`sym]}; post:enlist {[m;q;o] o~`bid`ask#q}; upd:enlist {[m;q;o] m upsert q})
q).qc.check[.qc.sm[`m0`init!(LQ0;{`LQ set LQ0})] cmds; ::];
FAIL falsified after 4 tests, 9 shrinks (45 attempts, seed 7)
qc.run insert
step cmd   arg                     res           ok
---------------------------------------------------
0    quote `sym`bid`ask!(`a;1f;1f) `bid`ask!1 1f 1
1    quote `sym`bid`ask!(`a;1f;1f) ::            0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 0 0 1 0 0 1 1 0 0 0 0 1 0 0 1]
```

**The report.** Two quotes for `a`, and the second raises `insert`: on a keyed table, `insert` refuses a key it
already has. The report says `qc.run insert`, an error raised by the system, and the trace ends on the step
that raised it.

**The fix** is `upsert`, which is what was meant. `insert` has one use left, a table that must never see the
same key twice, where the error is the point.

```q
q)LQ0:([sym:`symbol$()] bid:`float$(); ask:`float$())
q)upd:{[q] `LQ upsert q;}
q)cmds:([cmd:enlist `quote] gen:enlist {[m] `sym`bid`ask!(.qc.elem `a`b; .qc.flt 1 9; .qc.flt 1 9)}; run:enlist {[q] upd q; LQ[q`sym]}; post:enlist {[m;q;o] o~`bid`ask#q}; upd:enlist {[m;q;o] m upsert q})
q).qc.check[.qc.sm[`m0`init!(LQ0;{`LQ set LQ0})] cmds; ::];
ok 100 tests (seed 7)
```

A second habit that `insert` punishes: a table made with untyped empty columns, `([] sym:(); px:())`, takes its
column types from the first row inserted and refuses a row of another type after it.

```q
q).qc.check[.qc.lst[1 5] .qc.one (.qc.flt 1 9; .qc.int 1 9); {`T set ([] sym:(); px:()); {`T insert (`a;x)} each x; 1b}];
FAIL falsified after 2 tests, 3 shrinks (30 attempts, seed 7)
x: (1;1f)
type
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 1 0 0 0 1 0]
```

The counterexample is a long and a float: whichever comes first sets the type, and the other is refused with
`type`. Give an empty table its types, `` ([] sym:`symbol$(); px:`float$()) ``, so that it refuses the wrong row
before the first right one has made it wrong.

## A feed that sends the wrong type

**The rule.** A feed handler appends what it is sent to a table whose columns have types. The feed mostly sends
the right types, and sometimes a `real` where a `float` is stored or an `int` where a `long` is. The rule is that
the table keeps its types, whatever the batch: `meta` after the handler equals `meta` before.

**The generator.** A table whose columns are drawn from alternatives, `.qc.one`, one of which casts to the
narrower type. Most rows are right, which is what a feed looks like.

```q
q)T0:([] sym:`symbol$(); px:`float$(); qty:`long$())
q)upd:{[x] `T insert x;}
q)batch:.qc.tabr[1 3] `sym`px`qty!(.qc.elem `a`b; .qc.one (.qc.flt 1 9; '[`real$; .qc.flt 1 9]); .qc.one (.qc.int 1 9; '[`int$; .qc.int 1 9]))
q).qc.check[batch; {`T set T0; upd x; .qc.eq[meta T; meta T0]}];
FAIL falsified after 1 tests, 4 shrinks (31 attempts, seed 7)
x:
  sym px qty
  ----------
  a   1  1
type
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 1 0 0 1 0 1 0]
```

**The report.** A batch of one row, and `insert` raises `type`: q refuses to put a `real` into a `float`
column. That is the right answer from the table's point of view, and the wrong one from the feed's, which now
has a batch it cannot deliver. A handler written with a join instead of `insert` does something quieter:

```q
q)T0:([] sym:`symbol$(); px:`float$(); qty:`long$())
q)upd:{[x] `T set T,x;}
q)batch:.qc.tabr[1 3] `sym`px`qty!(.qc.elem `a`b; .qc.one (.qc.flt 1 9; '[`real$; .qc.flt 1 9]); .qc.one (.qc.int 1 9; '[`int$; .qc.int 1 9]))
q).qc.check[batch; {`T set T0; upd x; .qc.eq[meta T; meta T0]}];
FAIL falsified after 1 tests, 5 shrinks (31 attempts, seed 7)
x:
  sym px qty
  ----------
  a   1  1
qc.eq
path why   a     b
----------------------
t    value "sfi" "sfj"
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 0 0 1 1 1 0]
```

Joined onto an empty table, the batch's types win: `qty` is now a column of ints, and the next batch of longs
joined onto it turns `qty` into a mixed list, which nothing that reads the table expects. On a table with rows
a join does the same with a `real` in `px`, silently, where `insert` raises `type`. The diff shows `meta`'s type
column, the table's and the reference's.

**The fix** is to cast at the door, so that the table's types are the handler's business and not the feed's:

```q
q)T0:([] sym:`symbol$(); px:`float$(); qty:`long$())
q)upd:{[x] `T insert update "f"$px, "j"$qty from x;}
q)batch:.qc.tabr[1 3] `sym`px`qty!(.qc.elem `a`b; .qc.one (.qc.flt 1 9; '[`real$; .qc.flt 1 9]); .qc.one (.qc.int 1 9; '[`int$; .qc.int 1 9]))
q).qc.check[batch; {`T set T0; upd x; .qc.eq[meta T; meta T0]}];
ok 100 tests (seed 7)
```

## Text that needs escaping: JSON and CSV round trips

**The rule.** Text goes out through `.j.j` or `csv 0:` and comes back through `.j.k` or `0:`, and what comes
back should be what went out. The default string and symbol generators draw letters, digits and spaces, which
no encoding has trouble with. The characters an encoding must escape are the ones to draw: quotes,
backslashes, the delimiter, newlines and tabs, brackets, and the bytes of a UTF-8 sequence.

```q
q)hard:.qc.strc[.qc.AZ,"\",\\\n\t`[]{}:;",("c"$195 169 226 130 172); 0 8]
q).qc.check[.qc.list hard; {.qc.eq[x; .j.k .j.j x]}];
ok 100 tests (seed 7)
q)syms:.qc.symc[.qc.AZ,",\" "; 0 4]
q).qc.check[.qc.tabr[0 5] `s`n!(syms; .qc.int 0 9); {.qc.eq[x; ("SJ";enlist ",") 0: csv 0: x]}];
FAIL falsified after 9 tests, 5 shrinks (38 attempts, seed 7)
x:
  s n
  ---
  " 0
qc.eq
path why   a b
---------------
`s 0 value " ""
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 64 0 0 0]
```

JSON holds: `.j.j` escapes everything the rule threw at it, and the bytes of the two UTF-8 sequences (é and €)
come back as they were. CSV does not: a symbol that is one double quote comes back as two. `csv 0:` writes a
field that begins with a quote between quotes with the quote doubled, as the format says, and `0:` reading it
back strips the outer quotes and not the doubling: four quote marks come back as two. The counterexample is
the shortest such field.

**The fix** depends on where the text is going. For a file that q alone will read, `set` and `get` keep every
byte; for a CSV that must go out, the rule is narrowed to what the format carries, and the generator with it:
`.qc.symc[.qc.AZ," ";0 4]` for symbols without quotes or the delimiter.

## A partitioned database: the sym file and the partitions

**The rule.** A day's trades are written as a partition with `.Q.dpft`, and the database mapped again with
`\l`. Three rules a kdb+ programmer relies on: a day written comes back as it was written; the `sym` file only
grows, so the symbols already in it keep their places and every partition written before still reads; and a
query for a day works, which needs every partition to hold every table.

```q
q)root:hsym `$first system "mktemp -d"
q)day:.qc.tabr[0 5] `time`sym`px!(.qc.mono[.qc.ts[2024.01.02D09:30;2024.01.02D16:00];.qc.int (0;"j"$0D00:01)]; .qc.elem `a`b`c; .qc.flt 1 9)
q)wr:{[d;t] `trade set t; .Q.dpft[root;d;`sym;`trade]; system"l ",1_string root; select from trade where date=d}
q).qc.check[day; {[t] .qc.eq[t; delete date from wr[2024.01.02;t]]}];
FAIL falsified after 0 tests, 0 shrinks (1 attempts, seed 7)
x:
  time sym px
  -----------
qc.eq
path why  a  b
---------------
sym  type 11 20
rerun: .qc.again[]  or  .qc.recheck[gen;prop;0]
q)system"rm -rf ",1_string root

```

**The report.** The first example is the empty table, and it differs in type: `sym` went in as symbols and
came back as an enumeration, as in the splayed recipe. `.Q.dpft` also sorts the table by the parted column and
moves that column to the front. The rule, restated with those three facts about the format:

```q
q)root:hsym `$first system "mktemp -d"
q)day:.qc.tabr[0 5] `time`sym`px!(.qc.mono[.qc.ts[2024.01.02D09:30;2024.01.02D16:00];.qc.int (0;"j"$0D00:01)]; .qc.elem `a`b`c; .qc.flt 1 9)
q)wr:{[d;t] `trade set t; .Q.dpft[root;d;`sym;`trade]; system"l ",1_string root; select from trade where date=d}
q).qc.check[day; {[t] .qc.eq[`sym xasc t; (cols t) xcols update value sym from delete date from wr[2024.01.02;t]]}];
ok 100 tests (seed 7)
q).qc.check[(day;day); {[t;u] wr[2024.01.02;t]; s0:get ` sv root,`sym; wr[2024.01.03;u]; s1:get ` sv root,`sym; s0~(count s0)#s1}];
ok 100 tests (seed 7)
q).qc.check[(day;day); {[t;u] wr[2024.01.02;t]; `quote set ([]time:`timestamp$();sym:`symbol$();bid:`float$()); .Q.dpft[root;2024.01.02;`sym;`quote]; wr[2024.01.03;u]; .qc.eq[count select from quote where date=2024.01.03; 0]}];
FAIL falsified after 0 tests, 0 shrinks (2 attempts, seed 7)
t:
  time sym px
  -----------
u:
  time sym px
  -----------
length
rerun: .qc.again[]  or  .qc.recheck[gen;prop;0 0]
q)system"rm -rf ",1_string root

```

The second rule holds: `.Q.en` appends new symbols to the `sym` file and moves none. The third fails on the
first example: a `quote` table written for the first day and not the second, and a query of the second day's
quotes raises `length` instead of returning no rows. q lists the partitioned tables from the last partition,
and that one has no `quote` directory, so `quote` is not mapped at all: the name still holds the empty table
set before the write, `date` now holds the two partitions, and the `where` clause does not conform. Had the
table been missing from the first day and not the last, the error would name the file it could not find.
Either way, every partition must hold every table, empty or not.

**The fix** is `.Q.chk`, which writes an empty copy of every table into each partition that lacks it, after
each write:

```q
q)root:hsym `$first system "mktemp -d"
q)day:.qc.tabr[0 5] `time`sym`px!(.qc.mono[.qc.ts[2024.01.02D09:30;2024.01.02D16:00];.qc.int (0;"j"$0D00:01)]; .qc.elem `a`b`c; .qc.flt 1 9)
q)wr:{[d;t] `trade set t; .Q.dpft[root;d;`sym;`trade]; .Q.chk root; system"l ",1_string root; select from trade where date=d}
q).qc.check[(day;day); {[t;u] wr[2024.01.02;t]; `quote set ([]time:`timestamp$();sym:`symbol$();bid:`float$()); .Q.dpft[root;2024.01.02;`sym;`quote]; wr[2024.01.03;u]; .qc.eq[count select from quote where date=2024.01.03; 0]}];
ok 100 tests (seed 7)
q)system"rm -rf ",1_string root

```

Each session here writes under a directory `mktemp` made, and `\l` of it makes that directory the working
directory of the session; a script that does this should remove the directory when it exits (`.z.exit` runs on
every exit), and a failure database kept by the library stays where q was started.

## `fby` and the order of `where` clauses

**The rule.** "The best price for each symbol on exchange `N`" is an everyday query, and `fby` is how q writes
the per-group part of it: `px=(max;px) fby sym`. The `where` clause has two constraints, and it seems not to
matter which comes first. It does: q applies them in order, and `fby` groups over the rows that are left by the
clauses before it.

```q
q)t:.qc.tabr[0 6] `sym`ex`px!(.qc.elem `a`b; .qc.elem `N`Q; .qc.int 1 9)
q).qc.check[t; {.qc.eq[select from x where ex=`N, px=(max;px) fby sym; select from x where px=(max;px) fby sym, ex=`N]}];
FAIL falsified after 8 tests, 8 shrinks (62 attempts, seed 7)
x:
  sym ex px
  ---------
  a   N  1
  a   Q  2
qc.eq
path why   a b
--------------
     count 1 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 1 1 0 1 2 0]
```

**The report.** Two rows for `a`: a price of 1 on `N` and 2 on `Q`. With the exchange first, the maximum over
`N` alone is 1 and the row is kept; with `fby` first, the maximum over both exchanges is 2, the `Q` row is the
best, and then the exchange clause throws it away, so nothing is left. Neither query is wrong; they ask
different questions, and the one that was meant is the first. An oracle says so without `fby`: the per-symbol
maximum as a dictionary, looked up row by row.

```q
q)t:.qc.tabr[0 6] `sym`ex`px!(.qc.elem `a`b; .qc.elem `N`Q; .qc.int 1 9)
q).qc.check[t; {n:select from x where ex=`N; m:exec max px by sym from n; .qc.eq[select from n where px=(max;px) fby sym; select from n where px=m sym]}];
ok 100 tests (seed 7)
```

## The first item: `deltas`, `differ` and `sums`

**The rule.** `deltas` gives the differences between neighbours, and its first item is the first item itself,
as if a zero came before it. `differ` says where a value changed from the one before, and its first item is
always true. The first is what makes `sums deltas x` give `x` back, and both catch out code that reads them
as "the steps" or "the changes".

```q
q).qc.check[.qc.list .qc.int -9 9; {x~sums deltas x}];
ok 100 tests (seed 7)
q).qc.check[.qc.list .qc.t"j"; {x~sums deltas x}];
FAIL falsified after 14 tests, 13 shrinks (64 attempts, seed 7)
x: ,0N
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 0 0 0]
q).qc.check[.qc.lst[2 9] .qc.int -9 9; {.qc.eq[max abs deltas x; max abs 1_deltas x]}];
FAIL falsified after 6 tests, 2 shrinks (38 attempts, seed 7)
x: 1 1
qc.eq
path why   a b
--------------
     value 1 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 1 0]
q).qc.check[.qc.lst[1 9] .qc.int 0 2; {.qc.eq[sum differ x; sum 0<>1_deltas x]}];
FAIL falsified after 0 tests, 0 shrinks (6 attempts, seed 7)
x: ,0
qc.eq
path why   a b
--------------
     value 1 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0]
```

**The report.** The round trip holds on longs and fails on a null: `deltas` of `,0N` is `,0N`, and `sums`
skips a null, so what comes back is `,0`. The largest step of `1 1` is 0, not 1: the 1 that `max abs deltas`
reports is the first item, not a step. And a list of one item has no changes in it, where `sum differ` says
one. Drop the first item, `1_deltas x`, where a step or a change is what is meant.

## `sublist`, not take

**The rule.** "The first n items" is `n sublist x`, and `n#x` looks the same and is often written for it.
Take recycles: asked for more items than the list has, it starts again from the front. `sublist` stops.
`rotate` has the opposite habit, and a useful one: it works modulo the count, so rotating back undoes it
whatever `n` is.

```q
q).qc.check[(.qc.int 0 9; .qc.list .qc.int 0 9); {[n;x] .qc.eq[n sublist x; n#x]}];
FAIL falsified after 2 tests, 3 shrinks (8 attempts, seed 7)
n: 1
x: ()
qc.eq
path why   a b
--------------
     count 0 1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0]
q).qc.check[(.qc.int 0 20; .qc.lst[1 5] .qc.int 0 9); {[n;x] x~neg[n] rotate n rotate x}];
ok 100 tests (seed 7)
```

**The report.** One item asked of an empty list: `sublist` gives the empty list, and take gives one item where
there was none (a null of the list's type; for the general empty list, an empty list). The rule about `rotate` holds.

## Forward fill, by symbol

**The rule.** A table of quotes with gaps in the price, and `fills` to carry the last price forward. Written
`update fills px from t`, it carries a price forward across symbols: `b` gets `a`'s price. The rule is that a
symbol's filled prices are only ever prices that symbol had.

```q
q)q0:.qc.tabr[0 6] `sym`px!(.qc.elem `a`b; .qc.freq[3 1] (.qc.flt 1 9; 0n))
q)own:{[x;r;s] all (r[`px] where r[`sym]=s) in 0n,x[`px] where x[`sym]=s}
q).qc.check[q0; {r:update fills px from x; all own[x;r] each distinct x`sym}];
FAIL falsified after 18 tests, 5 shrinks (49 attempts, seed 7)
x:
  sym px
  ------
  a   1
  b
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 0 0 1 1 1 1 0]
q).qc.check[q0; {r:update fills px by sym from x; all own[x;r] each distinct x`sym}];
ok 100 tests (seed 7)
```

**The report.** Two rows: a price for `a` and a gap for `b`, and `b` is filled with `a`'s price. `by sym` is
the fix, and the second check is the fixed one. `.qc.freq[3 1]` draws a price three times in four and a null
once, so that gaps are common but not the rule.

## Casts and text: what comes back is not what went in

**The rule.** Casts that narrow, and text that is parsed back, both look like round trips and are not quite.
Three rules, all false, each with the value that breaks it:

```q
q).qc.check[.qc.t"j"; {x~"j"$"i"$x}];
FAIL falsified after 1 tests, 33 shrinks (101 attempts, seed 7)
x: 2147483648
rerun: .qc.again[]  or  .qc.recheck[gen;prop;0 0 2147483648]
q).qc.check[.qc.t"f"; {.qc.eq[x; "F"$string x]}];
FAIL falsified after 1 tests, 54 shrinks (123 attempts, seed 7)
x: 1e+07
qc.eq
path why   a           b
----------------------------------
     value "10000001f" "10000000f"
rerun: .qc.again[]  or  .qc.recheck[gen;prop;0 0 0 0 10000001]
q).qc.check[.qc.flt 0 99; {not null "I"$string x}];
FAIL falsified after 1 tests, 54 shrinks (72 attempts, seed 7)
x: 0.5
rerun: .qc.again[]  or  .qc.recheck[gen;prop;0 1 1]
```

**The report.** A long one past the largest int comes back as the int infinity: a cast that narrows does not
signal, it caps. A float with eight significant digits comes back as a different float: `string` prints seven,
the console's precision (`\P`), and what it printed is what was parsed. And `"I"$` of a string with a decimal
point in it is a null, not an error, since parsing text into a type gives the type's null for anything it does
not recognise. Each of these is a place where a check of the result, `null`, `=`, or `.qc.eq` in a test, is the
only thing standing between the mistake and the data.

## Integer overflow

**The rule.** q does not check for overflow on longs: `0W+1` is the null, and a sum past the largest long
wraps to a negative number. The Fibonacci numbers grow, and a function that computes the first `n` of them
computes positive numbers, for a while.

```q
q)fib:{x {x,sum -2#x}/1 1}
q).qc.check[.qc.int 0 100; {all 0<fib x}];
FAIL falsified after 32 tests, 2 shrinks (14 attempts, seed 7)
x: 91
rerun: .qc.again[]  or  .qc.recheck[gen;prop;91]
```

**The report.** The 93rd Fibonacci number does not fit in a long, and the sequence turns negative at `n` 91.
Shrinking found the first `n` that fails, because every `n` after it fails too. A rule about a range of inputs
like this one is also the cheapest way to document a limit.

## A call that must signal

**The rule.** Some inputs should be refused, and the refusal is what to test: a function given a bad price
must signal, and given a good one must not. The natural way to write it, `@[f;x;{x~"px must be positive"}]`,
returns `f`'s result when nothing was signalled, which is rarely a boolean. The safe shape returns a pair,
whether it signalled and what came back, and the property reads the pair.

```q
q)chkpx:{[p] if[not p>0; '"px must be positive"]; p}
q)call:{[f;x] @[{(1b;x y)}[f];x;{(0b;x)}]}
q).qc.check[.qc.flt -9 9; {r:call[chkpx;x]; $[x>0; r 0; not r 0]}];
ok 100 tests (seed 7)
q)chkpx:{[p] p}
q).qc.check[.qc.flt -9 9; {r:call[chkpx;x]; $[x>0; r 0; not r 0]}];
FAIL falsified after 0 tests, 0 shrinks (3 attempts, seed 7)
x: 0f
rerun: .qc.again[]  or  .qc.recheck[gen;prop;0 0 0]
```

**The report.** The check that forgets to refuse passes a price of 0, and the property says which. Two
things to know about protected evaluation: an error inside the handler fails the whole call, which is why
`.qc.eq` inside a handler still counts as a falsification; and a call that signals nothing returns `(1b;result)`
here, so the property can go on to check the result as well.

## Laws of the built-ins

**The rule.** Several built-ins have a habit that is easy to forget until it bites. Each habit is a one-line
rule, and a run of each says which are true. `xbar` gives the largest multiple of `n` at or below `x`, so its
result is within `n` below `x`:

```q
q).qc.check[(.qc.int 1 9; .qc.int -99 99); {[n;x] r:n xbar x; (r<=x) and (x<r+n) and 0=r mod n}];
ok 100 tests (seed 7)
q).qc.check[.qc.t"p"; {r:0D00:05 xbar x; (r<=x) and x<r+0D00:05}];
FAIL falsified after 6 tests, 1 shrinks (7 attempts, seed 7)
x: 0Np
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0]
```

The rule holds for longs, negatives included, and fails on a timestamp: the null. `0Np` bars to `0Np`, and
`0Np+n` is `0Np`, so the second comparison, `x<r+n`, is `0Np<0Np` and false. Bar code that may see a null
timestamp has to say what a null bars to.

`sv` and `vs` split and join text on a delimiter, and joining what was split gives the text back; splitting
what was joined does not, when a field holds the delimiter:

```q
q).qc.check[.qc.lst[1 3] .qc.strc["a,";0 3]; {.qc.eq[x; "," vs "," sv x]}];
FAIL falsified after 5 tests, 4 shrinks (21 attempts, seed 7)
x: ,,","
qc.eq
path why   a    b
------------------
()   count 1    2
,0   value ,"," ""
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 0 0]
q).qc.check[.qc.t"j"; {x~0x00 sv 0x00 vs x}];
ok 100 tests (seed 7)
```

One field that is a comma comes back as two empty fields. A long split into bytes and joined again is itself,
nulls and infinities included.

`rank` is `iasc iasc`, and finding each item in the sorted list is not the same thing when values repeat:

```q
q).qc.check[.qc.list .qc.int 0 9; {(x~(asc x) rank x) and (rank x)~iasc iasc x}];
ok 100 tests (seed 7)
q).qc.check[.qc.list .qc.int 0 9; {.qc.eq[rank x; (asc x)?x]}];
FAIL falsified after 2 tests, 0 shrinks (14 attempts, seed 7)
x: `s#0 0
qc.eq
path why   a b
--------------
1    value 1 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 1 0 0]
```

Two zeros have ranks 0 and 1, and find gives 0 for both. The counterexample prints with `` `s# ``: `asc` of a
list that is already sorted sets the sorted attribute on the list itself, so the report shows the list as it was
left.

`inter` is not the intersection of two sets: an item that repeats in the left list is kept as often as it
repeats there, so the result can be longer than the right list. `within` takes its bounds in order, and a pair
the wrong way round matches nothing:

```q
q).qc.check[(.qc.lst[1 6] .qc.int 0 3; .qc.lst[1 6] .qc.int 0 3); {[x;y] count[x inter y]<=count y}];
FAIL falsified after 11 tests, 10 shrinks (63 attempts, seed 7)
x: 0 0
y: ,0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 1 0 0 1 0 0]
q).qc.check[(.qc.lst[0 6] .qc.int 0 3; .qc.lst[0 6] .qc.int 0 3); {[x;y] ((x inter y)~x where x in y) and ((x union y)~distinct x,y) and (x except y)~x where not x in y}];
ok 100 tests (seed 7)
q).qc.check[3#enlist .qc.int -9 9; {[x;a;b] (x within (a;b))=x within (a&b;a|b)}];
FAIL falsified after 6 tests, 6 shrinks (20 attempts, seed 7)
x: 0
a: 0
b: -1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;0 0 -1]
```

`ungroup` undoes `xgroup`, but returns the rows gathered by the grouping column, each group where its key
first appeared, not in their first order; and the characters `like` treats as special (`*`, `?`, `[`, `]`)
can be escaped by bracketing them. `^` is special only as the first character of a class, where it means "not",
and bracketing it alone does not make a class of its own:

```q
q).qc.check[.qc.tabr[1 9] `k`v!(.qc.elem `b`a; .qc.int 0 9); {.qc.eq[x; ungroup `k xgroup x]}];
FAIL falsified after 3 tests, 2 shrinks (37 attempts, seed 7)
x:
  k v
  ---
  b 0
  a 0
  b 0
qc.eq
path why   a b
--------------
`k 1 value a b
`k 2 value b a
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 1 1 0 1 0 0 0]
q)esc:{raze {$[x in "*?[]^";"[",x,"]";enlist x]} each x}
q).qc.check[.qc.strc["ab*?[]^";1 5]; {x like esc x}];
FAIL falsified after 4 tests, 4 shrinks (46 attempts, seed 7)
x: "^*"
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 6 1 2 0]
```

A `b` row, an `a` row and a `b` row come back as `b b a`. And `"^*"` does not match its own escaping: the `]`
right after `[^` is a member of the class, not its close, so `[^][*]` is one class, any single character but
`]`, `[` or `*`, and the two characters of `"^*"` cannot match it. A `^` outside brackets matches itself, so the
escape is to bracket everything but `^`:

```q
q)esc:{raze {$[x in "*?[]";"[",x,"]";enlist x]} each x}
q).qc.check[.qc.strc["ab*?[]^";1 5]; {x like esc x}];
ok 100 tests (seed 7)
```

## A functional query against its template

**The rule.** A query built by a program is written in the functional form, `?[t;c;b;a]`, and the rule is that
it gives what the template form gives. The classic slip is a symbol in the constraint left as it is, where the
functional form reads a symbol as a column name: `` (=;`c1;`a) `` compares `c1` with a column called `a`.

```q
q)t:.qc.tabr[0 5] `c1`c2!(.qc.elem `a`b; .qc.int 0 9)
q).qc.check[t; {.qc.eq[?[x;enlist (=;`c1;enlist `a);0b;()]; select from x where c1=`a]}];
ok 100 tests (seed 7)
q).qc.check[t; {.qc.eq[?[x;enlist (=;`c1;`a);0b;()]; select from x where c1=`a]}];
FAIL falsified after 0 tests, 0 shrinks (1 attempts, seed 7)
x:
  c1 c2
  -----
a
rerun: .qc.again[]  or  .qc.recheck[gen;prop;0]
```

**The report.** The first is right and the second fails on the first example, the empty table, with the error
`a`: there is no column `a`. Enlisting the symbol, `` enlist `a ``, makes it a value. `parse` on the template
form gives the functional form q itself would use, and is the way to check one that is written by hand.

## A pivot that loses a value

**The rule.** A pivot turns rows `(k;p;v)` into a table with a column for each `p` and a row for each `k`. Whatever
it does with the shape, the values are all still there, so their sum is the sum of `v`:

```q
q)piv:{[t] P:asc distinct t`p; exec P#(p!v) by k:k from t}
q)piv ([]k:`x`x`y;p:`a`b`a;v:1 2 3)
k| a b
-| ---
x| 1 2
y| 3
q).qc.check[.qc.tabr[1 6] `k`p`v!(.qc.elem `x`y; .qc.elem `a`b; .qc.int 1 9); {r:piv x; .qc.eq[sum x`v; sum raze value flip value r]}];
FAIL falsified after 1 tests, 0 shrinks (19 attempts, seed 7)
x:
  k p v
  -----
  x a 1
  x a 1
qc.eq
path why   a b
--------------
     value 2 1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 1 1 0 0 1 0]
```

**The report.** Two rows with the same `k` and `p`: the dictionary `p!v` has the key twice, and `P#` looks the
keys up, which finds the first; the second is gone. A pivot has to say what it does when a cell gets two
values, and this one says nothing. The fix depends on the answer: sum them first, `exec P#(p!v) by k:k from
select sum v by k,p from t`, which passes the rule; or make `(k;p)` a key of the input with `.qc.ktab[`k`p;...]`
and the rule about the input, not the pivot.

## Update by group, and splitting the input

**The rule.** `update cv:sums qty by sym from t` is a running total per symbol. Two rules say it is right: for
each symbol, the column is the running total of that symbol's rows; and the result on the first `n` rows is
the first `n` rows of the result, since a running total looks only backwards. The second is how a batch
computation is shown to agree with an incremental one.

```q
q)t:.qc.tabr[0 6] `sym`qty!(.qc.elem `a`b; .qc.int 1 9)
q)own:{[x;r;s] (r[`cv] where r[`sym]=s)~sums x[`qty] where x[`sym]=s}
q).qc.check[t; {r:update cv:sums qty by sym from x; all own[x;r] each distinct x`sym}];
ok 100 tests (seed 7)
q).qc.check[(t;.qc.int 0 6); {[x;n] n:n&count x; r:update cv:sums qty by sym from x; .qc.eq[n#r; update cv:sums qty by sym from n#x]}];
ok 100 tests (seed 7)
```

Both hold. The mistake they catch is a `sums` without the `by`, which the first rule finds on two rows of
different symbols, or an aggregation that looks forward, which the second finds on any split.

## A view as the oracle

**The rule.** A cache of the last quote per symbol, kept up to date by hand as quotes arrive, is a piece of
derived state, and the same state written as a *view* is the oracle for it: `qlast::select last bid,last ask
by sym from quote` is always right, because q recomputes it from the quotes. The rule is that the cache equals
the view after every quote. The bug: the cache is only updated when the bid moves.

```q
q)quote:([]sym:`symbol$();bid:`float$();ask:`float$())
q)qlast::select last bid,last ask by sym from quote
q)qcache:([sym:`symbol$()] bid:`float$();ask:`float$())
q)onq:{[q] `quote insert q; if[not q[`bid]=qcache[q`sym;`bid]; `qcache upsert q];}
q)cmds:([cmd:enlist `quote] gen:enlist {[m] `sym`bid`ask!(.qc.elem `a`b; '[`float$; .qc.int 1 3]; '[`float$; .qc.int 1 3])}; run:enlist {[q] onq q}; post:enlist {[m;q;o] qlast~`sym xkey `sym xasc 0!qcache})
q).qc.check[.qc.sm[`m0`init!(::;{`quote set 0#quote; `qcache set 0#qcache})] cmds; ::];
FAIL falsified after 10 tests, 6 shrinks (39 attempts, seed 7)
qc.post
step cmd   arg                     res model ok
-----------------------------------------------
0    quote `sym`bid`ask!(`a;1f;1f) ::  ::    1
1    quote `sym`bid`ask!(`a;1f;2f) ::  ::    0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 1 1 1 0 0 1 2]
```

**The report.** Two quotes for `a` with the same bid and a different ask, and the cache keeps the old ask.
The comparison sorts the cache by symbol first: `by sym` returns its rows in key order, a cache upserted into
does not. `::` inside a function assigns a global and does not define a view, so `init` clears the tables the
view depends on rather than the view itself. The model here is `::`: the view carries the state, and the postcondition
does the comparing.

## Amend by name and by value

**The rule.** A position book is a dictionary from symbol to quantity, and a fill adds to it. Written with
amend by name, `` .[`book;enlist s;+;q] ``, the fill changes the global. Written with amend by value inside a
function, `book:.[book;enlist s;+;q]`, it changes a local called `book` that did not exist, and q says so.

```q
q)book:()!()
q)onfill:{[s;q] .[`book;enlist s;+;q]}
q).qc.check[.qc.lst[1 5] (.qc.elem `a`b; .qc.int -5 5); {book::(0#`)!0#0; onfill ./: x; m:exec sum q by s from ([]s:x[;0];q:x[;1]); .qc.eq[book key m; value m]}];
ok 100 tests (seed 7)
q)onfill2:{[s;q] book:.[book;enlist s;+;q]}
'book
```

The property compares the book with a sum by symbol, looking the symbols up rather than comparing the two
dictionaries whole: a book keeps its keys in the order fills arrived, the `by` returns them sorted. The
second definition does not get as far as a check: an assignment anywhere in a function makes the name local
to the whole function, so the `book` read on the right-hand side is a local with no value yet, and q refuses
the definition as it parses it, naming the variable.

## Dictionaries: join, fill and arithmetic

**The rule.** Three laws of dictionaries that code relies on without saying so: joining two, `,`, keeps the
right side's value where a key is in both; filling, `^`, is the same except that a null on the right does not
win; and arithmetic works over the union of the keys.

```q
q)d:.qc.tabr[1 3] `k`v!(.qc.uniq .qc.elem `a`b`c; .qc.t"j")
q)mk:{x[`k]!x`v}
q).qc.check[(d;d); {[x;y] a:mk x; b:mk y; ((a,b) key b)~value b}];
ok 100 tests (seed 7)
q).qc.check[(d;d); {[x;y] a:mk x; b:mk y; .qc.eq[a^b; a,b]}];
FAIL falsified after 47 tests, 6 shrinks (72 attempts, seed 7)
x:
  k v
  ---
  a 0
y:
  k v
  ---
  a
qc.eq
path why   a b
--------------
a    value 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 0 0 0 1 0 1 0 0 0]
q).qc.check[(d;d); {[x;y] a:mk x; b:mk y; .qc.eq[key a+b; distinct key[a],key b]}];
ok 100 tests (seed 7)
```

**The report.** The first and third hold. The second fails on a right-hand null: `a,b` takes it, `a^b` keeps
the left value, which is what `^` is for. The generator is a table with a distinct key column, turned into a
dictionary with `!`, because a dictionary made from a list with a repeated key keeps both entries and a lookup
sees only the first; over such dictionaries the first and third laws fail too, and the counterexample is the
repeated key.

## Patterns without a default

**The rule.** q 4.1 added patterns, and a conditional pattern with no default signals `match` when nothing
matches. A common example counts the bytes of a UTF-8 character from its first byte, and looks exhaustive:

```q
q)sz:{[uch] :[`long$5#0b vs first uch;(1;1;1;1;0);4;(1;1;1;0;);3;(1;1;0;;);2;(0;;;;);1]}
q)sz "a"
1
q).qc.check[.qc.int 0 255; {sz enlist "c"$x; 1b}];
FAIL falsified after 48 tests, 7 shrinks (16 attempts, seed 7)
x: 128
match
rerun: .qc.again[]  or  .qc.recheck[gen;prop;128]
```

**The report.** They are exhaustive over the first byte of a well-formed character. Byte 128 is not one: it is
a continuation byte, `10xxxxxx`, and matches no pattern, so `sz` signals `match`. Whether that is the right
answer depends on who calls `sz`; a pattern that is meant to be total needs a default, and a rule over all 256
bytes says whether it has one.

## Compressed files and an append log

**The rule.** Two ways of writing to disk beside plain `set`: a compressed write, `(f;17;2;6) set x`, and an
append, `` .[f;();,;x] ``, which adds to a file without reading it. Both are round trips: what is read back is
what was written.

```q
q)root:hsym `$first system "mktemp -d"
q).qc.check[.qc.val; {f:` sv root,`a; (f;17;2;6) set x; x~get f}];
FAIL falsified after 97 tests, 0 shrinks (25 attempts, seed 7)
x: `d
d
rerun: .qc.again[]  or  .qc.recheck[gen;prop;0 9 1 3 0]
q).qc.check[.qc.list .qc.int 0 9; {f:` sv root,`log; f set (); {[f;x] .[f;();,;enlist x]}[f] each x; .qc.eq[get f; x]}];
ok 100 tests (seed 7)
q)system"rm -rf ",1_string root

```

**The report.** The log holds. The compressed write fails on a symbol atom, with the symbol as the error: with
the compression parameters given, `set` reads a symbol on its right as the *name of a variable* whose value
to save, and there is no variable called `d`. Plain `set` writes the symbol. An arbitrary value, `.qc.val`, is
what finds a case like this; a test written with a table in mind would not have.

## Asynchronous messages and the close of a handle

*As a script: `examples/pubsub.q`, which starts a second q process; the transcript below is one run of it.*

**The rule.** A publisher sends rows to a subscriber in another process as asynchronous messages, `neg[h]`,
and now and then drops its connection and opens it again. The rule is that the subscriber holds what was sent:
a stateful test with `send`, `reconnect` and `get` as the commands, the model the table the subscriber ought to
hold, and `get` reading it back synchronously. The bug is in `reconnect`: it closes the handle with nothing
flushed, and q may drop asynchronous messages still in the handle's buffer when it is closed.

```
$ q examples/pubsub.q
asynchronous sends, a reconnect that flushes nothing (false):
FAIL falsified after 3 tests, 2 shrinks (32 attempts, seed 201462819)
qc.post
step cmd       arg           res                          ok
------------------------------------------------------------
0    send      `id`px!(0;1f) ::                           1
1    reconnect ::            ::                           1
2    get       ::            +`id`px!(`long$();`float$()) 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 0 0 1 1 1 1 2]

with a synchronous chaser before the close:
ok 100 tests (seed 219394819)
```

**The report.** One row sent, a reconnect, and the subscriber has nothing. **The fix** is the usual one: a
synchronous message on the handle before it is closed, `h""`, which returns only once every message sent
before it has been handled. The script's second run has it. A synchronous read on the *same* handle is
ordered after the asynchronous sends before it, which is why `get` needs no chaser of its own, and why the
test could not have found this bug without the reconnect.
