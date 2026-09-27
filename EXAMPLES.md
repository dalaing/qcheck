# qcheck by example

A tour of the library, from drawing one value to testing a system in another process. It assumes you know q and
have read the first two sections of `README.md`; it does not assume you have used a property-based testing
library before.

Every block that shows a `q)` prompt is a session of its own, and what follows each line is what q prints. To
follow along, start q in the repository root and type:

```
q)\l qc.q
q).qc.cfg[`db`seed]:(`;7i)
```

The second line is what makes your numbers match the ones here: it pins the seed, and it turns off the failure
database, which is explained [below](#the-failure-database). The test suite runs every block the same way and
requires the output shown. A report from `check` will match wherever you run it. What `.qc.draw` prints depends
on what the session has drawn before, so it matches in a fresh session.

Five of the sections are also scripts under `examples/`, with the commentary as comments. Each runs from the
repository root, for example `q examples/reverse.q`. They take their seed from the clock, so the first line of a
report (how many tests passed, how many shrinks) differs from run to run and from what is printed here.

| script | section |
|---|---|
| `examples/reverse.q` | [A first property](#a-first-property) |
| `examples/tree.q` | [Trees](#trees) |
| `examples/aj.q` | [A generator of your own](#a-generator-of-your-own) |
| `examples/sm_table.q` | [A state machine against a table](#a-state-machine-against-a-table) |
| `examples/sm_ipc.q` | [A system in another process](#a-system-in-another-process) |

## Drawing values

A generator describes a set of values and can draw one of them. `.qc.int 0 9` is a generator of longs from 0 to
9; `.qc.list g` is a generator of lists whose items come from the generator `g`. `.qc.draw` draws one value, and
`.qc.minimal` gives the simplest value a generator has, which is where every shrink is heading.

```q
q).qc.draw .qc.int 0 9
1
q).qc.draw .qc.lst[0 5] .qc.int 0 9
2 9 1
q).qc.minimal .qc.int -5 5
0
q)count .qc.minimal .qc.list .qc.int 0 9
0
q).qc.minimal .qc.lst[2 2] .qc.int 0 9
0 0
```

The simplest long is the one nearest 0, and the simplest list is the empty one. `.qc.lst` is `.qc.list` with a
range for the length: up to five items in the second line, exactly two in the last. Many names come in such a
pair, the short one taking a range or a setting first: `list` and `lst`, `tab` and `tabr`, `sym` and `symc`,
`check` and `chk`.

Every random decision a generator makes is recorded as a *choice*, a long with the range it was drawn from, and
`.qc.C` holds the choices of the last draw.

```q
q).qc.draw .qc.lst[0 5] .qc.int 0 9
9 2 9 1
q).qc.C
v lo hi o
---------
1 0  1  0
9 0  9  0
1 0  1  0
2 0  9  0
1 0  1  0
9 0  9  0
1 0  1  0
1 0  9  0
0 0  1  0
q).qc.replay[1 3 1 7 0] .qc.lst[0 5] .qc.int 0 9
3 7
```

The columns are the value chosen, the bounds it was chosen within, and the *origin*, the value that counts as
simplest. The list of four items took nine choices: "another item?" yes (1), the item (9), and so on for each
item, then "another item?" no (0). `.qc.replay` runs a generator on choices you give it, and five choices of the
same pattern draw a list of two items.

You will rarely need to look at choices, but they explain two things that follow. Shrinking works on them, by
deleting choices and moving them towards their origins, which is why anything you can generate can be shrunk
without your writing a shrinker for it. And the `rerun:` line of a report is a list of choices, which is why a
failure can be reproduced exactly.

## Records, tuples and types

A list of generators is a generator of tuples, and a dict of generators is a generator of records. There is a
generator for an atom of every q type.

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

`.qc.t` takes type characters as `$` does, and draws from the whole domain of the type, nulls and infinities
included; `.qc.tf` leaves those out. An empty list from `.qc.vec` or `.qc.str` has its type, as the last line
shows.

## A first property

*As a script: `examples/reverse.q`.*

A property is a function of one drawn value that returns `1b` when the rule it states holds. Reversing a list
twice gives the list back:

```q
q)ints:.qc.list .qc.int -99 99
q).qc.check[ints; {x~reverse reverse x}];
ok 100 tests (seed 7)
```

A hundred lists were drawn and the rule held for each. (The `;` at the end of the line is only there to keep the
REPL from printing what `check` returns, which is the [result](#the-result-is-data).)

A rule that is false, that a list is its own reverse:

```q
q)ints:.qc.list .qc.int -99 99
q).qc.check[ints; {x~reverse x}];
FAIL falsified after 5 tests, 1 shrinks (18 attempts, seed 7)
x: 0 1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 1 1 0]
```

Five lists passed (the empty list and lists of one item are their own reverse, and so are some others). The sixth
did not, and it was shrunk: 18 simpler lists were tried, and one of them also failed. `0 1` is what is left. No
list of fewer than two items can fail, and no two different longs are nearer to 0 than these.

In the `rerun:` line, `gen` and `prop` stand for the generator and the property that were given to `check`, and
the numbers are the choices that draw `0 1`.

### Seeing the difference

`~` answers yes or no. `.qc.eq[a;b]` is `~` that explains itself: when the two sides differ, the report carries
a table of the differences.

```q
q).qc.check[.qc.list .qc.int 0 100; {.qc.eq[x;asc x]}];
FAIL falsified after 5 tests, 8 shrinks (36 attempts, seed 7)
x: 1 0
qc.eq
path why   a b
--------------
0    value 1 0
1    value 0 1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 0 0]
```

One row for each difference: `path` is where it lies (here an index; for a table a column and a row, for a dict
a key), `why` is the kind of difference (`value`, `type`, `count`, `order`), and `a` and `b` are the two sides.

### Several inputs

A property of two arguments takes a list of two generators. With a dict of generators the property's parameters
are matched by name, in any order, and the report uses the names:

```q
q).qc.check[(.qc.int 0 9; .qc.int 0 9); {x<=x+y}];
ok 100 tests, exhausted (seed 7)
q).qc.check[`xs`n!(.qc.list .qc.int 0 9; .qc.int 0 5); {[n;xs] n<=count xs}];
FAIL falsified after 1 tests, 0 shrinks (3 attempts, seed 7)
xs: ()
n: 1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;0 1]
```

The second rule says a list has at least `n` items. The simplest input it could fail for is the empty list and
a count of 1, and that is the counterexample.

### What a property may return

A property passes when it returns `1b`, a boolean list that is all `1b`, or `::`. It fails when it returns
anything else or signals an error, and an error is reported with its message. This property signals for a list
of more than three items, and the counterexample is the simplest list of four:

```q
q).qc.check[.qc.list .qc.int 0 9; {if[3<count x; '"too long"]; 1b}];
FAIL falsified after 7 tests, 5 shrinks (38 attempts, seed 7)
x: 0 0 0 0
too long
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 1 0 1 0 1 0 0]
```

## Running a failure again

`.qc.again[]` tests the last counterexample again. `.qc.recheck` does the same for a generator, a property and
the choices of a `rerun:` line, which is how you test the fix: give it the corrected property, or the same
property over corrected code.

```q
q).qc.check[.qc.list .qc.int 0 100; {x~asc x}];
FAIL falsified after 5 tests, 8 shrinks (36 attempts, seed 7)
x: 1 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 0 0]
q).qc.again[];
FAIL falsified after 1 tests, 0 shrinks (0 attempts, seed 7)
x: 1 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 0 0]
q).qc.recheck[.qc.list .qc.int 0 100; {(asc x)~asc asc x}; 1 1 1 0 0];
ok 1 tests (seed 7)
```

### The failure database

Unless it is turned off, a failing run saves its counterexample in a directory `.qc` under the working
directory, and the next run of the same generator and property tries that counterexample before anything else.
A failure therefore stays failed until it is fixed, whatever the seed of the next run.

```q
q).qc.cfg[`db]:hsym `$first system"mktemp -d"
q).qc.check[.qc.list .qc.int 0 100; {x~asc x}];
FAIL falsified after 5 tests, 8 shrinks (36 attempts, seed 7)
x: 1 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 0 0]
q).qc.check[.qc.list .qc.int 0 100; {x~asc x}];
FAIL falsified after 0 tests, 0 shrinks (15 attempts, seed 7)
x: 1 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 0 0]
```

The second run says `after 0 tests`: it failed on the saved counterexample before drawing anything. When a saved
counterexample passes it is deleted and the run goes on as usual. `.qc.cfg[`db]` is the directory, and the null
symbol turns the database off, as the sessions in this tour and the scripts in `examples/` do.

## Drawing inside the property

A property can draw for itself with `.qc.draw`, which is useful when what to draw depends on something computed
along the way. The generator given to `check` is then `::`, for nothing. What is drawn inside shrinks like
everything else, but the report cannot know what to call it, so say so with `.qc.note`:

```q
q).qc.check[::; {n:.qc.draw .qc.int 1 9; .qc.note n; n<7}];
FAIL falsified after 6 tests, 0 shrinks (4 attempts, seed 7)
7
rerun: .qc.again[]  or  .qc.recheck[gen;prop;7]
```

## Tables

`.qc.tab` takes a dict of column generators and draws a table; `.qc.tabr` takes a range for the number of rows
first, and `.qc.ktab` a key and a range. Three wrappers make a column depend on the rows before it or on the row
it is in:

- `.qc.mono[base;delta]` starts at a value drawn from `base` and adds a value drawn from `delta` for each row, so
  the column never decreases: a time column;
- `.qc.uniq g` never repeats a value: a key column;
- `.qc.dep f` calls `f` with the row so far, as a dict, and draws from the generator it returns: an ask that is
  never below its bid.

```q
q).qc.draw .qc.tabr[4 4] `t`k`v!(.qc.mono[.qc.int 0 9;.qc.int 1 9]; .qc.uniq .qc.elem `a`b`c`d; .qc.dep {[r] .qc.int (r`t;20)})
t k v
------
1 b 3
4 a 10
6 d 14
8 c 8
```

`t` rises, `k` has no repeats, and each `v` lies between its row's `t` and 20.

When there is already a table of the shape you want, `.qc.schema` reads the generator off it: the column types,
the keys, the attributes and the enumerations.

```q
q)dom:`a`b`c
q)trade:([]time:`s#09:30:00 09:30:05 09:31:00; sym:`dom$`a`b`a; px:1.5 2.5 3.5)
q)meta .qc.draw .qc.schema trade
c   | t f a
----| -----
time| v   s
sym | s
px  | f
```

A table shrinks by losing rows and by its values moving towards their origins. This rule says the values of a
table never add up to 20, and the counterexample is the fewest rows that can, with the smallest values that do:

```q
q).qc.check[.qc.tab `k`v!(.qc.uniq .qc.int 0 3; .qc.int 0 9); {20>sum x`v}];
FAIL falsified after 42 tests, 10 shrinks (124 attempts, seed 7)
x:
  k v
  ---
  0 2
  1 9
  2 9
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 2 1 0 9 1 0 9 0]
```

The simplest table of all is the empty one, and its columns have their types, so a property over tables meets
the empty table first. Many of the failures in `COOKBOOK.md` and `WALKTHROUGH.md` are found there.

## Any value at all

`.qc.val` draws an arbitrary q value: an atom of any type, a list, a dict, a table, a keyed table. It is for
rules about what a program does to values in general: serialising them, sending them, storing them.

```q
q).qc.check[.qc.val; {x~-9!-8!x}];
ok 100 tests (seed 7)
```

`COOKBOOK.md` puts the same question to JSON, which answers differently.

## Large data

The generators so far record a choice or two for each value, which is fine for a table of fifty rows and slow
for a vector of a million. `.qc.bulk[r;nr]` draws a vector of longs in the range `r`, of a length in the range
`nr`, as one block; `.qc.btab` is a table of such columns. `.qc.nch` is how many draws the last example made.

```q
q)count .qc.draw .qc.bulk[0 99;1000000 1000000]
1000000
q).qc.nch
2
```

A block shrinks by deleting chunks of itself as well as by lowering its values, so a failure found in a hundred
thousand values is still reported in a handful:

```q
q).qc.check[.qc.bulk[0 99;0 100000]; {x~asc x}];
FAIL falsified after 1 tests, 10 shrinks (26 attempts, seed 7)
x: 1 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;2 1 0]
q).qc.check[.qc.btab[0 100000] `k`v!(0 9;("d";0 9)); {all x[`v]<2000.01.09}];
FAIL falsified after 1 tests, 9 shrinks (18 attempts, seed 7)
x:
  k v
  ------------
  0 2000.01.09
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 8]
```

## Trees

*As a script: `examples/tree.q`.*

`.qc.rec[k;leaf;node]` draws a recursive structure. `k` is a range for the number of children of a node, `leaf`
is the generator of a leaf, and `node` is a function that builds a node from the list of its children, which
have been drawn by the time it is called. A binary tree of longs, a node being the pair of its children
(`.Q.s1` prints it on one line):

```q
q)tree:.qc.rec[2 2; .qc.int 0 9; {(x 0;x 1)}]
q).Q.s1 .qc.draw tree
"(((2 2;1 3);(1;0 2));(0 0;(9;(7 1;0))))"
q).qc.minimal tree
0
```

The functions over a tree need one piece of care. A node is a general list and a leaf is an atom, but a node
whose children are both leaves is a pair of longs, which q keeps as a vector, so there are three cases:

```q
q)tree:.qc.rec[2 2; .qc.int 0 9; {(x 0;x 1)}]
q)depth:{$[0h=type x; 1+max .z.s each x; 0<type x; 1; 0]}
q)leaves:{$[0h=type x; sum .z.s each x; 0<type x; count x; 1]}
q)nodes:{$[0h=type x; 1+sum .z.s each x; 0<type x; 1; 0]}
q).qc.check[tree; {leaves[x]=1+nodes x}];
ok 100 tests (seed 7)
q).qc.check[tree; {depth[x]<3}];
FAIL falsified after 4 tests, 2 shrinks (30 attempts, seed 7)
x: (0;(0;0 0))
rerun: .qc.again[]  or  .qc.recheck[gen;prop;3 0 0 0 2 0 0 0 1 0 0 0 0 0]
```

A binary tree has one more leaf than it has nodes. It is not true that every tree is less than three deep, and
the counterexample is the simplest tree of depth three. A tree shrinks by a subtree becoming a leaf and by its
values being lowered, so what is left is a bare spine with 0 at every leaf.

## Small spaces are enumerated

When a generator can produce only a few values, `check` does not sample them. It tries every one, simplest
first, and says so:

```q
q).qc.check[.qc.bool; {1b}];
ok 2 tests, exhausted (seed 7)
q).qc.check[.qc.one (.qc.bool; .qc.int 0 9); {1b}];
ok 12 tests, exhausted (seed 7)
q).qc.check[(.qc.int 0 3; .qc.bool); {[a;b] a<3}];
FAIL falsified after 6 tests, 0 shrinks (4 attempts, seed 7)
a: 3
b: 0b
rerun: .qc.again[]  or  .qc.recheck[gen;prop;3 0]
```

`ok 2 tests, exhausted` is a proof and not a sample: there are two booleans and both passed. `.qc.one` draws from
one of several generators, here a boolean or a long from 0 to 9, which is twelve values. This covers lists of a
bounded length, alternatives, and short state machines, because what is enumerated is the choices. When the
space is too large to try in the number of tests allowed, the run samples, and the report does not say
`exhausted`.

## What the examples looked like

A passing run says that the rule held for the examples drawn. It is worth asking what those were: a rule about
wide tables proves little if every table drawn was narrow. Inside a property, `.qc.classify[name;b]` counts the
example under `name` when `b` is true, and the report prints the counts:

```q
q).qc.check[.qc.list .qc.int 0 9; {.qc.classify[`empty;0=count x]; .qc.classify[`long;10<count x]; x~reverse reverse x}];
ok 100 tests (seed 7)
label n  pct req lo       hi       ok bar
---------------------------------------------------
empty 3  3       1.025434 8.452078 1
long  67 67      57.30516 75.43702 1  #############
```

`n` and `pct` are how many of the examples had the label. `lo` and `hi` are the bounds between which the true
rate lies with 95% confidence, given that many examples.

`.qc.cover[name;pct;b]` turns the count into a requirement. The run goes on until it can tell whether the label
turns up in at least `pct` percent of examples, and fails if it does not:

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

The first run needed 192 tests before the lower bound passed 90. The second stopped at 100, because by then the
upper bound was below 90 and no more tests could change the answer. `.qc.elem` draws an item of a list.

## A suite

`.qc.checks` takes a dict from names to pairs of a generator and a property, runs each, and returns a table
with a row for each.

```q
q).qc.checks `comm`sorted!(((.qc.int 0 9;.qc.int 0 9);{(x+y)=y+x}); (.qc.list .qc.int 0 9;{x~asc x}));
--- comm
ok 100 tests, exhausted (seed 7)
--- sorted
FAIL falsified after 5 tests, 1 shrinks (17 attempts, seed 7)
x: 1 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 0 0]
name   ok why       stop      n   shrinks seed
----------------------------------------------
comm   1  ok        exhausted 100 0       7
sorted 0  falsified fail      5   1       7
```

`.qc.main` does the same and then exits with the number of failures, which is the shape of a CI script.
`.qc.must[g;prop]` is `check` for use inside another test framework: it returns the result when the property
passes and signals the whole report as one error when it does not.

## The result is data

`check` prints a report and returns a dict, and the report is made from the dict.

```q
q)r:.qc.check[.qc.list .qc.int 0 100; {x~asc x}];
FAIL falsified after 5 tests, 8 shrinks (36 attempts, seed 7)
x: 1 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 0 0]
q)r`ok`why`n`shrinks
0b
`falsified
5
8
q)r`x
x| 1 0
q)r`choices
1 1 1 0 0
q).qc.report r
"FAIL falsified after 5 tests, 8 shrinks (36 attempts, seed 7)"
"x: 1 0"
"rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 0 0]"
```

`REFERENCE.md` lists the keys.

## A generator of your own

*As a script: `examples/aj.q`. `COOKBOOK.md` takes the same example further.*

When the library's generators cannot say what you need, write a function that draws. It takes one argument,
which it ignores, and calls `.qc.draw` for each thing it wants. What it draws later can depend on what it drew
earlier, which is the point.

To test an as-of join, the quotes and the trades must have symbols in common, or no trade would find a quote. So
the symbols are drawn first, and both tables take their `sym` column from them:

```q
q)syms:.qc.lst[1 3] .qc.symc["abc";1 1]
q)tbl:{[s;nm;g] .qc.tabr[1 0W] (`sym`time,nm)!(.qc.elem s; .qc.mono[.qc.int 0 9;.qc.int 0 9]; g)}
q)pair:{[d] s:.qc.draw syms; `q`t!(.qc.draw tbl[s;`px;.qc.int 0 9]; .qc.draw tbl[s;`qty;.qc.int 0 9])}
q)p:.qc.draw pair
q)3#p`q
sym time px
-----------
c   0    1
c   1    1
c   2    1
q)3#p`t
sym time qty
------------
c   6    9
c   7    3
c   7    2
```

`syms` is one to three symbols of one letter each. `tbl` builds the generator of a table over the symbols `s`:
a `sym` from them, a `time` that never decreases, and one more column. `pair` is the generator of your own: it
draws the symbols, then the two tables.

The property compares `aj` with a join written the obvious way, which has a bug: it takes the first quote at or
before the trade where it should take the last.

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
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 0 0 0 1 0 0 0 0 1 0 0 0 1 0 0 1 0]
```

Two quotes for one symbol at one time, with different prices, and one trade. With only one quote, first and last
are the same quote; with the same price twice, the wrong quote gives the right answer. The diff says the price
of row 0 is 1 from `aj` and 0 from the naive join.

## A state machine against a table

*As a script: `examples/sm_table.q`. `README.md` explains the idea and how to read the trace.*

The system is a stack kept in a table. The model is a list. Each command says when it can run, what its input
is, how to call the system, what the answer should have been, and how the model moves on:

```q
q)S:([]v:`long$())
q)push:{`S insert enlist x;}
q)pop:{r:$[2<count S; first S`v; last S`v]; delete from `S where i=count[S]-1; r}
q)cmds:([cmd:`push`pop] pre:({1b};{0<count x}); gen:({.qc.int 0 9};{::}); run:(push;pop); post:({[m;i;o] 1b};{[m;i;o] o=last m}); upd:({[m;i;o] m,i};{[m;i;o] -1_m}))
q).qc.draw .qc.sm[`m0`init`steps!(`long$();{S::0#S};3 3)] cmds
step cmd  arg res model ok
--------------------------
0    push 1   ::  ,1    1
1    push 2   ::  1 2   1
2    pop  ::  2   ,1    1
q).qc.check[.qc.sm[`m0`init!(`long$();{S::0#S})] cmds; ::];
FAIL falsified after 10 tests, 3 shrinks (43 attempts, seed 7)
qc.post
step cmd  arg res model ok
--------------------------
0    push 0   ::  ,0    1
1    push 0   ::  0 0   1
2    push 1   ::  0 0 1 1
3    pop  ::  0   0 0   0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 1 0 0 1 0 1 1 1]
```

`.qc.sm[h] cmds` is a generator, so `.qc.draw` works on it: it runs one sequence of commands on the real stack
and returns the trace. The draw here asks for exactly three steps (`steps` is a range, and without it a sequence
is as long as the size of the example allows). `check` draws up to a hundred sequences and stops at the first
with a row that is not `ok`.

`pop` is wrong once three items are stacked, when it returns the bottom of the stack and not the top. The trace
is the shortest sequence that shows it. With another seed the three pushes may carry other values, such as
`1 0 0` with a `pop` that returns 1; what cannot change is that three pushes are needed and that the top and the
bottom must differ.

## A system in another process

*As a script: `examples/sm_ipc.q`, which is not run as a session here because it starts a second q.*

Nothing about a state machine needs the system to be in the same process. The commands of this one send their
calls down a handle, to a counter that wraps to zero when it passes three:

```
h "n:0; inc:{n::n+1; if[n>3; n::0]; n}; rd:{n}; rst:{n::0}"
cmds:([cmd:`inc`get]
  run: ({[i] h(`inc;::)}; {[i] h(`rd;::)});
  post:({[m;i;o] o=m+1};   {[m;i;o] o=m});
  upd: ({[m;i;o] m+1};     {[m;i;o] m}))
.qc.check[.qc.sm[`m0`init!(0;{h(`rst;::)})] cmds; ::]
```

There is no `gen` column because neither command takes an input, and no `pre` because either can run at any
time: a column left out takes its default. The model is the count there ought to be.

```
$ q examples/sm_ipc.q
a counter in another q process (it wraps after 3), reset over IPC before every sequence:
FAIL falsified after 9 tests, 5 shrinks (24 attempts, seed 2121582113)
qc.post
step cmd arg res model ok
-------------------------
0    inc ::  1   1     1
1    inc ::  2   2     1
2    inc ::  3   3     1
3    inc ::  0   4     0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 1 0 1 0 1 0]
```

Four increments, and every `get` that was in the sequence has been shrunk away, since reading the counter has
nothing to do with the bug. What makes this work is `init`. It resets the remote counter before every sequence,
and shrinking runs a great many sequences, each of which must start from zero.

## Settings

`.qc.cfg` holds the settings, and `.qc.chk` takes a dict of them, or just a number of tests, for one run:

```q
q).qc.chk[`n`seed!(1000;42i); .qc.list .qc.int 0 9; {x~reverse reverse x}];
ok 1000 tests (seed 42)
q).qc.chk[20; .qc.list .qc.int 0 9; {x~reverse reverse x}];
ok 20 tests (seed 7)
q)key .qc.cfg
`n`nmax`seed`sz`shrinks`disc`tries`depth`choices`same`clamp`db`name`rows`v
```

The ones you are most likely to change are `n`, the number of tests; `seed`, which is taken from the clock when
it is null; and `db`, the directory of the failure database. `REFERENCE.md` describes them all.
