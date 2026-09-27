# qcheck

Property-based testing for q/kdb+, with integrated shrinking in the style of Hypothesis, failure reports in
the style of Hedgehog, and state-machine testing. One file, no dependencies; validated on kdb+ 5.0 (it uses
`binr`, `.Q.trp`, `.Q.sbt` and `'[;]` composition, so 3.5 or later should work, unverified).

```q
q)\l qc.q
q).qc.check[.qc.list .qc.int 0 100; {x~asc x}];
FAIL falsified after 5 tests, 8 shrinks (36 attempts, seed 7)
x: 1 0
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 1 1 0 0]
```

## Generators

A generator is a function you call with `[]`; the library's take their configuration first, so supplying it
gives a projection, and the projection is the generator. Any q data structure of generators is a generator:
a general list draws a tuple, a dict draws a record, anything else is a constant.

```q
.qc.int -100 100                       / a long; shrinks toward 0
.qc.int 1 1000 1                       / lo hi origin: shrinks toward 1
.qc.int {0,x}                          / a range may be a function of size (0..100 over the run)
.qc.list .qc.int 0 9                   / a list; .qc.lst[3 5] g for a length range
(.qc.int 0 9; .qc.sym)                 / a pair
`name`age!(.qc.sym; .qc.int 0 120)     / a record: named inputs in the report
'[neg; .qc.int 0 9]                    / map is composition
{n:.qc.draw .qc.int 1 9; .qc.draw .qc.lst[n,n] .qc.sym}   / bind is a lambda
.qc.one (.qc.int 0 9; .qc.sym)         / alternatives; .qc.freq[3 1] gs weights them
.qc.such[{x>0}] .qc.int -9 9           / a filter (bounded retries, then a discard)
.qc.t"j"                               / any atom type's full domain, nulls and infinities included
.qc.t"jf"                              / a pair of them; .qc.tf"j" the finite domain, no null or infinity
.qc.ts[2024.01.02D09:30;2024.01.02D16:00] / a timestamp in a session; .qc.dates[from;to] a date
.qc.val                                 / any q value at all: atoms, lists, dicts, tables (for serialisation round trips)
.qc.flt 0 1                            / a float in a range; .qc.dbl is any finite double
.qc.str                                / a string; .qc.sym a symbol over a bounded alphabet
.qc.vec[0 5]"d"                        / a typed vector, here of dates
.qc.tab `a`b!(.qc.int 0 9; .qc.sym)    / a table; .qc.ktab[`a;0 9] cols keyed (keys distinct)
.qc.tab `t`k`v!(.qc.mono[.qc.int 0 9;.qc.int 1 9]; .qc.uniq .qc.elem `a`b`c; .qc.dep {[r] .qc.int (r`t;99)})   / a sorted column, distinct keys, a column that sees the row
.qc.schema ([]time:`s#09:30 09:31; sym:`a`b; px:1.5 2.5)   / tables shaped like a sample: types, keys, attributes, enumerations
.qc.atr[`s] .qc.list .qc.int 0 9         / a sorted vector carrying s#
.qc.bulk[0 99;0 1000000]                 / a long vector of up to a million values in one block; .qc.btab[nr] cols a table of them
.qc.rec[2 2; .qc.int 0 9; {(x 0;x 1)}] / a binary tree: arity range, leaf, node of its children (values)
```

Draw one interactively with `.qc.draw g`, the simplest value with `.qc.minimal g` (a filtered generator whose
simplest value fails its filter discards), and see what a recorded choice vector produces with
`.qc.replay[choices] g`. After any draw, `.qc.C` holds the choices it made.

## Properties

```q
spec:.qc.int 0 9; prop:{x<10}
.qc.check[spec; prop]                  / a list spec applies prop . x; a dict spec by parameter name; else prop @ x
.qc.check[(.qc.int 0 9; .qc.int 0 9); {x>=y}]
.qc.check[`xs`n!(.qc.list .qc.int 0 9; .qc.int 0 5); {[n;xs] n<=count xs}]
.qc.check[::; {n:.qc.draw .qc.int 1 9; n>0}]       / draw inside the property; it shrinks with everything
.qc.chk[`n`seed!(1000;42i); spec; prop]            / configuration first; .qc.cfg holds the defaults
.qc.checks `comm`sorted!((( .qc.int 0 9;.qc.int 0 9);{(x+y)=y+x}); (.qc.list .qc.int 0 9;{x~asc x}))
```

A run stops when it has learned what it can: `ok 2 tests, exhausted` means every input the spec can produce
was tried (a small space is enumerated by walking the tree of choices made so far, simplest first, so
alternatives, short lists and small state machines count too); otherwise it samples `n` inputs, and keeps going
only to settle an open coverage question. A property passes if it returns `::` or all of a boolean result; any
signal fails it. Inside a property:
`.qc.eq[a;b]` explains a mismatch as a diff table, `.qc.note x` attaches a value to the report,
`.qc.classify[`big;x>5]`, `.qc.collect x` (by value: one symbol per distinct value, so keep the space small) and
`.qc.cover[`big;90;x>5]` build the coverage table, and `cover`
fails the run only when it is confident the rate is under the requirement.

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

The result is a dict (`ok why n shrinks attempts seed x err bt notes cover choices hist disc stale`); the
report is data too (`.qc.report r` returns the lines), and `.j.j r` is JSON. Failures are saved under `.qc/`
and replayed first next time; `.qc.again[]` rechecks the last failure.

Inside another test framework, `.qc.must[spec;prop]` returns the result on success and signals the whole report
otherwise (`'qc: FAIL falsified after 3 tests…`), so k4unit, qspec or a `.Q.trp` script sees one error whose
first line is the verdict. `.qc.main d` runs a suite dict and exits with the number of failures, for CI; the
table `.qc.checks` returns carries an `ms` column. A check reseeds the process RNG (`\S`): pin `.qc.cfg[`seed]`
if your process depends on its own `rand` stream.

## State machines

```q
S:([]v:`long$())                                            / the real system: a stack in a table
push:{`S insert enlist x;}
pop:{r:last S`v; delete from `S where i=count[S]-1; r}
cmds:([cmd:`push`pop]
  pre: ({1b};             {0<count x});                     / model -> can this command run?
  gen: ({.qc.int 0 9};    {::});                            / model -> input spec
  run: (push;             pop);                             / input -> output, on the real system
  post:({[m;i;o] 1b};     {[m;i;o] o=last m});              / model before, input, output -> ok?
  upd: ({[m;i;o] m,i};    {[m;i;o] -1_m}))                  / model before, input, output -> model after
.qc.check[.qc.sm[`m0`init!(`long$();{S::0#S})] cmds; ::]
```

`.qc.sm[h] cmds` draws and executes a command sequence and yields the trace; `h` may carry an `inv` (an invariant
of the model, checked after every step) and `cmds` a `w` column of weights; a failed postcondition prints the
trace with the failing step marked and the sequence shrinks like any other input. `init` resets the real
system before every example and every replay, so the system can live in another process (`examples/sm_ipc.q`).

Every transcript in this file and in `EXAMPLES.md` is executed by the test suite (in a session with
`.qc.cfg[`seed]:7i`) and must print exactly what is shown.

See `EXAMPLES.md` for a tour in verified transcripts, and `COOKBOOK.md` for recipes: an as-of join, upsert on
keyed tables, a splayed table read back, a tickerplant handler as a state machine, serialisation over any value,
per-minute bars — each with a planted bug found and shrunk.

`examples/mdp/LOG.md` is the long form: a market data pipeline built in five pieces, each with its properties as
it was written, then a state machine over the whole with a full-replay oracle — developed honestly and logged as
it went, the bugs being whatever surfaced (twelve findings, one of them only visible where renames, positions and
the day boundary meet). Every transcript, including the buggy steps, is executed by the suite.

## Files

```
qc.q          the library            examples/   reverse.q tree.q sm_table.q sm_ipc.q aj.q
COOKBOOK.md   recipes for kdb tasks    examples/mdp/  a pipeline built in pieces; its log LOG.md; q examples/mdp/run.q
DESIGN.md     design, conventions,   t/          q t/run.q runs the tests and prints one table
              measurements, pitfalls spikes/     sh spikes/run.sh re-runs the design's measurements
```
