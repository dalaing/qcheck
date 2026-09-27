/ examples/mdp/props.q — the pieces' properties that survived (LOG.md entries 3, 8, 10, 13, 16), as one suite for
/ .qc.checks. Loaded by run.q after mdp.q; the generators are the log's (steps/08_gen.q).
system"l examples/mdp/steps/08_gen.q"
replay:{[ev] .mdp.seq::0; .mdp.quote::0#.mdp.quote; .mdp.qcache::0#.mdp.qcache; {[o;e] $[`quote=e`kind; [.mdp.onquote enlist `time`sym`bid`ask#e; o]; o,.mdp.enrich1 enlist `time`sym`px`qty#e]}/[0#.mdp.enrich1 select time,sym,px,qty from ev;ev]}
same:{[a;b] .qc.eq[`sym`minute xasc 0!a; `sym`minute xasc 0!b]}
byk:{k:asc key x; k!x k}
mult:{exec sym!mult from .mdp.inst}
cash:{[f] exec sum mult[][sym]*qty*px*-1 1 `buy`sell?side from f}
reset:{.mdp.seq::0; .mdp.today::2024.01.02; .mdp.quote::0#.mdp.quote; .mdp.qcache::0#.mdp.qcache; .mdp.trade::0#.mdp.trade; .mdp.bar::0#.mdp.bar; .mdp.pos::0#.mdp.pos; .mdp.ren::0#.mdp.ren}
feed:{[ev] {[e] $[`quote=e`kind; .mdp.onquote enlist `time`sym`bid`ask#e; .mdp.ontrade enlist `time`sym`px`qty#e]} each ev;}
ask:{[d;s;a;b] `bars`vwap`trades!(.mdp.qbars[d;s;a;b]; .mdp.qvwap[d;s]; .mdp.qtrades[d;s])}
props:()!()
props[`round_idempotent]:(.mdp.g.ref; {s:x 0; px:x 1; r:.mdp.round[s;px]; r=.mdp.round[s;r]})
props[`round_within_half_a_tick]:(.mdp.g.ref; {s:x 0; px:x 1; (.5+1e-9)>=abs[px-.mdp.round[s;px]]%.mdp.inst[s;`tick]})   / (a float tolerance: entry 24)
props[`lots]:((.mdp.g.ref; .qc.int 0 1000); {[sp;q] l:.mdp.lots[sp 0;q]; (l<=q) and 0=l mod .mdp.inst[sp 0;`lot]})
props[`canon_idempotent]:(.mdp.g.ren; {s:x 0; d:x 1; c:.mdp.canon[s;d]; c=.mdp.canon[c;d]})
props[`canon_is_a_name_or_a_rename]:(.mdp.g.ren; {s:x 0; d:x 1; (.mdp.canon[s;d]=s) or .mdp.canon[s;d] in exec new from .mdp.ren where eff<=d})
props[`enrich_incremental_equals_batch]:(.mdp.g.stream; {inc:replay x; bat:.mdp.enrichb[select seq,time,sym,px,qty from inc; .mdp.quote]; .qc.eq[inc;bat]})
props[`bid_le_ask]:(.mdp.g.stream; {inc:replay x; all (inc[`bid]<=inc`ask) or null inc`bid})
props[`bars_fold_equals_batch]:(.mdp.g.trades; {.mdp.bar::0#.mdp.bar; .mdp.onbar x; same[.mdp.bar; .mdp.barsb x]})
props[`bars_split_anywhere]:((.mdp.g.trades; .qc.int 0 40); {[t;k] k:k&count t; .mdp.bar::0#.mdp.bar; .mdp.onbar k#t; .mdp.onbar k _ t; a:.mdp.bar; .mdp.bar::0#.mdp.bar; .mdp.onbar t; same[a;.mdp.bar]})
props[`position_is_the_signed_sum]:(.mdp.g.fills; {f:x 0; .mdp.pos::0#.mdp.pos; .mdp.onfill f; .qc.eq[byk exec sym!qty from .mdp.pos; byk exec sum qty*1 -1 `buy`sell?side by sym from f]})
props[`book_balances]:(.mdp.g.fills; {f:x 0; mk:x 1; .mdp.pos::0#.mdp.pos; .mdp.onfill f; lhs:(exec sum real from .mdp.pos)+.mdp.unreal mk; rhs:cash[f]+exec sum mult[][sym]*qty*mk sym from .mdp.pos; 1e-6>abs lhs-rhs})
props[`cost_within_the_fills]:(.mdp.g.fills; {f:x 0; .mdp.pos::0#.mdp.pos; .mdp.onfill f; p:0!select from .mdp.pos where qty<>0; r:select mn:min px,mx:max px by sym from f; k:([]sym:p`sym); all (p[`cost]>=(r[k]`mn)-1e-9) and p[`cost]<=1e-9+r[k]`mx})
props[`round_trip_realises_nothing]:((.qc.elem `A`B; .qc.elem 1 10 100; .qc.flt 1 100); {[s;q;p] .mdp.inst::([sym:`A`B] tick:0.01 0.01; lot:1 1; mult:1 10); .mdp.pos::0#.mdp.pos; .mdp.onfill ([]sym:s,s; side:`buy`sell; qty:q,q; px:p,p); (0=.mdp.pos[s;`qty]) and 1e-9>abs .mdp.pos[s;`real]})   / (a float tolerance: the average is an ulp off at some prices)
props[`queries_memory_equals_disk]:((.mdp.g.stream; .qc.ts[.mdp.open;.mdp.close]; .qc.ts[.mdp.open;.mdp.close]); {[ev;a;b] w:asc (a;b); reset[]; feed ev; s:exec sym from .mdp.inst; mem:ask[2024.01.02;;w 0;w 1] each s; .mdp.eod 2024.01.02; .qc.eq[mem; ask[2024.01.02;;w 0;w 1] each s]})
props[`two_days_on_disk]:((.mdp.g.stream; .mdp.g.stream); {[e1;e2] reset[]; feed e1; s:exec sym from .mdp.inst; d1:ask[2024.01.02;;.mdp.open;.mdp.close] each s; .mdp.eod 2024.01.02; feed update time+1D from e2; d2:ask[2024.01.03;;.mdp.open+1D;.mdp.close+1D] each s; .mdp.eod 2024.01.03; .qc.eq[(d1;d2); (ask[2024.01.02;;.mdp.open;.mdp.close] each s; ask[2024.01.03;;.mdp.open+1D;.mdp.close+1D] each s)]})
props[`the_cache_survives_the_close]:(.mdp.g.stream; {reset[]; feed x; c:.mdp.qcache; .mdp.eod 2024.01.02; (c~.mdp.qcache) and (0=count .mdp.trade) and 0=count .mdp.bar})
