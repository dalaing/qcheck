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

Six of the sections are also scripts under `examples/`, with the commentary as comments. Each runs from the
repository root, for example `q examples/reverse.q`. They take their seed from the clock, so the first line of a
report (how many tests passed, how many shrinks) differs from run to run and from what is printed here. The
counterexample should not: shrinking is built to end in the same place wherever it starts. It cannot promise
to, and a counterexample that changes with the seed is worth reporting.

| script | section |
|---|---|
| `examples/reverse.q` | [A first property](#a-first-property) |
| `examples/tree.q` | [Trees](#trees) |
| `examples/suite.q` | [A suite](#a-suite) |
| `examples/aj.q` | [A generator of your own](#a-generator-of-your-own) |
| `examples/sm_table.q` | [A stateful test of a table](#a-stateful-test-of-a-table) |
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
pair, one of which takes a range or a setting first: `lst`, `tabr`, `symc` and `chk`, beside `list`, `tab`,
`sym` and `check`.

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

`.qc.t` takes type characters as `$` does, and draws widely over the type, with its nulls and infinities
included: any long, dates a century either side of 2000. `.qc.tf` leaves the nulls and infinities out. An empty list from `.qc.vec` or `.qc.str` has its type, as the last line
shows. For a range of your own with a few nulls or infinities mixed in, see
[Nulls and infinities](#nulls-and-infinities).

## Choosing between generators

`.qc.elem xs` draws an item of the list `xs`. `.qc.one gs` draws from one of the generators in the list `gs`,
each as likely as the others. `.qc.freq[w] gs` does the same with weights, for when the alternatives are not
equally common, as quotes and trades are not:

```q
q)kind:.qc.freq[9 1] (`quote;`trade)
q)count each group .qc.draw 1000#enlist kind
quote| 893
trade| 107
q).qc.minimal kind
`quote
```

`1000#enlist kind` is a list of a thousand generators, which is a generator of a list of a thousand values.
Nine draws in ten are quotes. The simplest value is the first alternative, whatever its weight, so put the
simplest first: a counterexample will use the later ones only where it needs them.

The alternatives are generators, so they can be records of different shapes:

```q
q)quote:`kind`bid`spread!(`quote; .qc.flt 1 100; .qc.flt 0 5)
q)trade:`kind`px`qty!(`trade; .qc.flt 1 100; .qc.elem 1 10 100)
q)ev:.qc.freq[9 1] (quote;trade)
q).qc.draw ev
kind  | `quote
bid   | 52.08199
spread| 5f
q).qc.draw ev
kind  | `quote
bid   | 53.93625
spread| 2.342207
```

`` `quote `` and `` `trade `` in these are constants, and a constant is a generator of itself. One kind of
constant needs care. A function in a generator is taken for a generator and called, so to have the function
itself as the value, wrap it in `.qc.const`:

```q
q).qc.draw (.qc.int 0 9; `a; .qc.const {x+1})
1
`a
{x+1}
```

## A first property

*As a script: `examples/reverse.q`.*

A property is a function of one drawn value that returns `1b` when the rule it states holds. Reversing a list
twice gives the list back:

```q
q)ints:.qc.list .qc.int 0 99
q).qc.check[ints; {x~reverse reverse x}];
ok 100 tests (seed 7)
```

A hundred lists were drawn and the rule held for each. (The `;` at the end of the line is only there to keep the
REPL from printing what `check` returns, which is the [result](#the-result-is-data).)

A rule that is false, that a list is its own reverse:

```q
q)ints:.qc.list .qc.int 0 99
q).qc.check[ints; {x~reverse x}];
FAIL falsified after 5 tests, 6 shrinks (34 attempts, seed 7)
x: 0 1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 1 1 0]
```

Five lists passed (the empty list and lists of one item are their own reverse, and so are some others). The sixth
did not, and it was shrunk: 34 other lists were tried, and 6 of them failed and were simpler than the one
before. `0 1` is what is left. No list of fewer than two items can fail, and no two different longs in the range are nearer to 0 than these.

In the `rerun:` line, `gen` and `prop` stand for the generator and the property that were given to `check`, and
the numbers are the choices that draw `0 1`.

### Seeing the difference

`~` answers yes or no. `.qc.eq[a;b]` is `~` that explains itself: when the two sides differ, the report carries
a table of the differences.

```q
q).qc.check[.qc.list .qc.int 0 100; {.qc.eq[x;asc x]}];
FAIL falsified after 5 tests, 7 shrinks (59 attempts, seed 7)
x: 1 0
qc.eq
path why   a b
--------------
0    value 1 0
1    value 0 1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 0 0]
```

One row for each difference: `path` is where it lies (here an index; for a table a column and a row, for a dict
a key), `why` is the kind of difference (`value`, `type`, `count`, `key`, `order`), and `a` and `b` are what the
two sides have there: the values, or their types, counts or keys.

### Several inputs

A property of two arguments takes a list of two generators. With a dict of generators the property's parameters
are matched by name, in any order, and the report uses the names:

```q
q).qc.check[(.qc.int 0 9; .qc.int 0 9); {x<=x+y}];
ok 100 tests, exhausted (seed 7)
q).qc.check[`xs`n!(.qc.list .qc.int 0 9; .qc.int 0 5); {[n;xs] n<=count xs}];
FAIL falsified after 1 tests, 0 shrinks (4 attempts, seed 7)
xs: ()
n: 1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;0 1]
```

The first report says `exhausted`: two digits make a hundred pairs, and the run tried every one, which
[Small spaces are enumerated](#small-spaces-are-enumerated) explains. The second rule says a list has at least
`n` items. The simplest input it could fail for is the empty list and a count of 1, and that is the
counterexample.

### What a property may return

A property passes when it returns `1b`, a boolean list that is all `1b` (an empty list counts), or `::`. It
fails when it returns anything else, the long `1` included, or signals an error, and an error is reported with
its message. This property signals for a list
of more than three items, and the counterexample is the simplest list of four:

```q
q).qc.check[.qc.list .qc.int 0 9; {if[3<count x; '"too long"]; 1b}];
FAIL falsified after 7 tests, 5 shrinks (49 attempts, seed 7)
x: 0 0 0 0
too long
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 1 0 1 0 1 0 0]
```

## Running a failure again

`.qc.again[]` tests the last counterexample again. `.qc.recheck` does the same for a generator, a property and
the choices of a `rerun:` line, which is how you test the fix: give it the corrected property, or the same
property over corrected code. Both run one test, so their reports read `after 0 tests` for a failure and
`ok 1 tests` for a pass.

```q
q).qc.check[.qc.list .qc.int 0 100; {x~asc x}];
FAIL falsified after 5 tests, 7 shrinks (59 attempts, seed 7)
x: 1 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 0 0]
q).qc.again[];
FAIL falsified after 0 tests, 0 shrinks (0 attempts, seed 7)
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
FAIL falsified after 5 tests, 7 shrinks (59 attempts, seed 7)
x: 1 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 0 0]
q).qc.check[.qc.list .qc.int 0 100; {x~asc x}];
FAIL falsified after 0 tests, 0 shrinks (40 attempts, seed 7)
x: 1 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 0 0]
```

The second run says `after 0 tests`: it failed on the saved counterexample before drawing anything. When a saved
counterexample passes it is deleted and the run goes on as usual. `.qc.cfg[`db]` is the directory, and the null
symbol turns the database off, as the sessions in this tour and the scripts in `examples/` do.

## Drawing inside the property

A property can draw for itself with `.qc.draw`, which is useful when what to draw depends on something computed
along the way. The generator given to `check` is then `::`, for nothing. What is drawn inside shrinks like
everything else, but a report shows only what the generator given to `check` drew, so add the value to the
report with `.qc.note`:

```q
q).qc.check[::; {n:.qc.draw .qc.int 1 9; .qc.note n; n<7}];
FAIL falsified after 6 tests, 0 shrinks (5 attempts, seed 7)
7
rerun: .qc.again[]  or  .qc.recheck[gen;prop;7]
```

## Nulls and infinities

Code that is right for ordinary values is often wrong for a null or an infinity, and real data has both. There
are two ways to get them into the examples. `.qc.t` draws widely over a type, so `.qc.t"f"` is any float at
all. `.qc.spc[specials] g` keeps a range of your own: it draws from the generator `g` most of the time,
and about one time in twenty it gives one of `specials` instead.

Prices from 1 to 100, with now and then a null or an infinity:

```q
q)px:.qc.spc[0n 0w] .qc.flt 1 100
q)sum (.qc.draw 1000#enlist px) in 0n 0w
35i
q).qc.minimal px
1f
```

In a thousand draws a few dozen were special. The simplest value is still the simplest ordinary one, so a
special value stays in a counterexample only when the failure needs it.

The rule: prices are positive, so a running total of them never falls.

```q
q)px:.qc.spc[0n 0w] .qc.flt 1 100
q).qc.check[.qc.lst[1 0W] .qc.flt 1 100; {all 0<=1_deltas sums x}];
ok 100 tests (seed 7)
q).qc.check[.qc.lst[1 0W] px; {all 0<=1_deltas sums x}];
FAIL falsified after 8 tests, 9 shrinks (53 attempts, seed 7)
x: 0w 1
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 0 0 1 1 0 0 0 0 1 0]
```

It holds for ordinary prices and fails once an infinity has a price after it. After an infinite price the
running total is `0w 0w`, the step between the two is `0w-0w`, and that is null. The counterexample is as short
as it can be: the infinity, and one price after it to take the step. The nulls did no harm to this rule, since
`sums` passes over them.

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
table add up to less than 20, and the counterexample is the fewest rows that can reach 20, with the smallest
values that do:

```q
q).qc.check[.qc.tab `k`v!(.qc.uniq .qc.int 0 3; .qc.int 0 9); {20>sum x`v}];
FAIL falsified after 42 tests, 12 shrinks (114 attempts, seed 7)
x:
  k v
  ---
  0 2
  1 9
  2 9
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 2 1 0 9 1 0 9 0]
```

The simplest table of all is the empty one, and its columns of atoms have their types, so a property over
tables meets the empty table first. Many of the failures in `COOKBOOK.md` and `WALKTHROUGH.md` are found there.

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
`nr`, as one block; `.qc.btab` is a table of such columns. `.qc.nch` is how many choices the last example
recorded, a block counting as one: here the length and the block.

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
FAIL falsified after 1 tests, 10 shrinks (76 attempts, seed 7)
x: 1 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;2 1 0]
q).qc.check[.qc.btab[0 100000] `k`v!(0 9;("d";0 9)); {all x[`v]<2000.01.09}];
FAIL falsified after 1 tests, 9 shrinks (22 attempts, seed 7)
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
q).qc.check[tree; {depth[x]<4}];
FAIL falsified after 6 tests, 2 shrinks (49 attempts, seed 7)
x: (0;(0;(0;0 0)))
rerun: .qc.again[]  or  .qc.recheck[gen;prop;4 0 0 0 3 0 0 0 2 0 0 0 1 0 0 0 0 0]
```

A binary tree has one more leaf than it has nodes. It is not true that every tree is less than four deep, and
the counterexample is the simplest tree of depth four. A tree shrinks by a subtree becoming a leaf and by its
values being lowered, so what is left is a bare spine with 0 at every leaf.

The script goes on to trees with up to four children at a node, and counts how many of those drawn were wide at
the root, with `.qc.classify`, which [What the examples looked like](#what-the-examples-looked-like) explains.

## Small spaces are enumerated

When a generator can produce only a few values, `check` does not sample them. It tries every one, simplest
first, and says so:

```q
q).qc.check[.qc.bool; {1b}];
ok 2 tests, exhausted (seed 7)
q).qc.check[.qc.one (.qc.bool; .qc.int 0 9); {1b}];
ok 12 tests, exhausted (seed 7)
q).qc.check[(.qc.int 0 3; .qc.bool); {[a;b] a<3}];
FAIL falsified after 6 tests, 0 shrinks (6 attempts, seed 7)
a: 3
b: 0b
rerun: .qc.again[]  or  .qc.recheck[gen;prop;3 0]
```

`ok 2 tests, exhausted` is a proof and not a sample: there are two booleans and both passed. `.qc.one` draws from
one of several generators, here a boolean or a long from 0 to 9, which is twelve values. This covers lists of a
bounded length, alternatives, and stateful tests whose sequences are short ([below](#a-stateful-test-of-a-table)),
because what is enumerated is the choices. When the space is too large to try in the number of tests allowed, or
the run cannot tell early on that it is small enough, the run samples, and the report does not say `exhausted`.

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

`.qc.label name` counts the example under a name that the property works out, and `.qc.collect x` counts it
under a value, here the length of the list:

```q
q).qc.check[.qc.lst[0 4] .qc.int 0 99; {.qc.collect count x; 1b}];
ok 100 tests (seed 7)
label n  pct req lo       hi       ok bar
-------------------------------------------
0     27 27      19.26946 36.4323  1  #####
1     17 17      10.89348 25.54818 1  ###
4     17 17      10.89348 25.54818 1  ###
2     22 22      15.00117 31.07053 1  ####
3     17 17      10.89348 25.54818 1  ###
q).qc.check[.qc.list .qc.int 0 99; {.qc.label `$("short";"long") 10<count x; 1b}];
ok 100 tests (seed 7)
label n  pct req lo       hi       ok bar
-------------------------------------------------
short 42 42      32.79822 51.79369 1  ########
long  58 58      48.20631 67.20178 1  ###########
```

Use `collect` where the values are few. Each distinct value is a row of the table, and a row for each of a
thousand lengths would tell you nothing.

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
upper bound was below 90 and the run was confident that the rate is too. `.qc.elem` draws an item of a list.

## How examples grow

A run does not draw every example from the same place. Each example has a *size*, which rises over the run from
0 to just short of 100, and the size is a cap on how much an example may hold: the items of a list, the rows of a table, the
nodes of a tree. The early examples are therefore small and quick, and the later ones large. The labels show it:

```q
q).qc.check[.qc.list .qc.int 0 9; {.qc.classify[`under_10;10>count x]; .qc.classify[`over_50;50<count x]; 1b}];
ok 100 tests (seed 7)
label    n  pct req lo       hi       ok bar
-----------------------------------------------
under_10 33 33      24.56298 42.69484 1  ######
over_50  19 19      12.51465 27.77902 1  ###
q).qc.chk[enlist[`sz]!enlist 10; .qc.list .qc.int 0 9; {.qc.classify[`under_10;10>count x]; .qc.classify[`over_50;50<count x]; 1b}];
ok 100 tests (seed 7)
label    n   pct req lo       hi  ok bar
---------------------------------------------------------
under_10 100 100     96.30052 100 1  ####################
```

The setting `sz` is the size that a run rises to. Lower it when the property is slow and small examples will do,
as in the second line, where no list is longer than ten.

**Part of a generator.** `.qc.small g` draws from `g` at half the size. It is for the inner levels of something
nested, where full size at every level is more than anyone wants: three lists of up to a hundred items each, or
three of up to fifty.

```q
q).qc.check[.qc.lst[0 3] .qc.list .qc.int 0 9; {.qc.classify[`long;30<count raze x]; 1b}];
ok 100 tests (seed 7)
label n  pct req lo       hi       ok bar
-----------------------------------------------
long  48 48      38.46438 57.68359 1  #########
q).qc.check[.qc.lst[0 3] .qc.small .qc.list .qc.int 0 9; {.qc.classify[`long;30<count raze x]; 1b}];
ok 100 tests (seed 7)
label n  pct req lo       hi       ok bar
------------------------------------------
long  21 21      14.16555 29.98015 1  ####
```

**A range that grows.** A range of longs may be a function of the size that returns one: for `.qc.int`, for the
length of a list, a string or a vector, and for the rows of a table. (`.qc.flt` and the `k` of `.qc.rec` take a
constant range only.) `.qc.int {0,x}` is a long from 0 to the size, and `.qc.lin[lo;hi]` is such a function,
which would reach `hi` at size 100.

```q
q).qc.lin[0;1000] each 0 50 100
0 0
0 500
0 1000
q).qc.check[.qc.int {0,x}; {x<50}];
FAIL falsified after 63 tests, 0 shrinks (8 attempts, seed 7)
x: 50
rerun: .qc.again[]  or  .qc.recheck[gen;prop;50]
```

The first line shows the ranges that `.qc.lin[0;1000]` gives at three sizes. In the second, the rule `x<50`
could not fail until the size had reached 50, so at least fifty tests had to pass first. Here it was 63 before a
value of 50 or more was drawn. A range that grows keeps the first examples of a run simple.

**A generator that depends on the size.** `.qc.sized f` calls `f` with the size and draws from the generator it
returns. Lists of at most a tenth of the size, plus one:

```q
q)short:.qc.sized {[n] .qc.lst[0,1+n div 10] .qc.int 0 9}
q).qc.check[short; {.qc.collect count x; 1b}];
ok 100 tests (seed 7)
label n  pct req lo        hi       ok bar
-------------------------------------------
0     24 24      16.69121  33.23252 1  ####
1     24 24      16.69121  33.23252 1  ####
2     16 16      10.0952   24.42044 1  ###
3     7  7       3.431882  13.74967 1  #
5     8  8       4.109297  14.99827 1  #
4     7  7       3.431882  13.74967 1  #
6     5  5       2.154336  11.1752  1  #
7     5  5       2.154336  11.1752  1  #
9     3  3       1.025434  8.452078 1
8     1  1       0.1767387 5.448752 1
q).qc.check[short; {3>count x}];
FAIL falsified after 21 tests, 3 shrinks (35 attempts, seed 7)
x: 0 0 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 1 0 1 0 0]
```

One rule goes with all of these. **As the size grows, a range may only widen**: its lower end must not rise and
its upper end must not fall. A counterexample found at a small size is shrunk and run again at full size, and
it is the same value there only if everything that could be drawn at the small size can still be drawn. So
`{0,x}` is sound, and `{(x div 2;x)}`, "at least half the size", is not. For the same reason `short` draws a
list of *up to* a length that depends on the size. A list of exactly that length would be a different list at
full size.

## Filtering

`.qc.such[p] g` draws from `g` until the predicate `p` holds for the value:

```q
q)even:.qc.such[{0=x mod 2}] .qc.int 0 99
q).qc.draw .qc.lst[5 5] even
6 24 8 0 2
```

It is the first thing to reach for and often the wrong one, because a filter changes which values are drawn
without saying so. Multiples of a thousand, by filter:

```q
q).qc.check[.qc.such[{0=x mod 1000}] .qc.int 1 100000; {.qc.collect x; 1b}];
ok 100 tests (seed 7)
label  n   pct req lo       hi  ok bar
-------------------------------------------------------
100000 100 100     96.30052 100 1  ####################
```

A hundred tests passed, and every one of them was the same number. One long in a thousand passes the filter.
The simplest value of a range, its neighbours and the two ends are drawn far more often than the values in the
middle, because bugs live there. The upper end of this range happens to pass the filter, and it is drawn about
a hundred times as often as all the other multiples of a thousand together.

The better way is to draw something simple and *make* the value from it. `'[f;g]` is the generator `g` with the
function `f` applied to what it draws:

```q
q).qc.check[('[1000*;.qc.int 1 100]); {.qc.classify[`over_50000;x>50000]; 1b}];
ok 100 tests, exhausted (seed 7)
label      n  pct req lo       hi       ok bar
-----------------------------------------------------
over_50000 50 50      40.38298 59.61702 1  ##########
```

Every value is a multiple of a thousand, nothing is drawn and thrown away, and since there are only a hundred of
them the run tried them all. The same goes for a sorted list (`'[asc;g]`, or `.qc.atr`, which gives the other
attributes too), for distinct keys (`.qc.uniq`), and for an ask above its bid (`.qc.dep`). Keep `such` for a
condition that most values meet.

`such` tries fifty times, which is the setting `tries`, and then gives the example up as a *discard*. A property
can discard too, with `.qc.discard[]`, when it finds that an example is not one the rule is about:

```q
q).qc.check[.qc.list .qc.int 0 9; {if[0=count x; .qc.discard[]]; (max x) in x}];
ok 100 tests (seed 7)
q).qc.check[.qc.list .qc.int 0 9; {if[5>count x; .qc.discard[]]; (max x) in x}];
FAIL gave up after 0 tests; discards: discard 1001
```

A discarded example is not a test, and a run that discards too much gives up, which is a failure: nothing was
learned. The second run discards every list of fewer than five items. The size of an example rises with the
number of tests that have passed, and a discard is not a test, so the size never left 0 and almost every list
drawn was empty. After a thousand discards, which is ten (the setting `disc`) for each test wanted, the run
gave up. The fix is once more to draw what is wanted, here with `.qc.lst[5 0W]`, a list of at least five.

One more thing to know: `.qc.minimal` of a filtered generator signals `qc.discard` when the simplest value of
the generator fails the filter.

## A suite

*As a script: `examples/suite.q`.*

`.qc.checks` takes a dict from names to pairs of a generator and a property, runs each, and returns a table
with a row for each.

```q
q).qc.checks `comm`sorted!(((.qc.int 0 9;.qc.int 0 9);{(x+y)=y+x}); (.qc.list .qc.int 0 9;{x~asc x}));
--- comm
ok 100 tests, exhausted (seed 7)
--- sorted
FAIL falsified after 5 tests, 1 shrinks (27 attempts, seed 7)
x: 1 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 0 0]
name   ok why       stop      n   shrinks seed
----------------------------------------------
comm   1  ok        exhausted 100 0       7
sorted 0  falsified fail      5   1       7
```

The report of each property comes first, under its name, and the table last, with a row for each.

`.qc.main` does the same and then exits, with the number of failures as the exit code, which is what a CI job
looks at. `examples/suite.q` is a script of that shape:

```
$ q examples/suite.q; echo "exit code $?"
--- reverse_twice
ok 100 tests (seed 1521818691)
--- sum_any_order
ok 100 tests (seed 1565486691)
--- count_of_a_join
ok 100 tests (seed 1607639691)
--- already_sorted
FAIL falsified after 4 tests, 8 shrinks (59 attempts, seed 1692669691)
x: 1 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 0 0]
name            ok why       stop n   shrinks seed
--------------------------------------------------------
reverse_twice   1  ok        n    100 0       1521818691
sum_any_order   1  ok        n    100 0       1565486691
count_of_a_join 1  ok        n    100 0       1607639691
already_sorted  0  falsified fail 4   8       1692669691
exit code 1
```

## Inside another test framework

A test framework wants an expression that either returns or signals. `.qc.must[g;prop]` is `check` in that
form. It prints nothing. When the property passes it returns the result, and when it fails it signals the whole
report as one error:

```q
q)r:.qc.must[.qc.list .qc.int 0 9; {x~reverse reverse x}]
q)r`ok`n
1b
100
q)e:@[.qc.must[.qc.list .qc.int 0 9]; {x~asc x}; {x}]
q)-1 e;
qc: FAIL falsified after 5 tests, 1 shrinks (27 attempts, seed 7)
x: 1 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 0 0]
```

The first line of the error is the verdict, and the rest is what you need to reproduce the failure. `.qc.mustc`
takes settings first, as `.qc.chk` does.

A framework that treats an error in a test as a failed test can use `.qc.must[g;prop]` as the whole test. Most
frameworks tell an *error* from a *failure*, though, and count a signal as an error. To have a failing property
counted as a failure, run the check quietly, with the setting `v` of 0, and hand its result to the framework's
own assertion, with the report as the message:

```q
q)r:.qc.chk[enlist[`v]!enlist 0; .qc.list .qc.int 0 9; {x~asc x}]
q)r`ok
0b
q)"\n" sv .qc.report r
"FAIL falsified after 5 tests, 1 shrinks (27 attempts, seed 7)\nx: 1 0\nrerun..
```

`examples/frameworks/` has a file for each of three frameworks, tried on kdb+ 5.0 with the versions of them
current in September 2026:

| framework | file | a test is | a failing property shows as |
|---|---|---|---|
| k4unit | `k4unit.csv` | a `true` row whose code is ``(.qc.check[g;prop])`ok`` | `ok` of `0b` in `KUTR`, with the report on the console |
| qspec | `qspec.q` | `.qc.must[g;prop]` | an error, with the report |
| | | ``must[r`ok; "\n" sv .qc.report r]`` | a failure, with the report |
| QUnit | `qunit.q` | `.qc.must[g;prop]` | the status `error`, with the report as the result |
| | | ``.qunit.assertTrue[r`ok; "\n" sv .qc.report r]`` | the status `fail`, with the report as the message |

k4unit's `true` wants exactly `1b` and keeps no message from an error, which is why its row uses `check` and not
`must`: `must` alone returns a dict, which k4unit would record as a failed test, and its report would be lost.
In each file `qc.q` is loaded before the framework runs the tests.

## The result is data

`check` prints a report and returns a dict, and the report is made from the dict.

```q
q)r:.qc.check[.qc.list .qc.int 0 100; {x~asc x}];
FAIL falsified after 5 tests, 7 shrinks (59 attempts, seed 7)
x: 1 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 0 0]
q)r`ok`why`n`shrinks
0b
`falsified
5
7
q)r`x
x| 1 0
q)r`choices
1 1 1 0 0
q).qc.report r
"FAIL falsified after 5 tests, 7 shrinks (59 attempts, seed 7)"
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

Two quotes for one symbol at one time, with different prices, and one trade. With only one quote, first and last
are the same quote; with the same price twice, the wrong quote gives the right answer. The diff says the price
of row 0 is 1 from `aj` and 0 from the naive join.

## A stateful test of a table

*As a script: `examples/sm_table.q`. `README.md` ("Stateful testing") explains the idea and how to read the trace.*

The system is a stack kept in a table. The model is a list. Each command says when it can run, what its input
is, how to call the system, what the answer should have been, and how the model moves on:

```q
q)S:([]v:`long$())
q)push:{`S insert enlist x;}
q)pop:{r:$[2<count S; first S`v; last S`v]; delete from `S where i=count[S]-1; r}
q)cmds:([cmd:`push`pop] pre:({1b};{0<count x}); gen:({.qc.int 0 9};{::}); run:`push`pop; post:({[m;i;o] 1b};{[m;i;o] o=last m}); upd:({[m;i;o] m,i};{[m;i;o] -1_m}))
q).qc.draw .qc.sm[`m0`init`steps!(`long$();{`S set 0#S};3 3)] cmds
step cmd  arg res model ok
--------------------------
0    push 1   ::  ,1    1
1    push 2   ::  1 2   1
2    pop  ::  2   ,1    1
q).qc.check[.qc.sm[`m0`init!(`long$();{`S set 0#S})] cmds; ::];
FAIL falsified after 10 tests, 3 shrinks (55 attempts, seed 7)
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
is of any length up to the size of the example). `check` draws up to a hundred sequences and stops at the first
with a row that is not `ok`.

`pop` is wrong once three items are stacked, when it returns the bottom of the stack and not the top. The trace
is the shortest sequence that shows it: three pushes are needed, and the top and the bottom must differ. `0 0 1`
is the simplest three values that do, and the script ends on them whatever its seed.

## A system in another process

*As a script: `examples/sm_ipc.q`, which is not run as a session here because it starts a second q.*

Nothing about a stateful test needs the system to be in the same process. The commands of this one send their
calls as synchronous messages down a connection handle, to a counter that wraps to zero when it passes three:

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
FAIL falsified after 9 tests, 5 shrinks (32 attempts, seed 2121582113)
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
