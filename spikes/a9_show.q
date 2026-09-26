\l spikes/h.q
/ A9: rendering a failure report: nested tables inside a dict, width, tables as tables
x:`n`xs`t!(3;1 2 3;([]a:1 2 3;b:`x`y`z))
s:.Q.s x
.h.t["default .Q.s prints a nested table in flip notation (the problem)"; s like "*+`a`b!*"]
/ custom formatter: dict keys as labels, nested tables/dicts indented as blocks
ind:{[n;s] "\n" sv (n#" "),/:"\n" vs s}
.f.v:{$[type[x] in 98 99h; "\n",ind[2;.f.s x]; " ",-1_.Q.s x]}
.f.s:{$[99h=type x; "\n" sv {string[x],":",.f.v y}'[key x;value x]; -1_.Q.s x]}
o:.f.s x
-1 o;
.h.t["formatter shows nested table with a column header line"; o like "*  a b*"]
.h.t["formatter keeps atoms and vectors inline"; o like "n: 3*"]
/ width handling
system"c 25 80"; big:([]a:til 3;b:3#enlist 200#"x")
w:max count each "\n" vs .Q.s big
.h.t[".Q.s respects console width (<=80)"; w<=80]
system"c 25 400"; w2:max count each "\n" vs .Q.s big
.h.t["widening \\c shows more"; w2>w]
system"c 25 80"
/ a diff table renders compactly
d:([]path:(enlist 0;enlist 1;`b);why:`value`value`type;a:(1;0;7h);b:(0;1;6h))
-1 .Q.s d;
.h.t["diff table has one row per difference"; 3=count d]
.h.t["✓/✗ print"; (count "✗ falsified")>0]
.h.done[]
