\l spikes/h.q
/ A15: recursion sizing strategies — distribution of node count and depth for binary and rose trees
/ mini engine: fresh draws only (distribution study; no replay needed)
.s.V:`long$(); .s.sz:0; .s.rd:0; .s.mx:0; .s.nodes:0; .s.p:0.5
bit:{[p] v:p>rand 1.0; .s.V,:"j"$v; v}                                             / choices are longs: a boolean appended to a long vector is a type error
int:{[lo;hi] v:lo+rand 1+hi-lo; .s.V,:v; v}
draw:{if[5000<count .s.V; '"qc.toolarge"]; $[type[x] within 100 112; x[]; 0h=type x; .z.s each x; x]}
lst:{[g;d] xs:(); while[(count[xs]<4) and bit 0.7; xs:xs,enlist draw g]; xs}      / 0..4 children. NB xs:xs,y promotes to a general list; xs,:y does not
leaf:{[d] int[0;9]}
two:{(x;x)}; rose:{lst x}                                                        / node specs receiving the child *generator* (bin is a q keyword)
pr:{$[.s.p~`dyn; .s.sz%.s.sz+3; .s.p]}                                            / probability of recursing
enter:{.s.rd+:1; .s.mx|:.s.rd; .s.nodes+:1; if[.s.rd>400; '"qc.toodeep"]}
leave:{.s.rd-:1}
/ S1 halving: children see half the parent's size; nothing is consumed
rec1:{[leaf;node;d] $[(.s.sz<1) or not bit pr[]; draw leaf; [enter[]; s:.s.sz; .s.sz:s div 2; r:draw node rec1[leaf;node]; .s.sz:s; leave[]; r]]}
/ S2 fuel, depth-first, no partition: each node spends one unit from a shared pool
rec2:{[leaf;node;d] $[(.s.sz<1) or not bit pr[]; draw leaf; [enter[]; .s.sz-:1; r:draw node rec2[leaf;node]; leave[]; r]]}
/ S3 fuel with stick-breaking: each child draws a share of what is left and hands back what it did not use
rec3:{[leaf;node;d] $[(.s.sz<1) or not bit pr[]; draw leaf; [enter[]; .s.sz-:1; r:draw node kid3[leaf;node]; leave[]; r]]}
kid3:{[leaf;node;d] b:.s.sz; s:int[0;b]; .s.sz:s; r:rec3[leaf;node;::]; .s.sz:b-s-.s.sz; r}
/ S4 depth decay, no budget: p = 0.9 * 0.8^depth (Hypothesis-flavoured; relies on discards for the tail)
rec4:{[leaf;node;d] $[not bit 0.9*0.8 xexp .s.rd; draw leaf; [enter[]; r:draw node rec4[leaf;node]; leave[]; r]]}
/ S5 composition: draw the node count once; at each node draw the child count from range k and split the
/    remaining budget among the children exactly (last child takes the rest); node receives the children *values*.
/    A node with budget left has at least one child (if the range allows), so the budget is spent exactly.
rec5:{[k;leaf;node;d] sub5[k;leaf;node;int[0;.s.sz]]}
sub5:{[k;leaf;node;b] $[b<1; draw leaf; [enter[]; b-:1; m:int[(k 0)|(k 1)&b>0;k 1]; cs:(); i:0;                        / budget left => at least one child, so nothing is wasted
  while[i<m; s:$[i=m-1; b; int[0;b]]; b-:s; cs:cs,enlist sub5[k;leaf;node;s]; i+:1]; r:node cs; leave[]; r]]}
two5:{(x 0;x 1)}; rose5:{(`n;x)}
/ the study
one:{[g;sz] .s.V:`long$(); .s.sz:sz; .s.rd:0; .s.mx:0; .s.nodes:0; r:@[draw;g;{x}]; $[10h=type r; `disc; (.s.nodes;.s.mx)]}
q3:{(asc x) "j"$(count[x]-1)*0.25 0.5 0.75}
stat:{[st;sh;p;g;sz] .s.p:p; r:one ./: 1000#enlist (g;sz); d:sum r~\:`disc; ok:r where not r~\:`disc; n:ok[;0]; dp:ok[;1];
  `strat`shape`sz`n25`n50`n75`d25`d50`d75`dmax`deep`shallow`disc!(st;sh;sz),q3[n],q3[dp],(max dp;avg dp>=sz div 3;avg (dp<=3)&n>=5;d)}
G:((`halve;`bin;0.5;rec1[leaf;two]);(`halve;`rose;0.5;rec1[leaf;rose]);
   (`dfs;`bin;2%3;rec2[leaf;two]);(`dfs;`rose;2%3;rec2[leaf;rose]);
   (`stick67;`bin;2%3;rec3[leaf;two]);(`stick67;`rose;2%3;rec3[leaf;rose]);
   (`stick80;`bin;0.8;rec3[leaf;two]);(`stick80;`rose;0.8;rec3[leaf;rose]);
   (`stickdyn;`bin;`dyn;rec3[leaf;two]);(`stickdyn;`rose;`dyn;rec3[leaf;rose]);
   (`decay;`bin;0.5;rec4[leaf;two]);(`decay;`rose;0.5;rec4[leaf;rose]);
   (`comp;`bin;0n;rec5[2 2;leaf;two5]);(`comp;`rose;0n;rec5[0 4;leaf;rose5]))
system"S 7"
T:raze {[g] {[g;sz] stat[g 0;g 1;g 2;g 3;sz]}[g] each 10 30 100} each G
T:flip `strat`shape`sz`n25`n50`n75`d25`d50`d75`dmax`deep`shallow`disc!flip value each T
system"c 60 200"; show T
c:{[t;s;sh;z] first select from t where strat=s,shape=sh,sz=z}                     / (a param named sz would be shadowed by the column)
rc:c[T;`comp;`bin;30]; rr:c[T;`comp;`rose;30]; rh:c[T;`halve;`bin;30]; rc100:c[T;`comp;`bin;100]
-1 "info: comp bin sz30: nodes ",.Q.s1[rc`n25`n50`n75]," depth ",.Q.s1[rc`d25`d50`d75]," dmax ",string rc`dmax;
.h.t["comp: no discards, node count never exceeds size"; (0=sum exec disc from T where strat=`comp) and all exec n75<=sz from T where strat=`comp]
.h.t["comp: node counts spread across the budget (IQR>=10 at size 30, n75>=20)"; ((rc[`n75]-rc`n25)>=10) and rc[`n75]>=20]
.h.t["comp: depth varies (IQR>=3, dmax>=10 at size 30)"; ((rc[`d75]-rc`d25)>=3) and rc[`dmax]>=10]
.h.t["comp: scales with size (median nodes at 100 > 2x median at 30)"; rc100[`n50]>2*rc`n50]
.h.t["comp: rose trees also use the budget (n75>=10 at size 30)"; rr[`n75]>=10]
.h.t["halving is narrow (depth IQR<=4 and dmax<=6 at size 30)"; (4>=rh[`d75]-rh`d25) and rh[`dmax]<=6]
.h.t["all budgeted strategies never discard"; 0=sum exec disc from T where not strat=`decay]
.h.done[]
