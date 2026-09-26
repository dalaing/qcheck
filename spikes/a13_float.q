\l spikes/h.q
\l spikes/bench.q
/ A13: a float built from integer choices. Layout is uniform (every field always drawn) so no alternative is
/ shorter than another. Value = sign * m * 2^e with the exponent before the mantissa: shrinking e toward 0 first
/ makes integers simpler than fractions and, because m stays put when e moves, the search can cross between them
/ (a three-field ip + num/2^k layout gets stuck: -0.5 cannot reach -1 by any single move).
/ [kind; special; sign; e; m]  value = kind ? (0n 0w -0w)[special] : sign * m * 2^e
fl:{[d] .qc.dd[d;"fl"]; kind:.qc.ch[(0;1;0);0.05]; sp:.qc.ch[(0;2;0);`u]; s:.qc.ch[(0;1;0);0.3];
  e:.qc.ch[(-60;60;0);::]; m:.qc.ch[(0;9007199254740991;0);::];
  $[kind; (0n;0w;-0w) sp; (1 -1 s)*m*2 xexp e]}
fin:{not (null x) or 0w=abs x}                                    / q: 0n=0n is true and 0n<100 is true; say what you mean
cases:([] name:`lt100`x_plus_1`x_plus_1_tol`lt_half`nan`inf`neg`quarter;
  spec:8#enlist fl;
  prop:({x<100};{$[fin x; 0<>(x+1)-x; 1b]};{$[fin x; x<>x+1; 1b]};{x<0.5};{not null x};{not x>1e300};{$[null x; 1b; x>=0]};{not x within 0.25 0.75});   / q: 0n>=0 is false, so NaN is a genuine counterexample of x>=0
  minp:({100f~x`x};{9007199254740992f~x`x};{(x`x) within 8.7e12 1e13};{1f~x`x};{null x`x};{0w~x`x};{-1f~x`x};{0.5~x`x});
  lists:8#0b)
T:.b.run[.b.q,enlist[`n]!enlist 1000;cases]
.b.show T
.h.t["floats shrink to the intended simplest values"; all T`ok]
.h.t["q's tolerant <> makes x<>x+1 first fail near 2^43, not 2^53"; (exec first found from T where name=`x_plus_1_tol)[`x]<1e13]
/ the layout lesson: under the shortlex order a shorter alternative ranks as simpler. with specials on a 2-choice
/ branch and normals on a 4-choice branch, 0w would rank below 100f for x<100 whenever the search reached both
.h.t["shortlex ranks the shorter special branch (0w) below the normal branch (100f)"; .qc.less[.qc.skey[1 1;0 0];.qc.skey[0 0 100 0;0 0 0 0]]]
.h.done[]
