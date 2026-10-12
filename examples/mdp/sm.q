/ examples/mdp/sm.q — the stateful test of the whole pipeline (LOG.md entries 17-23; the test is steps/25_sm.q),
/ with the seam labels of run 2, as one entry for .qc.checks. Loaded by run.q after mdp.q.
system"l ",.mdp.root,"/steps/25_sm.q"
/ the seam labels: what a trace exercised, so a passing run says what it reached (entries 18, 20, 23). The
/ trace's model column is the model after the step; a fill's argument is (sym;side;qty;px), the others' sym is at 1.
argsym:{[r] r[`arg] $[`fill=r`cmd; 0; 1]}
seams:{[tr] c:tr`cmd;
  .qc.classify[`rename_in_effect; any (c=`eod) and 0<sums c=`rename];
  .qc.classify[`old_name_used_after_its_rename; any {[r] $[r[`cmd] in `quote`trade`late`fill; argsym[r]<>.mdp.canon[argsym r;r[`model]`day]; 0b]} each tr];
  .qc.classify[`positions_merged_at_a_close; any {[r] $[`eod=r`cmd; any (exec sym from r[`model]`f)<>.mdp.canon'[exec sym from r[`model]`f;r[`model]`day]; 0b]} each tr];
  .qc.classify[`query_of_a_past_day_by_a_renamed_name; any {[r] $[`query=r`cmd; (r[`arg][0]<r[`model]`day) and (r[`arg][1])<>.mdp.canon[r[`arg][1];r[`model]`day]; 0b]} each tr];
  .qc.classify[`late_trade_then_query_of_its_day; any {[r] $[`query=r`cmd; (r[`arg][0]) in "d"$exec time from r[`model][`t] where arr>"d"$time; 0b]} each tr];
  .qc.classify[`bust_of_a_past_day; any {[r] $[`bust=r`cmd; ("d"$first exec time from r[`model][`t] where seq=r`arg)<r[`model]`day; 0b]} each tr];
  1b}
stateful:enlist[`stateful_60_steps]!enlist (.qc.sm[.mdp.hooks,enlist[`steps]!enlist 0 60] .mdp.cmds; seams)
