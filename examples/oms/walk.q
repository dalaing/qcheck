/ examples/oms/walk.q — what the sessions of WALKTHROUGH2.md load beside the steps: a loader for the steps by
/ name, the code that feeds the system and asks it questions, and the rules, each named and written out over a
/ few lines so that a session reads as one call. WALKTHROUGH2.md shows each of them where it is first used.
/ Load it from the repository root, after qc.q.

/ ---- the steps ----
/ .oms.walk`04_ref`01_gen loads examples/oms/steps/04_ref.q then 01_gen.q. A step of the end-of-day piece, or the
/ whole-system test, needs a database directory of its own: an empty temporary one is made the first time it is
/ asked for, and .oms.clean[] removes it. Every session that touches the disk ends with .oms.clean[].
.oms.walk:{[fs] fs:(),fs; if[any fs like "*_eod"; if[not `hdb in key `.oms; .oms.hdb:hsym `$first system"mktemp -d"]];
  {system"l examples/oms/steps/",string[x],".q"} each fs; if[`inst in key `.oms.g; .oms.inst:.oms.g.inst];}   / (the generators' reference data is the system's, once 08_gen.q is loaded)
.oms.clean:{if[`hdb in key `.oms; system"rm -rf ",1_string .oms.hdb]}
.qc.cfg[`rerun]:0b                                                            / the reports leave out their rerun line: the document shows it once, in the primer

/ ---- piece 1: reference data and FX ----
lastrate:{[f;t;c] $[count r:exec rate from f where ccy=c,time<=t; last r; 0n]}   / the rate as of t by the obvious exec: the last one at or before t, null if none
rate_is_last_seen:{[f;t;c] .oms.fxr::f;                                       / the drawn rates become the system's
  .qc.eq[.oms.rate[t;c]; lastrate[f;t;c]]}
there_and_back:{[f;t;c;a] .oms.fxr::f; r:.oms.rate[t;c];
  $[null r; 1b; 1e-9>abs a-.oms.tobase[t;c;a]%r]}                            / (no rate yet: the rule steps around it)
call:{[f;x] @[{(1b;y . x)}[;f];x;{(0b;x)}]}                                   / (1b; result) if f . x returns, (0b; message) if it signals
refused_without_a_rate:{[f;t;c;a] .oms.fxr::f; r:call[.oms.tobase;(t;c;a)];
  $[null .oms.rate[t;c]; not r 0; (r 0) and not null r 1]}                     / no rate: refused, any error counting; a rate: a number
refused_by_name:{[f;t;c;a] .oms.fxr::f; r:call[.oms.tobase;(t;c;a)];
  $[null .oms.rate[t;c]; (not r 0) and (r 1) like "oms: no rate for *"; (r 0) and not null r 1]}   / no rate: refused, and the message says so

/ ---- piece 2: quotes ----
feed:{[t] .oms.quote::0#.oms.quote; .oms.lq::0#.oms.lq; .oms.onquote'[t`time;t`sym;t`bid;t`ask];}   / a session of quotes, from empty, one at a time
naive:{[q;t;s] $[count r:select from q where sym=s,time<=t; .oms.midof[last r`bid;last r`ask]; 0n]}   / the mid as of t by the obvious select
mid_is_naive:{[q;t;s] q:.oms.g.qs q; feed q;                                   / (g.qs turns the drawn rows, with their (bid;ask) pair, into a quote table)
  .qc.eq[.oms.mid[t;s]; naive[q;t;s]]}
cache_is_latest:{[q;s] q:.oms.g.qs q; feed q;
  .qc.eq[.oms.now s; .oms.mid[max .oms.g.close,q`time;s]]}                    / the cache is the mid as of the latest time in the session

/ ---- pieces 3 to 5: orders, positions, a split ----
fx0:([]time:3#2024.01.02D09:30; ccy:`EUR`GBP`JPY; rate:1.1 1.3 0.007)          / one rate per currency, at the open: piece 1 tested the rates, these pieces only need some
reset:{{[n] if[n in key `.oms; (` sv `.oms,n) set 0#get ` sv `.oms,n]} each `order`fill`pos`quote`lq`ca; .oms.seq::0; .oms.fxr::fx0}   / every table the loaded pieces have, empty; the rates fx0
new_is_new:{[t;a] reset[]; id:.oms.neworder[t;a 0;a 1;a 2;a 3]; o:.oms.order id;   / a is (sym; side; qty; px)
  (o[`st]=`new) and (o[`leaves]=a 2) and (o[`sym]=a 0) and o[`px]=a 3}
lot_and_tick:{[t;a;dq;dp] reset[];                                             / dq shares more, dp more on the price
  r:@[{.oms.neworder . x; 1b};(t;a 0;a 1;(a 2)+dq;a 3);{0b}];                  / accepted?
  s:@[{.oms.neworder . x; 1b};(t;a 0;a 1;a 2;(a 3)+dp);{0b}];
  (r=0=dq mod .oms.g.inst[a 0;`lot]) and s=.oms.ontick[a 0;(a 3)+dp]}          / accepted exactly when on the lot, exactly when on the tick
fq:.qc.lst[0 5] .qc.int 1 5                                                    / a run of fills, in lots
fills_add_up:{[t;a;fs] reset[]; oid:.oms.neworder[t;a 0;a 1;a 2;a 3]; .oms.ack oid; lot:.oms.g.inst[a 0;`lot];
  {[t;oid;lot;q] o:.oms.order oid; if[(o[`leaves]>0) and (q*lot)<=o`leaves; .oms.onfill[t;oid;q*lot;o`px]]}[t;oid;lot] each fs;   / each fill that fits
  o:.oms.order oid; f:select from .oms.fill where id=oid;
  ((o[`qty]-o`leaves)=sum f`qty) and o[`st]=$[o[`leaves]=0; `filled; count[f]>0; `part; `ack]}
book:{[t;s;fs] {[t;s;f] lot:.oms.inst[s;`lot]; id:.oms.neworder[t;s;f 0;lot*f 1;.oms.g.inst[s;`tick]]; .oms.ack id; .oms.onfill[t;id;lot*f 1;f 2]}[t;s] each fs;}   / each fill (side; lots; px) as an order acked and filled in full
position_is_sum:{[s;fs] reset[]; book[.oms.g.open;s;fs];
  (0^.oms.pos[s;`qty])=sum .oms.sgn'[fs[;0]]*.oms.inst[s;`lot]*fs[;1]}         / the signed sum of the fills, in shares
pnl_is_cash:{[s;fs;m] reset[]; book[.oms.g.open;s;fs]; .oms.onquote[.oms.g.open;s;m;m];   / m: the mid the position is marked at
  r:.oms.rate[.oms.g.open;.oms.inst[s;`ccy]]; lot:.oms.inst[s;`lot];
  cash:sum neg .oms.sgn'[fs[;0]]*lot*fs[;1]*fs[;2];                            / what the fills brought in, in the instrument's currency
  want:r*cash+m*0^.oms.pos[s;`qty];                                            / plus the open quantity marked, all at the one rate
  got:(0^.oms.pos[s;`real])+.oms.unreal[.oms.g.open;s];
  1e-6>abs want-got}
split_keeps_value:{[s;fs;m;r] reset[]; book[.oms.g.open;s;fs]; .oms.onquote[.oms.g.open;s;m;m]; u0:.oms.unreal[.oms.g.open;s];
  .oms.split[.oms.g.open;s;r]; .oms.onquote[.oms.g.open+1;s;m%r;m%r]; u1:.oms.unreal[.oms.g.open+1;s];   / the market quotes at the new level
  1e-6>abs u0-u1}
split_keeps_order_exactly:{[a;r] reset[]; id:.oms.neworder[.oms.g.open;a 0;a 1;a 2;a 3]; .oms.ack id; o0:.oms.order id;
  .oms.split[.oms.g.open;a 0;r]; o1:.oms.order id;
  (1e-6>abs (o0[`leaves]*o0`px)-o1[`leaves]*o1`px) and (o1[`qty]=r*o0`qty) and 0=o1[`leaves] mod .oms.inst[a 0;`lot]}
split_keeps_order:{[a;r] reset[]; id:.oms.neworder[.oms.g.open;a 0;a 1;a 2;a 3]; .oms.ack id; o0:.oms.order id;
  .oms.split[.oms.g.open;a 0;r]; o1:.oms.order id;
  (1e-6>abs[(o0[`leaves]*o0`px)-o1[`leaves]*o1`px]-o1[`leaves]*.oms.inst[a 0;`tick]) and (o1[`qty]=r*o0`qty) and 0=o1[`leaves] mod .oms.inst[a 0;`lot]}   / worth the same to within a tick on what is left
split_on_tick:{[a;r] reset[]; id:.oms.neworder[.oms.g.open;a 0;a 1;a 2;a 3]; .oms.split[.oms.g.open;a 0;r];
  .oms.ontick[a 0;.oms.order[id;`px]]}

/ ---- piece 6: a day ----
wipe:{reset[]; .oms.fxr::0#.oms.fxr; .oms.today::.oms.day0; system"rm -rf ",(1_string .oms.hdb),"/*"; if[count k:`execs`quote`fxr`order inter key `.; ![`.;();0b;k]]}   / a fresh day and a fresh database
day:{[fx;qs;fs] .oms.onfx'[fx`time;fx`ccy;fx`rate]; qs:.oms.g.qs qs; .oms.onquote'[qs`time;qs`sym;qs`bid;qs`ask];   / one day: the rates, the quotes,
  {[s;fl] {[s;f] lot:.oms.inst[s;`lot]; id:.oms.neworder[.oms.g.open+0D01;s;f 0;lot*f 1;.oms.g.inst[s;`tick]]; .oms.ack id; .oms.onfill[.oms.g.open+0D02;id;lot*f 1;f 2]}[s] each fl}'[.oms.g.syms;fs];}   / then a run of fills per instrument
gday:{(.oms.g.fx1;.oms.g.quotes;.oms.g.fillrun each .oms.g.syms)}             / what a day is drawn from (a function, since the generators load after this file)
day_comes_back:{[fx;qs;fs] wipe[]; day[fx;qs;fs]; f0:`sym`time xasc .oms.fill;
  .oms.eod .oms.day0;
  .qc.eq[f0; `sym`time xasc raze .oms.fillsof[.oms.day0] each .oms.g.syms]}   / read back from disk
carry_over_at_close:{[fx;qs;fs] wipe[]; day[fx;qs;fs];
  r0:.oms.rate[.oms.g.close;] each .oms.g.ccys; m0:.oms.mid[.oms.g.close;] each .oms.g.syms;   / as of the close
  .oms.eod .oms.day0; t:.oms.opn .oms.today;
  .qc.eq[(r0;m0); (.oms.rate[t;] each .oms.g.ccys; .oms.mid[t;] each .oms.g.syms)]}   / as of the next open
carry_over:{[fx;qs;fs] wipe[]; day[fx;qs;fs]; e:max .oms.g.close,.oms.quote`time;   / as of the latest time seen, which may be after the close
  r0:.oms.rate[e;] each .oms.g.ccys; m0:.oms.mid[e;] each .oms.g.syms;
  .oms.eod .oms.day0; t:.oms.opn .oms.today;
  .qc.eq[(r0;m0); (.oms.rate[t;] each .oms.g.ccys; .oms.mid[t;] each .oms.g.syms)]}
slippage_bps:{[fx;qs;fs] wipe[]; day[fx;qs;fs]; s:raze .oms.slip[.oms.day0] each .oms.g.syms;
  o:.oms.order ([]id:s`id);                                                    / the fills' orders, a table of keys
  all 1e-6>abs s[`bps]-1e4*.oms.sgn'[o`side]*(s[`px]-o`arr)%o`arr}

/ ---- the whole system: what a sequence reached ----
reach:{[tr] c:tr`cmd; .qc.classify[`fill;`fill in c]; .qc.classify[`eod;`eod in c]; .qc.classify[`split;`split in c]; .qc.classify[`two_days;1<sum c=`eod];
  .qc.classify[`fill_then_split;(`fill in c) and (`split in c) and first[where c=`fill]<last where c=`split];
  .qc.classify[`split_then_fill;(`fill in c) and (`split in c) and last[where c=`fill]>first where c=`split]; 1b}
