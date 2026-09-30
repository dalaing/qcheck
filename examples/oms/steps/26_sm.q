/ oms: a stateful test of the whole system. step 26: the oracle books a fill at the rate known when it was made, so a
/ rate that arrives later, timed at or before the fill, does not re-book it (entry 12). Step 21 describes the test.
\d .oms
sys.o0:([id:`long$()] sym:`symbol$(); side:`symbol$(); qty:`long$(); px:`float$(); st:`symbol$(); leaves:`long$(); arr:`float$())
sys.f0:([]day:`date$(); time:`timestamp$(); id:`long$(); sym:`symbol$(); side:`symbol$(); qty:`long$(); px:`float$(); rate:`float$(); arr:`float$(); adj:`long$())   / rate: the rate the fill was booked at; adj: the split factor applied since
sys.m0:`day`now`fresh`fx`q`o`f!(day0; opn day0; 1b; 0#fxr; 0#quote; sys.o0; sys.f0)
sys.init:{inst::g.inst; order::0#order; fill::0#fill; seq::0; pos::0#pos; fxr::0#fxr; quote::0#quote; lq::0#lq; ca::0#ca; today::day0;
  system"rm -rf ",(1_string hdb),"/*"; if[count k:`execs`quote`fxr`order inter key `.; ![`.;();0b;k]]}
sys.tg:{[m] .qc.ts[m`now; m[`now]+0D00:05]}                                                 / a time for an event: the clock, or up to five minutes after it
/ the oracle, from the log
sys.rat:{[m;t;c] $[c=base; 1f; exec last rate from m[`fx] where ccy=c, time<=t]}     / the last rate at or before t; null if none
sys.mid:{[m;t;sy] r:select from m[`q] where sym=sy, time<=t; $[count r; midof[last r`bid; last r`ask]; 0n]}
sys.qty:{[m;sy] f:select from m[`f] where sym=sy; $[count f; sum (sgn each f`side)*(f`qty)*f`adj; 0]}   / (sum of nothing is (), not 0)
sys.cash:{[m;sy] f:select from m[`f] where sym=sy; $[count f; neg sum (sgn each f`side)*(f`qty)*(f`px)*f`rate; 0f]}   / booked at the rate known when the fill was made: a rate that arrives later, timed at or before it, does not re-book it
sys.val:{[m;sy] q:sys.qty[m;sy]; $[q=0; 0f; q*sys.mid[m;m`now;sy]*sys.rat[m;m`now;inst[sy;`ccy]]]}
sys.pnl:{[m;sy] sys.cash[m;sy]+sys.val[m;sy]}
sys.bps:{[f] 1e4*(sgn each f`side)*((f`px)-f`arr)%f`arr}
sys.slip:{[m;d;sy] f:`time xasc select from m[`f] where day=d, sym=sy; ([]time:f`time; id:f`id; bps:sys.bps f)}
sys.inv:{[m] ks:exec distinct sym from m`f; p:pnl m`now;
  .qc.eq["j"$sys.qty[m] each ks; pos[([]sym:ks);`qty]];
  r:p ([]sym:ks); .qc.eq["f"$sys.pnl[m] each ks; (r`real)+r`unreal];
  ds:day0+til 1+(m`day)-day0;
  .qc.eq[(ds cross ks)!sys.slip[m] .' ds cross ks; (ds cross ks)!{select time,id,bps from .oms.slip[x;y]} .' ds cross ks]; 1b}
/ the commands
sys.qs:{[m] exec distinct sym from m`q}                                                / the instruments with a quote, on which an order can be priced
sys.can:{[m;ev] exec id from m[`o] where not null .oms.o.nx[st;ev]}
sys.canf:{[m] exec id from m[`o] where not null .oms.o.nx[st;`fill], not null .oms.sys.rat[m;m`now] each .oms.inst[([]sym:sym);`ccy]}   / a fill needs a rate to convert at
sys.cmds:([cmd:`fx`quote`new`ack`cancel`fill`split`eod]
  w:   2 4 3 3 1 3 1 1f;
  pre: ({[m] 1b}; {[m] 1b}; {[m] 0<count sys.qs m}; {[m] 0<count sys.can[m;`ack]}; {[m] 0<count sys.can[m;`cxl]}; {[m] 0<count sys.canf m}; {[m] m`fresh}; {[m] not m`fresh});
  gen: ({[m] c:.qc.draw .qc.elem g.ccys; (sys.tg m; .qc.const c; g.rate c)};      / everything a step draws is drawn here, in gen, where the model sees it and post and upd can read it
        {[m] sy:.qc.draw .qc.elem g.syms; (sys.tg m; .qc.const sy; .qc.const g.quote sy)};
        {[m] sy:.qc.draw .qc.elem sys.qs m; (sys.tg m; .qc.const (sy; .qc.draw g.side; g.qty sy; g.lim sy))};   / (drawn as the generator is built, as in the lifecycle test)
        {[m] sys.pick[m;`ack]}; {[m] sys.pick[m;`cxl]};
        {[m] id:.qc.draw .qc.elem sys.canf m; (sys.tg m; .qc.const id; .qc.int (1;m[`o;id;`leaves]); .qc.flt g.px m[`o;id;`sym])};
        {[m] (.qc.const opn m`day; .qc.elem g.syms; .qc.int 2 4)};
        {[m] .qc.const m`day});
  run: ({[a] onfx[a 0;a 1;a 2]; a 2};
        {[a] onquote[a 0;a 1;a[2;0];a[2;1]]; a 2};
        {[a] t:a 0; o:a 1; id:neworder[t;o 0;o 1;o 2;o 3]; (t;id;order[id;`arr])};
        {[id] ack id}; {[id] cancel id};
        {[a] t:a 0; onfill[t;a 1;a 2;a 3]; (t;order[a 1;`st`leaves])};
        {[a] split[a 0;a 1;a 2]; pos[a 1;`qty]};
        {[d] eod d; ondisk d});
  post:({[m;a;o] rate[a 0;a 1]=o};
        {[m;a;o] now[a 1]=midof . o};
        {[m;a;o] (o 2)=sys.mid[m;o 0;a[1;0]]};
        {[m;id;o] o=`ack}; {[m;id;o] o=`cxl};
        {[m;a;o] (o 1)~(D[m[`o;a 1;`st];$[(a 2)=m[`o;a 1;`leaves];`fill;`part]]; m[`o;a 1;`leaves]-a 2)};
        {[m;a;o] (0^o)~(a 2)*sys.qty[m;a 1]};                                             / (no position is a null, and a null times anything is null)
        {[m;d;o] o});
  upd: ({[m;a;o] m[`now]:a 0; m[`fresh]:0b; m[`fx],:enlist `time`ccy`rate!a; m};
        {[m;a;o] m[`now]:a 0; m[`fresh]:0b; m[`q],:enlist `time`sym`bid`ask!(a 0;a 1;o 0;o 1); m};
        {[m;a;o] m[`now]:o 0; m[`fresh]:0b; m[`o],:enlist `id`sym`side`qty`px`st`leaves`arr!(o 1;a[1;0];a[1;1];a[1;2];a[1;3];`new;a[1;2];o 2); m};
        {[m;id;o] m[`o;id;`st]:`ack; m}; {[m;id;o] m[`o;id;`st]:`cxl; m};
        {[m;a;o] m[`now]:o 0; m[`fresh]:0b; r:m[`o;a 1]; m[`o;a 1;`st`leaves]:o 1;
          m[`f],:enlist `day`time`id`sym`side`qty`px`rate`arr`adj!(m`day;o 0;a 1;r`sym;r`side;a 2;a 3;sys.rat[m;o 0;inst[r`sym;`ccy]];r`arr;1); m};
        {[m;a;o] m[`o]:![m`o;((=;`sym;enlist a 1);(in;`st;enlist `new`ack`part));0b;`qty`leaves`px`arr!((*;`qty;a 2);(*;`leaves;a 2);(.oms.totick;`side;(%;`px;a 2);inst[a 1;`tick]);(%;`arr;a 2))];
          m[`f]:![m`f;enlist (=;`sym;enlist a 1);0b;(1#`adj)!enlist (*;`adj;a 2)]; m};
        {[m;d;o] m[`day]:d+1; m[`now]:opn d+1; m[`fresh]:1b; m}))
sys.pick:{[m;ev] .qc.elem sys.can[m;ev]}
sys.hooks:`m0`init`inv!(sys.m0;sys.init;sys.inv)
\d .
