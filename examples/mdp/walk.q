/ examples/mdp/walk.q — what the sessions of WALKTHROUGH.md load beside the steps: the code that feeds the pipeline
/ and asks it questions, and the longer properties. WALKTHROUGH.md shows each of these where it is first used.
/ Load it from the repository root, after qc.q and the steps of the piece under test.

/ ---- piece 2: quotes and enrichment ----
/ replay a stream of events in order, as first written: quotes to the cache, each trade enriched as it arrives
replay0:{[ev] .mdp.quote::0#.mdp.quote; .mdp.qcache::0#.mdp.qcache; out:0#.mdp.enrich1 select time,sym,px,qty from ev;
  {[e] $[`quote=e`kind; .mdp.onquote enlist `time`sym`bid`ask#e; out,:.mdp.enrich1 enlist `time`sym`px`qty#e]} each ev;
  out}
/ the same as a fold: the enriched trades so far are passed along, not reached for
replay:{[ev] .mdp.seq::0; .mdp.quote::0#.mdp.quote; .mdp.qcache::0#.mdp.qcache;
  {[o;e] $[`quote=e`kind; [.mdp.onquote enlist `time`sym`bid`ask#e; o]; o,.mdp.enrich1 enlist `time`sym`px`qty#e]}/[0#.mdp.enrich1 select time,sym,px,qty from ev;ev]}
/ the rule: enriching each trade as it arrives (rp replays the stream) agrees with enriching them all afterwards
agree0:{[rp;ev] inc:rp ev;
  bat:.mdp.enrichb[select time,sym,px,qty from ev where kind=`trade; select time,sym,bid,ask from ev where kind=`quote];
  .qc.eq[inc;bat]}
/ the rule once the feed stamps a sequence number: the batch side joins the stamped trades to the stamped quotes
agree:{[ev] inc:replay ev; bat:.mdp.enrichb[select seq,time,sym,px,qty from inc; .mdp.quote]; .qc.eq[inc;bat]}

/ ---- piece 3: bars ----
fold:{[t] .mdp.bar::0#.mdp.bar; .mdp.onbar t; .mdp.bar}                        / the bars of a day, trade by trade
same:{[a;b] .qc.eq[`sym`minute xasc 0!a; `sym`minute xasc 0!b]}                / equal as bar tables: sorted by key first
split:{[t;k] k:k&count t; .mdp.bar::0#.mdp.bar; .mdp.onbar k#t; .mdp.onbar k _ t; a:.mdp.bar; same[a;fold t]}   / fed in two batches, or in one

/ ---- piece 4: positions ----
book:{[f] .mdp.pos::0#.mdp.pos; .mdp.onfill f;}                                / book a fill log from flat
signed:{[f] exec sum qty*1 -1 `buy`sell?side by sym from f}                    / the signed quantity filled, per sym
byk:{k:asc key x; k!x k}                                                       / a dict in the order of its keys
mult:{exec sym!mult from .mdp.inst}                                            / the contract multiplier, per sym
cash:{[f] exec sum mult[][sym]*qty*px*-1 1 `buy`sell?side from f}              / the cash the fills brought in (a buy pays out)
/ the book balances: realised plus unrealised is the cash flow plus the open position at the mark
balances:{[x] f:x 0; mk:x 1; book f;
  lhs:(exec sum real from .mdp.pos)+.mdp.unreal mk;
  rhs:cash[f]+exec sum mult[][sym]*qty*mk sym from .mdp.pos;
  1e-6>abs lhs-rhs}
/ the cost of an open position lies between the lowest and the highest price paid
costs:{[x] f:x 0; book f; p:0!select from .mdp.pos where qty<>0; r:select mn:min px,mx:max px by sym from f; k:([]sym:p`sym);
  all (p[`cost]>=(r[k]`mn)-1e-9) and p[`cost]<=1e-9+r[k]`mx}
/ buying and selling the same quantity at one price leaves nothing: no position, nothing realised
trip:{[s;q;p] .mdp.inst::([sym:`A`B] tick:0.01 0.01; lot:1 1; mult:1 10);
  book ([]sym:s,s; side:`buy`sell; qty:q,q; px:p,p);
  (0=.mdp.pos[s;`qty]) and 1e-9>abs .mdp.pos[s;`real]}

/ ---- piece 5: end of day ----
day1:2024.01.02
reset:{.mdp.seq::0; .mdp.today::day1; .mdp.quote::0#.mdp.quote; .mdp.qcache::0#.mdp.qcache; .mdp.trade::0#.mdp.trade; .mdp.bar::0#.mdp.bar}
feed:{[ev] {[e] $[`quote=e`kind; .mdp.onquote enlist `time`sym`bid`ask#e; .mdp.ontrade enlist `time`sym`px`qty#e]} each ev;}
ask:{[d;s;a;b] `bars`vwap`trades!(.mdp.qbars[d;s;a;b]; .mdp.qvwap[d;s]; .mdp.qtrades[d;s])}   / the three queries, of one sym
/ the answers from memory, before the close, are the answers from disk, after it
memdisk:{[ev;a;b] w:asc (a;b); reset[]; feed ev; s:exec sym from .mdp.inst;
  mem:ask[day1;;w 0;w 1] each s;
  .mdp.eod day1;
  .qc.eq[mem; ask[day1;;w 0;w 1] each s]}
/ two days closed in turn can both still be asked about
twodays:{[e1;e2] reset[]; feed e1; s:exec sym from .mdp.inst;
  d1:ask[day1;;.mdp.open;.mdp.close] each s; .mdp.eod day1;
  feed update time+1D from e2;
  d2:ask[day1+1;;.mdp.open+1D;.mdp.close+1D] each s; .mdp.eod day1+1;
  .qc.eq[(d1;d2); (ask[day1;;.mdp.open;.mdp.close] each s; ask[day1+1;;.mdp.open+1D;.mdp.close+1D] each s)]}
/ the close empties the day's tables and leaves the quote cache as it was
closes:{[ev] reset[]; feed ev; c:.mdp.qcache; .mdp.eod day1; (c~.mdp.qcache) and (0=count .mdp.trade) and 0=count .mdp.bar}

/ ---- the state machine ----
/ what a trace reached: a property that always passes and counts the traces in which each thing happened
reached:{[tr] c:tr`cmd;
  .qc.classify[`close; `eod in c];
  .qc.classify[`late; `late in c];
  .qc.classify[`late_after_a_close; any (c=`late) and 0<sums c=`eod];
  .qc.classify[`late_timed_yesterday; any {[r] $[`late=r`cmd; ("d"$r[`arg]0)<r[`model]`day; 0b]} each tr];
  .qc.classify[`query_of_a_past_day; any {[r] $[`query=r`cmd; r[`arg][0]<r[`model]`day; 0b]} each tr];
  1b}
