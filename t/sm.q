/ M5 state machine tests. loaded by t/run.q
.qc.new[]
.qc.cfg[`v]:0
q:.qc.cfg,`v`n`seed`db!(0;100;7;`)
system"S 7"
/ a real system: a counter in a global, with a planted bug (wraps after 3)
N:0; NI:0
inc:{N::N+1; if[N>3; N::0]; N}
rd:{N}
cm:([cmd:`inc`get] run:(inc;{rd[]}); post:({[m;i;o] o=m+1};{[m;i;o] o=m}); upd:({[m;i;o] m+1};{[m;i;o] m}))
h:`m0`init!(0;{N::0; NI+:1})
/ shape
tr:.qc.draw .qc.sm[h,enlist[`steps]!enlist 2 2] cm
.t.t["sm: the value is a trace table with step cmd arg res model ok"; (98h=type tr) and (`step`cmd`arg`res`model`ok~cols tr) and 2=count tr]
.t.t["sm: defaults fill missing columns (pre, gen)"; all (tr`arg)~\:(::)]
.t.t["sm: init runs once per draw"; (NI=k+1) and 1=NI-k:NI-1]
tr:.qc.minimal .qc.sm[h] cm
.t.t["sm: the minimal trace is empty (a stop bit is still recorded)"; (0=count tr) and 0<count .qc.C]
/ the bug is found, reported as a falsification with the trace noted, and shrunk to the minimal sequence
r:.qc.chk[q;.qc.sm[h] cm;::]
.t.t["sm: a failed postcondition falsifies with qc.post"; (`falsified=r`why) and ("qc.post"~r`err) and (::)~r`x]
t:last r`notes
.t.t["sm: the note is the trace, last step marked not ok"; (98h=type t) and (not last t`ok) and all -1_t`ok]
.t.t["sm: shrinks to four incs (the get steps are deleted)"; (4=count t) and all `inc=t`cmd]
.t.t["sm: model column is the model after each step"; 1 2 3 4~t`model]
/ preconditions
cm2:([cmd:`a`b] pre:({[m] m<2};{[m] m>=2}); run:({[i] ::};{[i] ::}); upd:({[m;i;o] m+1};{[m;i;o] m+1}))
tr:.qc.replay[1 0 1 0 1 0 1 0 0] .qc.sm[`m0`steps!(0;4 4)] cm2
.t.t["sm: pre selects the available commands"; `a`a`b`b~tr`cmd]
.t.t["sm: no available command stops the sequence"; 0=count .qc.draw .qc.sm[enlist[`m0]!enlist 0] ([cmd:enlist `x] pre:enlist {[m] 0b})]
/ errors in run and post are failures with the trace noted
cm3:([cmd:enlist `boom] run:enlist {[i] '"kaboom"})
r:.qc.chk[q;.qc.sm[enlist[`m0]!enlist 0] cm3;::]
.t.t["sm: an error in run is a failure of the system, with its text and the trace so far"; (`falsified=r`why) and ("qc.run kaboom"~r`err) and 98h=type last r`notes]
/ inputs shrink with the sequence
cm4:([cmd:enlist `put] gen:enlist {[m] .qc.int 0 99}; run:enlist {[i] i}; post:enlist {[m;i;o] 50>sum m,i}; upd:enlist {[m;i;o] m,i})
r:.qc.chk[q;.qc.sm[enlist[`m0]!enlist `long$()] cm4;::]
t:last r`notes
.t.t["sm: inputs shrink: one put of 50"; (1=count t) and 50~first t`arg]
/ validation and the canary
.t.t["sm: cmds must be a table with a cmd column"; ("qc: cmds"~@[.qc.draw;.qc.sm[h] 5;{x}]) and "qc: cmds"~@[.qc.draw;.qc.sm[h] ([]a:1 2);{x}]]
.t.t["sm: canary"; (@[.qc.sm[h;cm];1;{x}]) like "qc: too many*"]
/ C7, C11
.qc.reset[`long$();0;0b;0b]
.t.t["C7 sm records a choice at size 0"; {.qc.minimal x; 0<count .qc.C} .qc.sm[h] cm]
system"S 3"
.t.t["C11 sm replays across sizes"; {[g] .qc.reset[`long$();5;0b;0b]; v:.qc.draw g; c:.qc.C`v; .qc.new[]; v~.qc.replay[c] g} .qc.sm[h] cm2]
.qc.new[]
.qc.cfg[`v]:1
