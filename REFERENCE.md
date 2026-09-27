# qcheck — every public name

One line each. Ranges `r` are `lo hi` or `lo hi origin` (shrinking heads for the origin); a *spec* is anything
`.qc.draw` interprets: a generator, a list or dict of specs, or a constant. Long and short forms of a name differ
by taking a range or a configuration first (`list`/`lst`, `check`/`chk`). `t/docs.q` checks this table against
`qc.q` both ways: every name here exists, and every documented generator is here.

## Generators

| name | form | draws |
|---|---|---|
| `int` | `.qc.int r` | a long in `r`; no null, no infinity |
| `bool`, `bit` | `.qc.bool`, `.qc.bit p` | a boolean; `bit p` is `1b` with probability `p` on fresh draws, origin `0b` |
| `flt` | `.qc.flt r` | a float in `[lo;hi]`: integers before halves before quarters, 0 (or the nearest bound) simplest |
| `dbl`, `dble` | `.qc.dbl`, `.qc.dble` | any finite double; `dble` over single-precision exponents and mantissas (a float32 column's values) |
| `chr`, `chrc` | `.qc.chr`, `.qc.chrc s` | a char from `.qc.AZ` (letters, digits, space), or from alphabet `s` |
| `str`, `strc` | `.qc.str`, `.qc.strc[s;r]` | a string, typed even when empty; alphabet `s`, length range `r` |
| `sym`, `symc` | `.qc.sym`, `.qc.symc[s;r]` | a symbol over a bounded alphabet (default `"abcd"`, lengths 0–3); the null symbol simplest |
| `gid`, `gidf` | `.qc.gid`, `.qc.gidf` | a guid; `gidf` is never null |
| `t`, `tf` | `.qc.t c`, `.qc.tf c` | an atom of type char `c`: `t` over the full domain (nulls and infinities), `tf` over the finite one |
| `ts`, `dates` | `.qc.ts[from;to]`, `.qc.dates[from;to]` | a timestamp or a date in a window, the start simplest |
| `const` | `.qc.const x` | the value `x` (the escape hatch when a value looks like a spec) |
| `elem` | `.qc.elem xs` | an element of the constant list `xs` |
| `one`, `freq` | `.qc.one gs`, `.qc.freq[w] gs` | one of the alternative specs `gs`, the first simplest; weighted by `w` |
| `such` | `.qc.such[p] g` | `g` filtered by `p`, with bounded retries, then a discard |
| `spc` | `.qc.spc[specials] g` | `g`, or one of `specials` (nulls, infinities, bounds) some of the time |
| `small`, `sized` | `.qc.small g`, `.qc.sized f` | `g` at half the size budget; `f` of the size, returning a spec |
| `list`, `lst` | `.qc.list g`, `.qc.lst[r] g` | a list of `g`, length in `r` (default `0 0W`, capped by size); homogeneous atoms become a vector |
| `vec` | `.qc.vec[r] c` | a typed vector of `.qc.t c`, typed even when empty |
| `tab`, `tabr`, `ktab` | `.qc.tab cols`, `.qc.tabr[r] cols`, `.qc.ktab[k;r] cols` | a table from a dict of column specs, row count in `r`, keyed on `k`; typed even when empty |
| `mono`, `uniq`, `dep` | `.qc.mono[base;delta]`, `.qc.uniq g`, `.qc.dep f` | column constraints `tab` recognises: non-decreasing from `base` by `delta`; distinct; `f` of the row so far |
| `atr` | `.qc.atr[a] g` | the value with attribute `a` (`s`, `u`, `p`, `g`), sorted first where the attribute needs it |
| `schema` | `.qc.schema t` | a generator read from a sample table: types, enumerations, attributes, keys, typed empties |
| `bulk`, `btab` | `.qc.bulk[r;nr]`, `.qc.btab[nr] cols` | a long vector or a table of a length in `nr`, drawn as blocks: a million values in milliseconds |
| `rec`, `recb` | `.qc.rec[k;leaf;node]`, `.qc.recb[k;leaf;node]` | a recursive structure: `k` children per node, `leaf` a spec, `node` a function of the children; `recb` splits the budget uniformly |
| `val` | `.qc.val` | an arbitrary q value: atoms of every type, lists, dicts, tables, keyed tables |
| `sm` | `.qc.sm[h] cmds` | a state-machine run over the command table `cmds` (`cmd pre gen run post upd w`) with hooks `h` (`m0 init fini steps inv`); yields the trace |
| `lin` | `.qc.lin[lo;hi]` | not a generator: a range that widens with size, for `int`, `lst` and the others that take one |

## Running properties

| name | form | does |
|---|---|---|
| `check`, `chk` | `.qc.check[spec;prop]`, `.qc.chk[cfg;spec;prop]` | run `prop` over draws of `spec`, shrink a failure, print and return the result dict; `cfg` a dict of settings or a test count |
| `checks`, `chks` | `.qc.checks d`, `.qc.chks[cfg;d]` | a suite: `d` is name → `(spec;prop)`; one table |
| `must`, `mustc` | `.qc.must[spec;prop]`, `.qc.mustc[cfg;spec;prop]` | `check` that signals on failure, for another framework's assertion |
| `main` | `.qc.main d` | `checks d`, then exit with the number of failures: a CI script |
| `draw`, `minimal` | `.qc.draw spec`, `.qc.minimal spec` | one value of a spec; its simplest value |
| `replay`, `strict` | `.qc.replay[choices;spec]`, `.qc.strict[choices;spec]` | the value a recorded choice vector produces; the same, refusing to draw past it |
| `recheck`, `again` | `.qc.recheck[spec;prop;choices]`, `.qc.again[]` | run the property on recorded choices; rerun the last failure |
| `report`, `rerun` | `.qc.report r`, `.qc.rerun choices` | the report lines of a result; the rerun line |
| `cfg`, `new` | `.qc.cfg`, `.qc.new[]` | the settings dict (see DESIGN §1.4); fresh interactive state |
| `lf` | `.qc.lf` | the last failure's spec, property and choices |

## Inside a property

| name | form | does |
|---|---|---|
| `eq` | `.qc.eq[a;b]` | `a~b`, explained: on failure the diff table (`path why a b`) is noted and the property fails with `qc.eq` |
| `label`, `classify`, `collect` | `.qc.label s`, `.qc.classify[s;b]`, `.qc.collect x` | count this example under `s`; under `s` when `b`; under its value |
| `cover` | `.qc.cover[s;pct;b]` | require `s` in at least `pct`% of examples; the run extends until it can tell, and fails if not |
| `discard` | `.qc.discard[]` | this example does not count |
| `draw` | `.qc.draw spec` | a draw inside the property: it shrinks with everything else |

## Results and signals

The result dict: `ok why stop n shrinks attempts seed x err bt notes cover choices hist disc stale`. `why` is `ok`,
`falsified`, `error`, `gaveup` or `cover`; `stop` is `n`, `exhausted`, `cover`, `nmax` or `fail`. Signals beginning
`qc.eq`, `qc.post`, `qc.run`, `qc.inv` are falsifications wherever raised; `qc.discard` is a discard;
`qc.toodeep`, `qc.toolarge`, `qc.overrun` are budget stops. Every usage error begins `qc: ` and says what was wrong.
