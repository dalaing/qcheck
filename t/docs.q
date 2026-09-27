/ C18: every .qc.name the design and README mention exists
idch:.Q.a,.Q.A,.Q.n
names:{[f] ln:read0 f; distinct raze {[l] raze {[l;i] n:(i+4)_l; `$n til count[n]^first where not n in idch}[l] each l ss ".qc."} each ln}   / (a name that ends its line: first where gives 0N, and til 0N is a domain error)
have:key `.qc
missing:{[f] (names[f] except have) except `}
.t.t["every .qc name in DESIGN.md exists"; 0=count missing `:DESIGN.md]
.t.t["every .qc name in README.md exists"; 0=count missing `:README.md]
.t.t["every .qc name in COOKBOOK.md exists"; 0=count missing `:COOKBOOK.md]
.t.t["every .qc name in EXAMPLES.md exists"; 0=count missing `:EXAMPLES.md]
.t.t["every .qc name in examples/mdp/LOG.md exists"; 0=count missing `:examples/mdp/LOG.md]
if[count missing `:DESIGN.md; -1 "  DESIGN.md mentions: ",.Q.s1 missing `:DESIGN.md]
if[count missing `:README.md; -1 "  README.md mentions: ",.Q.s1 missing `:README.md]
/ REFERENCE.md is the index of every public name: every name it gives exists, and every generator qc.q documents
/ (a dd[d;".qc.…"] string) is in it, so a new generator cannot land without a line there
.t.t["every .qc name in REFERENCE.md exists"; 0=count missing `:REFERENCE.md]
if[count missing `:REFERENCE.md; -1 "  REFERENCE.md mentions: ",.Q.s1 missing `:REFERENCE.md]
docd:distinct raze {[l] {[l;i] n:(i+10)_l; `$n til count[n]^first where not n in idch}[l] each l ss "dd[[]d;\".qc."} each read0 `:qc.q   / the documented generators' names
.t.t["every generator qc.q documents is in REFERENCE.md"; 0=count docd except names `:REFERENCE.md]
if[count docd except names `:REFERENCE.md; -1 "  not in REFERENCE.md: ",.Q.s1 docd except names `:REFERENCE.md]
