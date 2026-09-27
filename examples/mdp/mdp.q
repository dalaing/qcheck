/ examples/mdp/mdp.q — the market data pipeline as it stands at the end of LOG.md: the last step of each piece.
/ Load from the repo root, as run.q and the tests do. The HDB root is .mdp.hdb: a fresh temporary directory unless
/ set before loading. The pieces: reference data (round, lots, canon), quotes and enrichment, per-minute bars,
/ positions and PnL, end of day and queries; the assembly's upd and eod; corrections (bust, a late day); renames.
if[not `qc in key `; system"l qc.q"]
/ .mdp.root is where this directory is, absolute: set it before loading from anywhere but the repository root. It is
/ absolute because the first close makes the HDB the working directory, for good (the mapped tables need it so).
if[not `root in key `.mdp; .mdp.root:"examples/mdp"]
if[not "/"=first .mdp.root; .mdp.root:(system"cd"),"/",.mdp.root]
/ The later steps patch the earlier: 16_upd.q defines upd; 17_amend.q redefines ontrade (a late day goes to its
/ partition) and adds amend, bust, rebar; 22_rename.q redefines upd (canonical names on the way in) and wraps eod
/ with roll. So the system is the last definition of each name, in load order — steps/README.md lists them.
{system"l ",.mdp.root,"/steps/",x} each ("02_ref.q";"06_quotes.q";"07_bars.q";"10_pos.q";"13_eod.q";"16_upd.q";"17_amend.q";"22_rename.q";"25_final.q");
if[`~.mdp.hdb; .mdp.hdb:hsym `$first system"mktemp -d"]
