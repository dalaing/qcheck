/ mdp: the state machine, run 2. step 18: two commands more — bust a trade by id, and a late trade may be timed up to
/ eighteen hours back, so one reported in the morning can fall on the day before. The model keeps the busted ids;
/ the oracle leaves them out. Needs the pieces, 16_upd.q and 17_amend.q loaded.
/ Three instruments, a clock that starts at the open of day0 and moves with each quote and trade, and a model
/ that is the event log itself: quotes and trades in arrival order with the feed's sequence number, and the fills.
/ The oracle recomputes everything from the log — the trades of a day are those whose time falls on it, enriched
/ by the batch join, barred by the batch select; positions are the signed sum of the fills — and the invariant
/ compares the system to it after every step. query asks the same three questions of the system and the oracle.
\d .mdp
syms:`A`B`C
inst0:([sym:`A`B`C] tick:0.01 0.05 1f; lot:1 10 100; mult:1 10 50)
day0:2024.01.02
opn:{[d] ("p"$d)+0D09:30}
hdb:hsym `$first system"mktemp -d"
byk:{k:asc key x; k!x k}
m0:`now`day`seq`bust`q`t`f!(opn day0; day0; 0; `long$(); ([]seq:`long$(); time:`timestamp$(); sym:`symbol$(); bid:`float$(); ask:`float$());
  ([]seq:`long$(); time:`timestamp$(); sym:`symbol$(); px:`float$(); qty:`long$()); ([]sym:`symbol$(); side:`symbol$(); qty:`long$(); px:`float$()))
init:{inst::inst0; seq::0; today::day0; quote::0#quote; qcache::0#qcache; trade::0#trade; bar::0#bar; pos::0#pos; system"rm -rf ",(1_string hdb),"/*";}                                                   / (the contents, not the directory: loading the HDB made it the working directory)
/ the oracle, from the model
otr:{[m;d] select from m[`t] where d="d"$time, not seq in m`bust}                / the trades of day d: those timed on it, not busted
oenr:{[m;d] enrichb[otr[m;d]; m`q]}
obars:{[m;d] 0!barsb otr[m;d]}
opos:{[m] exec sum qty*1 -1 `buy`sell?side by sym from m`f}
olq:{[m] select last bid,last ask by sym from m`q}
live:{[m] exec seq from m[`t] where not seq in m`bust}                                / the trade ids that can still be busted
row:{[ks;xs] flip ks!enlist each xs}                                                 / one row from atoms (vs is a keyword: xs)
cmds:([cmd:`quote`trade`late`fill`eod`query`bust]
  w:   4 4 1 2 1 2 1f;
  pre: ({[m] 1b}; {[m] 1b}; {[m] 1b}; {[m] 1b}; {[m] 1b}; {[m] 1b}; {[m] 0<count live m});
  gen: ({[m] (.qc.ts[m`now;m[`now]+0D00:01]; .qc.elem syms; .qc.flt 1 100; .qc.flt 0 5)};                   / time sym bid spread
        {[m] (.qc.ts[m`now;m[`now]+0D00:01]; .qc.elem syms; .qc.flt 1 100; .qc.int 1 5)};                   / time sym px lots
        {[m] (.qc.ts[m[`now]-0D18:00;m`now]; .qc.elem syms; .qc.flt 1 100; .qc.int 1 5)};                   / a trade reported late: timed up to 18 hours back
        {[m] (.qc.elem syms; .qc.elem `buy`sell; .qc.elem 1 10 100; .qc.flt 1 100)};
        {[m] ::};
        {[m] (.qc.elem m[`day]-til 1+m[`day]-day0; .qc.elem syms; .qc.int 0 390; .qc.int 0 390)};           / day sym window (minutes from the open)
        {[m] .qc.elem live m});
  run: ({[a] upd[`quote; row[`time`sym`bid`ask; (a 0;a 1;a 2;(a 2)+a 3)]]};
        {[a] upd[`trade; row[`time`sym`px`qty; (a 0;a 1;a 2;(a 3)*inst0[a 1;`lot])]]};
        {[a] upd[`trade; row[`time`sym`px`qty; (a 0;a 1;a 2;(a 3)*inst0[a 1;`lot])]]};
        {[a] upd[`fill; row[`sym`side`qty`px; a]]};
        {[a] eod today};
        {[a] d:a 0; s:a 1; w:asc opn[d]+0D00:01*a 2 3; `bars`vwap`trades!(qbars[d;s;w 0;w 1]; qvwap[d;s]; qtrades[d;s])};
        {[a] bust a});
  post:({[m;i;o] (qcache[i 1;`bid]=i 2) and qcache[i 1;`ask]=(i 2)+i 3};
        {[m;i;o] lq:olq m; (first o`bid)~lq[i 1;`bid]};                                   / enriched with the last quote seen for the sym
        {[m;i;o] lq:olq m; (first o`bid)~lq[i 1;`bid]};
        {[m;i;o] 1b};
        {[m;i;o] (0=count trade) and (0=count quote) and 0=count bar};
        {[m;i;o] d:i 0; s:i 1; w:asc opn[d]+0D00:01*i 2 3;
          .qc.eq[o; `bars`vwap`trades!(`minute xasc select from obars[m;d] where sym=s, minute within w; exec qty wavg px from otr[m;d] where sym=s; `seq xasc select from oenr[m;d] where sym=s)]};
        {[m;i;o] not i in trade`seq});
  upd: ({[m;i;o] m[`now]:i 0; m[`q],:row[`seq`time`sym`bid`ask; (m`seq;i 0;i 1;i 2;(i 2)+i 3)]; m[`seq]+:1; m};   / (the feed stamps from 0)
        {[m;i;o] m[`now]:i 0; m[`t],:row[`seq`time`sym`px`qty; (m`seq;i 0;i 1;round[i 1;i 2];(i 3)*inst0[i 1;`lot])]; m[`seq]+:1; m};
        {[m;i;o] m[`t],:row[`seq`time`sym`px`qty; (m`seq;i 0;i 1;round[i 1;i 2];(i 3)*inst0[i 1;`lot])]; m[`seq]+:1; m};
        {[m;i;o] m[`f],:row[`sym`side`qty`px; i]; m};
        {[m;i;o] m[`day]+:1; m[`now]:opn m`day; m};
        {[m;i;o] m};
        {[m;i;o] m[`bust],:i; m}))
/ the invariant (inv is a keyword): after every step the system's state is what the oracle computes from the log
invar:{[m] d:m`day; mk:(syms!count[syms]#1f),exec sym!0.5*bid+ask from 0!qcache; mu:exec sym!mult from inst;
  (.qc.eq[byk exec sym!qty from pos; byk opos m];
   .qc.eq[`sym`minute xasc 0!bar; `sym`minute xasc obars[m;d]];
   .qc.eq[`sym xasc select sym,bid,ask from 0!qcache; `sym xasc 0!olq m];
   1e-6>abs ((exec sum real from pos)+unreal mk)-(exec sum mu[sym]*qty*px*-1 1 `buy`sell?side from m`f)+exec sum mu[sym]*qty*mk sym from pos)}
hooks:`m0`init`inv`steps!(m0;init;invar;0 20)   / (inv is a keyword: the hook is invar)
\d .
