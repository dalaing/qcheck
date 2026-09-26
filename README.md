# qcheck

Property-based testing for q/kdb+, with integrated shrinking in the style of Hypothesis, failure reports in
the style of Hedgehog, and state-machine testing. One file, no dependencies, kdb+ 4.0 or later.

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
.qc.t"jf"                              / a pair of them
.qc.flt 0 1                            / a float in a range; .qc.dbl is any finite double
.qc.str                                / a string; .qc.sym a symbol over a bounded alphabet
.qc.vec[0 5]"d"                        / a typed vector, here of dates
.qc.tab `a`b!(.qc.int 0 9; .qc.sym)    / a table; .qc.ktab[`a;0 9] cols keyed
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
`.qc.classify[`big;x>5]`, `.qc.collect x` and `.qc.cover[`big;90;x>5]` build the coverage table, and `cover`
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
report is data too (`.qc.report r` returns the lines). Failures are saved under `.qc/` and replayed first
next time; `.qc.again[]` rechecks the last failure.

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

`.qc.sm[h] cmds` draws and executes a command sequence and yields the trace; a failed postcondition prints the
trace with the failing step marked and the sequence shrinks like any other input. `init` resets the real
system before every example and every replay, so the system can live in another process (`examples/sm_ipc.q`).

Every transcript in this file and in `EXAMPLES.md` is executed by the test suite (in a session with
`.qc.cfg[`seed]:7i`) and must print exactly what is shown.

See `EXAMPLES.md` for a tour in verified transcripts.

## Files

```
qc.q          the library            examples/   reverse.q tree.q sm_table.q sm_ipc.q
DESIGN.md     design, conventions,   t/          q t/run.q runs the tests and prints one table
              measurements, pitfalls spikes/     sh spikes/run.sh re-runs the design's measurements
```
