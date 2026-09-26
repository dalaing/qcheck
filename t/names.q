/ C5: a name is free iff not in .Q.res,key .q; nothing in .qc may shadow a reserved word
.t.t["no .qc name shadows a reserved word"; not any (key[`.qc] except `) in .Q.res,key .q]
.t.t["the words that bit us are indeed reserved"; all `bin`tables`cov in .Q.res,key .q]
/ C14: the error vocabulary is closed: every 'qc. literal in the source is an engine signal in ENG or is qc.eq
lits:raze {[l] {[l;i] first "\"" vs (i+2)_l}[l] each l ss "'\"qc."} each read0 `:qc.q
.t.t["every qc. literal in the source is an engine signal (ENG) or begins with a failure-signal stem (FS)"; (0<count lits) and all (lits in .qc.ENG) or .qc.fsg each lits]
