/ M5 state machine tests. loaded by t/run.q
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
.t.t["sm: cmds must be a table with a cmd column"; ((@[.qc.draw;.qc.sm[h] 5;{x}]) like "qc: cmds must be a table*got type -7") and (@[.qc.draw;.qc.sm[h] ([]a:1 2);{x}]) like "qc: cmds needs a cmd column; columns are a"]
.t.t["sm: canary"; (@[.qc.sm[h;cm];1;{x}]) like "qc: too many*"]
/ C7, C11
.t.sz 0
.t.t["C7 sm records a choice at size 0"; {.qc.minimal x; 0<count .qc.C} .qc.sm[h] cm]
system"S 3"
.t.t["C11 sm replays across sizes"; {[g] .t.sz 5; v:.qc.draw g; c:.qc.C`v; .t.sz 100; v~.qc.replay[c] g} .qc.sm[h] cm2]
.t.sz 100
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
/ a command is recorded as its place among all the commands (A29). Objects are made one at a time and linked by their
/ numbers, and the system's walk along the links never counts past two. No more than five may be made, so the command
/ that makes them comes and goes; recorded as a place among the commands that could run, a step after the fifth
/ object changed its meaning when an earlier one was deleted, and the trace kept objects that it did not need
swn:`long$()
sww:{[p;a] n:0; c:a; while[$[c<0; 0b; n<count p]; n+:1; c:p c]; n}
swc:([cmd:`new`link`walk] pre:({[m] 5>count m};{[m] 1<count m};{[m] 0<count m});
  gen:({[m] ::};{[m] (.qc.elem til count m;.qc.elem til count m)};{[m] .qc.elem til count m});
  run:({[a] swn,:-1;};{[a] if[not a[0]=a 1; swn[a 0]:a 1];};{[a] 2&sww[swn;a]});
  post:({[m;a;o] 1b};{[m;a;o] 1b};{[m;a;o] o=sww[m;a]});
  upd:({[m;a;o] m,-1};{[m;a;o] $[a[0]=a 1; m; @[m;a 0;:;a 1]]};{[m;a;o] m}))
swt:{[s] r:.qc.chk[q,`seed`n!(s;100);.qc.sm[`m0`init!(`long$();{swn::`long$()})] swc;::]; $[`falsified=r`why; exec cmd from first r`notes; `$()]}
.t.t["sm: a machine with a command that comes and goes shrinks to the same trace at every seed"; all {`new`new`new`link`link`walk~swt x} each "i"$1+til 10]
/ neighbouring steps are swapped where that makes the whole simpler, though the step brought forward is the longer (A29)
swc2:([cmd:`a`b] gen:({[m] .qc.int 0 3};{[m] ::}); post:({[m;x;o] not `b in m};{[m;x;o] not `a in m}); upd:({[m;x;o] distinct m,`a};{[m;x;o] distinct m,`b}))
swt2:{[s] r:.qc.chk[q,`seed`n!(s;100);.qc.sm[enlist[`m0]!enlist `symbol$()] swc2;::]; $[`falsified=r`why; exec cmd from first r`notes; `$()]}
.t.t["sm: two steps that fail in either order end in the order that is simpler"; all {`a`b~swt2 x} each "i"$1+til 10]
/ on replay a number whose command cannot run stands for the next that can, the first after the last, and the record
/ says which ran (A29): a cannot run once the model is 2, c cannot run at first
swc3:([cmd:`a`b`c] pre:({[m] m<2};{[m] 1b};{[m] m>0}); upd:3#enlist {[m;x;o] m+1})
tr:.qc.strict[1 2 1 2 1 0 1 0 0] .qc.sm[enlist[`m0]!enlist 0] swc3
.t.t["sm: a number whose command cannot run stands for the next that can, and the last for the first"; `a`c`b`b~tr`cmd]
.t.t["sm: and the record is of the commands that ran"; 1 0 1 2 1 1 1 1 0~.qc.C`v]
r:.qc.recheck[.qc.sm[enlist[`m0]!enlist 0] swc3;::;1 0 1 2 1 1 1 1 0]
.t.t["sm: which replays as itself"; (not r`stale) and 1 0 1 2 1 1 1 1 0~r`choices]
/ a run that tries every input does not try the commands that cannot run: six commands of which one can run at each
/ step, up to three steps, are four traces, with nothing discarded
swc4:([cmd:`a`b`c`d`e`f] pre:{[k;m] k=m mod 6}@/:til 6; upd:6#enlist {[m;x;o] m+1})
r:.qc.chk[q;.qc.sm[`m0`steps!(0;0 3)] swc4;::]
.t.t["sm: a machine with one command that can run at each step is exhausted in a trace for each length"; (`exhausted=r`stop) and (4=r`n) and 0=count r`disc]
/ and a fresh draw is what it was without the commands that cannot run: no random number goes on a choice of one
swc5:([cmd:`a`b] pre:({[m] 1b};{[m] 0b}); gen:2#enlist {[m] .qc.int 0 99})
swd:{[cm] system"S 7"; tr:.qc.draw .qc.sm[`m0`steps!(0;5 5)] cm; tr`arg}
.t.t["sm: a command that can never run changes nothing in what is drawn"; swd[swc5]~swd 1#swc5]
/ the next that can, not the first that can: b cannot run, and stands for c
swc7:([cmd:`a`b`c] pre:({[m] 1b};{[m] 0b};{[m] 1b}))
.t.t["sm: a number whose command cannot run stands for the next that can, where an earlier one can too"; (enlist `c)~(.qc.strict[1 1 0] .qc.sm[enlist[`m0]!enlist 0] swc7)`cmd]
/ the first command that can run is the origin of the choice, so a step that had no choice is as simple as it can be
/ and its number is no part of what the steps are sorted by: thirty inputs that must differ end as til 30
swc8:([cmd:`a`b`c`d`e`f] pre:{[k;m] k=m mod 6}@/:til 6; upd:6#enlist {[m;x;o] m+1}; gen:6#enlist {[m] .qc.int 0 99})
r:.qc.chk[q;.qc.sm[enlist[`m0]!enlist 0] swc8;{not 30<=count distinct x`arg}]
.t.t["sm: the inputs of thirty steps that had no choice of command are sorted and lowered"; (til 30)~(r[`x]`x)`arg]
r:.qc.chk[q;.qc.sm[enlist[`m0]!enlist 0] swc8;{not 20<=count x}]
.t.t["sm: and twenty such steps cost no attempts on their commands (under 300)"; (20=count r[`x]`x) and 300>r`attempts]
/ a swap that brings the lesser step forward is tried though the two are less simple as they stand: the replay is shorter
swc9:([cmd:`a`b] pre:({[m] m=0};{[m] 1b}); gen:({[m] .qc.int 0 1};{[m] ::}); upd:({[m;x;o] m};{[m;x;o] m+1}))
swt9:{[s] r:.qc.chk[q,enlist[`seed]!enlist s;.qc.sm[enlist[`m0]!enlist 0] swc9;{not (1<count x) and `b=last x`cmd}]; (r[`x]`x)`cmd}
.t.t["sm: two steps that replay as fewer when swapped are swapped"; all {`b`b~swt9 x} each "i"$1+til 12]
/ a step's continue bit and its command are both the step's, and are not duplicates of one another
swc10:([cmd:`a`b`c] gen:3#enlist {[m] ::})
swt10:{[s] r:.qc.chk[q,`seed`n!(s;300);.qc.sm[enlist[`m0]!enlist 0] swc10;{[x] cm:x`cmd; $[4>count cm; 1b; not 1=count distinct 4#cm]}]; (r[`x]`x)`cmd}
.t.t["sm: four steps of one command are lowered to the first command together"; all {`a`a`a`a~swt10 x} each "i"$1+til 10]
/ what a probe notes of the commands that cannot run is not left behind it: a machine in a column of a table of 0 or 1 rows
swc11:([cmd:`a`b`c] pre:({[m] 0b};{[m] 1b};{[m] 1b}); gen:3#enlist {[m] ::})
r:.qc.chk[q,enlist[`n]!enlist 2000;.qc.tabr[0 1] `a`b!(.qc.lst[0 1] .qc.int 0 1;.qc.sm[`m0`steps!(0;1 1)] swc11);{1b}]
.t.t["sm: a machine in a table's column is exhausted as it was (7)"; (`exhausted=r`stop) and 7=r`n]
/ commands that can run at one visit of a prefix and not at the next (pre looks outside the model): the branch is dead
swk:0
swc12:([cmd:`a`b`c] pre:({[m] 0=swk mod 2};{[m] 1b};{[m] 1=swk mod 3}))
r:.qc.chk[q;.qc.sm[`m0`init`steps!(0;{swk+::1};0 2)] swc12;::]
.t.t["sm: a command that can run at one visit and not the next is a discard, and the run ends"; 0<sum r`disc]
/ a long as the hint of a fresh draw is that value, kept within the range
.t.t["ch: a long hint is the value drawn, within the range"; (7=.qc.draw {.qc.ch[5 9 5;7]}) and 5=.qc.draw {.qc.ch[5 9 5;1]}]
/ a candidate that gives a step a command that could not run there is put right before it is tried, to the command
/ that number stands for: the next that can run, and not the first
.qc.strict[1 2 0] .qc.sm[enlist[`m0]!enlist 0] swc7; .qc.cv:.qc.C`v; .qc.cC:.qc.C; .qc.cD:.qc.DV; .qc.cDv:.qc.cv
.t.t["sm: a candidate's number for a command that cannot run stands for the next that can"; (1 2 0~.qc.can 1 1 0) and 1 0 0~.qc.can 1 0 0]
.qc.tidy[]
/ a cell of pre gen run post upd may be a symbol naming a function, looked up when it is called: a fix to the function
/ is seen by again[], where a function held by value is not
swi:0
swinc:{[a] swi+:1; $[swi>3; 0; swi]}
swrd:{[a] swi}
swc13:([cmd:`inc`get] run:`swinc`swrd; post:(`swpost;{[m;a;o] o=m}); upd:({[m;a;o] m+1};{[m;a;o] m}))
swpost:{[m;a;o] o=m+1}
r:.qc.chk[q;.qc.sm[`m0`init!(0;{swi::0})] swc13;::]
swinc:{[a] swi+:1; swi}
.t.t["sm: a symbol names a command's function, looked up at each call, so again[] sees a fix"; (`falsified=r`why) and `ok=(.qc.again[])`why]
.t.t["sm: a symbol that names nothing is refused by name"; (@[.qc.draw;.qc.sm[enlist[`m0]!enlist 0] ([cmd:enlist `z] run:enlist `nosuch);{x}]) like "qc: nosuch*"]
/ a draw inside run belongs to the step (A31): clear's run draws a value that could never pass for a decision bit, its
/ two inputs are timed from the model's clock, and it resets the counter, so it can neither be swapped past an inc nor
/ dropped from the tail; a counter planted to fail at three increments shrinks to three steps (before A31, at 4 seeds of 10)
swc4:([cmd:`clear`nop`inc] w:2 1 1f; gen:({[m] (.qc.int (m`t;(m`t)+5); .qc.int 0 9)};{[m] ::};{[m] .qc.const 1}); run:({[a] swn4::0; .qc.draw .qc.int 100 1000};{[a] ::};{[a] swn4+:1; swn4}); post:({[m;a;o] 1b};{[m;a;o] 1b};{[m;a;o] o<3}); upd:({[m;a;o] m[`t]:a 0; m[`n]:0; m};{[m;a;o] m};{[m;a;o] m[`n]+:1; m}))
swt4:{[s] r:.qc.chk[q,`seed`n!(s;100);.qc.sm[`m0`init`steps!(`n`t!0 0;{swn4::0};6 30)] swc4;::]; $[`falsified=r`why; exec cmd from first r`notes; `$()]}
.t.t["sm: a draw inside run is the step's own, and the steps around it are deleted whole"; all {`inc`inc`inc~swt4 x} each "i"$1+til 10]
