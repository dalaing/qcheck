/ C18: every .qc.name the design and README mention exists
idch:.Q.a,.Q.A,.Q.n
names:{[f] L:read0 f; distinct raze {[l] raze {[l;i] n:(i+4)_l; `$n til first where not n in idch}[l] each l ss ".qc."} each L}
have:key `.qc
missing:{[f] (names[f] except have) except `}
.t.t["every .qc name in DESIGN.md exists"; 0=count missing `:DESIGN.md]
.t.t["every .qc name in README.md exists"; 0=count missing `:README.md]
if[count missing `:DESIGN.md; -1 "  DESIGN.md mentions: ",.Q.s1 missing `:DESIGN.md]
if[count missing `:README.md; -1 "  README.md mentions: ",.Q.s1 missing `:README.md]
