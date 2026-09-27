/ mdp after the review (REVIEW.md, section 5): step 25. Needs the pieces, 16_upd.q, 17_amend.q and 22_rename.q loaded.
/ Nothing here was found by a test; a reader found them (entry 25). The constants the pieces and the machine had each
/ written down are defined once; a closed day is one the HDB has (`.Q.pv`), not "some table named trade exists"; a trade timed after today, a fill for an unknown instrument
/ and a rename of an unknown name are refused instead of lost; upd leaves an empty table alone (pitfall 45).
.mdp.day0:2024.01.02
.mdp.opn:{[d] ("p"$d)+0D09:30}
.mdp.cls:{[d] ("p"$d)+0D16:00}
.mdp.today:.mdp.day0
.mdp.remap:{system"l ",1_string .mdp.hdb;}   / \l dir makes dir the working directory, and the mapped tables need it to stay so: everything else the system loads is by absolute path (mdp.q's root; pitfall 44)
.mdp.ondisk:{[d] $[`trade in key `.; d in .Q.pv; 0b]}                                                          / a closed day the HDB holds
.mdp.past:{[d] $[.mdp.ondisk d; .mdp.dq select from trade where date=d; 0#.mdp.trade]}
.mdp.amend:{[d;f] t:f .mdp.past d; .mdp.save1[d;`trade;t]; .mdp.save1[d;`bar;0!.mdp.barsb t]; .mdp.remap[];}
.mdp.eod:{[d] .mdp.save1[d]'[`trade`quote`bar;(.mdp.trade;.mdp.quote;.mdp.bar)]; .mdp.trade:0#.mdp.trade; .mdp.quote:0#.mdp.quote; .mdp.bar:0#.mdp.bar;
  .mdp.remap[]; .mdp.today:d+1; .mdp.roll[]}
.mdp.ontrade:{[t] e:.mdp.enrich1 t; dd:"d"$e`time; if[any dd>.mdp.today; '"mdp: a trade timed after today: ",.Q.s1 e where dd>.mdp.today];
  .mdp.trade,:e where dd=.mdp.today; .mdp.onbar e where dd=.mdp.today;
  {[e;d] .mdp.amend[d;{[x;t] t,x}[e where d="d"$e`time]]} [e] each distinct dd where dd<.mdp.today; e}
.mdp.onfill0:.mdp.onfill
.mdp.onfill:{[f] if[count u:(exec sym from f) except exec sym from .mdp.inst; '"mdp: fill for an unknown instrument: ",", " sv string u]; .mdp.onfill0 f}
.mdp.rename:{[o;n;e] s:exec sym from .mdp.inst; if[not o in s; '"mdp: rename: unknown name ",string o]; if[n in s; '"mdp: rename: ",string[n]," already exists"];
  if[e<.mdp.today; '"mdp: rename: effective date ",string[e]," is past"]; .mdp.ren,:`old`new`eff!(o;n;e); .mdp.inst[n]:.mdp.inst o;}
.mdp.upd:{[t;x] if[count x; x:update sym:.mdp.canon'[sym;.mdp.today] from x];
  $[t=`quote; .mdp.onquote x; t=`trade; .mdp.ontrade update px:.mdp.round'[sym;px] from x; t=`fill; .mdp.onfill x; '"mdp: unknown table ",string t]}
