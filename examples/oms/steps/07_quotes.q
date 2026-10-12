/ oms piece 2: quotes and benchmark prices. step 7: the cache takes a quote only if it is not older than the one it
/ holds, so that a late tick does not become "now" (entry 6). The piece is described in 05_quotes.q. Needs 04_ref.q.
\d .oms
quote:([]time:`timestamp$(); sym:`symbol$(); bid:`float$(); ask:`float$())
lq:([sym:`symbol$()] time:`timestamp$(); bid:`float$(); ask:`float$())
onquote:{[t;s;b;a] `.oms.quote insert (t;s;b;a); if[t>=lq[s;`time]; `.oms.lq upsert (s;t;b;a)];}   / appended; the cache takes it unless an earlier-timed one arrived late (a null time in the cache compares low)
midof:{[b;a] 0.5*b+a}
mid:{[t;s] r:aj[`sym`time; ([]sym:(),s; time:(),t); `sym`time xasc quote]; m:midof[r`bid;r`ask]; $[0>type t; first m; m]}   / the mid as of each time asked, null before the first quote
now:{[s] midof[lq[s;`bid];lq[s;`ask]]}                                                / the mid of the last quote seen
\d .
