# qcheck — every public name

One line each. A *generator* is anything `.qc.draw` can draw from: one of the functions below with its
arguments given, a function of your own that draws, a list or a dict of generators, or a constant. In the forms
below `g` is a generator and `gs` a list of them. A range `r` is `lo hi`, or `lo hi origin`, where the origin is
the value that shrinking heads for. The long and short forms of a name differ in that the short one takes a
range or a setting first (`list` and `lst`, `check` and `chk`).

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
| `const` | `.qc.const x` | the value `x` (for a value that would otherwise be taken for a generator, such as a list of functions) |
| `elem` | `.qc.elem xs` | an element of the constant list `xs` |
| `one`, `freq` | `.qc.one gs`, `.qc.freq[w] gs` | one of the alternative generators `gs`, the first simplest; weighted by `w` |
| `such` | `.qc.such[p] g` | `g` filtered by `p`, with bounded retries, then a discard |
| `spc` | `.qc.spc[specials] g` | `g`, or one of `specials` (nulls, infinities, bounds) some of the time |
| `small`, `sized` | `.qc.small g`, `.qc.sized f` | `g` at half the size budget; `f` of the size, returning a generator |
| `list`, `lst` | `.qc.list g`, `.qc.lst[r] g` | a list of `g`, length in `r` (default `0 0W`, capped by size); homogeneous atoms become a vector |
| `vec` | `.qc.vec[r] c` | a typed vector of `.qc.t c`, typed even when empty |
| `tab`, `tabr`, `ktab` | `.qc.tab cols`, `.qc.tabr[r] cols`, `.qc.ktab[k;r] cols` | a table from a dict of column generators, row count in `r`, keyed on `k`; typed even when empty |
| `mono`, `uniq`, `dep` | `.qc.mono[base;delta]`, `.qc.uniq g`, `.qc.dep f` | column constraints `tab` recognises: non-decreasing from `base` by `delta`; distinct; `f` of the row so far |
| `atr` | `.qc.atr[a] g` | the value with attribute `a` (`s`, `u`, `p`, `g`), sorted first where the attribute needs it |
| `schema` | `.qc.schema t` | a generator read from a sample table: types, enumerations, attributes, keys, typed empties |
| `bulk`, `btab` | `.qc.bulk[r;nr]`, `.qc.btab[nr] cols` | a long vector or a table of a length in `nr`, drawn as blocks: a million values in milliseconds |
| `rec`, `recb` | `.qc.rec[k;leaf;node]`, `.qc.recb[k;leaf;node]` | a recursive structure: `k` children per node, `leaf` a generator, `node` a function of the children; `recb` splits the budget uniformly |
| `val` | `.qc.val` | an arbitrary q value: atoms of every type, lists, dicts, tables, keyed tables |
| `sm` | `.qc.sm[h] cmds` | a state-machine run over the command table `cmds` (`cmd pre gen run post upd w`) with hooks `h` (`m0 init fini steps inv`); yields the trace |
| `lin` | `.qc.lin[lo;hi]` | not a generator: a range that widens with size, for `int`, `lst` and the others that take one |

## Running properties

| name | form | does |
|---|---|---|
| `check`, `chk` | `.qc.check[g;prop]`, `.qc.chk[cfg;g;prop]` | run `prop` over draws of `g`, shrink a failure, print and return the result dict; `cfg` a dict of settings or a test count |
| `checks`, `chks` | `.qc.checks d`, `.qc.chks[cfg;d]` | a suite: `d` is name → `(g;prop)`; one table |
| `must`, `mustc` | `.qc.must[g;prop]`, `.qc.mustc[cfg;g;prop]` | `check` that signals on failure, for another framework's assertion |
| `main` | `.qc.main d` | `checks d`, then exit with the number of failures: a CI script |
| `draw`, `minimal` | `.qc.draw g`, `.qc.minimal g` | one value of a generator; its simplest value |
| `replay`, `strict` | `.qc.replay[choices;g]`, `.qc.strict[choices;g]` | the value a recorded choice vector produces; the same, refusing to draw past it |
| `recheck`, `again` | `.qc.recheck[g;prop;choices]`, `.qc.again[]` | run the property on recorded choices; rerun the last failure |
| `report`, `rerun` | `.qc.report r`, `.qc.rerun choices` | the report lines of a result; the rerun line |
| `cfg`, `new` | `.qc.cfg`, `.qc.new[]` | the dict of [settings](#settings); fresh interactive state |
| `lf` | `.qc.lf` | the last failure: its generator, property and choices, under the keys `spec`, `prop` and `choices` |

## Inside a property

| name | form | does |
|---|---|---|
| `eq` | `.qc.eq[a;b]` | `a~b`, explained: on failure the diff table (`path why a b`) is noted and the property fails with `qc.eq` |
| `label`, `classify`, `collect` | `.qc.label s`, `.qc.classify[s;b]`, `.qc.collect x` | count this example under `s`; under `s` when `b`; under its value |
| `cover` | `.qc.cover[s;pct;b]` | require `s` in at least `pct`% of examples; the run extends until it can tell, and fails if not |
| `discard` | `.qc.discard[]` | this example does not count |
| `draw` | `.qc.draw g` | a draw inside the property: it shrinks with everything else |

## Settings

`.qc.cfg` holds the defaults. `.qc.chk`, `.qc.chks` and `.qc.mustc` take a dict of any of them for one run.

| setting | default | what it sets |
|---|---|---|
| `n` | 100 | the number of tests |
| `nmax` | `0N`, for 10 times `n` | the most tests a run may take when a `cover` requirement keeps it going |
| `seed` | `0N`, for one taken from the clock | the seed of the run, an int |
| `sz` | 100 | the size that examples grow to over a run; lists, tables and recursive structures are capped by it |
| `shrinks` | 2000 | the most attempts the shrinker may make; 0 turns shrinking off |
| `disc` | 10 | how many discards for each test before the run gives up |
| `tries` | 50 | how many times `such` and `uniq` draw again before they discard the example |
| `depth` | 200 | how deeply generators may nest before an example is discarded as too deep |
| `choices` | 8192 | how many draws an example may make before it is discarded as too large |
| `same` | `1b` | a shrunk example must fail with the same message as the example it came from |
| `clamp` | `1b` | a replayed choice that is out of range is moved into range; `0b` refuses it |
| `db` | `` `:.qc `` | the directory of the failure database; the null symbol for none |
| `name` | `` ` `` | the name a failure is saved under; null for a hash of the generator and the property |
| `rows` | 20 | how many rows of a table a report shows |
| `v` | 1 | 0 prints nothing, 1 the report, 2 adds the backtrace of an error |

## Results and signals

The result of a check is a dict:

| key | holds |
|---|---|
| `ok` | `1b` when the property passed |
| `why` | `ok`, `falsified`, `error` (a generator signalled), `gaveup` (too many discards) or `cover` (a requirement not met) |
| `stop` | why the run ended: `n`, `exhausted`, `cover`, `nmax`, `fail` or `gaveup` |
| `n` | the number of tests that passed |
| `shrinks`, `attempts` | how many times the counterexample was made simpler, and how many candidates were tried |
| `seed` | the seed of the run |
| `x` | the counterexample, keyed by the names of the inputs; `::` when there is none |
| `err`, `bt` | the message of the failure, and the backtrace of an error |
| `notes` | what `.qc.note` and `.qc.eq` added |
| `cover` | the table of labels |
| `choices` | the choices that reproduce the counterexample |
| `hist` | the shrinks, in order |
| `disc` | the discards, counted by cause |
| `stale` | from `recheck`: `1b` when the choices given no longer fit the generator, which has changed since they were recorded |

Signals beginning
`qc.eq`, `qc.post`, `qc.run`, `qc.inv` are falsifications wherever raised; `qc.discard` is a discard;
`qc.toodeep`, `qc.toolarge`, `qc.overrun` are budget stops. Every usage error begins `qc: ` and says what was wrong.
