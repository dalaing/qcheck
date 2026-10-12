/ oms piece 1: reference data and currency. step 4: the refusal names the currency and the time for an atom asked as
/ well as for lists (step 3's message raised 'type on an atom; entry 3). The piece is described in 01_ref.q.
\d .oms
base:`USD
inst:([sym:`symbol$()] ccy:`symbol$(); lot:`long$(); tick:`float$())
fxr:([]time:`timestamp$(); ccy:`symbol$(); rate:`float$())
onfx:{[t;c;r] `.oms.fxr insert (t;c;r);}                                              / a rate seen: appended, in arrival order
rate:{[t;c] r:aj[`ccy`time; ([]ccy:(),c; time:(),t); `ccy`time xasc fxr]; r:@[r`rate; where base=(),c; :; 1f]; $[0>type t; first r; r]}   / the rate as of each time asked for, atoms or lists; the base is 1
tobase:{[t;c;amt] r:rate[t;c]; if[any null r; '"oms: no rate for ",(", " sv string distinct ((),c) where null (),r)," at ",.Q.s1 t]; amt*r}   / an amount in ccy at time t, in USD; no rate is a refusal
\d .
