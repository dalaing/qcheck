/ oms piece 2: quotes and benchmark prices. step 5. Needs 04_ref.q loaded.
/ Quotes are their own table and stay there. A price as of a time is an as-of join against the quotes in time order;
/ the price is the mid. The last quote of each instrument is also kept in a cache, lq, updated as quotes arrive, for
/ the callers that want "the price now" without a join.
\d .oms
quote:([]time:`timestamp$(); sym:`symbol$(); bid:`float$(); ask:`float$())
lq:([sym:`symbol$()] time:`timestamp$(); bid:`float$(); ask:`float$())
onquote:{[t;s;b;a] `.oms.quote insert (t;s;b;a); `.oms.lq upsert (s;t;b;a);}       / appended, and the cache takes it as the last
midof:{[b;a] 0.5*b+a}
mid:{[t;s] r:aj[`sym`time; ([]sym:(),s; time:(),t); `sym`time xasc quote]; m:midof[r`bid;r`ask]; $[0>type t; first m; m]}   / the mid as of each time asked, null before the first quote
now:{[s] midof[lq[s;`bid];lq[s;`ask]]}                                                / the mid of the last quote seen
\d .
