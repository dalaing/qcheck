/ shared shrink benchmark: .b.cases[L] builds the case table for a list constructor L (.qc.list or an alternative);
/ .b.run[cfg;cases] runs them and reports what was found, whether it is the analytic minimum, and the cost
if[not `qc in key `; system"l qc.q"]
.qc.cfg[`v]:0
.b.q:.qc.cfg,`v`n`seed`db!(0;100;7;`)
.b.tree:.qc.rec[2 2;.qc.int 0 9;{(x 0;x 1)}]
.b.rose:.qc.rec[0 4;.qc.int 0 9;{(`n;x)}]
.b.depth:{$[0h=type x; 1+max .z.s each x; 0<type x; 1; 0]}
.b.nodes:{$[0h=type x; 1+sum .z.s each x; 0<type x; 1; 0]}
/ columns: name, spec, prop, minimal? (predicate on the named counterexample dict), uses lists?
.b.cases:{[L] ints:L .qc.int 0 99;
  ([] name:`sorted`reverse`distinct`len5`sum100`adjeq`bound`neg`twoints`nested`bound5`tree3`tree4`rose3`filtered`bigint`interactive`squares;
     spec:(ints;ints;ints;ints;ints;ints;.qc.int 0 99;.qc.int -99 99;(.qc.int 0 9;.qc.int 0 9);L L .qc.int 0 9;L L .qc.int 0 9;.b.tree;.b.tree;.b.rose;L .qc.such[{x>0}] .qc.int -9 9;.qc.int 0 0W;::;ints);
     prop:({x~asc x};{x~reverse x};{x~distinct x};{5>count x};{100>=sum x};{not any (=)':[x]};{x<=50};{x>=0};{x>=y};{6>sum count each x};{5>=sum raze x};
           {.b.depth[x]<3};{.b.nodes[x]<4};{$[0h=type x; 3>count x 1; 1b]};{x~asc x};{x<1000000};{n:.qc.draw .qc.int 0 99; n<10};{100>sum x*x});
     minp:({1 0~x`x};{0 1~x`x};{0 0~x`x};{(5#0)~x`x};{2 99~x`x};{0 0~x`x};{51~x`x};{-1~x`x};{0 1~value x};{(6=sum count each x`x) and all 0=raze x`x};
          {(enlist enlist 6)~x`x};{(3=.b.depth x`x) and 3=.b.nodes x`x};{4=.b.nodes x`x};{(3=count x[`x;1]) and all 0=raze x[`x;1]};{2 1~x`x};{1000000~x`x};{1b};{(enlist 10)~x`x});
     lists:110111000110001001b)}
.b.one:{[c;r] t0:.z.p; o:.qc.chk[c;r`spec;r`prop]; ms:(.z.p-t0)%1000000;
  found:$[`falsified=o`why; $[(::)~o`x; o`choices; o`x]; o`why];
  `name`found`ok`shrinks`attempts`ms!(r`name;found;$[`falsified=o`why; r[`minp] $[(::)~o`x; enlist[`x]!enlist o`choices; o`x]; 0b];o`shrinks;o`attempts;"j"$ms)}
.b.run:{[c;cases] .b.one[c] each cases}
.b.show:{[t] system"c 60 200"; show select name,found:.Q.s1 each found,ok,shrinks,attempts,ms from t;
  -1 "minimal: ",string[sum t`ok],"/",string[count t],"  attempts: ",string[sum t`attempts],"  ms: ",string sum t`ms;}
