/ mdp piece 5: end of day. step 13: a query answered from disk comes back in memory's shape — the date column dropped, the
/ symbols un-enumerated (a splayed sym column reads back as an enumeration, type 20).
/ (the piece is described at the top of 11_eod.q)
.mdp.trade:([]seq:`long$(); time:`timestamp$(); sym:`symbol$(); px:`float$(); qty:`long$(); bid:`float$(); ask:`float$())
.mdp.ontrade:{[t] e:.mdp.enrich1 t; .mdp.trade,:e; .mdp.onbar e; e}
.mdp.today:2024.01.02
.mdp.hdb:`
.mdp.save1:{[d;n;t] (` sv .mdp.hdb,(`$string d),n,`) set @[.Q.en[.mdp.hdb] `sym xasc 0!t;`sym;`p#]}
.mdp.eod:{[d] .mdp.save1[d]'[`trade`quote`bar;(.mdp.trade;.mdp.quote;.mdp.bar)]; .mdp.trade:0#.mdp.trade; .mdp.quote:0#.mdp.quote; .mdp.bar:0#.mdp.bar;
  system"l ",1_string .mdp.hdb; .mdp.today:d+1}
.mdp.dq:{[t] update sym:value sym from delete date from t}
.mdp.qbars:{[d;s;a;b] `minute xasc $[d<.mdp.today; .mdp.dq select from bar where date=d, sym=s, minute within (a;b); 0!select from .mdp.bar where sym=s, minute within (a;b)]}
.mdp.qvwap:{[d;s] $[d<.mdp.today; first exec v from select v:qty wavg px from trade where date=d, sym=s; exec qty wavg px from .mdp.trade where sym=s]}
.mdp.qtrades:{[d;s] `seq xasc $[d<.mdp.today; .mdp.dq select from trade where date=d, sym=s; select from .mdp.trade where sym=s]}
