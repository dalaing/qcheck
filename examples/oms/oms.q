/ examples/oms/oms.q — the execution and positions system as it stands at the end of LOG.md: the last step of each
/ piece. Load from the repository root, as run.q and the tests do. The database root is .oms.hdb: a fresh temporary
/ directory unless set before loading. The pieces: reference data and FX (rate, tobase), quotes and the mid as of a
/ time, orders and fills against a transition table, positions and PnL in the base currency, corporate actions (a
/ split), end of day to a partitioned database with the day's slippage.
if[not `qc in key `; system"l qc.q"]
/ .oms.root is where this directory is, absolute: set it before loading from anywhere but the repository root. It is
/ absolute because the first close makes the database the working directory, for good (the mapped tables need it so).
if[not `root in key `.oms; .oms.root:"examples/oms"]
if[not "/"=first .oms.root; .oms.root:(system"cd"),"/",.oms.root]
if[not `hdb in key `.oms; .oms.hdb:hsym `$first system"mktemp -d"]
/ The later steps replace the earlier whole: each file is its piece as it stood, so the system is one file per piece,
/ in the order the pieces depend on each other. steps/README.md lists them. (27_pos.q wraps onfill of 28_orders.q.)
{system"l ",.oms.root,"/steps/",x} each ("04_ref.q";"07_quotes.q";"28_orders.q";"27_pos.q";"16_ca.q";"29_eod.q");
