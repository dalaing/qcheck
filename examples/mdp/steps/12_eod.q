/ mdp piece 5: end of day. step 12: the vwap over the HDB is a select (exec over a partitioned table is nyi). Needs pieces 2 and 3 loaded (06_quotes.q, 07_bars.q).
/ The day's enriched trades are kept; at the close the day's trades, quotes and bars are written to a date partition
/ of the HDB (sorted by sym, `p#, enumerated), the day tables are cleared, the HDB is remapped and the day advances.
/ The queries answer for any date: today's from memory, an earlier day's from disk, in one shape.
/ Written in the root namespace, naming .mdp.* in full, because the HDB's tables (trade, quote, bar) live in the root.
.mdp.trade:([]seq:`long$(); time:`timestamp$(); sym:`symbol$(); px:`float$(); qty:`long$(); bid:`float$(); ask:`float$())
.mdp.ontrade:{[t] e:.mdp.enrich1 t; .mdp.trade,:e; .mdp.onbar e; e}
.mdp.today:2024.01.02
.mdp.hdb:`
.mdp.save1:{[d;n;t] (` sv .mdp.hdb,(`$string d),n,`) set @[.Q.en[.mdp.hdb] `sym xasc 0!t;`sym;`p#]}
.mdp.eod:{[d] .mdp.save1[d]'[`trade`quote`bar;(.mdp.trade;.mdp.quote;.mdp.bar)]; .mdp.trade:0#.mdp.trade; .mdp.quote:0#.mdp.quote; .mdp.bar:0#.mdp.bar;
  system"l ",1_string .mdp.hdb; .mdp.today:d+1}
.mdp.qbars:{[d;s;a;b] `minute xasc $[d<.mdp.today; delete date from select from bar where date=d, sym=s, minute within (a;b); 0!select from .mdp.bar where sym=s, minute within (a;b)]}
.mdp.qvwap:{[d;s] $[d<.mdp.today; first exec v from select v:qty wavg px from trade where date=d, sym=s; exec qty wavg px from .mdp.trade where sym=s]}
.mdp.qtrades:{[d;s] `seq xasc $[d<.mdp.today; delete date from select from trade where date=d, sym=s; select from .mdp.trade where sym=s]}
