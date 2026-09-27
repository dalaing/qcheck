# The steps

One file per logged code change, the whole piece as it stood at that step. Buggy versions stay: the sessions of
`LOG.md` and of `WALKTHROUGH.md` load them by name, and `t/doctest.q` requires each to still fail as shown.

- The number is a clock across the whole development, not a count per piece: a piece skips numbers while another
  piece is being written (`upd` is 14 then 16; the state machine is 15, 18, 19, 21, 23, 24). Thirty files, twenty-four
  numbers: a step that changed the generators too has an `NN_gen.q` beside it.
- `NN_gen.q` is the generators as they stood at that step; `08_gen.q` is the last and is what `props.q` loads.
- A step's header says what changed and why. The first file of a piece describes the piece; later files point to it.
- The final system, loaded by `../mdp.q`: `02_ref.q`, `06_quotes.q`, `07_bars.q`, `10_pos.q`, `13_eod.q`,
  `16_upd.q`, `17_amend.q`, `22_rename.q` (which redefines `upd` of 16 and wraps `eod` of 13), and `25_final.q`
  (the review's hardening: constants, validations, `.Q.pv`); the machine is `25_sm.q`, loaded by `../sm.q`
  (`24_sm.q` is the one the log's entry 24 runs).
