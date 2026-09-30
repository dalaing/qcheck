/ oms piece 1: reference data and currency. step 2: rate takes atoms as well as lists (the first version built a table
/ from two atoms, which q refuses with 'rank; entry 2). The piece is described in 01_ref.q.
\d .oms
base:`USD
inst:([sym:`symbol$()] ccy:`symbol$(); lot:`long$(); tick:`float$())
fxr:([]time:`timestamp$(); ccy:`symbol$(); rate:`float$())
onfx:{[t;c;r] `.oms.fxr insert (t;c;r);}                                              / a rate seen: appended, in arrival order
rate:{[t;c] r:aj[`ccy`time; ([]ccy:(),c; time:(),t); `ccy`time xasc fxr]; r:@[r`rate; where base=(),c; :; 1f]; $[0>type t; first r; r]}   / the rate as of each time asked for, atoms or lists; the base is 1
tobase:{[t;c;amt] amt*rate[t;c]}                                                       / an amount in ccy at time t, in USD
\d .
