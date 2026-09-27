# qcheck

Property-based testing for q/kdb+. You state a rule your code should obey; qcheck generates inputs, finds one
that breaks the rule, and cuts it down to the simplest input that still does.

```q
q)\l qc.q
q).qc.check[.qc.list .qc.int 0 100; {x~asc x}];
FAIL falsified after 5 tests, 8 shrinks (36 attempts, seed 7)
x: 1 0
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 0 0]
```

It is one file with no dependencies. A failure is reported with its simplest input, a diff where two values
were compared, and a line that reproduces it. Cutting an input down needs nothing written by you, whatever the
inputs are. A system that keeps state, such as a table that `upd` appends to, is tested with sequences of calls.

## What property-based testing is

An ordinary test checks one input you thought of against the answer you worked out by hand: `1 2 3~asc 3 1 2`.
It passes, and it says nothing about the empty list, a list of nulls, or the input nobody thought of.

A property-based test states a rule and leaves the library to look for an input that breaks it. It has two parts:

- a **generator**, which describes the inputs: `.qc.list .qc.int 0 100` is "any list of longs from 0 to 100";
- a **property**, a function of one such input that returns `1b` when the rule holds: `{x~asc x}` is "the list
  is already sorted".

`.qc.check[g;prop]` draws *examples* from the generator `g`, the simplest ones first and then random ones that
grow, and calls the property on each; one call is a *test*. A hundred passing tests print a line that begins
`ok 100 tests`. The first failing test ends the run, and the library then *shrinks* the example that failed: it tries shorter lists and smaller numbers,
keeping every change that still fails, until nothing simpler does. What it reports is that *counterexample*.

The rule in the transcript above is false on purpose, so that its report can be read a piece at a time:

| in the report | what it says |
|---|---|
| `falsified after 5 tests` | five examples passed and the next one broke the rule |
| `8 shrinks (36 attempts` | the shrinker tried 36 simpler candidates; 8 of them still failed, each simpler than the last |
| `x: 1 0` | the counterexample: no unsorted list is shorter, and none of this length has smaller items |
| `seed 7` | the seed of the run: the same seed draws the same examples |
| `rerun:` | `.qc.again[]` tests this counterexample again, which is how you see that a fix worked; in the longer form, `gen` and `prop` stand for the generator and the property you gave, and the numbers reproduce the counterexample |

Shrinking is what makes a failure readable. With it switched off, the report is the example as it was drawn:

```q
q).qc.chk[enlist[`shrinks]!enlist 0; .qc.list .qc.int 0 100; {x~asc x}];
FAIL falsified after 5 tests, 0 shrinks (0 attempts, seed 7)
x: 1 44 1 29 15
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 1 44 1 1 1 29 1 15 0]
```

Five numbers leave you to work out which of them matter; `1 0` is the bug with nothing else in it.

A rule that sounds true finds the input you would not have written down. After `fills`, a list has no nulls:

```q
q).qc.check[.qc.list .qc.t"j"; {not any null fills x}];
FAIL falsified after 23 tests, 2 shrinks (13 attempts, seed 7)
x: ,0N
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 1 0 0 0]
```

`.qc.t"j"` draws any long, nulls and infinities included, and a list that starts with a null has nothing to fill
it from.

### Finding properties

Nobody can work out the expected answer for a random input by hand, so a property says how answers relate to
their inputs and to each other, not what they are. The shapes that come up most:

```q
ints:.qc.list .qc.int -9 9
.qc.check[.qc.val; {x~-9!-8!x}]                                         / a round trip: decoding undoes encoding
.qc.check[ints; {(distinct x)~{$[y in x;x;x,y]}/[0#x;x]}]               / an oracle: the fast way agrees with an obvious slow way
.qc.check[ints; {s:asc x; (all 0<=1_deltas s) and count[s]=count x}]    / an invariant: what is true of every answer
.qc.check[ints; {(asc x)~asc asc x}]                                    / idempotence: doing it twice changes nothing
.qc.check[(ints;ints); {[x;y] count[x,y]=count[x]+count y}]             / a law that relates two calls
```

For code of your own the oracle is often the place to start: a naive version that is too slow for production is
fast enough for a test, and easy to believe (`COOKBOOK.md` tests an as-of join this way).

## Getting started

Copy `qc.q` anywhere and load it: `\l qc.q` from the directory it is in, or `\l /path/to/qc.q`. Nothing else is
needed.

It is tested on kdb+ 5.0, on macOS. It uses `binr`, `.Q.trp`, `.Q.sbt` and `'[;]` composition, so 3.5 or later
should work, but that has not been tried.

A failing check saves its counterexample in a directory `.qc` under the working directory and tries it first the
next time, so a failure stays failed until it is fixed. ``.qc.cfg[`db]:` `` turns that off.

The licence is MIT: see `LICENSE`. `qc.q` carries the notice in its header, since it travels alone.

## Generators

A generator is anything `.qc.draw` can draw a value from. The library's generators are functions, most of which
take a range or a setting first: `.qc.int` is the function and `.qc.int 0 9` the generator. A list of generators
is a generator of tuples, a dict of generators is a generator of records, and any other value is a generator of
itself.

```q
.qc.int -100 100                       / a long; shrinks toward 0
.qc.int 1 1000 1                       / lo hi origin: shrinks toward 1
.qc.int {0,x}                          / a range may be a function of the size, which grows over a run
.qc.list .qc.int 0 9                   / a list; .qc.lst[3 5] g for a length range
(.qc.int 0 9; .qc.sym)                 / a pair
`name`age!(.qc.sym; .qc.int 0 120)     / a record: named inputs in the report
'[neg; .qc.int 0 9]                    / a function of what a generator draws: compose them
{n:.qc.draw .qc.int 1 9; .qc.draw .qc.lst[n,n] .qc.sym}   / a generator of your own is a function that draws
.qc.one (.qc.int 0 9; .qc.sym)         / alternatives; .qc.freq[3 1] gs weights them
.qc.such[{x>0}] .qc.int -9 9           / a filter: it draws again until the condition holds
.qc.t"j"                               / an atom of any type, drawn widely, nulls and infinities included
.qc.t"jf"                              / a pair of them; .qc.tf"j" leaves out the null and the infinities
.qc.ts[2024.01.02D09:30;2024.01.02D16:00] / a timestamp in a session; .qc.dates[from;to] a date
.qc.val                                 / an arbitrary q value: atoms of every type, lists, dicts, tables
.qc.flt 0 1                            / a float in a range; .qc.dbl is any finite double
.qc.str                                / a string; .qc.sym a symbol over a bounded alphabet
.qc.vec[0 5]"d"                        / a typed vector, here of dates
.qc.tab `a`b!(.qc.int 0 9; .qc.sym)    / a table; .qc.ktab[`a;0 9] cols keyed (keys distinct)
.qc.tab `t`k`v!(.qc.mono[.qc.int 0 9;.qc.int 1 9]; .qc.uniq .qc.elem `a`b`c; .qc.dep {[r] .qc.int (r`t;99)})   / a sorted column, distinct keys, a column that sees the row
.qc.schema ([]time:`s#09:30 09:31; sym:`a`b; px:1.5 2.5)   / tables shaped like a sample: types, keys, attributes, enumerations
.qc.atr[`s] .qc.list .qc.int 0 9         / a sorted vector carrying s#
.qc.bulk[0 99;0 1000000]                 / a long vector drawn as one block, for large data; .qc.btab[nr] cols a table of them
.qc.rec[2 2; .qc.int 0 9; {(x 0;x 1)}] / a binary tree: arity range, leaf, node of its children (values)
```

`.qc.draw g` draws a value from a generator, and `.qc.minimal g` gives its simplest value, which is where
shrinking is heading. Many names come in pairs, one of which takes a range or a setting first: `lst`, `tabr`,
`symc` and `chk`, beside `list`, `tab`, `sym` and `check`. `EXAMPLES.md` goes through the generators a few at a
time, with what size is and what a filter costs, and `REFERENCE.md` lists them all.

## Properties

```q
digit:.qc.int 0 9; prop:{x<10}
.qc.check[digit; prop]                             / one input: prop is given the value drawn
.qc.check[(.qc.int 0 9; .qc.int 0 9); {x>=y}]      / a list of generators: one argument for each
.qc.check[`xs`n!(.qc.list .qc.int 0 9; .qc.int 0 5); {[n;xs] n<=count xs}]   / a dict of generators: by parameter name
.qc.check[::; {n:.qc.draw .qc.int 1 9; n>0}]       / draw inside the property; it shrinks with everything
.qc.chk[`n`seed!(1000;42i); digit; prop]           / settings first; .qc.cfg holds the defaults
.qc.checks `comm`sorted!((( .qc.int 0 9;.qc.int 0 9);{(x+y)=y+x}); (.qc.list .qc.int 0 9;{x~asc x}))   / a suite
```

A property passes if it returns `1b`, a boolean list that is all `1b` (an empty list counts), or `::`. Any other
value fails it, the long `1` included, and so does an error, which is reported with its message.

A run draws `n` examples, 100 unless you say otherwise. When a generator has few enough choices to make that
every input can be tried within `n` tests, the run tries them all, simplest first, and says so:
`.qc.check[.qc.bool;{1b}]` prints `ok 2 tests, exhausted`. There are two booleans and both passed, which is a
proof and not a sample.

Inside a property:

| call | what it does |
|---|---|
| `.qc.eq[a;b]` | `a~b`, and when they differ the report shows where and how |
| `.qc.note x` | adds a value to the report of a failure |
| ``.qc.classify[`big;x>5]`` | counts the examples for which the condition holds; the report shows the counts |
| `.qc.collect x` | counts the examples by a value (keep the number of distinct values small) |
| ``.qc.cover[`big;90;x>5]`` | requires the condition in 90% of examples; the run goes on until it can tell, to at most ten times `n` tests, and fails when it is confident the rate is lower |

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

`check` returns its result as a dict (`REFERENCE.md` lists the keys), and the report is made from it:
`.qc.report r` returns the lines, and `.j.j r` is JSON.

Inside another test framework, `.qc.must[g;prop]` returns the result when the property passes and otherwise
signals the whole report as one error (`'qc: FAIL falsified after 3 tests…`), whose first line is the verdict.
It is meant for a framework whose tests fail by signalling; it has not been tried inside k4unit, qspec or QUnit.
`.qc.main d` runs a suite and exits with the number of failures, for CI.

A check sets the seed of the process (`\S`), and the state it had before cannot be put back. If your process
depends on its own stream of random numbers, set `\S` again after a check.

## State machines

A property tests a function: one input, one answer. A system that keeps state — a table that `upd` appends to, a
cache, a process on the other end of a handle — has no single input. What it answers depends on the calls it has
already had, and its bugs live in particular sequences of them: the `pop` after the third `push`. A state-machine
test draws *sequences of calls*, makes them on the real system, and checks every answer against a **model**.

The model is a plain q value that holds what the system ought to contain, in the simplest form that can answer
the questions asked of it: a list for a stack kept in a table, a dict for a keyed table, a row count for a
tickerplant's log. One-line functions update it, so it is easy to believe; the real system is the thing in doubt.

Each call the test may make is a *command*, a row of a keyed table whose columns are functions:

| column | arguments | what it answers |
|---|---|---|
| `pre` | model | can this command run now? (no `pop` from an empty stack) |
| `gen` | model | the generator its input is drawn from; it returns `::` when the command takes none |
| `run` | input | the output of the real system, called with that input |
| `post` | model before, input, output | is the output what the model predicts? |
| `upd` | model before, input, output | the model after the call |

```q
S:([]v:`long$())                                            / the real system: a stack in a table
push:{`S insert enlist x;}
pop:{r:last S`v; delete from `S where i=count[S]-1; r}
cmds:([cmd:`push`pop]
  pre: ({1b};             {0<count x});                     / model -> can this command run?
  gen: ({.qc.int 0 9};    {::});                            / model -> the generator of its input
  run: (push;             pop);                             / input -> output, on the real system
  post:({[m;i;o] 1b};     {[m;i;o] o=last m});              / model before, input, output -> ok?
  upd: ({[m;i;o] m,i};    {[m;i;o] -1_m}))                  / model before, input, output -> model after
.qc.check[.qc.sm[`m0`init!(`long$();{S::0#S})] cmds; ::]
```

`.qc.sm[h] cmds` is a generator like any other, and drawing an example from it runs one sequence. `init` resets the
real system and the model starts as `m0`; then, step by step, a command is chosen among those whose `pre` holds,
its input is drawn from `gen`, `run` makes the call, `post` checks the output and `upd` moves the model on. The
example is the *trace*, a table with a row for each step. The postconditions are the test, which is why the
property given to `check` is `::` — there is nothing left to assert.

This stack is right, and the check prints `ok 100 tests`. Break `pop`, so that it returns the first item once
three are stacked, and the same commands find it (`examples/sm_table.q` is this as a script):

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
rerun: .qc.again[]  or  .qc.recheck[gen;prop;1 0 0 1 0 0 1 0 1 1 1]
```

`qc.post` says a postcondition was false. Each row of the trace is one step: the command, the input drawn for it
(`arg`), what the real system returned (`res`), the model after the step, and whether `post` held (`ok`). The last
row is the disagreement: the model held `0 0 1`, so `pop` should have returned 1, and the system returned 0.

A sequence shrinks as a list does — steps are deleted and inputs lowered for as long as the failure remains — so
every row still there is needed. There are three pushes because the bug needs three items, and the last of them
pushes a 1 because a 0 popped from `0 0 0` would have looked right.

### Writing one

- **Keep the model simpler than the system.** A model that is a second implementation has the same bugs. It
  can leave out whatever is not being tested: storage, attributes, the order of rows.
- **`pre` and `gen` work from the model**, not from the real system. Where an input must be valid, `gen` draws a
  valid one (`{.qc.int 0,x`balance}` for a withdrawal) instead of drawing anything and filtering.
- **`post` checks one answer; an invariant checks the system.** `h` may carry an `inv`, a function of the model
  that is checked after every step, which is where "the table has as many rows as the model has counted" goes:
  `` `m0`init`inv!(0; {TBL::0#TBL}; {[m] m=count TBL}) ``. A false one reports `qc.inv` with the trace.
- **`init` must reset everything.** It runs before every example, every shrink attempt and every replay, and a
  failure that depends on state left over from an earlier sequence cannot be replayed. A system in another
  process is reset over its handle (`examples/sm_ipc.q`).
- **Start with two commands** and add the rest once those pass. The table needs only the columns that some
  command uses, and a column left out is the default for every command: `pre` always, `gen` no input, `run` no
  call, `post` true, `upd` the model unchanged. A `w` column weights the choice, so that a `clear` can be rare.

`COOKBOOK.md` has a tickerplant handler tested this way, and `WALKTHROUGH.md` a machine over a whole pipeline.

## Where to go next

| read | for |
|---|---|
| `EXAMPLES.md` | a tour of the library a piece at a time, from drawing one value to testing a system in another process |
| `COOKBOOK.md` | recipes for kdb+ tasks: an as-of join, an upsert, a splayed table, a tickerplant handler, serialisation, bars, a sorted vector; most find a planted bug and then show the fix |
| `WALKTHROUGH.md` | the long example: a market data pipeline built in five pieces and tested as it was written, wrong turns included, with a state machine over the whole |
| `REFERENCE.md` | every public name and every setting, a line each |
| `examples/` | the scripts that the tour and the cookbook talk through, to run and to change; `examples/mdp/` is the pipeline |

Every session shown with a `q)` prompt, in this file and in those, is run by the test suite, which requires the
output shown. The sessions start with ``.qc.cfg[`db`seed]:(`;7i)``, and with that set yours will print the same.

## Working on qcheck

`q t/run.q`, from the repository root, runs the tests and prints one table. It takes about two and a half
minutes, and `QC_FAST=1 q t/run.q` skips the slowest sessions. It needs `q` on the PATH, because the sessions in
the documents and the scripts in `examples/` are run in q processes of their own.

`docs/` has the design of the library and the record of how it was built.
