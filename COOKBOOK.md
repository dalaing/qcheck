# qcheck cookbook

Recipes for things a kdb+ programmer tests: a join, an upsert, a table written to disk, a tickerplant's `upd`,
serialisation, bars. Each recipe has a bug planted in it, so that you see the report you would get, and then
the fix, so that you see the passing run too.

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
| [A tickerplant handler as a state machine](#a-tickerplant-handler-as-a-state-machine) | a model and an invariant | `sm`; a table as a command's input |
| [Serialisation, over any value](#serialisation-over-any-value) | a round trip | `val`; narrowing a generator to what a rule covers |
| [Per-minute bars](#per-minute-bars) | an oracle | `ts`, `mono` over timestamps |

## An as-of join against a naive one

*As a script: `examples/aj.q`.*

**The rule.** You have written a join, and there is an obvious, slow way to compute the same answer: for each
trade, look through the quotes. The slow way is the *oracle*, and the rule is that the two agree on every input.
Here the roles are the other way round, so that the recipe runs as it stands: q's `aj` is taken as right, and
the hand-written join has the bug. It takes the *first* quote at or before the trade, where an as-of join takes
the last.

**The generators.** Two tables are needed, and they must share their symbols, or no trade would ever find a
quote and the rule would pass without testing anything. So a list of symbols is drawn first and both tables draw
their `sym` from it.

```q
q)syms:.qc.lst[1 3] .qc.symc["abc";1 1]
q)tbl:{[s;nm;g] .qc.tabr[1 0W] (`sym`time,nm)!(.qc.elem s; .qc.mono[.qc.int 0 9;.qc.int 0 9]; g)}
q)pair:{[d] s:.qc.draw syms; `q`t!(.qc.draw tbl[s;`px;.qc.int 0 9]; .qc.draw tbl[s;`qty;.qc.int 0 9])}
q)naive:{[t;q] f:{[q;s;tm] $[count r:exec px from q where sym=s,time<=tm; first r; 0N]}[q]; update px:"j"$f'[sym;time] from t}
q).qc.check[pair; {.qc.eq[aj[`sym`time;x`t;x`q]; naive[x`t;x`q]]}];
FAIL falsified after 1 tests, 9 shrinks (74 attempts, seed 7)
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
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 1 0 0 0 1 0 0 0 0 1 0 0 0 1 0 0 1 0]
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
of rows, and the key values within one table are distinct. The keys here come from 0 to 3, so that two tables
drawn separately are likely to collide, which is the case the rule is about. A generator with keys from 0 to a
million would pass this rule for a long time.

```q
q)kt:.qc.ktab[`k;0 5] `k`v!(.qc.int 0 3; .qc.int 0 9)
q).qc.draw kt
k| v
-| -
0| 0
3| 2
2| 1
q)bad:{[t;u] keys[t] xkey (0!t),0!u}
q).qc.check[(kt;kt); {[t;u] .qc.eq[t upsert u; bad[t;u]]}];
FAIL falsified after 4 tests, 5 shrinks (38 attempts, seed 7)
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
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 0 0 0 1 0 0 0]
```

**The property** takes two tables, so the generator is a list of two, and the report names the inputs after the
property's parameters.

**The report.** One row in each table, with the same key. The diff has no path, because the difference is in the
tables as wholes: a `count` of 1 on one side and 2 on the other. The values did not matter, so they shrank to 0.

**The fix** is to join keyed tables as keyed tables: `,` on two keyed tables is an upsert.

```q
q)kt:.qc.ktab[`k;0 5] `k`v!(.qc.int 0 3; .qc.int 0 9)
q).qc.check[(kt;kt); {[t;u] .qc.eq[t upsert u; t,u]}];
ok 100 tests (seed 7)
```

## A splayed table reads back changed

**The rule.** A *round trip*: write a value, read it back, and you should have what you started with. It is the
rule to reach for whenever two functions are meant to undo each other.

**The generator.** `.qc.schema` reads a generator off a sample table: the same columns, of the same types. It
saves writing out a generator for a table you already have.

```q
q)dir:`$":",getenv[`TMPDIR],"/qc_hdb"
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
rerun: .qc.again[]  or  .qc.recheck[spec;prop;0]
q).qc.check[trade; {.qc.eq[x; update value sym from saveload x]}];
ok 100 tests (seed 7)
```

**The report.** The rule fails on the first example, and the counterexample is a table with no rows: the
difference is one of type, so no row is needed to show it. The `sym` column went in as symbols (type 11) and came
back as an enumeration (type 20), which is what `.Q.en` is for. The two tables look the same at the console and
are not the same to `~`, nor to a caller that joins the answer to a table of its own.

**The fix** is in the rule and not in the code. What is promised is that the *values* come back, so the property
compares against `value sym`, and the second check passes. A failing property does not always mean the code is
wrong; sometimes it means the rule said more than you meant, and finding that out is worth as much.

## A tickerplant handler as a state machine

**The rule.** `upd` has no answer to check. It changes a table, and what matters is the table after many calls.
That calls for a state machine (`README.md` explains them). The *model* is the simplest thing that can say what
the table should hold: here, a count of the rows that have been fed. The rule is an *invariant*, checked after
every call: the table has as many rows as the model has counted.

This `upd` upserts by symbol, so a batch in which a symbol appears twice loses a row.

```q
q)TBL:([]sym:`symbol$(); px:`float$())
q)upd:{[t;x] TBL::0!(`sym xkey TBL) upsert x}
q)cmds:([cmd:enlist `upd] gen:enlist {[m] .qc.tabr[1 5] `sym`px!(.qc.symc["ab";1 1]; .qc.flt 0 9)}; run:enlist {[x] upd[`trade;x]}; upd:enlist {[m;a;o] m+count a})
q).qc.check[.qc.sm[`m0`init`inv!(0; {TBL::0#TBL}; {[m] m=count TBL})] cmds; ::];
FAIL falsified after 4 tests, 5 shrinks (52 attempts, seed 7)
qc.inv
step cmd arg                  res model ok
------------------------------------------
0    upd +`sym`px!(`b`b;0 0f) ::  2     1
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 0 1 1 1 0 0 0 0 1 1 1 0 0 0 0 0]
```

**The commands.** There is one, so every column is a list of one item, made with `enlist`.

- `gen` is the generator of the command's input, a batch of one to five rows. The symbols are one letter from
  `"ab"`, so that repeats are common.
- `run` makes the call on the real system.
- `upd` moves the model on: the count goes up by the size of the batch. (This `upd` is the column of the command
  table; the `upd` in `run` is the handler.)
- There is no `pre` column, since the command can always run, and no `post`, since there is no answer to check.

**The hooks**, the dict given to `.qc.sm`: `m0` is the model at the start; `init` empties the table before
every sequence; `inv` is the invariant, a function of the model that may look at the real system.

**The report.** `qc.inv` says the invariant was false, and the trace is one step long: one batch of two rows for
the same symbol. The `arg` column shows the batch as q prints a table on one line, a flipped dict of columns.
The `model` column says 2, and the table had one row.

**The fix** is to append, and the invariant then holds over every sequence of batches drawn.

```q
q)TBL:([]sym:`symbol$(); px:`float$())
q)upd:{[t;x] TBL,:x}
q)cmds:([cmd:enlist `upd] gen:enlist {[m] .qc.tabr[1 5] `sym`px!(.qc.symc["ab";1 1]; .qc.flt 0 9)}; run:enlist {[x] upd[`trade;x]}; upd:enlist {[m;a;o] m+count a})
q).qc.check[.qc.sm[`m0`init`inv!(0; {TBL::0#TBL}; {[m] m=count TBL})] cmds; ::];
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
FAIL falsified after 1 tests, 7 shrinks (26 attempts, seed 7)
x: 0x00
rerun: .qc.again[]  or  .qc.recheck[spec;prop;0 2 0]
q).j.k .j.j 0x00
"00"
```

q's own serialisation is the identity on all of them. JSON is not, and the simplest value that it changes is a
byte, which goes out as a string of two characters and stays one.

**Narrowing the rule.** JSON cannot be fixed, and the rule as stated is false. What can be said is *which* values
survive, and the way to find out is to try a narrower generator and read the counterexample. Lists of floats:

```q
q).qc.check[.qc.list .qc.flt 0 1; {x~.j.k .j.j x}];
FAIL falsified after 4 tests, 53 shrinks (78 attempts, seed 7)
x: ,0.0004882812
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 0 11 1 0]
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
rerun: .qc.again[]  or  .qc.recheck[spec;prop;0]
```

With seventeen digits the floats survive. The table does not, when it is empty: it goes out as `[]`, which
comes back as an empty list and not as a table. With at least one row the rule holds:

```q
q)system"P 17"
q).qc.check[.qc.tabr[1 20] `px`ok`s!(.qc.flt 0 1; .qc.bool; .qc.str); {x~.j.k .j.j x}];
ok 100 tests (seed 7)
```

The rule that stands is a statement of what JSON carries for you: tables of floats, booleans and strings, with
at least a row, at full precision. Each of the three conditions came from a counterexample.

## Per-minute bars

**The rule.** An oracle once more. Bars are computed by one `select`, and the high of each bar can be checked
against a second, simpler query that computes only the high. The bug: the high is taken with `first`.

**The generator.** A table of trades in one session. `.qc.ts[from;to]` draws a timestamp in a window, and `mono`
over it gives times that start somewhere in the session and move forward by up to a minute for each row, so
that some minutes hold several trades and some trades cross into the next minute.

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
q).qc.check[trades; {b:0!bars x; mx:0!select mx:max px by 0D00:01 xbar time from x; all b[`h]>=mx`mx}];
FAIL falsified after 3 tests, 11 shrinks (57 attempts, seed 7)
x:
  time                          px
  --------------------------------
  2024.01.02D09:30:00.000000000 1
  2024.01.02D09:30:00.000000000 2
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 757503000000000000 0 43 8796093022208 1 0 0 0 2 0]
```

**The report.** Two trades in one minute, the second at a higher price. One trade could not show the bug, since
the first price of a bar of one trade is its highest, and two trades at falling prices could not either. The
time shrank to the start of the session and the prices to 1 and 2, the simplest floats in the range that differ
in the right direction.

**The fix** is `max` for `first`.

```q
q)day:2024.01.02D09:30; close:2024.01.02D16:00
q)trades:.qc.tabr[1 50] `time`px!(.qc.mono[.qc.ts[day;close]; .qc.int (0;"j"$0D00:01)]; .qc.flt 1 100)
q)bars:{select o:first px, h:max px, l:min px, c:last px by 0D00:01 xbar time from x}
q).qc.check[trades; {b:0!bars x; mx:0!select mx:max px by 0D00:01 xbar time from x; all b[`h]>=mx`mx}];
ok 100 tests (seed 7)
```

A rule that needs no oracle at all would have caught the same bug: in every bar the high is at least the open
and the close, and the low at most. Rules of that kind, true of every right answer, are cheap to write and worth
keeping beside the oracle:

```q
q)day:2024.01.02D09:30; close:2024.01.02D16:00
q)trades:.qc.tabr[1 50] `time`px!(.qc.mono[.qc.ts[day;close]; .qc.int (0;"j"$0D00:01)]; .qc.flt 1 100)
q)bars:{select o:first px, h:first px, l:min px, c:last px by 0D00:01 xbar time from x}
q).qc.check[trades; {b:0!bars x; all (b[`h]>=b`o) and (b[`h]>=b`c) and (b[`l]<=b`o) and b[`l]<=b`c}];
FAIL falsified after 3 tests, 13 shrinks (57 attempts, seed 7)
x:
  time                          px
  --------------------------------
  2024.01.02D09:30:00.000000000 1
  2024.01.02D09:30:00.000000000 2
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 757503000000000000 0 24 16777216 1 0 0 0 2 0]
```
