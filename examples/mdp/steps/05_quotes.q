/ mdp piece 2: quotes and enrichment. step 05 — stamp puts seq first, where the tables declare it (step 04 appended it,
/ and .qc.eq reported the two enrichments as the same rows in a different column order)
\d .mdp
seq:0                                                                              / the feed's arrival counter
quote:([]seq:`long$(); time:`timestamp$(); sym:`symbol$(); bid:`float$(); ask:`float$())
qcache:([sym:`symbol$()] seq:`long$(); time:`timestamp$(); bid:`float$(); ask:`float$())
stamp:{[t] seq::seq+count t; `seq xcols update seq:.mdp.seq-reverse 1+til count t from t}   / (q-sql resolves names in the root: .mdp.seq)
onquote:{[q] q:stamp q; quote,:q; qcache::qcache upsert `sym xkey q}
enrich1:{[t] (stamp t) lj `sym xkey select sym,bid,ask from qcache}               / the prevailing quote now
enrichb:{[t;q] aj[`sym`seq;t;`sym`seq xasc q]}                                    / the prevailing quote as of each trade's arrival
\d .
