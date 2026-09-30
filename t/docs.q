/ C18: every .qc.name the design and README mention exists
idch:.Q.a,.Q.A,.Q.n
names:{[f] ln:read0 f; distinct raze {[l] raze {[l;i] n:(i+4)_l; `$n til count[n]^first where not n in idch}[l] each l ss ".qc."} each ln}   / (a name that ends its line: first where gives 0N, and til 0N is a domain error)
have:key `.qc
missing:{[f] (names[f] except have) except `}
.t.t["every .qc name in docs/DESIGN.md exists"; 0=count missing `:docs/DESIGN.md]
.t.t["every .qc name in README.md exists"; 0=count missing `:README.md]
.t.t["every .qc name in COOKBOOK.md exists"; 0=count missing `:COOKBOOK.md]
.t.t["every .qc name in EXAMPLES.md exists"; 0=count missing `:EXAMPLES.md]
.t.t["every .qc name in examples/mdp/LOG.md exists"; 0=count missing `:examples/mdp/LOG.md]
.t.t["every .qc name in WALKTHROUGH.md exists"; 0=count missing `:WALKTHROUGH.md]
.t.t["every .qc name in WALKTHROUGH2.md exists"; 0=count missing `:WALKTHROUGH2.md]
if[count missing `:WALKTHROUGH2.md; -1 "  WALKTHROUGH2.md mentions: ",.Q.s1 missing `:WALKTHROUGH2.md]
if[count missing `:WALKTHROUGH.md; -1 "  WALKTHROUGH.md mentions: ",.Q.s1 missing `:WALKTHROUGH.md]
if[count missing `:docs/DESIGN.md; -1 "  docs/DESIGN.md mentions: ",.Q.s1 missing `:docs/DESIGN.md]
if[count missing `:README.md; -1 "  README.md mentions: ",.Q.s1 missing `:README.md]
/ REFERENCE.md is the index of every public name: every name it gives exists, and every generator qc.q documents
/ (a dd[d;".qc.…"] string) is in it, so a new generator cannot land without a line there
.t.t["every .qc name in REFERENCE.md exists"; 0=count missing `:REFERENCE.md]
if[count missing `:REFERENCE.md; -1 "  REFERENCE.md mentions: ",.Q.s1 missing `:REFERENCE.md]
docd:distinct raze {[l] {[l;i] n:(i+10)_l; `$n til count[n]^first where not n in idch}[l] each l ss "dd[[]d;\".qc."} each read0 `:qc.q   / the documented generators' names
.t.t["every generator qc.q documents is in REFERENCE.md"; 0=count docd except names `:REFERENCE.md]
if[count docd except names `:REFERENCE.md; -1 "  not in REFERENCE.md: ",.Q.s1 docd except names `:REFERENCE.md]
/ WALKTHROUGH.md's excerpts: a ```q block that is not a transcript begins with a comment naming a file, and every
/ other line of it is a line of that file, so an excerpt cannot drift from the code it shows
excs:{[f] ln:read0 f; o:where ln like "```q"; c:where ln like "```"; b:{[ln;c;o] e:first c where c>o; ln (o+1)+til (e-o)-1}[ln;c] each o; b where not any each b like\:"q)*"}
exok:{[b] $[not (first b) like "/ *"; 0b; @[{[b] all (1_b) in read0 hsym `$2_first b};b;0b]]}
exb:excs `:WALKTHROUGH.md
.t.t["every excerpt in WALKTHROUGH.md names its file and is in it, line for line"; (10<count exb) and all exok each exb]
if[not all exok each exb; -1 "  not in its file: ",/:first each exb where not exok each exb]
exo:excs `:WALKTHROUGH2.md
.t.t["every excerpt in WALKTHROUGH2.md names its file and is in it, line for line"; (10<count exo) and all exok each exo]
if[not all exok each exo; -1 "  not in its file: ",/:first each exo where not exok each exo]
