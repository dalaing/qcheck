/ q examples/tree.q — recursive data with .qc.rec. Run it from the repository root; EXAMPLES.md ("Trees") talks
/ through the output.
\l qc.q
.qc.cfg[`db]:`                                   / no failure database: every run of this script searches afresh

/ .qc.rec[k;leaf;node] draws a tree: k is how many children a node has (a range), leaf is the generator of a
/ leaf, and node is a function that builds a node from the list of its children, which are already values.
/ Here every node has exactly two children, a leaf is a long, and a node is the pair of its children.
tree:.qc.rec[2 2; .qc.int 0 9; {(x 0;x 1)}]

/ Functions over such a tree. A node is a general list (type 0h) and a leaf is an atom; but a node whose two
/ children are both leaves is a pair of longs, which q keeps as a vector (type 7h), so that case is handled too.
depth: {$[0h=type x; 1+max .z.s each x; 0<type x; 1; 0]}
leaves:{$[0h=type x; sum .z.s each x; 0<type x; count x; 1]}
nodes: {$[0h=type x; 1+sum .z.s each x; 0<type x; 1; 0]}

/ 1. A rule that holds for every binary tree: one more leaf than it has nodes.
-1 "a binary tree has one more leaf than it has nodes:";
.qc.check[tree; {leaves[x]=1+nodes x}];

/ 2. A rule that does not: trees are shallow. The counterexample is the simplest tree of depth 4, a single
/ spine with 0 at every leaf. Shrinking a tree replaces subtrees by leaves and lowers the values.
-1 "\nevery tree is less than four deep (false):";
.qc.check[tree; {depth[x]<4}];

/ 3. What did the examples look like? A rose tree has from 0 to 4 children at each node, and a node is tagged
/ (`n;children). The property always passes; .qc.classify counts the examples whose root has more than three
/ children, and the report prints the count as a table.
-1 "\nrose trees, and how many of them were wide at the root:";
rose:.qc.rec[0 4; .qc.int 0 9; {(`n;x)}]
.qc.check[rose; {if[0h=type x; .qc.classify[`wide;3<count x 1]]; 1b}];   / (a leaf is a bare long: nothing to count)
exit 0
