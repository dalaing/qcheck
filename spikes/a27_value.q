\l spikes/h.q
/ A27: an arbitrary q value. rec over the zoo with list, dict, table and keyed-table nodes: what does it reach at
/ size 30 and 100, and does -9!-8! round-trip everything it makes?
if[not `qc in key `; system"l qc.q"]
system"S 7"
cs:"bgxhijefcspmdznuvt"
leaf:.qc.one (value .qc.t),(.qc.str;.qc.sym;{[d] .qc.draw .qc.vec[0 4] .qc.draw .qc.elem cs})
node:{if[not 0h=type x; :x]; k:.qc.draw .qc.elem `list`dict`tab`ktab; n:count x;   / children that are same-type atoms arrive as a typed vector (pitfall 16) and conforming dicts as a table: both already values
  $[k=`list; x; k=`dict; (.qc.draw .qc.lst[n,n] .qc.sym)!x;
    $[not k in `tab`ktab; 0b; n=0; 0b; not all (type each x) within 1 19; 0b; 1=count distinct count each x]; [t:flip (`$"c",/:string til n)!x; $[(k=`ktab) and n>1; 1!t; t]];   / (cond, not and: C2)
    x]}
val:.qc.rec[0 4;leaf;node]
.qc.cfg[`sz]:30; .qc.new[]; V30:{.qc.draw x} each 1000#enlist val
.qc.cfg[`sz]:100; .qc.new[]; V100:{.qc.draw x} each 300#enlist val
.qc.cfg[`sz]:100
kinds:{$[99h=type x; $[98h=type key x; `ktab; `dict]; 98h=type x; `tab; 0h=type x; `list; type[x] within 1 19; `vec; `atom]}
.s.nodes:enlist (::)                                                                / behind a :: seed: nodes include dicts and tables (pitfall 30)
visit:{.s.nodes,:enlist x; $[0h=type x; .z.s each x; 99h=type x; .z.s each value x; 98h=type x; .z.s each value flip x; ::]; ::}   / every node
nodes:{.s.nodes:enlist (::); visit each x; 1_.s.nodes}
N30:nodes V30; K30:kinds each N30
show count each group K30
.h.t["at size 30: atoms, typed vectors, general lists, dicts, tables and keyed tables all appear"; all `atom`vec`list`dict`tab`ktab in K30]
.h.t["all 18 atom types appear"; all (neg .Q.t?cs) in "j"$distinct type each N30]   / (in wants one type: .Q.t? gives longs, type gives shorts)
depth:{$[0h=type x; 1+max 0,.z.s each x; 99h=type x; 1+max 0,.z.s each value x; 98h=type x; 1+max 0,.z.s each value flip x; 0]}
-1 "info: depth quartiles at 30: ",.Q.s1[asc[depth each V30] 250 500 750],"  at 100: ",.Q.s1 asc[depth each V100] 75 150 225;
.h.t["depth grows with size"; (med depth each V100)>=med depth each V30]
rt:{x~-9!-8!x}
.h.t["-9!-8! round-trips every value at size 30"; all rt each V30]
.h.t["and at size 100"; all rt each V100]
bad:V30 where not rt each V30
if[count bad; -1 "info: first non-round-tripping value: ",.Q.s1 first bad]
.h.done[]
