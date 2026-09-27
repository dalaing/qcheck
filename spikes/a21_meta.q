\l spikes/h.q
/ A21: a generator from a schema. First try: from meta (c t f a). Finding: meta's f names only keyed-table foreign
/ keys, so an enumerated symbol column is indistinguishable from a plain one — a schema read from a sample table's
/ values (type, key for the enumeration domain, attr, 0# for typed empties) can reproduce everything meta shows
/ and the enumeration too. Exit: the generated table's meta equals the original's for six shapes. (like is a keyword: lk.)
if[not `qc in key `; system"l qc.q"]
system"S 7"
dom:`a`b`c                                                                          / an enumeration domain
/ the generator for one column, read from its values: the type (nested: the inner type of the first element),
/ an enumeration's domain via key (meta's f names only keyed-table foreign keys), a general column as a mixed pair
colg:{[c] tc:type c;
  $[tc>=20h; {[f;d] f$.qc.draw .qc.elem value f}[key c]; tc within 1 19h; .qc.t .Q.t tc;
    (0h=tc) and (count c) and all (type each c) within 1 19h; .qc.vec[0 3] .Q.t abs type first c; {[d] (.qc.draw .qc.int 0 9;.qc.draw .qc.sym)}]}
/ from a sample table: column generators from the values, attributes reapplied (s and p after a sort), empties typed
/ by 0# of the sample, keys as keys says (distinct keys are M7's uniq; not enforced here)
lk:{[t] k:keys t; u:0!t; cs:cols u; vals:value flip u; cg:colg each vals; at:cs!attr each vals;
  {[k;cs;vals;cg;at;d] n:.qc.ch[(0;5;0);`u]; r:$[n; {[n;g] .qc.draw n#enlist g}[n] each cg; `#'0#'vals]; tb:flip cs!r;   / (`#: 0# keeps a vector's attribute, though 0# of a table drops them)
    if[n; tb:@[tb;where at in `s`p;asc]; tb:{[at;tb;c] @[tb;c;(at c)#]}[at]/[tb;where not null at]];   / (0# of a table drops attributes, so an empty table has none)
    $[count k; k xkey tb; tb]}[k;cs;vals;cg;at]}   / (at is passed into the inner lambda: a lambda does not capture the enclosing locals)
shapes:`plain`keyed`nested`attrs`general`enum!(
  ([]a:1 2;b:`x`y;c:1.5 2.5;d:2000.01.01 2000.01.02);
  ([k:1 2]v:`x`y);
  ([]a:1 2;b:(1 2;3 4 5);c:("ab";"cde"));
  ([]t:`s#1 2 3;s:`g#`a`b`a;p:`p#1 1 2);
  ([]a:1 2;b:(1;`x));
  ([]s:`dom$`a`b;v:1 2))
res:{[t] g:lk t; ok:{[t;g;i] tb:.qc.draw g; (meta $[count tb; t; 0#t])~meta tb}[t;g] each til 20; all ok}'[value shapes]   / (an empty nested column has no type to show: compare with 0#t)
show flip `shape`ok!(key shapes;res)
.h.t["meta round-trips for every shape"; all res]
.h.t["the key columns of the keyed shape are what keys says"; (enlist `k)~keys .qc.draw lk shapes`keyed]
-1 "info: enum column types over 8 draws: ",.Q.s1 {type (.qc.draw lk shapes`enum)`s} each til 8;
.h.t["the enumerated column stays enumerated (type 20h)"; all 20h={type (.qc.draw lk shapes`enum)`s} each til 8]
-1 "info: meta of a drawn nested table:"; show meta .qc.draw lk shapes`nested
.h.done[]
