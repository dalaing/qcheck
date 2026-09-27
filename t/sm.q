/ M5 state machine tests. loaded by t/run.q
.qc.new[]
.qc.cfg[`v]:0
q:.qc.cfg,`v`n`seed`db!(0;100;7;`)
system"S 7"
/ a real system: a counter in a global, with a planted bug (wraps after 3)
cnt:0; ni:0                                                   / (not N: .qc.N is the notes)
inc:{cnt::cnt+1; if[cnt>3; cnt::0]; cnt}
rd:{cnt}
cm:([cmd:`inc`get] run:(inc;{rd[]}); post:({[m;i;o] o=m+1};{[m;i;o] o=m}); upd:({[m;i;o] m+1};{[m;i;o] m}))
h:`m0`init!(0;{cnt::0; ni+:1})
/ shape
tr:.qc.draw .qc.sm[h,enlist[`steps]!enlist 2 2] cm
.t.t["sm: the value is a trace table with step cmd arg res model ok"; (98h=type tr) and (`step`cmd`arg`res`model`ok~cols tr) and 2=count tr]
.t.t["sm: defaults fill missing columns (pre, gen)"; all (tr`arg)~\:(::)]
.t.t["sm: init runs once per draw"; (ni=k+1) and 1=ni-k:ni-1]
tr:.qc.minimal .qc.sm[h] cm
.t.t["sm: the minimal trace is empty (a stop bit is still recorded)"; (0=count tr) and 0<count .qc.C]
/ the bug is found, reported as a falsification with the trace noted, and shrunk to the minimal sequence
r:.qc.chk[q;.qc.sm[h] cm;::]
.t.t["sm: a failed postcondition falsifies with qc.post"; (`falsified=r`why) and ("qc.post"~r`err) and (::)~r`x]
trc:last r`notes                                                / (trc, not t: .qc.t is the type zoo)
.t.t["sm: the note is the trace, last step marked not ok"; (98h=type trc) and (not last trc`ok) and all -1_trc`ok]
.t.t["sm: shrinks to four incs (the get steps are deleted)"; (4=count trc) and all `inc=trc`cmd]
.t.t["sm: model column is the model after each step"; 1 2 3 4~trc`model]
/ preconditions
cm2:([cmd:`a`b] pre:({[m] m<2};{[m] m>=2}); run:({[i] ::};{[i] ::}); upd:({[m;i;o] m+1};{[m;i;o] m+1}))
tr:.qc.replay[1 0 1 0 1 0 1 0 0] .qc.sm[`m0`steps!(0;4 4)] cm2
.t.t["sm: pre selects the available commands"; `a`a`b`b~tr`cmd]
.t.t["sm: no available command stops the sequence"; 0=count .qc.draw .qc.sm[enlist[`m0]!enlist 0] ([cmd:enlist `x] pre:enlist {[m] 0b})]
/ errors in run and post are failures with the trace noted
cm3:([cmd:enlist `boom] run:enlist {[i] '"kaboom"})
r:.qc.chk[q;.qc.sm[enlist[`m0]!enlist 0] cm3;::]
.t.t["sm: an error in run is a failure of the system, with its text and the trace so far"; (`falsified=r`why) and ("qc.run kaboom"~r`err) and 98h=type last r`notes]
.t.t["sm: the noted trace ends with the step that raised, marked not ok"; (`boom=(last r`notes)[`cmd] 0) and not (last r`notes)[`ok] 0]
cm3b:([cmd:enlist `bp] run:enlist {[i] 7}; post:enlist {[m;i;o] '"nope"})
r:.qc.chk[q;.qc.sm[enlist[`m0]!enlist 0] cm3b;::]
.t.t["sm: a post that raises notes the step with its result"; ("qc.post nope"~r`err) and (7~(last r`notes)[`res] 0) and not (last r`notes)[`ok] 0]
cm3c:([cmd:enlist `put] gen:enlist {[m] .qc.int 0 9}; run:enlist {[i] i}; post:enlist {[m;i;o] 2>count m}; upd:enlist {[m;i;o] m,enlist[`v]!enlist i})
r:.qc.chk[q;.qc.sm[enlist[`m0]!enlist ([]v:`long$())] cm3c;::]
.t.t["sm: a model that holds a table is left out of the noted trace; an atom model stays (line 25)"; not `model in cols last r`notes]
/ inputs shrink with the sequence
cm4:([cmd:enlist `put] gen:enlist {[m] .qc.int 0 99}; run:enlist {[i] i}; post:enlist {[m;i;o] 50>sum m,i}; upd:enlist {[m;i;o] m,i})
r:.qc.chk[q;.qc.sm[enlist[`m0]!enlist `long$()] cm4;::]
trc:last r`notes
.t.t["sm: inputs shrink: one put of 50"; (1=count trc) and 50~first trc`arg]
/ invariants and weights (M10)
cm5:([cmd:`inc`dec] run:({[a] ::};{[a] ::}); upd:({[m;a;o] m+1};{[m;a;o] m-1}))
r:.qc.chk[q;.qc.sm[`m0`inv!(0;{[m] m<3})] cm5;::]
.t.t["sm: a failed invariant falsifies with qc.inv, the trace noted, and shrinks to the three steps that break it"; (`falsified=r`why) and ("qc.inv"~r`err) and (3=count trc) and all `inc=(trc:last r`notes)`cmd]
.t.t["sm: an invariant that errors is qc.inv with the text"; "qc.inv boom"~(.qc.chk[q;.qc.sm[`m0`inv!(0;{[m] '"boom"})] cm5;::])`err]
.t.t["sm: a non-function inv is refused"; (@[.qc.draw;.qc.sm[`m0`inv!(0;5)] cm5;{x}]) like "qc: inv*"]
cm6:([cmd:`a`b] run:({[a] ::};{[a] ::}); w:3 1f)
tr:.qc.draw .qc.sm[`m0`steps!(0;200 200)] cm6
.t.t["sm: w weights the choice among available commands (3:1 over 200 steps, within 3 sigma)"; (avg `a=tr`cmd) within 0.65 0.85]
.t.t["sm: weights must be positive numbers"; ((@[.qc.draw;.qc.sm[enlist[`m0]!enlist 0] update w:0 1f from cm6;{x}]) like "qc: cmds: w*") and (@[.qc.draw;.qc.sm[enlist[`m0]!enlist 0] update w:`x`y from cm6;{x}]) like "qc: cmds: w*"]
/ validation and the canary
.t.t["sm: cmds must be a table with a cmd column"; ("qc: cmds"~@[.qc.draw;.qc.sm[h] 5;{x}]) and "qc: cmds"~@[.qc.draw;.qc.sm[h] ([]a:1 2);{x}]]
.t.t["sm: canary"; (@[.qc.sm[h;cm];1;{x}]) like "qc: too many*"]
/ C7, C11
.t.sz 0
.t.t["C7 sm records a choice at size 0"; {.qc.minimal x; 0<count .qc.C} .qc.sm[h] cm]
system"S 3"
.t.t["C11 sm replays across sizes"; {[g] .t.sz 5; v:.qc.draw g; c:.qc.C`v; .t.sz 100; v~.qc.replay[c] g} .qc.sm[h] cm2]
.t.sz 100
.qc.cfg[`v]:1
/ C9: fini runs on every way out of a run, including the harness's own errors and an exhausted strict replay
fc:0; hf:`m0`fini!(0;{fc+:1})
.t.e[.qc.draw;.qc.sm[hf] ([cmd:enlist `a] pre:enlist {[m] '"prebang"})]
.t.t["sm: fini runs when pre raises"; 1=fc]
fc:0; .t.e[.qc.draw;.qc.sm[hf] ([cmd:enlist `a] upd:enlist {[m;a;o] '"updbang"})]
.t.t["sm: fini runs when upd raises"; 1=fc]
fc:0; .t.e[.qc.strict[enlist 1];.qc.sm[hf] ([cmd:enlist `a] gen:enlist {[m] .qc.int 0 9})]
.t.t["sm: fini runs when a strict replay runs out of choices"; 1=fc]
fc:0; .qc.draw .qc.sm[hf] ([cmd:enlist `a] run:enlist {[a] ::})
.t.t["sm: fini runs exactly once on a clean run"; 1=fc]
