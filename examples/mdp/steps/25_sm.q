/ mdp: the stateful test after the review. step 25: the postconditions say more — a fill moves the position by its
/ signed quantity, a trade is enriched with bid and ask and rounded to the tick, a bust leaves the id nowhere the
/ queries can see, a rename is in ren and the new name inherits the instrument — and the invariant checks yesterday on
/ disk as well as today in memory. The HDB root and the day constants come from 25_final.q. Needs the pieces, 16_upd.q,
/ 17_amend.q, 22_rename.q and 25_final.q loaded.
\d .mdp
syms:`A`B`C
inst0:([sym:`A`B`C] tick:0.01 0.05 1f; lot:1 10 100; mult:1 10 50)
if[`~hdb; hdb:hsym `$first system"mktemp -d"]                                       / (day0, opn, cls: 25_final.q)
byk:{k:asc key x; k!x k}
m0:`now`day`seq`bust`names`q`t`f!(opn day0; day0; 0; `long$(); syms; ([]seq:`long$(); time:`timestamp$(); sym:`symbol$(); bid:`float$(); ask:`float$());
  ([]seq:`long$(); time:`timestamp$(); sym:`symbol$(); px:`float$(); qty:`long$(); arr:`date$()); ([]sym:`symbol$(); side:`symbol$(); qty:`long$(); px:`float$()))
init:{inst::inst0; ren::0#ren; seq::0; today::day0; quote::0#quote; qcache::0#qcache; trade::0#trade; bar::0#bar; pos::0#pos; system"rm -rf ",(1_string hdb),"/*"; if[count k:`trade`quote`bar inter key `.; ![`.;();0b;k]];}   / (the contents, not the directory: loading the HDB made it the working directory; and the tables it mapped, which would otherwise still point at the partitions just removed — guarded: a functional delete with no names deletes every global)
/ the oracle, from the model
otr:{[m;d] select from m[`t] where d="d"$time, not seq in m`bust}                / the trades of day d: those timed on it, not busted
oenr:{[m;d] t:otr[m;d]; delete arr from $[count t; raze {[m;t;a] enrichb[select from t where arr=a; named[m`q;a]]}[m;t] each distinct t`arr; enrichb[t;m`q]]}   / each trade from the instrument's quotes under its arrival day's names
obars:{[m;d] 0!barsb otr[m;d]}
named:{[t;d] $[count t; update sym:.mdp.canon'[sym;d] from t; t]}                        / a table under the names of day d (each over an empty typed column gives a general one: leave an empty table alone; asof is a keyword)
cur:{[m;t] named[t;m`day]}                                                                / under today's names
opos:{[m] exec sum qty*1 -1 `buy`sell?side by sym from cur[m;m`f]}
olq:{[m] select last bid,last ask by sym from cur[m;m`q]}
live:{[m] exec seq from m[`t] where not seq in m`bust}                                / the trade ids that can still be busted
row:{[ks;xs] enlist ks!xs}                                                           / one row from atoms: a list of one record is a table (vs is a keyword: xs)
cmds:([cmd:`quote`trade`late`fill`eod`query`bust`rename]
  w:   4 4 1 2 1 2 1 1f;
  pre: ({[m] 1b}; {[m] 1b}; {[m] m[`day]>day0}; {[m] 1b}; {[m] 1b}; {[m] 1b}; {[m] 0<count live m}; {[m] 3>count[m`names]-count syms});
  gen: ({[m] (.qc.ts[m`now;m[`now]+0D00:01]; .qc.elem m`names; .qc.flt 1 100; .qc.flt 0 5)};                   / time sym bid spread
        {[m] (.qc.ts[m`now;m[`now]+0D00:01]; .qc.elem m`names; .qc.flt 1 100; .qc.int 1 5)};                   / time sym px lots
        {[m] (.qc.ts[opn m[`day]-1;cls m[`day]-1]; .qc.elem m`names; .qc.flt 1 100; .qc.int 1 5)};              / a trade reported for yesterday, timed in its session
        {[m] (.qc.elem m`names; .qc.elem `buy`sell; .qc.elem 1 10 100; .qc.flt 1 100)};
        {[m] ::};
        {[m] (.qc.elem m[`day]-til 1+m[`day]-day0; .qc.elem m`names; .qc.int 0 390; .qc.int 0 390)};       / day sym window (minutes from the open)
        {[m] .qc.elem live m};
        {[m] (.qc.elem m[`names] where m[`names]=canon'[m`names;m[`day]+1]; .qc.elem enlist `$"N",string count[m`names]-count syms; .qc.elem enlist m[`day]+1)});   / a name still current tomorrow, a fresh one, effective tomorrow
  run: ({[a] upd[`quote; row[`time`sym`bid`ask; (a 0;a 1;a 2;(a 2)+a 3)]]};
        {[a] upd[`trade; row[`time`sym`px`qty; (a 0;a 1;a 2;(a 3)*inst[a 1;`lot])]]};
        {[a] upd[`trade; row[`time`sym`px`qty; (a 0;a 1;a 2;(a 3)*inst[a 1;`lot])]]};
        {[a] upd[`fill; row[`sym`side`qty`px; a]]};
        {[a] eod today};
        {[a] d:a 0; s:a 1; w:asc opn[d]+0D00:01*a 2 3; `bars`vwap`trades!(qbars[d;s;w 0;w 1]; qvwap[d;s]; qtrades[d;s])};
        {[a] bust a};
        {[a] rename . a});
  post:({[m;i;o] s:canon[i 1;m`day]; (qcache[s;`bid]=i 2) and qcache[s;`ask]=(i 2)+i 3};                 / the cache holds it under today's name
        {[m;i;o] lq:olq m; s:canon[i 1;m`day]; ((first o`bid)~lq[s;`bid]) and ((first o`ask)~lq[s;`ask]) and (first o`px)=round[s;i 2]};   / enriched with the last quote seen for the instrument, at the tick
        {[m;i;o] lq:olq m; s:canon[i 1;m`day]; ((first o`bid)~lq[s;`bid]) and ((first o`ask)~lq[s;`ask]) and (first o`px)=round[s;i 2]};
        {[m;i;o] s:canon[i 0;m`day]; pos[s;`qty]=(0^(opos m) s)+(i 2)*$[`buy=i 1; 1; -1]};                       / the position moved by the fill
        {[m;i;o] (0=count trade) and (0=count quote) and 0=count bar};
        {[m;i;o] d:i 0; s:i 1; w:asc opn[d]+0D00:01*i 2 3;
          .qc.eq[o; `bars`vwap`trades!(`minute xasc select from obars[m;d] where sym=s, minute within w; exec qty wavg px from otr[m;d] where sym=s; `seq xasc select from oenr[m;d] where sym=s)]};
        {[m;a;o] t:first select from m[`t] where seq=a; not a in exec seq from qtrades["d"$t`time;t`sym]};        / gone from wherever its day lives (a, not i: inside a select i is the row index)
        {[m;a;o] (1=count select from ren where old=a 0,new=a 1,eff=a 2) and inst[a 1]~inst[a 0]});   / (a, not i: inside a select i is the row index)
  upd: ({[m;i;o] m[`now]:i 0; m[`q],:row[`seq`time`sym`bid`ask; (m`seq;i 0;canon[i 1;m`day];i 2;(i 2)+i 3)]; m[`seq]+:1; m};   / (the feed stamps from 0)
        {[m;i;o] m[`now]:i 0; m[`t],:row[`seq`time`sym`px`qty`arr; (m`seq;i 0;canon[i 1;m`day];round[i 1;i 2];(i 3)*inst[i 1;`lot];m`day)]; m[`seq]+:1; m};
        {[m;i;o] m[`t],:row[`seq`time`sym`px`qty`arr; (m`seq;i 0;canon[i 1;m`day];round[i 1;i 2];(i 3)*inst[i 1;`lot];m`day)]; m[`seq]+:1; m};
        {[m;i;o] m[`f],:row[`sym`side`qty`px; (canon[i 0;m`day];i 1;i 2;i 3)]; m};
        {[m;i;o] m[`day]+:1; m[`now]:opn m`day; m};
        {[m;i;o] m};
        {[m;i;o] m[`bust],:i; m};
        {[m;i;o] m[`names],:i 1; m}))
/ the invariant (inv is a keyword): after every step the system's state is what the oracle computes from the log
invar:{[m] d:m`day; mk:(m[`names]!count[m`names]#1f),exec sym!0.5*bid+ask from 0!qcache; mu:exec sym!mult from inst;
  (.qc.eq[byk exec sym!qty from pos; byk opos m];
   .qc.eq[`sym`minute xasc 0!bar; `sym`minute xasc obars[m;d]];
   .qc.eq[`sym xasc select sym,bid,ask from 0!qcache; `sym xasc 0!olq m];
   1e-6>abs ((exec sum real from pos)+unreal mk)-(exec sum mu[sym]*qty*px*-1 1 `buy`sell?side from m`f)+exec sum mu[sym]*qty*mk sym from pos;
   $[d>day0; all {[m;d;s] (count qtrades[d;s])=count select from otr[m;d] where sym=s}[m;d-1] each m`names; 1b];   / yesterday, on disk, has the oracle's trades
   $[d>day0; [s:get ` sv hdb,`sym; (s~distinct s) and all raze (`trade`quote`bar) in/: {[d] key ` sv hdb,`$string d} each .Q.pv]; 1b];   / the sym file has no duplicates, and every partition holds every table
   $[d>day0; all parted each .Q.pv; 1b])}   / on disk, sym is parted
hooks:`m0`init`inv`steps!(m0;init;invar;0 20)   / (inv is a keyword: the hook is invar)
\d .
