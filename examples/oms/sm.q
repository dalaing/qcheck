/ examples/oms/sm.q — the stateful test of the whole system (LOG.md entry 12; the test is steps/30_sm.q), with the
/ labels of what a trace reached, as one entry for .qc.checks. Loaded by run.q after oms.q and props.q (the
/ generators and the lifecycle test's o.nx come from there).
system"l ",.oms.root,"/steps/30_sm.q"
reach:{[tr] c:tr`cmd; .qc.classify[`fill;`fill in c]; .qc.classify[`eod;`eod in c]; .qc.classify[`split;`split in c]; .qc.classify[`two_days;1<sum c=`eod];
  .qc.classify[`fill_then_split;(`fill in c) and (`split in c) and first[where c=`fill]<last where c=`split];
  .qc.classify[`split_then_fill;(`fill in c) and (`split in c) and last[where c=`fill]>first where c=`split]; 1b}
stateful:enlist[`whole_system]!enlist (.qc.sm[.oms.sys.hooks] .oms.sys.cmds; reach)
