/ examples/oms/props.q — the pieces' rules that survived (LOG.md entries 3, 4, 7, 9, 10, 11), as one suite for
/ .qc.checks, and the two pieces' own stateful tests (entries 6 and 8). Loaded by run.q after oms.q; the generators
/ are the log's (steps/NN_gen.q, each the additions of its step), and the reference data the generators'.
{system"l ",.oms.root,"/steps/",x} each ("01_gen.q";"05_gen.q";"08_gen.q";"13_gen.q";"12_sm.q";"06_sm.q");
.oms.inst:.oms.g.inst
call:{[f;x] @[{(1b;y . x)}[;f];x;{(0b;x)}]}                                            / (ok; result) or (refused; message)
reset:{[fx] .oms.order::0#.oms.order; .oms.fill::0#.oms.fill; .oms.seq::0; .oms.pos::0#.oms.pos; .oms.fxr::fx; .oms.quote::0#.oms.quote; .oms.lq::0#.oms.lq; .oms.ca::0#.oms.ca}
feed:{[t] .oms.quote::0#.oms.quote; .oms.lq::0#.oms.lq; .oms.onquote'[t`time;t`sym;t`bid;t`ask];}
naive:{[q;t;s] $[count r:select from q where sym=s,time<=t; .oms.midof[last r`bid;last r`ask]; 0n]}
run:{[t;s;fs] {[t;s;f] lot:.oms.inst[s;`lot]; id:.oms.neworder[t;s;f 0;lot*f 1;.oms.g.inst[s;`tick]]; .oms.ack id; .oms.onfill[t;id;lot*f 1;f 2]}[t;s] each fs;}
day:{[fx;qs;fs] .oms.onfx'[fx`time;fx`ccy;fx`rate]; qs:.oms.g.qs qs; .oms.onquote'[qs`time;qs`sym;qs`bid;qs`ask]; {[s;fl] {[s;f] lot:.oms.inst[s;`lot]; id:.oms.neworder[.oms.g.open+0D01;s;f 0;lot*f 1;.oms.g.inst[s;`tick]]; .oms.ack id; .oms.onfill[.oms.g.open+0D02;id;lot*f 1;f 2]}[s] each fl}'[.oms.g.syms;fs];}
wipe:{reset 0#.oms.fxr; .oms.today::.oms.day0; system"rm -rf ",(1_string .oms.hdb),"/*"; if[count k:`execs`quote`fxr`order inter key `.; ![`.;();0b;k]]}   / a fresh day and a fresh database
fq:.qc.lst[0 5] .qc.int 1 5
fx0:([]time:3#.oms.g.open; ccy:.oms.g.ccys; rate:1.1 1.3 0.007)                     / piece 3's rules ran before piece 4 wrapped onfill; in the whole system a fill books a position and needs a rate
gday:(.oms.g.fx1;.oms.g.quotes;.oms.g.fillrun each .oms.g.syms)
props:()!()
/ piece 1: a conversion is refused, by name, when there is no rate, and is a number when there is (entry 3)
props[`tobase_refuses_without_a_rate]:((.oms.g.fx;.oms.g.t;.qc.elem .oms.g.ccys;.oms.g.amt); {[f;t;c;a] .oms.fxr::f; r:call[.oms.tobase;(t;c;a)]; $[null .oms.rate[t;c]; (not r 0) and (r 1) like "oms: no rate for *"; (r 0) and not null r 1]})
/ piece 2: the mid as of a time is what a loop finds; the cache is the mid as of the latest time seen (entry 4)
props[`mid_as_of_is_the_last_quote_before]:((.oms.g.quotes;.oms.g.t;.qc.elem .oms.g.syms); {[q;t;s] q:.oms.g.qs q; feed q; .qc.eq[.oms.mid[t;s]; naive[q;t;s]]})
props[`cache_is_mid_as_of_the_latest]:((.oms.g.quotes;.qc.elem .oms.g.syms); {[q;s] q:.oms.g.qs q; feed q; .qc.eq[.oms.now s; .oms.mid[max .oms.g.close,q`time;s]]})
/ piece 3: an order arrives new with its leaves; lot and tick are checked; fills reduce leaves and the last fills (entry 7)
props[`new_order_is_new]:((.oms.g.t;.oms.g.order); {[t;a] reset fx0; id:.oms.neworder[t;a 0;a 1;a 2;a 3]; o:.oms.order id; (o[`st]=`new) and (o[`leaves]=a 2) and (o[`sym]=a 0) and o[`px]=a 3})
props[`lot_and_tick_are_checked]:((.oms.g.t;.oms.g.order;.qc.int 1 9;.qc.flt 0 0.009); {[t;a;dq;dp] reset fx0; r:@[{.oms.neworder . x; 1b};(t;a 0;a 1;(a 2)+dq;a 3);{0b}]; s:@[{.oms.neworder . x; 1b};(t;a 0;a 1;a 2;(a 3)+dp);{0b}]; (r=0=dq mod .oms.g.inst[a 0;`lot]) and s=.oms.ontick[a 0;(a 3)+dp]})
props[`fills_reduce_leaves]:((.oms.g.t;.oms.g.order;fq); {[t;a;fs] reset fx0; id:.oms.neworder[t;a 0;a 1;a 2;a 3]; .oms.ack id; lot:.oms.g.inst[a 0;`lot]; {[t;id;lot;q] o:.oms.order id; if[(o[`leaves]>0) and (q*lot)<=o`leaves; .oms.onfill[t;id;q*lot;o`px]]}[t;id;lot] each fs; o:.oms.order id; f:select from .oms.fill where id=id; ((o[`qty]-o`leaves)=sum f`qty) and (o[`st]=$[o[`leaves]=0; `filled; count[f]>0; `part; `ack])})
/ piece 4: the position is the signed sum of the fills; realised plus unrealised is the cash plus the open quantity marked, at one rate (entry 9; real is never null since entry 12)
props[`position_is_the_signed_sum]:((.oms.g.fx1;.qc.elem .oms.g.syms;.oms.g.fillrun `A); {[fx;s;fs] reset fx; run[.oms.g.open;s;fs]; q:0^.oms.pos[s;`qty]; q=sum .oms.sgn'[fs[;0]]*.oms.inst[s;`lot]*fs[;1]})
props[`pnl_is_cash_plus_marked]:((.oms.g.fx1;.qc.elem .oms.g.syms;.oms.g.fillrun `A;.qc.flt 10 20); {[fx;s;fs;m] reset fx; run[.oms.g.open;s;fs]; .oms.onquote[.oms.g.open;s;m;m]; r:.oms.rate[.oms.g.open;.oms.inst[s;`ccy]]; lot:.oms.inst[s;`lot]; cash:sum neg .oms.sgn'[fs[;0]]*lot*fs[;1]*fs[;2]; q:0^.oms.pos[s;`qty]; want:r*cash+q*m; got:$[count fs; .oms.pos[s;`real]+.oms.unreal[.oms.g.open;s]; 0f]; 1e-6>abs want-got})
/ piece 5: a split leaves the marked value alone; an open order is worth the same to within a tick and stays on lot and tick (entry 10)
props[`split_keeps_the_value]:((.oms.g.fx1;.qc.elem .oms.g.syms;.oms.g.fillrun `A;.qc.flt 10 20;.qc.int 2 4); {[fx;s;fs;m;r] reset fx; run[.oms.g.open;s;fs]; .oms.onquote[.oms.g.open;s;m;m]; u0:.oms.unreal[.oms.g.open;s]; .oms.split[.oms.g.open;s;r]; .oms.onquote[.oms.g.open+1;s;m%r;m%r]; u1:.oms.unreal[.oms.g.open+1;s]; 1e-6>abs u0-u1})
props[`split_keeps_an_order_worth_the_same]:((.oms.g.fx1;.oms.g.order;.qc.int 2 4); {[fx;a;r] reset fx; id:.oms.neworder[.oms.g.open;a 0;a 1;a 2;a 3]; .oms.ack id; o0:.oms.order id; .oms.split[.oms.g.open;a 0;r]; o1:.oms.order id; (1e-6>abs[(o0[`leaves]*o0`px)-o1[`leaves]*o1`px]-o1[`leaves]*.oms.inst[a 0;`tick]) and (o1[`qty]=r*o0`qty) and 0=o1[`leaves] mod .oms.inst[a 0;`lot]})
props[`split_keeps_an_order_on_tick]:((.oms.g.fx1;.oms.g.order;.qc.int 2 4); {[fx;a;r] reset fx; id:.oms.neworder[.oms.g.open;a 0;a 1;a 2;a 3]; .oms.split[.oms.g.open;a 0;r]; .oms.ontick[a 0;.oms.order[id;`px]]})
/ piece 6: a day written comes back as it was; the carry-over is the last of the day; slippage is the arithmetic (entry 11)
props[`a_day_written_comes_back]:(gday; {[fx;qs;fs] wipe[]; day[fx;qs;fs]; f0:`sym`time xasc .oms.fill; .oms.eod .oms.day0; .qc.eq[f0; `sym`time xasc raze .oms.fillsof[.oms.day0] each .oms.g.syms]})
props[`carry_over_is_the_last_of_the_day]:(gday; {[fx;qs;fs] wipe[]; day[fx;qs;fs]; e:max .oms.g.close,.oms.quote`time; r0:.oms.rate[e;] each .oms.g.ccys; m0:.oms.mid[e;] each .oms.g.syms; .oms.eod .oms.day0; t:.oms.opn .oms.today; .qc.eq[(r0;m0); (.oms.rate[t;] each .oms.g.ccys; .oms.mid[t;] each .oms.g.syms)]})
props[`slippage_in_bps]:(gday; {[fx;qs;fs] wipe[]; day[fx;qs;fs]; s:raze .oms.slip[.oms.day0] each .oms.g.syms; o:.oms.order ([]id:s`id); all 1e-6>abs s[`bps]-1e4*.oms.sgn'[o`side]*(s[`px]-s`arr)%s`arr})
/ the pieces' own stateful tests: the quote cache (entry 6) and the order lifecycle (entry 8)
props[`quote_cache]:(.qc.sm[.oms.q.hooks] .oms.q.cmds; ::)
props[`order_lifecycle]:(.qc.sm[.oms.o.hooks,enlist[`steps]!enlist 0 40] .oms.o.cmds; ::)
