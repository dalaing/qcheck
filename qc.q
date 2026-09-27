/ qcheck — property-based testing for q.   design and rationale: DESIGN.md
/   \l qc.q
/   .qc.check[.qc.list .qc.int 0 9; {x~asc x}]
\d .qc

/ ---- configuration ----------------------------------------------------------------------------------
cfg:`n`nmax`seed`sz`shrinks`disc`tries`depth`choices`same`clamp`db`name`rows`v!(100;0N;0Ni;100;2000;10;50;200;8192;1b;1b;`:.qc;`;20;1)
cf:cfg                                                / effective config of the current run

/ ---- engine state: global, reset per example --------------------------------------------------------
C:([]v:`long$();lo:`long$();hi:`long$();o:`long$())                   / choices: value, bounds, origin
E:([]s:`long$();e:`long$();l:`long$();d:`long$();x:`boolean$())       / spans: start end label depth discarded
P:`long$()                  / prefix being replayed
i:0                         / cursor into P
sz:100                      / size: the budget structures spend
bs:100                      / base size of the current example; sz is restored to it at the boundary (C9)
dp:0                        / interpreter depth
mn:0b                       / minimal mode: fresh draws return their origin
sh:0b                       / shrinking: a draw past the prefix is invalid
st:()                       / open spans (start;label;depth)
L:(enlist (::))!enlist 0N   / span labels: generator identity -> id (seeded so the key list is general)
N:()                        / notes of the current example
LB:(`symbol$())!`long$()    / label counts over the run
LX:`symbol$()               / labels of the current example
TB:(`symbol$())!()          / counting tables for rec, per arity range
/ (CS UR US, the per-table state of constrained columns, are defined with the tables: saved and restored around each table)
run:0b                      / inside chk/recheck (or a top-level draw): draws share one example
nch:0                       / draw calls this example (a block counts once): what cfg`choices bounds
/ the choice tree of the current run (C19): one node per prefix of choices. A node holds the range drawn at it
/ (lo hi o, width w) or the conclusion c an example reached there (pass fail disc); nc children exist, nx of
/ them exhausted. A node is exhausted (x) when it concludes or all w of its children are; root exhausted = every
/ input tried. TX: (parent; value) -> node.
TR:([]p:`long$();v:`long$();lo:`long$();hi:`long$();o:`long$();w:`float$();nc:`long$();nx:`long$();x:`boolean$();c:`symbol$())
TX:(enlist 0#0)!enlist 0N                             / seeded with an empty vector key (pitfall 19)

reset:{[p;s;m;h] if[not abs[type p:(),p] in 1 4 5 6 7h; '"qc: choices must be integers"]; P::"j"$p; i::0; nch::0; C::0#C; E::0#E; st::(); dp::0; sz::bs::s; mn::m; sh::h; N::(); LX::`symbol$();}
new:{reset[`long$();cfg`sz;0b;0b]}                    / fresh interactive state
/ the implicit d is never supplied by users, so a non-null d means one argument too many (C1)
dd:{[d;n] if[not (::)~d; '"qc: too many arguments; ",$[n like "* *"; "the configurable form is ",n; n," takes none"]]}   / a form with a space is configurable
fn:{$[(::)~x; 0b; type[x] within 100 112]}              / callable? the library never applies what is not (C20); :: is 101h but is not a function (pitfall 10)
need:{[f;what] if[not fn f; '"qc: ",what," must be a function"]}
dct:{$[99h<>type x; 0b; not 98h=type key x]}              / a dict, and not a keyed table, which is 99h too (pitfall 28)

/ ---- the primitive ----------------------------------------------------------------------------------
/ a range is  lo hi  or  lo hi origin  or a function of size returning one; origin defaults to 0 clamped
rng:{r:$[type[x] within 100 112; x sz; x]; r:"j"$(),r; if[not count[r] in 2 3; '"qc: range"];
  if[r[0]>r 1; '"qc: range"]; $[2=count r; r,r[0]|r[1]&0; @[r;2;{y|z&x}[;r 0;r 1]]]}
/ ch[r;w]: draw a long in range r.  w hints the fresh-draw law: :: mixture, `u uniform, float p Bernoulli
/ (0/1 ranges), float vector = weights over lo..hi.  Replay clamps into range; past the prefix while
/ shrinking is invalid; minimal mode returns the origin.  rand is called only by fresh and its helpers unif and mix.
ch:{[r;w] r:rng r; lo:r 0; hi:r 1; o:r 2; j:i; i+:1;
  v:$[j<count P; $[cf`clamp; lo|hi&P j; (P j) within (lo;hi); P j; '"qc.misaligned"]; sh; '"qc.overrun"; mn; o; fresh[lo;hi;o;w]];
  nch+:1; if[cf[`choices]<nch; '"qc.toolarge"];
  C,:(v;lo;hi;o); v}
/ chn[r;n;w]: n choices of range r at once — one call, one append, one unit of the choice budget (M8, A22). Replay
/ slices the prefix and clamps; past the prefix while shrinking is invalid; minimal mode gives origins; fresh
/ values are drawn vectorised by freshn. Deleting inside a block is the shrinker's pblk (§1.5).
chn:{[r;n;w] r:rng r; lo:r 0; hi:r 1; o:r 2; j:i; i+:n; m:0|n&count[P]-j; p:m#j _ P;
  p:$[cf`clamp; lo|hi&p; all p within (lo;hi); p; '"qc.misaligned"];
  v:$[m=n; p; sh; '"qc.overrun"; mn; p,(n-m)#o; p,freshn[lo;hi;o;w;n-m]];
  nch+:1; if[cf[`choices]<nch; '"qc.toolarge"];
  C,:flip `v`lo`hi`o!(v;n#lo;n#hi;n#o); v}
freshn:{[lo;hi;o;w;n] $[lo=hi; n#lo; -9h=type w; hi&lo+"j"$w>n?1f; 9h=type w; lo+sums[w] binr n?sum w; w~`u; unifn[lo;hi;n]; mixn[lo;hi;o;n]]}
unifn:{[lo;hi;n] $[lo=hi; n#lo; 0<k:1+hi-lo; lo+n?k; ?[n?01b; lo+n?0W; hi-n?0W]]}   / (the vector conditional wants booleans: n?01b, not n?2 — pitfall 42)
mixn:{[lo;hi;o;n] b:0=n?8; nb:(o;lo;hi;$[o<hi; o+1; o];$[o>lo; o-1; o]) n?5; sg:$[o=lo; n#1; o=hi; n#-1; (1 -1) n?2];
  ?[b;nb;lo|hi&"j"$("f"$o)+sg*(n?1f)*2 xexp n?1+bits hi-lo]}
fresh:{[lo;hi;o;w] $[lo=hi; lo; -9h=type w; hi&lo+"j"$w>rand 1.0; 9h=type w; lo+sums[w] binr rand sum w;
  w~`u; unif[lo;hi]; mix[lo;hi;o]]}
unif:{[lo;hi] $[lo=hi; lo; 0<n:1+hi-lo; lo+rand n; rand 2; lo+rand 0W; hi-rand 0W]}   / a width that overflows (null or negative) draws from [lo;lo+0W) or (hi-0W;hi]: on the full long range that misses 0 (mix reaches it as the origin); `u is only used on small ranges
bits:{$[null x; 63; x<0; 63; x<1; 1; count 2 vs x]}
/ boundary values one time in eight, else a random magnitude; the sign only goes where the origin leaves room
/ (a random sign on a one-sided range clamps half the draws to the bound: 56% zeros on 0..1000, C17)
/ the neighbours of the origin are guarded and the magnitude is added in floats, then saturated and clamped: o+1 at
/ 0W and o+2^63 both wrap in longs (C21)
mix:{[lo;hi;o] $[0=rand 8; (o;lo;hi;$[o<hi; o+1; o];$[o>lo; o-1; o]) rand 5;
  lo|hi&"j"$("f"$o)+$[o=lo; 1; o=hi; -1; 1 -1 rand 2]*rand 2 xexp rand 1+bits hi-lo]}

/ ---- the interpreter --------------------------------------------------------------------------------
/ label = the generator's structure, with projections reduced to their lambdas: a composition built per draw
/ from varying arguments must not add a label each time
lbl:{[g] k:$[104h=type g; first value g; 105h=type g; `$raze string md5 "c"$-8!{$[104h=type x; first value x; x]} each value g; g];   / an atom key: a list would index several keys
  n:L k; if[null n; L[k]:n:count L]; n}
beg:{[l] st,:enlist (count C;lbl l;dp);}
end:{r:last st; st::-1_st; E,:(r 0;count C;r 1;r 2;0b);}
call:{[g] dp+:1; if[cf[`depth]<dp; '"qc.toodeep"]; beg g; r:g[]; end[]; dp-:1; r}
/ dr x: call a function, recurse into dicts and general lists, return anything else unchanged
dr:{$[(::)~x; x; type[x] within 100 112; call x; 99h=type x; $[98h=type key x; x; key[x]!.z.s each value x];
  0h=type x; .z.s each x; x]}
/ the interactive entry points own the example boundary: reset, run flag, protected dr, restore (C6, C9, C10)
/ outside a run the effective config is the defaults: a cfg edit must reach the next interactive draw
top:{[p;m;h;s] if[run; '"qc: nested check"]; cf::cfg; reset[p;bs;m;h]; run::1b; r:@[dr;s;{run::0b; dp::0; st::(); sz::bs; 'x}]; run::0b; r}
draw:{$[run or dp>0; dr x; top[`long$();0b;0b;x]]}   / fresh draws; inside a run or a draw, just interpret
minimal:top[`long$();1b;0b]                           / the simplest value of a spec: every draw is its origin
replay:{[p;s] top[p;0b;0b;s]}                         / the value a recorded choice vector produces
strict:{[p;s] top[p;0b;1b;s]}                         / the same with the prefix strict: a draw past it is qc.overrun (what the shrinker sees)

/ ---- generators: config first, generator last, the implicit d is never supplied by users -------------
int:{[r;d] dd[d;".qc.int r"]; ch[r;::]}
lin:{[lo;hi] {[lo;hi;s] lo,"j"$("f"$lo)+floor ((("f"$hi)-"f"$lo)*s)%100}[lo;hi]}   / a range that widens linearly with size (C11); in floats so lin[0;0W] does not wrap (C21)
bit:{[p;d] dd[d;".qc.bit p"]; 1=ch[0 1 0;"f"$p]}
bool:bit[0.5]
const:{[x;d] dd[d;".qc.const x"]; x}
sized:{[f;d] dd[d;".qc.sized f"]; need[f;"sized's f"]; draw f sz}
small:{[g;d] dd[d;".qc.small g"]; s:sz; sz::s div 2; r:draw g; sz::s; r}
elem:{[xs;d] dd[d;".qc.elem xs"]; if[99h=type xs; '"qc: elem takes a list"]; xs:(),xs; if[0=count xs; '"qc: elem of nothing"]; xs ch[(0;-1+count xs;0);`u]}
one:{[gs;d] dd[d;".qc.one gs"]; if[99h=type gs; '"qc: one takes a list of alternatives"]; gs:(),gs; if[0=count gs; '"qc: one of nothing"]; draw gs ch[(0;-1+count gs;0);`u]}
freq:{[w;gs;d] dd[d;".qc.freq[w] gs"]; if[99h=type gs; '"qc: freq takes a list of alternatives"]; gs:(),gs; if[not type[w] in -5 -6 -7 -8 -9 5 6 7 8 9h; '"qc: freq needs numeric weights"]; w:"f"$(),w;
  if[$[0=count gs; 1b; count[w]<>count gs; 1b; any w<0; 1b; 0=sum w]; '"qc: freq needs one non-negative weight per alternative, not all zero"]; draw gs ch[(0;-1+count gs;0);w]}
such:{[p;g;d] dd[d;".qc.such[p] g"]; need[p;"such's predicate"]; k:0; while[k<cf`tries; beg`try; x:draw g; end[]; if[p x; :x]; E[count[E]-1;`x]:1b; k+:1]; '"qc.discard"}
discard:{'"qc.discard"}
/ list: continue bit before each element (forced while under lo); size caps the length; the bit's
/ probability makes the length uniform on lo..m
/ every iteration records its decision bit, forced 1 under lo and forced 0 at the cap, so the structure is the
/ same at every size and a replay at a larger size still finds its stop (C7). span = decision bit + element.
/ elements gather behind a :: seed and the seed is dropped at the end: a list of conforming dicts is a table and the
/ next dict that does not conform cannot be joined onto it (pitfall 30); atoms still collapse to a typed vector
lst:{[r;g;d] dd[d;".qc.lst[r] g"]; r:rng r; lo:r 0; m:"j"$("f"$r 1)&("f"$lo)+sz; xs:enlist (::); n:0; go:1b;   / the cap in floats: lo+sz wraps near 0W (C21)
  while[go; beg`el; go:1=$[n<lo; ch[1 1 1;::]; n<m; ch[0 1 0;(m-n)%1+m-n]; ch[0 0 0;::]];
    $[go; [x:draw g; end[]; xs:xs,enlist x; n+:1]; end[]]]; 1_xs}
list:lst[0 0W]

/ bulk[r;nr]: a long vector of a length in nr with values in r, recorded as one block (M8): 1e6 values in
/ milliseconds, and a block shrinks by deleting chunks (pblk) as well as by its values. span = length + block.
bulk:{[r;nr;d] dd[d;".qc.bulk[r;nr]"]; nr:rng nr; nr[1]&:"j"$("f"$nr 0)+sz*1000; beg`blk; n:ch[nr;`u]; v:chn[r;n;::]; end[]; v}   / the length is capped at lo+1000*size (in floats, C21)
/ btab[nr] cols: a table of blocks with one drawn row count; a column is a range or (type char; range)
btab:{[nr;cg;d] dd[d;".qc.btab[nr] cols"]; if[not dct cg; '"qc: btab needs a dict of column ranges"]; nr:rng nr; nr[1]&:"j"$("f"$nr 0)+sz*1000; beg`blk; n:ch[nr;`u];   / (cap in floats, C21)
  if[not all {$[0h<>type x; 1b; -10h<>type x 0; 0b; (x 0) in key t]} each value cg; '"qc: btab: a column is a range or (type char; range)"];
  cs:{[n;s] $[0h=type s; (s 0)$chn[s 1;n;::]; chn[s;n;::]]}[n] each value cg; end[]; flip key[cg]!cs}
/ ---- recursion: rec[k;leaf;node] spends the size budget exactly; shape law = fresh-draw weights ------
conv:{[a;b] {[a;b;r] sum a[til 1+r]*b[r-til 1+r]}[a;b] each til count a}
/ counting tables: T[n] trees with n internal nodes and arity in k; C[m][r] m-tuples of trees totalling r
ctab:{[k;n] T:1f,n#0f; CT:(1+k 1)#enlist 1f,n#0f; j:1;
  while[j<=n; T[j]:sum CT[k[0]+til 1+k[1]-k 0;j-1];
    CT:{[T;m] $[m=0; 1f,(count[T]-1)#0f; conv over m#enlist T]}[T] each til 1+k 1; j+:1]; `T`C!(T;CT)}
tabs:{[k;n] if[n>300; '"qc: rec: size above 300 has too many shapes to count; lower cfg`sz"]; s:`$"," sv string k;
  if[$[s in key TB; n>=count TB[s]`T; 1b]; TB[s]:ctab[k;n|300&cf`sz]]; TB s}
/ uniform over shapes: arity weighted by C[m][r], child sizes by T[j]*C[m-1-i][r-j]; last child takes the rest
sub:{[k;leaf;node;tb;b] $[b<1; draw leaf; [r:b-1; ms:k[0]+til 1+k[1]-k 0; m:ms ch[(0;-1+count ms;0);tb[`C][ms;r]];
  cs:enlist (::); j:0; while[j<m; beg`sub; s:$[j=m-1; ch[(r;r;r);::]; ch[(0;r;0);tb[`T][til 1+r]*tb[`C][m-1-j;r-til 1+r]]]; r-:s;
    c:.z.s[k;leaf;node;tb;s]; end[]; cs:cs,enlist c; j+:1]; node 1_cs]]}   / span = share + subtree; children behind a :: seed (pitfall 30)
rec:{[k;leaf;node;d] dd[d;".qc.rec[k;leaf;node]"]; need[node;"rec's node"]; k:2#(),"j"$k; tb:tabs[k;sz]; beg`sub; n:ch[(0;sz;0);`u];   / rec[2;..]: exactly two
  n:last where 0<tb[`T] til 1+n; r:sub[k;leaf;node;tb;n]; end[]; r}
/ uniform cut (random binary-search-tree law): same choices, uniform weights
subb:{[k;leaf;node;b] $[b<1; draw leaf; [r:b-1; m:ch[((k 0)|(k 1)&r>0;k 1;k 0);`u]; cs:enlist (::); j:0;
  while[j<m; beg`sub; s:$[j=m-1; ch[(r;r;r);::]; ch[(0;r;0);`u]]; r-:s; c:.z.s[k;leaf;node;s]; end[]; cs:cs,enlist c; j+:1]; node 1_cs]]}
recb:{[k;leaf;node;d] dd[d;".qc.recb[k;leaf;node]"]; need[node;"recb's node"]; k:2#(),"j"$k; beg`sub; r:subb[k;leaf;node;ch[(0;sz;0);`u]]; end[]; r}


/ ---- the type zoo -----------------------------------------------------------------------------------
cast:{[c;g] ('[$[c;];g])}                            / a generator cast to type char c (composition = map)
/ spc[specials;g]: full-domain wrapper, uniform layout [kind; special; value...] so no branch is shorter (C12)
spc:{[sp;g;d] dd[d;".qc.spc[specials] g"]; sp:(),sp; k:ch[(0;1;0);0.05]; ix:ch[(0;-1+count sp;0);`u]; v:draw g; $[k; sp ix; v]}   / (ss and cols are keywords)
/ dbl: any finite double, [sign; e; m] = sign*m*2^e; the exponent shrinks first so integers come before fractions
dbl:{[d] dd[d;".qc.dbl"]; s:ch[(0;1;0);0.3]; e:ch[(-1022;970;0);::]; m:ch[(0;9007199254740991;0);::]; (1 -1 s)*m*2 xexp e}
/ flt r: a float in [lo;hi], [sign; k; m] = sign*m/2^k with m ranged so the value never leaves [lo;hi]:
/ 0 (or the nearest bound) is simplest, integers before halves before quarters, uniform within each k
flt:{[r;d] dd[d;".qc.flt r"]; r:"f"$(),r; if[$[2<>count r; 1b; r[0]>r 1]; '"qc: range"]; lo:r 0; hi:r 1;
  s:ch[(hi<0;lo<0;0);0.3]; a:$[s; neg 0&hi; 0|lo]; b:$[s; neg lo; hi];
  k:ch[(0;0|52&"j"$62-xlog[2;1|b];0);`u]; p:2 xexp k; m:ch[("j"$ceiling a*p;"j"$floor b*p;0);`u]; (1 -1 s)*m%p}   / beyond 2^62 the mantissa saturates: |value| <= 9.2e18
gid:{[d] dd[d;".qc.gid"]; k:ch[(0;1;0);0.05]; b:draw 16#enlist int 0 255; $[k; 0Ng; 0x0 sv "x"$b]}
AZ:.Q.a,.Q.A,.Q.n," "
chrc:{[s;d] dd[d;".qc.chrc s"]; s:(),s; s ch[(0;-1+count s;0);`u]}        / (),s: a one-char alphabet arrives as an atom (C16)
chr:chrc[AZ]
strc:{[s;r;d] dd[d;".qc.strc[s;r]"]; "c"$draw lst[r] chrc s}
str:strc[AZ;0 0W]
symc:{[s;r;d] dd[d;".qc.symc[s;r]"]; `$"c"$draw lst[r] chrc s}     / bounded alphabet: symbols intern forever
sym:symc["abcd";0 3]
gidf:{[d] dd[d;".qc.gidf"]; 0x0 sv "x"$draw 16#enlist int 0 255}   / a guid that is never null
/ dble: a double that fits a real (24-bit mantissa, exponent to 2^103), so "e"$ never overflows to 0we
dble:{[d] dd[d;".qc.dble"]; s:ch[(0;1;0);0.3]; e:ch[(-126;103;0);::]; m:ch[(0;16777215;0);::]; (1 -1 s)*m*2 xexp e}
/ tin: each atom type's finite domain — no null, no infinity (h i j stop one short of their infinities, e fits a
/ real, c has no space, s no empty symbol: those are q's nulls); tf c is that as a generator (M10, A26); t c wraps
/ it in spc, adding the null and both infinities, and keeps chr, sym and gid for c s g: the full domain
tin:"bgxhijefcspmdznuvt"!(bool;gidf;cast["x";int 0 255];cast["h";int -32766 32766];cast["i";int -2147483646 2147483646];int (-0W+1;0W-1);cast["e";dble];dbl;chrc[.Q.a,.Q.A,.Q.n];symc["abcd";1 3];
  cast["p";int -1500000000000000000 1500000000000000000];cast["m";int -1200 1200];cast["d";int -36500 36500];cast["z";flt -36500 36500];
  cast["n";int -1000000000000000000 1000000000000000000];cast["u";int 0 1439];cast["v";int 0 86399];cast["t";int 0 86399999])
spcs:"hijefpmdznuvt"!((0Nh;0Wh;-0Wh);(0Ni;0Wi;-0Wi);(0N;0W;-0W);(0Ne;0We;-0We);(0n;0w;-0w);(0Np;0Wp;-0Wp);(0Nm;0Wm;-0Wm);(0Nd;0Wd;-0Wd);(0Nz;0Wz;-0Wz);(0Nn;0Wn;-0Wn);(0Nu;0Wu;-0Wu);(0Nv;0Wv;-0Wv);(0Nt;0Wt;-0Wt))
tf:tin
t:tin,key[spcs]!{[sp;g] spc[sp;g]}'[value spcs;tin key spcs]; t["g"]:gid; t["c"]:chr; t["s"]:sym   / (spc'[a;b] would be a projection of the each, not 13 results)
/ ts[from;to], dates[from;to]: one timestamp or date in a window, the start simplest (A26); a monotone series is
/ mono[ts[a;b];int 0 60000000000] in a table, or atr[`s] list ts[a;b]
tmb:{[a;what] if[not type[a] in -12 -14 -15h; '"qc: ",what," takes timestamps or dates as bounds"]}   / (a datetime casts too)
ts:{[a;b;d] dd[d;".qc.ts[from;to]"]; tmb[a;"ts"]; tmb[b;"ts"]; "p"$ch[("j"$"p"$a;"j"$"p"$b;"j"$"p"$a);::]}
dates:{[a;b;d] dd[d;".qc.dates[from;to]"]; tmb[a;"dates"]; tmb[b;"dates"]; "d"$ch[("j"$"d"$a;"j"$"d"$b;"j"$"d"$a);::]}
/ val: an arbitrary q value — rec over the full-domain zoo with list, dict, table and keyed-table nodes (A27), for
/ properties about serialisation, IPC, formatting and match itself; -9!-8!x round-trips everything it makes.
/ Children that are same-type atoms arrive as a typed vector and conforming dicts as a table: both already values.
vleaf:one (value t),(str;{[d] draw vec[0 4] draw elem key t})
vnode:{if[not 0h=type x; :x]; k:draw elem `list`dict`tab`ktab; n:count x;
  $[k=`list; x; k=`dict; (draw lst[n,n] sym)!x;
    $[not k in `tab`ktab; 0b; n=0; 0b; not all (type each x) within 1 19h; 0b; 1=count distinct count each x]; [tb:flip (`$"c",/:string til n)!x; $[(k=`ktab) and n>1; 1!tb; tb]];
    x]}
val:{[d] dd[d;".qc.val"]; draw rec[0 4;vleaf;vnode]}
vec:{[r;c;d] dd[d;".qc.vec[r] c"]; c$draw lst[r] t c}            / typed even when empty
/ ---- tables: rows are spans (deleting a row is one deletion); a constrained column is drawn with the row so far ----
/ A constrained column is a projection of mono, uniq or dep, which tabr recognises (mark) and draws itself; drawn on
/ its own each is just its plain part. mono[b;g]: the first row draws b, each later row adds a delta drawn from g
/ (sortedness is in the choices, so it survives every shrink, A18). uniq g: distinct values — over a finite set
/ (an elem, or an int with a small constant range) by indexing the values not yet used, one choice and no retries,
/ with the row count capped by the set (A19); otherwise by retrying g and discarding when tries run out.
/ dep f: f receives the row so far (a dict of the columns before it, in column order) and returns a spec.
/ The delta must be non-negative: a negative one would break the promise in the name, so it is a usage error.
mono:{[b;g;d] dd[d;".qc.mono[base;delta]"]; draw b}
uniq:{[g;d] dd[d;".qc.uniq g"]; draw g}
dep:{[f;d] dd[d;".qc.dep f"]; need[f;"dep's f"]; draw f (0#`)!()}
atr:{[a;g;d] dd[d;".qc.atr[a] g"]; if[not a in `s`u`p`g; '"qc: atr takes one of `s`u`p`g"]; v:draw g; a#$[a in `s`p; asc v; a=`u; distinct v; v]}   / s and p need sorted input, u distinct: the generator makes the value fit its attribute (A23)
mark:{[g] $[104h<>type g; `; (f:first value g)~mono; `mono; f~uniq; `uniq; f~dep; `dep; `]}
/ the finite candidate set of a generator, or :: — an elem's list, an int's constant range of at most 1024 values
cands:{[g] $[104h<>type g; ::; (f:first value g)~elem; (),value[g] 1; not f~int; ::; type[value[g] 1] within 100 112; ::; 1024<w:wid . 2#r:rng value[g] 1; ::; r[0]+til "j"$w]}
/ per-table state: mono's last value, uniq's remaining candidates, uniq's used values. CS and each US entry grow behind
/ a :: seed: a dict amended with one long has a typed value list and refuses the next timestamp (pitfall 6, dict form)
CS:(enlist `)!enlist (::); UR:(0#`)!(); US:(0#`)!()
udraw:{[k;g] $[k in key UR; [rem:UR k; v:rem ch[(0;-1+count rem;0);`u]; UR[k]:rem except v; v];
  [n:0; while[n<cf`tries; v:draw g; if[not any v~/:1_US k; US[k]:US[k],enlist v; :v]; n+:1]; '"qc.discard"]]}   / (match, not in: a dict has no place on in's left; 1_: the seed)
mdel:{[g] v:draw g; if[v<0; '"qc: mono: the delta must be non-negative"]; v}   / a mono column's step
/ one row: the columns in order, a constrained column with the state and the row so far. The row grows behind a ::
/ seed (a dict amended with one symbol has a typed value list and refuses the next long: pitfall 6). d: via draw
rowd:{[cg;ks;d] r:(enlist `)!enlist (::); c:key cg; j:0;
  while[j<count c; k:c j; g:cg k; a:$[`=ks k; ::; value g];
    v:$[`mono=ks k; $[k in key CS; CS[k]+mdel a 2; draw a 1]; `uniq=ks k; udraw[k;a 1]; `dep=ks k; draw (a 1) 1_r; draw g];
    if[`mono=ks k; CS[k]:v]; r[k]:v; j+:1]; 1_r}
/ probe g: its minimal value, drawn outside the example (choices, spans, cursor and mode saved and restored), so a
/ table with no rows can still type its columns from what they would have drawn. A generator that cannot give a
/ minimal value (a dep over an empty row, a filter) leaves its column untyped.
probe:{[g] s:(C;E;st;i;nch;P;mn;sh;dp;CS;UR;US); P::`long$(); mn::1b; sh::0b; r:@[dr;g;{[s;e] unp s; (::)}[s]]; unp s; r}
unp:{[s] C::s 0; E::s 1; st::s 2; i::s 3; nch::s 4; P::s 5; mn::s 6; sh::s 7; dp::s 8; CS::s 9; UR::s 10; US::s 11;}   / what probe saved
empties:{[xs] {[v] $[(::)~v; (); 0>type v; 0#enlist v; ()]} each xs}      / each probed value: an atom's typed empty (0# of a symbol atom is nyi; of a 1-vector it is fine), else general. (xs, not vs: vs is a keyword)
emtab:{[cg;p] key[cg]!$[(::)~p; count[cg]#enlist (); empties value p]}     / typed empties from a probed row, or untyped when the probe failed
/ the table core: rows through lst; em gives typed empty columns (a schema knows them; a column dict probes them, so
/ tab's empty table is typed where a minimal draw is possible); at (col -> attribute) is applied after the rows,
/ sorting by the p then s columns
tabx:{[r;cg;em;at] ks:key[cg]!mark each value cg; r:rng r;
  $[all `=value ks; [if[(::)~em; em:emtab[cg;probe cg]]; rs:draw lst[r] cg];   / the probe is one minimal row: a dep sees the columns before it
    [s0:(CS;UR;US); CS::(enlist `)!enlist (::); UR::(0#`)!(); US::(0#`)!(); uc:where ks=`uniq; cd:cands each {value[x] 1} each cg uc; UR::(uc where h)!cd where h:not (::)~/:cd; US::uc!count[uc]#enlist enlist (::);   / the generator inside each uniq; used values behind a :: seed
     if[count UR; r[1]&:min count each UR];                                                          / the rows fit the candidates
     if[(::)~em; p:probe rowd[cg;ks]; if[(::)~p; p:key[cg]!{[ks;k;g] $[`=ks k; probe g; `dep=ks k; ::; probe value[g] 1]}[ks]'[key cg;value cg]]; em:emtab[cg;p]];   / a row whose dep fails: type the other columns alone
     rs:@[{[r;cg;ks] draw lst[r] rowd[cg;ks]}[r;cg];ks;{[s0;e] CS::s0 0; UR::s0 1; US::s0 2; 'e}[s0]]; CS::s0 0; UR::s0 1; US::s0 2]];
  tb:$[count rs; flip key[cg]!flip value each rs; flip em];
  if[count[at] and count rs; tb:((where at=`p),where at=`s) xasc tb; tb:{[at;tb;c] @[tb;c;(at c)#]}[at]/[tb;key at]]; tb}   / parted columns sort first; an empty table carries none, as 0# of a table drops them
tabr:{[r;cg;d] dd[d;".qc.tabr[r] cols"]; if[not dct cg; '"qc: tab needs a dict of column generators"]; tabx[r;cg;::;(0#`)!`symbol$()]}
tab:tabr[0 0W]
ktab:{[k;r;cg;d] dd[d;".qc.ktab[k;r] cols"]; if[not dct cg; '"qc: ktab needs a dict of column generators"]; k:(),k;
  if[count k except key cg; '"qc: ktab: key columns must be columns"]; k xkey tabx[r;@[cg;k;{$[`=mark x; uniq x; x]}];::;(0#`)!`symbol$()]}   / keys are distinct (A19)
/ schema t: a generator of tables shaped like t — the column types from the values (an enumeration's domain from
/ key, nested columns from the first element, a general column as a mix), attributes and keys as t has them,
/ typed empties from 0# (an empty table carries no attributes, as 0# of a table does not, A21)
colg:{[c] tc:type c; $[tc within 20 76h; {[f;d] f$draw elem value f}[key c]; 10h=tc; str; tc within 1 19h; t .Q.t tc;   / enumerations are 20h-76h; a table or dict value (98h 99h) is a general column
  $[0h<>tc; 0b; 0=count c; 0b; all (type each c) within 1 19h]; vec[0 3] .Q.t abs type first c; one (int 0 9;sym;str)]}
/ schema t is a constructor (as lin is): it reads t once and returns the generator schx[k;cg;em;at]
schema:{[x] if[not type[x] in 98 99h; '"qc: schema takes a table"]; k:keys x; u:0!x; cs:cols u; vals:value flip u;
  cg:cs!colg each vals; cg:@[cg;k,cs where `u=attr each vals;{$[`=mark x; uniq x; x]}]; at:cs!attr each vals; at:where[not null at]#at;
  if[(`p in at) and `s in at; '"qc: schema: a table with both a p# and an s# column cannot be reproduced row by row (sort by one or the other)"];
  schx[k;cg;cs!`#'0#'vals;at]}
schx:{[k;cg;em;at;d] dd[d;".qc.schema t"]; tb:tabx[0 0W;cg;em;at]; $[count k; k xkey tb; tb]}


/ ---- state machines ---------------------------------------------------------------------------------
/ sm[h] cmds: a spec whose value is the executed trace. h: `m0 the model, `init/`fini run before and after every
/ example and replay (the real system must be resettable), `steps a range (default 0 0W, capped by size).
/ cmds: a keyed table (or a table with a cmd column) with any of pre gen run post upd; missing columns take
/ the defaults. Each step's span holds its decision bit, command index and input draw and nothing else (C13);
/ run, post and upd happen after it, then inv on the new model. A failed postcondition notes the trace and raises
/ qc.post, a failed invariant qc.inv: failure signals. A w column weights the choice among the available commands.
smd:`pre`gen`run`post`upd!({[m] 1b};{[m] ::};{[a] ::};{[m;a;o] 1b};{[m;a;o] m})
smh:`m0`init`fini`steps`inv!(::;{};{};0 0W;{[m] 1b})   / inv: an invariant of the model, checked after every step (M10)
smt:([]step:`long$();cmd:`symbol$();arg:();res:();model:();ok:`boolean$())
smtab:{[R] $[count R; flip cols[smt]!flip R; smt]}
smnote:{[R] tr:smtab R; $[any blocky each tr`model; delete model from tr; tr]}   / the trace as noted on a failure: a model that holds tables or dicts is left out of the print, where it would bury the steps
sm:{[h;cmds;d] dd[d;".qc.sm[h] cmds"]; if[not dct h; '"qc: sm needs a dict of hooks (m0 init fini steps)"]; if[count k:key[h] except key smh; '"qc: sm: unknown hook ",", " sv string k]; h:smh,h; c:$[98h=type cmds; cmds; 99h<>type cmds; '"qc: cmds"; 98h=type key cmds; 0!cmds; '"qc: cmds"];
  if[not `cmd in cols c; '"qc: cmds"]; miss:key[smd] except cols c; if[count miss; c:c,'flip miss!{[n;f] n#enlist f}[count c] each smd miss];
  if[not all fn each raze c key smd; '"qc: cmds: pre gen run post upd must be functions"]; need[h`init;"init"]; need[h`fini;"fini"]; need[h`inv;"inv"];
  if[not `w in cols c; c:update w:1f from c]; if[$[not type[c`w] in 5 6 7 8 9h; 1b; any c[`w]<=0]; '"qc: cmds: w must be positive weights"]; c:update w:"f"$w from c;
  r:rng h`steps; lo:r 0; mx:"j"$("f"$r 1)&("f"$lo)+sz; m:h`m0; h[`init][]; R:(); n:0; go:1b;   / (cap in floats, C21)
  while[go; beg`step; av:where {[f;m] f m}[;m] each c`pre;
    go:1=$[0=count av; ch[0 0 0;::]; n<lo; ch[1 1 1;::]; n<mx; ch[0 1 0;(mx-n)%1+mx-n]; ch[0 0 0;::]];
    $[go; [j:av ch[(0;-1+count av;0);c[av;`w]]; a:@[draw;c[j;`gen] m;{[h;e] h[`fini][]; 'e}[h]]; end[];   / weighted over the available commands; fini on every exit; (a, not i: i is the cursor)
        o:@[c[j;`run];a;{[h;R;e] note smnote R; h[`fini][]; '"qc.run ",e}[h;R,enlist (n;c[j;`cmd];a;::;::;0b)]];   / an error in the system is a failure, not a generator bug; the trace shows the step that raised
        ok:@[c[j;`post][m;a;];o;{[h;R;e] note smnote R; h[`fini][]; '"qc.post ",e}[h;R,enlist (n;c[j;`cmd];a;o;::;0b)]]; ok:$[(::)~ok; 1b; all ok];
        m2:c[j;`upd][m;a;o]; R,:enlist (n;c[j;`cmd];a;o;m2;ok);
        if[not ok; h[`fini][]; note smnote R; '"qc.post"];
        iv:@[h`inv;m2;{[h;R;e] note smnote R; h[`fini][]; '"qc.inv ",e}[h;R]]; if[not $[(::)~iv; 1b; all iv]; h[`fini][]; note smnote R; '"qc.inv"];   / the invariant, on the model after the step
        m:m2; n+:1];
      end[]]];
  h[`fini][]; smtab R}

/ ---- inside a property ------------------------------------------------------------------------------
note:{N,:enlist x;}
lbs:{[s] if[-11h<>type s; '"qc: a label must be a symbol"]}
label:{[s] lbs s; LX::distinct LX,s;}
classify:{[s;b] if[b; label s];}
collect:{label `$wide[.Q.s1;x]}                        / label by value (bounded by the distinct values; not truncated to the console)
RQ:(`symbol$())!`float$()                              / coverage requirements of the run: label -> percent
cover:{[s;pct;b] lbs s; if[not type[pct] in -5 -6 -7 -8 -9h; '"qc: cover needs a percentage"]; RQ[s]:"f"$pct; if[not s in key LB; LB[s]:0]; if[b; label s];}
/ eq: q's match, explained. on failure the diff table is noted and the property fails with qc.eq
eq:{[a;b] if[a~b; :1b]; d:diff[a;b]; if[0=count d; d:flip `path`why`a`b!(enlist ();enlist `order;enlist shape a;enlist shape b)]; note d; '"qc.eq"}
shape:{$[99h=type x; key x; 98h=type x; cols x; x]}

/ ---- the runner -------------------------------------------------------------------------------------
conf:{$[(::)~x; cfg; type[x] in -6 -7h; cfg,enlist[`n]!enlist x; not dct x; '"qc: cfg"; count k:key[x] except key cfg; '"qc: cfg: unknown key ",", " sv string k; cfg,x]}
byname:{[p;x] $[100h<>type p; 0b; 99h<>type x; 0b; 98h=type key x; 0b; all (value p)[1] in key x]}   / a keyed table is 99h too (C3); a cond chain, not and (C2)
app:{[p;s;x] $[(::)~p; 1b; 0h=type s; p . x; byname[p;x]; p . x (value p)[1]; p @ x]}
pass:{$[(::)~x; 1b; type[x] in -1 1h; all x; ()~x; 1b; '"qc: property returned ",-3!x]}   / () is vacuously true, as all () is
trap:{[f;x] .Q.trp[{[f;x] `ok`r!(1b;f x)}[f];x;{[e;bt] `ok`e`bt!(0b;e;.Q.sbt bt)}]}
ENG:("qc.discard";"qc.overrun";"qc.toodeep";"qc.toolarge";"qc.misaligned")   / the engine's own signals: never a counterexample
FS:("qc.eq";"qc.post";"qc.run";"qc.inv")              / failure-signal stems: qc.<stem>[ detail] is a falsification wherever raised (C14)
fsg:{[e] any {[e;s] s~count[s]#e}[e] each FS}
/ one example: generate, apply, classify the outcome as pass / fail / disc
run1:{[spec;prop]
  g:trap[draw;spec];
  if[not g`ok; :$[g[`e] in ENG; `st`why!(`disc;`$3_g`e); fsg g`e; `st`x`err`bt`ph`notes`choices!(`fail;::;g`e;g`bt;`prop;N;C`v);
    `st`err`bt`ph`notes`choices!(`fail;g`e;g`bt;`gen;N;C`v)]];
  x:g`r; r:trap[{[p;s;x] pass app[p;s;x]}[prop;spec];x];
  $[not r`ok; $[r[`e] in ENG; `st`why!(`disc;`$3_r`e); `st`x`err`bt`ph`notes`choices!(`fail;x;r`e;r`bt;`prop;N;C`v)];   / an engine signal is a discard in either phase
    r`r; `st`x!(`pass;x); `st`x`err`bt`ph`notes`choices!(`fail;x;"false";"";`prop;N;C`v)]}
named:{[spec;prop;x] $[99h=type spec; x; 0h=type spec; pnames[prop;count x]!x; enlist[`x]!enlist x]}
pnames:{[p;n] $[100h=type p; $[n=count a:(value p)[1]; a; `$"x",/:string til n]; `$"x",/:string til n]}
/ Wilson 95% upper bound of a rate: a requirement fails only when the run is confident the rate is below it (C15)
wil:{[n;nn] z:1.96; p:n%nn; (p+(z*z%2*nn)+z*sqrt((p*1-p)%nn)+z*z%4*nn*nn)%1+z*z%nn}
wlo:{[n;nn] z:1.96; p:n%nn; (p+(z*z%2*nn)-z*sqrt((p*1-p)%nn)+z*z%4*nn*nn)%1+z*z%nn}
covt:{[tests] nn:1|tests; tb:([]label:key LB;n:value LB;pct:100*value[LB]%nn);
  tb:update req:.qc.RQ label,lo:100*.qc.wlo[n;nn],hi:100*.qc.wil[n;nn] from tb;   / q-sql resolves globals in the root, not the namespace
  update ok:(hi>=req) or null req,bar:{`$(floor x%5)#"#"} each pct from tb}
result:{[why;tests;seed;spec;prop;o] ok:why=`ok; f:why in `falsified`error; o:(`shrinks`attempts`hist`stop!(0;0;0#H;`n)),o;
  `ok`why`stop`n`shrinks`attempts`seed`x`err`bt`notes`cover`choices`hist`disc`stale!(ok;why;o`stop;tests;o`shrinks;o`attempts;seed;
   $[(why=`falsified) and not (::)~o`x; named[spec;prop;o`x]; (::)]; $[f; o`err; ""]; $[f; o`bt; ""]; $[f; o`notes; ()]; covt tests;
   $[f; o`choices; C`v]; o`hist; o`disc; 0b)}
/ a coverage requirement is open while the run is not yet confident either way (C15, C19)
opn:{[tests] tb:covt tests; any (tb[`lo]<tb`req)&tb[`req]<=tb`hi}
wid:{[lo;hi] $[null d:hi-lo; 0w; d<0; 0w; 1+"f"$d]}      / a range's width as a float; a full long range is infinite, not null
/ ---- the choice tree: the run enumerates a small space by walking it, and knows when it has tried every input (C19)
tnew:{TR::0#TR; TR,:(0N;0N;0N;0N;0N;0n;0;0;0b;`); TX::(enlist 0#0)!enlist 0N;}
xch:{[m;v] $[null c:TX (m;v); 0b; TR[c;`x]]}            / is the child of node m at value v exhausted?
/ the value nearest the origin whose child is absent or open: an open node has fewer than w exhausted children,
/ so the nearest nx+1 values in range include one
pick:{[m] r:TR m; o:r`o; d:0; while[d<=1+r`nx; if[(v:o+d) within r`lo`hi; if[not xch[m;v]; :v]]; if[(v:o-d) within r`lo`hi; if[not xch[m;v]; :v]]; d+:1]; '"qc: internal error in the choice tree, please report"}
/ the next input to try: descend from the root by pick until a child is absent. The prefix ends there; the rest
/ of the example is origins (minimal mode), so for a fixed structure the order is shortlex, simplest first
nxt:{m:0; p:`long$(); go:1b; while[go; p,:v:pick m; $[null c:TX (m;v); go:0b; m:c]]; p}
/ record the example's choices as a path ending in conclusion s, and say whether enumeration goes on. It stops
/ when the tree contradicts the path — a range or an ending differs from what an earlier example found at the
/ same prefix, so the structure depended on something other than the choices and no claim is safe — or when the
/ product of the widths along the path exceeds the budget n: a tree whose every path has product <= n has at
/ most n leaves (the leaves' reciprocal products sum to at most 1), so while it holds the run will finish
tput:{[n;s] V:C`v; LO:C`lo; HI:C`hi; O:C`o; k:0; pz:1f; m:0; ok:1b;
  while[ok and k<count V; r:TR m;
    $[not `=r`c; ok:0b; null r`lo; [TR[m;`lo]:LO k; TR[m;`hi]:HI k; TR[m;`o]:O k; TR[m;`w]:wid[LO k;HI k]]; not (r[`lo]=LO k) and r[`hi]=HI k; ok:0b];
    if[ok; pz*:TR[m;`w]; if[null c:TX (m;V k); c:count TR; TR,:(m;V k;0N;0N;0N;0n;0;0;0b;`); TX[(m;V k)]:c; TR[m;`nc]+:1]; m:c]; k+:1];
  if[ok; r:TR m; $[not null r`lo; ok:0b; not `=r`c; ::; [TR[m;`c]:s; TR[m;`x]:1b; TR[m;`w]:1f; p:r`p; go:1b;   / (a repeated input concludes nothing new)
    while[go and not null p; TR[p;`nx]+:1; $[TR[p;`nx]>=TR[p;`w]; [TR[p;`x]:1b; p:TR[p;`p]]; go:0b]]]]];
  ok and pz<=n}
/ the run stops when it has learned what it can (C19): a failure, a give-up, an exhausted space, the budget n
/ with no coverage question open, or the cap nmax on extending the budget to settle one. Example 0 is the
/ minimal input; while every path through the choice tree fits the budget the run enumerates the space
/ (every input once, simplest first) and stops exhausted when the tree is; otherwise it samples.
tidy:{run::0b; cf::cfg; dp::0; st::(); sz::bs::cfg`sz;}   / the example boundary on the way out: flag, config, depth, spans, base size (C9)
chk:{[c;spec;prop] if[run; '"qc: nested check"]; r:@[chk1[c;spec];prop;{tidy[]; 'x}]; tidy[]; r}
chk1:{[c;spec;prop] c:conf c; cf::c; if[not (::)~prop; need[prop;"the property"]];
  if[(100h=type prop) and 0h=type spec; if[count[spec]<>count (value prop)[1]; '"qc: the property takes ",string[count (value prop)[1]]," arguments, the spec has ",string count spec]]; seed:$[null c`seed; "i"$1+.z.p mod 2147483646; "i"$c`seed]; system"S ",string seed;
  LB::(`symbol$())!`long$(); RQ::(`symbol$())!`float$(); n:c`n; nmax:$[null c`nmax; 10*n; c`nmax]; dc:(`symbol$())!`long$();
  tests:0; nd:0; o:(`symbol$())!(); k:0; en:1b; ext:0b; tnew[]; run::1b;
  f:dbf[spec;prop]; if[not null f; if[count key f; reset[get f;c`sz;0b;0b]; r:run1[spec;prop]; $[`fail=r`st; o:r; hdel f]]];
  while[$[count o; 0b; nd>n*c`disc; 0b; en; not TR[0;`x]; tests<n; 1b; not opn tests; 0b; tests<nmax];
    if[tests>=n; ext:1b];
    $[en; reset[$[0=k; `long$(); nxt[]];c`sz;1b;0b]; reset[`long$();c[`sz]&(c[`sz]*tests) div n;0b;0b]];   / enumerating: the tree's next prefix, the rest origins, at full size so the ranges are the real ones; sampling: fresh, size ramping
    r:run1[spec;prop];
    if[en; en:tput[n;r`st]];
    $[`pass=r`st; [tests+:1; {LB[x]:1+0^LB x} each LX]; `disc=r`st; [nd+:1; dc[r`why]:1+0^dc r`why]; o:r];
    k+:1];
  gu:(nd>n*c`disc) or (0=tests) and nd>0;                          / gave up: too many discards, or nothing but discards
  stp:$[count o; `fail; gu; `gaveup; en; `exhausted; not ext; `n; opn tests; `nmax; `cover];   / (stp, not st: st is the span stack)
  if[(count o) and c[`shrinks]>0; o:shr[spec;prop;o]];
  if[count o; if[not null f; f set o`choices]];
  run::0b; why:$[count o; $[`gen=o`ph; `error; `falsified]; gu; `gaveup; not all (covt tests)`ok; `cover; `ok];
  if[count o; lf::`spec`prop`choices!(spec;prop;o`choices)];
  res:result[why;tests;seed;spec;prop;o,`disc`stop!(dc;stp)];
  if[c[`v]>0; rep res]; res}
check:chk[::]
lf:`spec`prop`choices!(::;::;`long$())               / the last failure; again[] rechecks it
again:{recheck[lf`spec;lf`prop;lf`choices]}
/ a suite: dict of name -> (spec;prop); one report per failure, one row per property
chks:{[c;d] if[$[not dct d; 1b; not all 2=count each value d]; '"qc: checks takes a dict of name -> (spec;prop)"];
  r:{[c;n;sp] if[0<conf[c]`v; -1 "--- ",string n]; t0:.z.p; o:chk[c;sp 0;sp 1]; (n;o`ok;o`why;o`stop;o`n;o`shrinks;o`seed;"j"$(.z.p-t0)%1000000)}[c]'[key d;value d];
  tb:flip `name`ok`why`stop`n`shrinks`seed`ms!flip r; if[0<conf[c]`v; show delete ms from tb]; tb}   / ms is data (timings are not for transcripts)
checks:chks[::]
/ ---- integration (M9): a property inside another framework, a suite as a script --------------------------
/ must: check quietly and signal the whole report on anything but ok, so k4unit, qspec or a .Q.trp script sees one
/ error whose first line is the verdict (A24). The spelling "qc: FAIL …" keeps the error vocabulary (C14).
mustc:{[c;spec;prop] c:conf c; c[`v]:0; r:chk[c;spec;prop]; if[not r`ok; '"qc: ","\n" sv report r]; r}
must:mustc[::]
main:{[d] r:checks d; exit "i"$sum not r`ok}                  / a suite as a CI script: prints the table, exits with the failure count
/ exact replay of a recorded choice vector; stale when the generator no longer consumes it as recorded
recheck:{[spec;prop;p] if[run; '"qc: nested check"]; if[not (::)~prop; need[prop;"the property"]]; r:@[recheck1[spec;prop];p;{tidy[]; 'x}]; tidy[]; r}
recheck1:{[spec;prop;p] cf::cfg; reset[p;cfg`sz;0b;0b]; run::1b; o:run1[spec;prop]; run::0b;
  why:$[`pass=o`st; `ok; `disc=o`st; `gaveup; `gen=o`ph; `error; `falsified];
  res:result[why;1;system"S";spec;prop;o,`disc`stop!((`symbol$())!`long$();$[`fail=o`st;`fail;`n])];
  if[not `fail=o`st; res[`choices]:C`v];
  res[`stale]:(i<>count P) or not (count[P]#C`v)~"j"$p; if[cfg[`v]>0; rep res]; res}


/ ---- shrinking: edit the recorded choice vector, replay, keep what still fails and is smaller ------------
zig:{(2*"f"$abs x)-x>0}                               / distance from origin: 0 1 -1 2 -2 ... (float: 2*0W overflows)
skey:{[v;o] (count v; zig ("f"$v)-"f"$o)}              / shortlex key; the distance in floats: a long difference wraps on full ranges (C21)
less:{[a;b] $[a[0]<>b 0; a[0]<b 0; a[1]~b 1; 0b; (a[1]<b 1) first where a[1]<>b 1]}
dl:{[v;s;e] (s#v),e _ v}
pt:{[v;s;e;w] (s#v),w,e _ v}
/ shrinker state: current vector, its choice and span tables, its outcome, the original error
cv:`long$(); cC:C; cE:E; co:()!(); cerr:""; na:0; ns:0; cp:`; sspec:(::); sprop:(::)
K:(enlist 0#0)!enlist 0N                              / candidates already tried (seeded with a vector key)
H:([]n:`long$();pass:`symbol$();len:`long$())         / history of accepted shrinks
/ try one candidate, as a cond chain: budget, identical, cached, valid, same failure, strictly smaller (C2)
try:{[cand] cand:"j"$cand;
  $[na>=cf`shrinks; 0b; cand~cv; 0b; not null K cand; 0b;
    [na+:1; reset[cand;bs;0b;1b]; r:run1[sspec;sprop];
     ok:$[not `fail=r`st; 0b; (r`err) in ENG; 0b; cf`same; r[`err]~cerr; 1b];
     if[ok; ok:less[skey[C`v;C`o];skey[cv;cC`o]]];
     if[ok; cv::C`v; cC::C; cE::E; co::r; ns+:1; H,:(na;cp;count cv)];
     K[cand]:0; ok]]}
spans:{`w xdesc update w:e-s from cE}                 / largest first
/ consecutive siblings from span s0: same label and depth, each starting where the previous ended
chain:{[s0;l0;d0] c:`s xasc select s,e from cE where l=l0,d=d0,s>=s0; if[not s0~c[0;`s]; :0#c];
  k:1; while[$[k<count c; c[k;`s]=c[k-1;`e]; 0b]; k+:1]; k#c}   / cond, not and: the row k does not exist at the end (C2)
/ passes: each loops over the current structure, re-deriving it after every accepted attempt, and returns progress
pdisc:{cp::`disc; p:0b; j:0; while[j<count tb:select from spans[] where x; $[try dl[cv;tb[j;`s];tb[j;`e]]; p:1b; j+:1]]; p}
pdel:{cp::`del; p:0b; j:0; while[j<count tb:spans[]; s:tb[j;`s];
  $[try dl[cv;s;tb[j;`e]]; [p:1b; adel[s;tb[j;`l];tb[j;`d]]]; j+:1]]; p}
adel:{[s;l;d] k:2; while[$[k<=count c:chain[s;l;d]; try dl[cv;s;c[k-1;`e]]; 0b]; k*:2];}   / delete 2, 4, 8 siblings
pzero:{cp::`zero; p:0b; j:0; while[j<count tb:spans[]; ix:tb[j;`s]+til tb[j;`w]; w:cC[`o] ix;
  $[cv[ix]~w; j+:1; try @[cv;ix;:;w]; p:1b; j+:1]]; p}
pdesc:{cp::`desc; p:0b; j:0; while[j<count tb:spans[]; s0:tb[j;`s]; e0:tb[j;`e]; l0:tb[j;`l];
  ds:select from tb where l=l0,s>=s0,e<=e0,not (s=s0)&e=e0; ii:0; ok:0b;
  while[(ii<count ds) and not ok; ok:try pt[cv;s0;e0;cv ds[ii;`s]+til ds[ii;`w]]; ii+:1];
  $[ok; p:1b; j+:1]]; p}
bkey:{[s;e] (e-s;zig ("f"$cv ix)-"f"$cC[`o] ix:s+til e-s)}    / shortlex key of one block (floats, C21)
ordr:{[ks] n:count ks; ix:til n; ii:0; while[ii<n-1; j:ii+1; while[j<n; if[less[ks ix j;ks ix ii]; ix[ii,j]:ix[j,ii]]; j+:1]; ii+:1]; ix}
blk:{[c;ix] raze {[s;e] cv s+til e-s}'[c[ix;`s];c[ix;`e]]}
psort:{cp::`sort; p:0b; j:0;
  while[j<count tb:`s xasc cE; c:chain[tb[j;`s];tb[j;`l];tb[j;`d]];
    $[2>count c; j+:1;
      [ks:bkey'[c`s;c`e]; ix:ordr ks; ok:0b;
       if[not ix~til count ix; ok:try pt[cv;c[0;`s];last c`e;blk[c;ix]]];
       ii:0; while[(ii<count[c]-1) and not ok; if[less[ks ii+1;ks ii]; ok:try pt[cv;c[ii;`s];c[ii+1;`e];blk[c;(ii+1;ii)]]]; ii+:1];
       $[ok; p:1b; j+:1]]]]; p}
pdup:{cp::`dup; p:0b; ix:where cv<>cC`o; g:ix each value group (flip (cv;cC`lo;cC`hi)) ix; g:g where 1<count each g; j:0;   / same value and range
  while[j<count g; ps:g j; ok:try @[cv;ps;:;cC[`o] ps];
    if[not ok; d:("f"$cv ps)-"f"$cC[`o] ps; go:1b; while[go and all 1<abs d; d:floor d%2; go:try @[cv;ps;:;cC[`o][ps]+"j"$d]; ok:ok or go]];   / distances in floats (C21)
    if[ok; p:1b]; j+:1]; p}
bsr:{[j] a:cC[`o] j; b:cv j; p:0b; while[1<abs ("f"$b)-"f"$a; m:"j"$(("f"$a)+"f"$b)%2; $[m in (a;b); a:b; try @[cv;j;:;m]; [b:m; p:1b]; a:m]]; p}   / float midpoint: b-a overflows on full ranges
pmin:{cp::`min; p:0b; j:0; while[j<count cv; $[cv[j]=cC[`o] j; j+:1; try @[cv;j;:;cC[`o] j]; p:1b; [if[bsr j; p:1b]; j+:1]]]; p}
/ pairs: move value from an earlier choice to a later one of the same range within a small window (elements of a
/ list are separated by their decision bits), then lower both together
pred:{cp::`pair; p:0b; ii:0; while[ii<count[cv]-1; vi:cv ii; oi:cC[`o] ii;
  $[vi=oi; ii+:1;
    [js:(ii+1+til 3) inter where (cC[`lo]=cC[`lo] ii)&cC[`hi]=cC[`hi] ii; ok:0b; n:0;
     while[(n<count js) and not ok; j:js n; vj:cv j; k:"j"$(("f"$vi)-"f"$oi)&("f"$cC[`hi] j)-"f"$vj;   / room to move, in floats (C21); a rounded candidate is clamped on replay
       ok:$[k>0; try @[cv;ii,j;:;(vi-k;vj+k)]; 0b];
       if[(not ok) and vj>cC[`o] j; ok:try @[cv;ii,j;-;1]]; n+:1];
     $[ok; p:1b; ii+:1]]]]; p}
/ blocks (M8): a blk span is a length choice k followed by m blocks of k values (one for bulk, one per column for
/ btab). Delete the same chunk from every block and lower k (ddmin: g chunks; a hit keeps g, a miss doubles it),
/ so a block reaches a minimum that is not a prefix.
pblk:{cp::`blk; p:0b; bl:L`blk; if[null bl; :0b]; j:0;
  while[j<count tb:select from cE where l=bl; s:tb[j;`s]; g:2; ok0:0b;
    while[$[1>k:cv s; 0b; g<=k]; m:(tb[j;`e]-s+1) div k; w:k div g; a:0; ok:0b;
      while[(a<k) and not ok; w2:w&k-a; ix:s+1+raze (a+til w2)+/:k*til m; ok:try @[cv (til count cv) except ix;s;:;k-w2]; a+:w];
      $[ok; [ok0:1b; g:2|g div 2]; g*:2]];
    if[ok0; p:1b]; j+:1]; p}
/ shrink a failing outcome: run every pass until a whole cycle makes no progress or the attempt budget is spent
shr:{[spec;prop;o] sspec::spec; sprop::prop; cv::C`v; cC::C; cE::E; co::o; cerr::o`err; na::0; ns::0;
  K::(enlist 0#0)!enlist 0N; H::0#H; bs::cf`sz;
  while[$[na<cf`shrinks; any {x[]} each (pblk;pdisc;pdel;pzero;pdesc;psort;pdup;pmin;pred); 0b]];   / cond, not and: passes are not free
  co,`shrinks`attempts`hist!(ns;na;H)}
/ failure database: one file per (spec;prop) under cfg`db, keyed by cfg`name or a hash of their source
dbf:{[spec;prop] $[null cf`db; `; ` sv (cf`db;$[null cf`name; `$raze string md5 "c"$-8!(spec;prop); cf`name])]}   / exact bytes: .Q.s1 truncates to the console

/ ---- formatting: a total dispatch over the eight shapes (C3) -------------------------------------------
kind:{ty:type x; $[(::)~x; `null; ty within 100 112; `fn; ty<0; `atom; ty within 1 19; `vec; 0h=ty; `list; 98h=ty; `tab;
  99h=ty; $[98h=type key x; `ktab; `dict]; `other]}
blocky:{k:kind x; $[k in `tab`ktab`dict; 1b; k=`list; any blocky each x; 0b]}   / needs a block: holds a table or dict somewhere
wide:{[f;x] c:system"c"; system"c 2000 400"; r:@[f;x;{[c;e] system"c "," " sv string c; 'e}[c]]; system"c "," " sv string c; r}
ind:{[n;s] "\n" sv (n#" "),/:"\n" vs s}
lab:{$[-11h=type x; string x; .Q.s1 x]}
ftab:{[tb] n:count tb; s:-1_.Q.s $[n>cf`rows; (cf`rows)#tb; tb]; $[n>cf`rows; s,"\n... ",string[n-cf`rows]," more rows"; s]}
fmt:{wide[fmt1;x]}
fmt1:{k:kind x; $[`null=k; "::"; k in `atom`vec`fn`other; .Q.s1 x; k in `tab`ktab; ftab x;
  `dict=k; "\n" sv {[k;v] $[blocky v; lab[k],":\n",ind[2;fmt1 v]; lab[k],": ",fmt1 v]}'[key x;value x];
  any blocky each x; "\n" sv {[ix;v] $[blocky v; string[ix],":\n",ind[2;fmt1 v]; string[ix],": ",fmt1 v]}'[til count x;x];
  .Q.s1 x]}

/ ---- diff: one row per difference, typed before counted before valued (C2, C3) ----------------------
dft:([]path:();why:`symbol$();a:();b:())
diff:{[a;b] r:df[();a;b]; $[count r; flip `path`why`a`b!flip r; dft]}
df:{[p;a;b] ta:type a; tb:type b;
  $[not ta=tb; enlist (p;`type;ta;tb);
    ta within 100 112; dat[p;a;b];
    ta<0; dat[p;a;b];
    10h=ta; dat[p;a;b];
    ta within 1 19; dvec[p;a;b];
    0h=ta; dlist[p;a;b];
    98h=ta; dtab[p;a;b];
    99h=ta; $[98h=type key a; dtab[p;0!a;0!b]; ddict[p;a;b]];
    dat[p;a;b]]}
dat:{[p;a;b] $[a~b; (); enlist (p;`value;a;b)]}
dcnt:{[p;a;b] $[count[a]=count b; (); enlist (p;`count;count a;count b)]}
dvec:{[p;a;b] n:count[a]&count b; dcnt[p;a;b],{[p;a;b;ii] (p,ii;`value;a ii;b ii)}[p;a;b] each where (n#a)<>n#b}
dlist:{[p;a;b] n:count[a]&count b; dcnt[p;a;b],raze {[p;a;b;ii] df[p,ii;a ii;b ii]}[p;a;b] each til n}
ddict:{[p;a;b] ka:key a; kb:key b; if[not type[ka]=type kb; :enlist (p;`keytype;type ka;type kb)];   / (two empty dicts can differ only there; without this row the diff is empty and eq says order)
  ({[p;k] (p,k;`key;k;::)}[p] each ka except kb),({[p;k] (p,k;`key;::;k)}[p] each kb except ka),
  raze {[p;a;b;k] df[p,k;a k;b k]}[p;a;b] each ka inter kb}
dtab:{[p;a;b] ca:cols a; cb:cols b; n:count[a]&count b;
  ({[p;c] (p,c;`key;c;::)}[p] each ca except cb),({[p;c] (p,c;`key;::;c)}[p] each cb except ca),dcnt[p;a;b],
  raze {[p;a;b;c] df[p,c;a c;b c]}[p;n#a;n#b] each ca inter cb}

/ ---- reporting -------------------------------------------------------------------------------------
sfx:`exhausted`cover`nmax!(", exhausted";", coverage settled";", coverage undecided")
rerun:{[c] "rerun: .qc.again[]  or  .qc.recheck[spec;prop;",$[count c; " " sv string c; "`long$()"],"]"}   / exact: .Q.s1 truncates; an empty vector is spelled, not elided
report:{[r] c:cf; s:$[r`ok; enlist "ok ",string[r`n]," tests",$[(r`stop) in key sfx; sfx r`stop; ""]," (seed ",string[r`seed],")";
  `gaveup=r`why; enlist "FAIL gave up after ",string[r`n]," tests; discards: ",", " sv {string[x]," ",string y}'[key r`disc;value r`disc];
  `cover=r`why; enlist "FAIL coverage not met after ",string[r`n]," tests";
  (enlist "FAIL ",string[r`why]," after ",string[r`n]," tests, ",string[r`shrinks]," shrinks (",string[r`attempts]," attempts, seed ",string[r`seed],")"),
   $[(::)~r`x; (); enlist fmt r`x],$[(r`err)~"false"; (); enlist r`err],(fmt each r`notes),$[c[`v]>1; enlist r`bt; ()],
   $[r`stale; enlist "stale: the generator has changed since these choices were recorded"; ()],
   enlist rerun r`choices];
  s,$[count r`cover; enlist ftab r`cover; ()]}
rep:{-1 "\n" sv report x;}

new[]
\d .
