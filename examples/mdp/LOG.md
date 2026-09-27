# Building a market data pipeline with qcheck — the log

A worked example, kept as it happened. Five pieces — reference data, quotes, bars, positions, end of day — are
written one at a time, each with properties as it is written, then assembled and driven by a state machine. Every
code change is a file under `steps/`, so every transcript below still runs: `t/doctest.q` executes each `q)` block
in a fresh q from the repository root (seed 7, `\c 25 80`) and requires the output shown. Nothing here is planted;
a bug appears in the log when it appeared in the work.

## Piece 1 — reference data

### Entry 1: instruments, tick rounding, lots

An instrument table keyed by symbol (tick size, lot size, contract multiplier) and two helpers: round a price to
the instrument's tick, round a quantity down to whole lots. The generator draws a small instrument table (keys
distinct through `ktab`), then a symbol from it and a price; it sets the piece's table as a side effect, which is
how the piece will be used.

The first properties: rounding is idempotent, and it never moves a price by more than half a tick.

```q
q)system"l examples/mdp/steps/01_ref.q"
q)system"l examples/mdp/steps/01_gen.q"
q).qc.draw .mdp.g.inst
sym| tick lot mult
---| -------------
ACC| 0.05 100 50  
ABC| 0.05 1   10  
AB | 1    1   10  
B  | 0.05 1   1   
q).qc.check[.mdp.g.ref; {[s;px] r:.mdp.round[s;px]; r=.mdp.round[s;r]}];
FAIL falsified after 0 tests, 0 shrinks (12 attempts, seed 7)
x: (`A;0f)
qc: property returned {[s;px] r:.mdp.round[s;px]; r=.mdp.round[s;r]}[(`A;0f)]
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 1 0 0 0 0 0 0 0 0 0 0]
q).qc.check[.mdp.g.ref; {[s;px] .5>=abs[px-.mdp.round[s;px]]%.mdp.inst[s;`tick]}];
FAIL falsified after 0 tests, 0 shrinks (12 attempts, seed 7)
x: (`A;0f)
qc: property returned {[s;px] .5>=abs[px-.mdp.round[s;px]]%.mdp.inst[s;`tick]}[(`A;0f)]
rerun: .qc.again[]  or  .qc.recheck[spec;prop;1 1 0 0 0 0 0 0 0 0 0 0]
q).qc.check[(.mdp.g.ref; .qc.int 0 1000); {[sp;q] l:.mdp.lots[sp 0;q]; (l<=q) and 0=l mod .mdp.inst[sp 0;`lot]}];
ok 100 tests (seed 7)
```

Not a bug in the piece: a mistake in how I wrote the properties. The spec `g.ref` is a lambda that *returns* a
pair, so the property receives the pair as one argument (`prop @ x`), and a two-parameter property applied to one
argument is a projection — which is what "property returned {…}[(`A;0f)]" is telling me, on the minimal input.
A general-list spec (`(g.ref; .qc.int 0 1000)`) is applied with `.`, which is why the third check worked. The
report is exact about it; I just had to read it.

### Entry 2: the same properties, taking one argument

```q
q)system"l examples/mdp/steps/01_ref.q"
q)system"l examples/mdp/steps/01_gen.q"
q).qc.check[.mdp.g.ref; {s:x 0; px:x 1; r:.mdp.round[s;px]; r=.mdp.round[s;r]}];
ok 100 tests (seed 7)
q).qc.check[.mdp.g.ref; {s:x 0; px:x 1; .5>=abs[px-.mdp.round[s;px]]%.mdp.inst[s;`tick]}];
ok 100 tests (seed 7)
q).qc.check[(.mdp.g.ref; .qc.int 0 1000); {[sp;q] l:.mdp.lots[sp 0;q]; (l<=q) and 0=l mod .mdp.inst[sp 0;`lot]}];
ok 100 tests (seed 7)
```

Rounding and lots hold. The idempotence comparison is `=` on floats, which is tolerant (pitfall 23); a tick
multiple computed twice can differ in the last bit, so tolerant is what I mean here.

### Entry 3: renames, and a generator that found a hang

A rename table (`old`, `new`, effective date) and `canon[s;d]`: the name `s` goes by on date `d`, following
renames in effect. Step 01's `canon` is a `while` loop: as long as a rename from the current name is in effect,
take it.

Writing the generator is where the thinking happened. Renames come from the instrument table; the new name is
either a fresh symbol or *another instrument* — because that is what happens: a name is retired, reused, or a
rename is reverted. That last case, `A→B` then `B→A`, is a cycle, and a `while` that follows renames until none
applies never stops. I did not notice this in the code; I noticed it when the generator was about to produce it.

I ran the idempotence property against step 01 anyway, to see. It hung. There is no transcript of that: a hung
run is the one outcome a property-based test cannot report — qcheck has no per-example timeout (q cannot
interrupt an example from inside) — so the evidence is the absence of output and a process killed by hand. That
is worth knowing about the tool as much as about the code.

Step 02 makes `canon` total: it follows the *latest* effective rename (two renames from one name on different
dates were also possible, and step 01 took whichever row came first) and stops when a name repeats, so a
reversion resolves to the name that is current.

```q
q)system"l examples/mdp/steps/02_ref.q"
q)system"l examples/mdp/steps/02_gen.q"
q).mdp.ren:([]old:`A`B; new:`B`A; eff:2024.01.01 2024.02.01)
q).mdp.canon[`A;2024.03.01]
`A
q).qc.check[.mdp.g.ren; {s:x 0; d:x 1; c:.mdp.canon[s;d]; c=.mdp.canon[c;d]}];
ok 100 tests (seed 7)
q).qc.check[.mdp.g.ren; {s:x 0; d:x 1; (.mdp.canon[s;d]=s) or .mdp.canon[s;d] in exec new from .mdp.ren where eff<=d}];
ok 100 tests (seed 7)
```

Two properties: `canon` is idempotent, and it returns either the name itself or a name some effective rename
maps to. Both pass. Piece 1 tally: one bug (the cycle), found by writing the generator rather than by running it.
