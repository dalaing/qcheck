/ oms piece 1: reference data and currency. step 1.
/ The instruments, keyed on sym, with the currency they trade in, the lot size and the tick. FX rates arrive as a
/ time series, USD per one unit of the currency, and a conversion to the base currency (USD) takes the rate as of
/ the time asked for: an as-of join of the (ccy; time) asked for against the rates seen so far.
\d .oms
base:`USD
inst:([sym:`symbol$()] ccy:`symbol$(); lot:`long$(); tick:`float$())
fxr:([]time:`timestamp$(); ccy:`symbol$(); rate:`float$())
onfx:{[t;c;r] `.oms.fxr insert (t;c;r);}                                              / a rate seen: appended, in arrival order
rate:{[t;c] r:aj[`ccy`time; ([]ccy:c; time:t); `ccy`time xasc fxr]; @[r`rate; where c=base; :; 1f]}   / the rate as of each time asked for; the base is 1
tobase:{[t;c;amt] amt*rate[t;c]}                                                       / an amount in ccy at time t, in USD
\d .
