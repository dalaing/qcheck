# The steps

One file per logged code change, the whole piece as it stood at that step. Buggy versions stay: the sessions of
`LOG.md` load them by name, and `t/doctest.q` requires each to still fail as shown.

- The number is a clock across the whole development, not a count per piece: a piece skips numbers while another
  is being written, and entry 12, the whole-system test, fixes three pieces in turn (`pos` is 13, 22, 23, 25, 27;
  `orders` is 8 and 28; `eod` is 17 to 20 and 29; the whole-system test is 21, 24, 26, 30). Thirty-four files,
  thirty numbers: a step that changed the generators too has an `NN_gen.q` beside it.
- `NN_gen.q` is what that step *added* to the generators; `props.q` loads all four (01, 05, 08, 13).
- A step's header says what changed and why. The first file of a piece describes the piece; later files point to it.
- The final system, loaded by `../oms.q`: `04_ref.q`, `07_quotes.q`, `28_orders.q`, `27_pos.q` (which wraps
  `onfill`), `16_ca.q`, `29_eod.q`. The pieces' own stateful tests are `06_sm.q` (the quote cache) and `12_sm.q`
  (the order lifecycle), loaded by `../props.q`; the whole-system test is `30_sm.q`, loaded by `../sm.q`.
- The `eod` steps (17 and later) and the whole-system test need `.oms.hdb` set to an empty directory of their own
  before they load, and its first close makes that directory the working directory.
