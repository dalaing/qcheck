/ spike harness: .h.t[name;ok] prints PASS/FAIL, .h.done[] exits 0/1. run from repo root: q spikes/aN_x.q
.h.n:0; .h.f:0
.h.t:{[nm;ok] ok:all ok; .h.n+:1; if[not ok;.h.f+:1]; -1 (("FAIL";"PASS") "i"$ok)," ",nm;}
.h.err:{[f;x] @[f;x;{x}]}                        / run f x, returning error string on signal
.h.done:{-1 "\n",string[.h.n-.h.f],"/",string[.h.n]," passed"; exit "i"$.h.f>0}
