# qcheck cookbook

Recipes for the things a kdb+ practitioner tests, each with a planted bug so the report is the point, and then
the fix, so the passing run is shown too. Every transcript is executed by `t/doctest.q` in a fresh q with `qc.q`
loaded and `.qc.cfg[`seed]:7i`, and must print exactly what is shown. Where a recipe needs `.qc.eq` the report carries a diff table; where it is a state
machine, the trace.

For the other kind of example — a system built in pieces, with the bugs that actually surfaced as it was written,
and a state machine that found one no piece could — see `examples/mdp/LOG.md`.

## An as-of join against a naive one

Quotes and trades over one drawn symbol list, times sorted by construction (`mono`), at least one row each. The
naive join takes the *first* quote at or before the trade instead of the last. The minimum is one symbol, two
quotes at one time with two prices, one trade — and the diff says which price was wrong.

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

The fix is `last` for `first`. The same generators, and the property now holds over a hundred pairs of tables.

```q
q)syms:.qc.lst[1 3] .qc.symc["abc";1 1]
q)tbl:{[s;nm;g] .qc.tabr[1 0W] (`sym`time,nm)!(.qc.elem s; .qc.mono[.qc.int 0 9;.qc.int 0 9]; g)}
q)pair:{[d] s:.qc.draw syms; `q`t!(.qc.draw tbl[s;`px;.qc.int 0 9]; .qc.draw tbl[s;`qty;.qc.int 0 9])}
q)fixed:{[t;q] f:{[q;s;tm] $[count r:exec px from q where sym=s,time<=tm; last r; 0N]}[q]; update px:"j"$f'[sym;time] from t}
q).qc.check[pair; {.qc.eq[aj[`sym`time;x`t;x`q]; fixed[x`t;x`q]]}];
ok 100 tests (seed 7)
```

## Upsert on keyed tables

`ktab` keys are distinct within a table, so the only way two tables collide is across them. A hand-rolled upsert
that appends the unkeyed rows and re-keys keeps both copies of a repeated key; the minimum is one row each with
the same key, and the diff is a count.

```q
q)kt:.qc.ktab[`k;0 5] `k`v!(.qc.int 0 3; .qc.int 0 9)
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

The fix is to join keyed tables as keyed tables: `,` on two keyed tables *is* upsert, and re-keying appended rows
never was.

```q
q)kt:.qc.ktab[`k;0 5] `k`v!(.qc.int 0 3; .qc.int 0 9)
q).qc.check[(kt;kt); {[t;u] .qc.eq[t upsert u; t,u]}];
ok 100 tests (seed 7)
```

## A splayed table reads back changed

`schema` makes tables shaped like the one you splay. Saving with `.Q.en` and reading back is not the identity: the
symbol column comes back enumerated (`20h`), and the smallest table that shows it is the empty one. The fix is in
the property, not the code: compare against the values (`value sym`), and it holds.

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

## A tickerplant handler as a state machine

The system is a table fed by `upd`; the model counts the rows fed; the invariant says they agree. This `upd`
upserts by symbol, so a batch with a repeated symbol loses a row. `init` resets the table before every example
and replay, and the trace shows the one batch that breaks the invariant.

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

The fix is to append: `TBL,:x`. The invariant then holds over every batch sequence the machine draws.

```q
q)TBL:([]sym:`symbol$(); px:`float$())
q)upd:{[t;x] TBL,:x}
q)cmds:([cmd:enlist `upd] gen:enlist {[m] .qc.tabr[1 5] `sym`px!(.qc.symc["ab";1 1]; .qc.flt 0 9)}; run:enlist {[x] upd[`trade;x]}; upd:enlist {[m;a;o] m+count a})
q).qc.check[.qc.sm[`m0`init`inv!(0; {TBL::0#TBL}; {[m] m=count TBL})] cmds; ::];
ok 100 tests (seed 7)
```

## Serialisation, over any value

`val` draws any q value. `-9!-8!` is the identity on all of them; JSON is not, and the smallest witness is a byte.

```q
q).qc.check[.qc.val; {x~-9!-8!x}];
ok 100 tests (seed 7)
q).qc.check[.qc.val; {x~.j.k .j.j x}];
FAIL falsified after 1 tests, 7 shrinks (26 attempts, seed 7)
x: 0x00
rerun: .qc.again[]  or  .qc.recheck[spec;prop;0 2 0]
```

JSON cannot be fixed, but the property can be scoped to what JSON carries: floats, booleans, strings, in tables
with rows. Two more things bite on the way — floats print at the console precision (`\P`, 7 digits by default),
so `0.0004882812` does not come back as `2 xexp -11` until `\P 17`; and an empty table serialises as `[]`, which
reads back as `()`, so the tables need a row. With both, the property holds.

```q
q)system"P 17"
q).qc.check[.qc.list .qc.flt 0 1; {x~.j.k .j.j x}];
ok 100 tests (seed 7)
q).qc.check[.qc.tabr[1 20] `px`ok`s!(.qc.flt 0 1; .qc.bool; .qc.str); {x~.j.k .j.j x}];
ok 100 tests (seed 7)
```

## Per-minute bars

Trades in a session, times monotone (`mono` over `ts` with deltas up to a minute), prices in a range. The bar's
high is computed with `first` instead of `max`; two trades in one minute with rising prices are the minimum.

```q
q)day:2024.01.02D09:30; close:2024.01.02D16:00
q)trades:.qc.tabr[1 50] `time`px!(.qc.mono[.qc.ts[day;close]; .qc.int (0;"j"$0D00:01)]; .qc.flt 1 100)
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

The fix is `max` for `first`.

```q
q)day:2024.01.02D09:30; close:2024.01.02D16:00
q)trades:.qc.tabr[1 50] `time`px!(.qc.mono[.qc.ts[day;close]; .qc.int (0;"j"$0D00:01)]; .qc.flt 1 100)
q)bars:{select o:first px, h:max px, l:min px, c:last px by 0D00:01 xbar time from x}
q).qc.check[trades; {b:0!bars x; mx:0!select mx:max px by 0D00:01 xbar time from x; all b[`h]>=mx`mx}];
ok 100 tests (seed 7)
```
