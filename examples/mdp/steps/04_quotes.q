/ mdp piece 2: quotes and enrichment. step 04 — arrival order decides a tie, so the feed stamps a sequence number and
/ the batch join is as-of the sequence, not the time (step 03's aj on time saw a quote that arrived after the trade)
\d .mdp
seq:0                                                                              / the feed's arrival counter
quote:([]seq:`long$(); time:`timestamp$(); sym:`symbol$(); bid:`float$(); ask:`float$())
qcache:([sym:`symbol$()] seq:`long$(); time:`timestamp$(); bid:`float$(); ask:`float$())
stamp:{[t] seq::seq+count t; update seq:.mdp.seq-reverse 1+til count t from t}   / (q-sql resolves names in the root: .mdp.seq)
onquote:{[q] q:stamp q; quote,:q; qcache::qcache upsert `sym xkey q}
enrich1:{[t] (stamp t) lj `sym xkey select sym,bid,ask from qcache}               / the prevailing quote now
enrichb:{[t;q] aj[`sym`seq;t;`sym`seq xasc q]}                                    / the prevailing quote as of each trade's arrival
\d .
