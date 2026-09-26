/ q examples/tree.q — recursive generation with .qc.rec
\l qc.q
tree:.qc.rec[2 2; .qc.int 0 9; {(x 0;x 1)}]            / binary tree: leaves are ints, nodes are pairs
depth:{$[0h=type x; 1+max .z.s each x; 0<type x; 1; 0]} / two leaf children collapse into a typed vector: depth 1
leaves:{$[0h=type x; sum .z.s each x; 0<type x; count x; 1]}
nodes:{$[0h=type x; 1+sum .z.s each x; 0<type x; 1; 0]}
-1 "a binary tree has one more leaf than internal nodes:";
.qc.check[tree; {leaves[x]=1+nodes x}];
-1 "\ntrees are not all shallow:";
.qc.check[tree; {depth[x]<4}];
-1 "\nrose trees with 0..4 children, node = (tag; children):";
rose:.qc.rec[0 4; .qc.int 0 9; {(`n;x)}]
.qc.check[rose; {if[0h=type x; .qc.classify[`wide;3<count x 1]]; 1b}];   / a leaf is a bare int
exit 0
