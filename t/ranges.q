/ the range grid: generators x range shapes x modes. loaded by t/run.q
system"S 7"                                                                       / fresh draws in modes (C8)
RS:(0 0;0 1;-1 1;0 9;5 5;-0W 0W;0 0W;-0W 0;0W 0W;-0W -0W;7 9 8;{0,x};{(neg x;x)};.qc.lin[0;1000])
nmr:.Q.s1
inr:{[r;v] rr:.qc.rng r; all v within rr 0 1}                                / at the current size
/ modes[name;gen;range;f;org;ex]: f maps a value to the number the range constrains (identity, or count for
/ lists); org is the documented minimal of that number (the range's origin for int and flt, lo for a list's
/ length); ex says whether the range width is the whole input space (true for int only)
modes:{[nm;g;r;f;org;ex]
  .t.t[nm,": 200 fresh draws in range"; inr[r] f each {.qc.draw x} each 200#enlist g];
  .t.t[nm,": minimal is the documented origin"; org[.qc.rng r]~f .qc.minimal g];
  .t.t[nm,": replays its own choices"; {[g] v:.qc.draw g; v~.qc.replay[.qc.C`v] g} g];
  .t.t[nm,": shrink-mode replay is exact"; {[g] v:.qc.draw g; c:.qc.C`v; rr:@[.qc.strict[c];g;{`ERR}]; (rr~v) and .qc.i=count c} g];
  if[ex; w:.qc.wid . .qc.rng[r] 0 1;
    if[w<=100; .t.t[nm,": a space that fits the budget is exhausted"; (`exhausted=res`stop) and w=(res:.qc.chk[q;g;{1b}])`n]];
    if[w>100; .t.t[nm,": a space beyond the budget samples"; `n=(.qc.chk[q;g;{1b}])`stop]]];}
{[r] modes["int ",nmr r;.qc.int r;r;::;{x 2};1b]} each RS
{[r] modes["lst[",nmr[r],"] length";.qc.lst[r] .qc.int 0 9;r;count;{x 0};0b]} each (0 0;0 1;0 9;5 5;7 9 8;{0,x})
/ the length checks above test the *list* value against the range; do it explicitly
.t.t["lst: lengths within every finite range at size 100"; all {[r] rr:.qc.rng r; all (count each {.qc.draw x} each 100#enlist .qc.lst[r] .qc.int 0 9) within rr 0 1} each (0 0;0 1;0 9;5 5;7 9 8)]
{[r] modes["flt ",nmr r;.qc.flt r;r;::;{"f"$x 2};0b]} each (0 0;0 1;-1 1;0 9;5 5)   / flt takes lo hi only
.t.t["flt: a huge range stays finite and in range"; all {(not null x) and x within -1e300 1e300} {.qc.draw x} each 100#enlist .qc.flt -1e300 1e300]
.t.t["elem: every finite small range as a list"; all {[r] rr:.qc.rng r; all ({.qc.draw x} each 100#enlist .qc.elem rr[0]+til 1+rr[1]-rr 0) within rr 0 1} each (0 0;0 1;-1 1;0 9;5 5)]
/ invalid ranges say so
.t.t["invalid ranges signal qc: range"; all {(@[.qc.draw;x;{x}]) like "qc: range*"} each (.qc.int 5 1;.qc.int enlist 5;.qc.int 1 2 3 4;.qc.flt 5 1;.qc.lst[3 1] .qc.bool)]
.qc.new[]
