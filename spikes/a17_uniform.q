\l spikes/h.q
/ A17: uniform-over-shapes recursion via counting ctab (the "recursive method"), as the fresh-draw law for
/      the share choice in .qc.rec. Compared with the uniform-cut (random BST) law. Size = internal nodes.
/ counting: T[n] trees with n internal nodes, arity in [lo;hi]; Cm[m][r] = m-tuples of trees with total size r
conv:{[a;b] n:count a; {[a;b;r] sum a[til 1+r]*b[r-til 1+r]}[a;b] each til n}
ctab:{[k;N] T:1f,N#0f; C:(1+k 1)#enlist (1f,N#0f);                        / C[0] = (r=0)
  i:1; while[i<=N; r:i-1; T[i]:sum {[C;m;r] C[m;r]}[C;;r] each (k 0)+til 1+(k 1)-k 0; 
    / recompute C[m] rows up to i lazily: C[m]=T convolved m times; cheap for N<=200
    C:{[T;m] $[m=0; 1f,(count[T]-1)#0f; conv over m#enlist T]}[T] each til 1+k 1; i+:1];   / over of a 1-list is the element itself
  `T`C!(T;C)}
/ NB: the above recomputes convolutions each step (O(N^3) overall); fine for N<=100 in a spike, done once per k in the engine
.s.V:`long$(); .s.rd:0; .s.mx:0; .s.nodes:0
wch:{[w] v:sums[w] binr rand sum w; .s.V,:v; v}                             / weighted fresh choice of an index (binr: bin gives -1 below the first weight)
uch:{[lo;hi] v:lo+rand 1+hi-lo; .s.V,:v; v}
enter:{.s.rd+:1; .s.mx|:.s.rd; .s.nodes+:1}; leave:{.s.rd-:1}
/ exact-size subtree, uniform over shapes: arity by weight Cm[r], child sizes by weight T[j]*C(m-1)[r-j]
gen:{[k;tb;node;leaf;b] $[b<1; leaf; [enter[]; r:b-1; ms:(k 0)+til 1+(k 1)-k 0; m:ms wch tb[`C][ms;r];
  cs:(); i:0; while[i<m; j:$[i=m-1; r; wch tb[`T][til 1+r]*tb[`C][m-1-i; r-til 1+r]]; r-:j; cs:cs,enlist .z.s[k;tb;node;leaf;j]; i+:1];
  x:node cs; leave[]; x]]}
/ same skeleton, uniform cut (the A15 law) for comparison
genu:{[k;node;leaf;b] $[b<1; leaf; [enter[]; r:b-1; m:uch[(k 0)|(k 1)&r>0;k 1]; cs:(); i:0;
  while[i<m; j:$[i=m-1; r; uch[0;r]]; r-:j; cs:cs,enlist .z.s[k;node;leaf;j]; i+:1]; x:node cs; leave[]; x]]}
two:{(x 0;x 1)}
tb:ctab[2 2;100]
.h.t["counts: T[0..5] are the Catalan numbers"; tb[`T][til 6]~1 1 2 5 14 42f]
.h.t["counts: T[100] = C_100 ~ 8.965e56 (float table suffices to size 100)"; (tb[`T][100] within 8.9e56 9.0e56)]
system"S 11"
/ uniformity over the 14 binary shapes with 4 internal nodes
shape:{$[0h=type x; "(",shape[x 0],shape[x 1],")"; 11h=type x; "(..)"; "."]}    / two leaf children collapse to a symbol vector
S:{[i] .s.nodes:0; shape gen[2 2;tb;two;`L;4]} each til 14000
cnt:count each group S
.h.t["all 14 shapes of size 4 appear"; 14=count cnt]
.h.t["uniform: every shape within 15% of 1000 (3.5 sd)"; all (value cnt) within 850 1150]
-1 "info: size-4 shape counts: ",.Q.s1 asc value cnt;
/ exactness and depth contrast at size 100
run:{[f;n] {[f;n;i] .s.rd:0; .s.mx:0; .s.nodes:0; f[n]; (.s.nodes;.s.mx)}[f;n] each til 500}
a:run[gen[2 2;tb;two;`L];100]; b:run[genu[2 2;two;`L];100]
.h.t["uniform-shape trees have exactly 100 internal nodes"; all 100=a[;0]]
.h.t["uniform-cut trees have exactly 100 internal nodes"; all 100=b[;0]]
q3:{(asc x) "j"$(count[x]-1)*0.25 0.5 0.75}
-1 "info: depth at n=100, uniform over shapes (Boltzmann law): q25/50/75 ",.Q.s1[q3 a[;1]]," max ",string max a[;1];
-1 "info: depth at n=100, uniform cut      (random BST law): q25/50/75 ",.Q.s1[q3 b[;1]]," max ",string max b[;1];
.h.t["uniform-shape trees are much deeper (median depth >= 1.5x the BST law)"; (med a[;1])>=1.5*med b[;1]]
.h.t["uniform-shape trees stay well under the depth guard (max < 100 at n=100)"; 100>max a[;1]]
/ rose trees, arity 0..4: counts and exactness
tr:ctab[0 4;60]
c:run[gen[0 4;tr;{(`n;x)};`L];60]
.h.t["rose 0..4: exactly 60 internal nodes, no waste and no arity hack"; all 60=c[;0]]
-1 "info: rose 0..4 depth at n=60: q25/50/75 ",.Q.s1[q3 c[;1]]," max ",string max c[;1];
/ cost of the ctab
t100:system"t ctab[2 2;100]"; t200:system"t ctab[0 4;100]"
-1 "info: table build ms: binary N=100 ",string[t100],", rose 0..4 N=100 ",string t200;
.h.t["table build for N=100 under 2s with the naive spike code"; 2000>t100|t200]
.h.done[]
