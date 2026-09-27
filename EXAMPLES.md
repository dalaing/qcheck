# qcheck by example

Every transcript below is executed by `t/doctest.q` in a fresh q with `qc.q` loaded; the output shown is what
the REPL prints. Each session starts with `.qc.cfg[`seed]:7i`, so the numbers are reproducible.

## Drawing values

A generator is a function called with `[]`; `.qc.draw` interprets any spec, `.qc.minimal` gives its simplest
value, and after a draw `.qc.C` holds the choices it made.

```q
q).qc.draw .qc.int 0 9
1
q).qc.minimal .qc.int -5 5
0
q).qc.minimal .qc.lst[2 2] .qc.int 0 9
0 0
q).qc.C
v lo hi o
---------
1 1  1  1
0 0  9  0
1 1  1  1
0 0  9  0
0 0  0  0
```

## Records, tuples, and the type zoo

```q
q).qc.draw `name`age!(.qc.sym; .qc.int 0 120)
name| `abb
age | 6
q).qc.draw (.qc.int 0 9; .qc.bool)
9
1b
q).qc.minimal each .qc.t "dpu"
2000.01.01
2000.01.01D00:00:00.000000000
00:00
q).qc.minimal each (.qc.flt 0 1; .qc.str; .qc.sym; .qc.vec[0 3]"j")
0f
""
`
`long$()
```

## Any value at all

`val` draws an arbitrary q value — every atom type with its nulls and infinities, typed and general lists, dicts,
tables — for properties about the things every q program does to values. Serialisation round-trips; JSON does not,
and the smallest counterexample is a byte.

```q
q).qc.check[.qc.val; {x~-9!-8!x}];
ok 100 tests (seed 7)
q).qc.check[.qc.val; {x~.j.k .j.j x}];
FAIL falsified after 1 tests, 7 shrinks (26 attempts, seed 7)
x: 0x00
rerun: .qc.again[]  or  .qc.recheck[spec;prop;0 2 0]
```

## Tables

A column can be constrained: `mono[b;g]` adds a drawn delta to the previous row, `uniq g` never repeats a value, and
`dep f` sees the row so far. `schema t` makes tables shaped like a sample, and a planted bug on a keyed table
shrinks to the fewest rows that show it.

```q
q).qc.draw .qc.tabr[4 4] `t`k`v!(.qc.mono[.qc.int 0 9;.qc.int 1 9]; .qc.uniq .qc.elem `a`b`c`d; .qc.dep {[r] .qc.int (r`t;20)})
t k v 
------
1 b 3 
4 a 10
6 d 14
8 c 8 
q)dom:`a`b`c
q)trade:([]time:`s#09:30:00 09:30:05 09:31:00; sym:`dom$`a`b`a; px:1.5 2.5 3.5)
q)meta .qc.draw .qc.schema trade
c   | t f a
----| -----
time| v   s
sym | s    
px  | f    
q).qc.check[.qc.tab `k`v!(.qc.uniq .qc.int 0 3; .qc.int 0 9); {20>sum x`v}];
FAIL falsified after 42 tests, 10 shrinks (124 attempts, seed 7)
x:
  k v
  ---
  0 2
  1 9
  2 9
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 0 2 1 0 9 1 0 9 0]
```

## Large data

`bulk` records a whole vector as one block, so a million values cost one draw call and a few milliseconds, and a
block shrinks by deleting chunks as well as by its values. `btab` is a table of blocks.

```q
q)count .qc.draw .qc.bulk[0 99;1000000 1000000]
1000000
q).qc.nch
2
q).qc.check[.qc.bulk[0 99;0 100000]; {x~asc x}];
FAIL falsified after 1 tests, 10 shrinks (26 attempts, seed 7)
x: 1 0
rerun: .qc.again[]  or  .qc.recheck[spec;prop;2 1 0]
q).qc.check[.qc.btab[0 100000] `k`v!(0 9;("d";0 9)); {all x[`v]<2000.01.09}];
FAIL falsified after 1 tests, 9 shrinks (18 attempts, seed 7)
x:
  k v         
  ------------
  0 2000.01.09
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 0 8]
```

## A first property, and what a failure looks like

```q
q).qc.check[.qc.list .qc.int 0 100; {x~asc x}];
FAIL falsified after 5 tests, 8 shrinks (36 attempts, seed 7)
x: 1 0
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 1 1 0 0]
```

`.qc.eq` explains a mismatch as a diff table:

```q
q).qc.check[.qc.list .qc.int 0 100; {.qc.eq[x;asc x]}];
FAIL falsified after 5 tests, 8 shrinks (36 attempts, seed 7)
x: 1 0
qc.eq
path why   a b
--------------
0    value 1 0
1    value 0 1
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 1 1 0 0]
```

A dict spec is applied by parameter name, and the report is keyed the same way:

```q
q).qc.check[`xs`n!(.qc.list .qc.int 0 9; .qc.int 0 5); {[n;xs] n<=count xs}];
FAIL falsified after 1 tests, 0 shrinks (3 attempts, seed 7)
xs: ()
n: 1
rerun: .qc.again[]  or  .qc.recheck[spec;prop;0 1]
```

## Shrinking a tree

```q
q)tree:.qc.rec[2 2; .qc.int 0 9; {(x 0;x 1)}]
q)depth:{$[0h=type x; 1+max .z.s each x; 0<type x; 1; 0]}
q).qc.check[tree; {depth[x]<3}];
FAIL falsified after 4 tests, 2 shrinks (30 attempts, seed 7)
x: (0;(0;0 0))
rerun: .qc.again[]  or  .qc.recheck[spec;prop;3 0 0 0 2 0 0 0 1 0 0 0 0 0]
```

## Rerunning the last failure

```q
q).qc.lf`choices
`long$()
q).qc.again[];
ok 1 tests (seed -314159)
```

## Drawing inside the property

```q
q).qc.check[::; {n:.qc.draw .qc.int 1 9; .qc.note n; n<7}];
FAIL falsified after 6 tests, 0 shrinks (4 attempts, seed 7)
7
rerun: .qc.again[]  or  .qc.recheck[spec;prop;7]
```

## Small spaces are enumerated, not sampled

The run walks a tree of the choices it has made, simplest first, and stops when every branch has been tried.
That covers structure that depends on earlier choices — alternatives, short lists, small state machines — so
`exhausted` is a proof over every input the spec can produce, not a sample.

```q
q).qc.check[.qc.bool; {1b}];
ok 2 tests, exhausted (seed 7)
q).qc.check[(.qc.int 0 3; .qc.bool); {[a;b] a<3}];
FAIL falsified after 6 tests, 0 shrinks (4 attempts, seed 7)
a: 3
b: 0b
rerun: .qc.again[]  or  .qc.recheck[spec;prop;3 0]
q).qc.check[.qc.one (.qc.bool; .qc.int 0 9); {1b}];
ok 12 tests, exhausted (seed 7)
q).qc.check[.qc.lst[0 3] .qc.bool; {x~asc x}];
FAIL falsified after 6 tests, 1 shrinks (20 attempts, seed 7)
x: 10b
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 1 1 0 0]
```

## Coverage

```q
q).qc.check[.qc.elem til 1000; {.qc.cover[`big;90;x<950]; 1b}];
ok 192 tests, coverage settled (seed 7)
label n   pct      req lo       hi       ok bar
--------------------------------------------------------------
big   181 94.27083 90  90.03367 96.77118 1  ##################
q).qc.check[.qc.elem til 1000; {.qc.cover[`big;90;x<800]; 1b}];
FAIL coverage not met after 100 tests
label n  pct req lo       hi       ok bar
-----------------------------------------------------
big   77 77  90  67.84544 84.15685 0  ###############
```

## A suite

```q
q).qc.checks `comm`sorted!(((.qc.int 0 9;.qc.int 0 9);{(x+y)=y+x}); (.qc.list .qc.int 0 9;{x~asc x}));
--- comm
ok 100 tests, exhausted (seed 7)
--- sorted
FAIL falsified after 5 tests, 1 shrinks (17 attempts, seed 7)
x: 1 0
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 1 1 0 0]
name   ok why       stop      n   shrinks seed
----------------------------------------------
comm   1  ok        exhausted 100 0       7
sorted 0  falsified fail      5   1       7
```

## A state machine against a table

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

## Configuration

```q
q).qc.chk[`n`seed!(20;3i); .qc.int 0 9; {x<10}];
ok 10 tests, exhausted (seed 3)
q)key .qc.cfg
`n`nmax`seed`sz`shrinks`disc`tries`depth`choices`same`clamp`db`name`rows`v
```
