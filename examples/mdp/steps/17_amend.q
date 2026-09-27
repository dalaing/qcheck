/ mdp run 2: corrections. step 17. Needs the pieces and 16_upd.q loaded.
/ A trade can be busted by its id (the feed's seq), and a trade can arrive timed on a day already closed. Both touch
/ a day that lives on disk: amend[d;f] reads the day's trades back, applies f, recomputes the day's bars from what is
/ left, writes both splays again and remaps the HDB. In the root namespace, like the queries, for the HDB's tables.
.mdp.past:{[d] $[`trade in key `.; .mdp.dq select from trade where date=d; 0#.mdp.trade]}        / a closed day's trades (none before the first close)
.mdp.amend:{[d;f] t:f .mdp.past d; .mdp.save1[d;`trade;t]; .mdp.save1[d;`bar;0!.mdp.barsb t]; system"l ",1_string .mdp.hdb;}
.mdp.ontrade:{[t] e:.mdp.enrich1 t; dd:"d"$e`time; .mdp.trade,:e where dd=.mdp.today; .mdp.onbar e where dd=.mdp.today;
  {[e;d] .mdp.amend[d;{[x;t] t,x}[e where d="d"$e`time]]} [e] each distinct dd where dd<.mdp.today; e}                     / a late day: into its partition
.mdp.rebar:{[s;mn] rest:select from .mdp.trade where sym=s, mn=0D00:01 xbar time;                                          / the bar of one minute, from what is left of it
  $[count rest; .mdp.bar[(s;mn)]:`o`h`l`c`v`n#first 0!.mdp.barsb rest; delete from `.mdp.bar where sym=s, minute=mn];}
.mdp.bust:{[id] $[id in .mdp.trade`seq; [r:first select from .mdp.trade where seq=id; .mdp.trade:delete from .mdp.trade where seq=id; .mdp.rebar[r`sym;0D00:01 xbar r`time]];
  [d:$[`trade in key `.; first exec date from select date from trade where seq=id; 0Nd]; if[null d; '"mdp: unknown trade ",string id]; .mdp.amend[d;{[id;t] delete from t where seq=id}[id]]]];}
