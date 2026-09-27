/ examples/mdp/mdp.q — the market data pipeline as it stands at the end of LOG.md: the last step of each piece.
/ Load from the repo root, as run.q and the tests do. The HDB root is .mdp.hdb: a fresh temporary directory unless
/ set before loading. The pieces: reference data (round, lots, canon), quotes and enrichment, per-minute bars,
/ positions and PnL, end of day and queries; the assembly's upd and eod; corrections (bust, a late day); renames.
if[not `qc in key `; system"l qc.q"]
{system"l examples/mdp/steps/",x} each ("02_ref.q";"06_quotes.q";"07_bars.q";"10_pos.q";"13_eod.q";"16_upd.q";"17_amend.q";"22_rename.q");
if[`~.mdp.hdb; .mdp.hdb:hsym `$first system"mktemp -d"]
