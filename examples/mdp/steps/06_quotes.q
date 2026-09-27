/ mdp piece 2: quotes and enrichment. step 06 — the batch join takes only the quote columns it is for: an aj brings every
/ right-hand column across, and step 05 overwrote the trade time with the quote time
\d .mdp
seq:0                                                                              / the feed's arrival counter
quote:([]seq:`long$(); time:`timestamp$(); sym:`symbol$(); bid:`float$(); ask:`float$())
qcache:([sym:`symbol$()] seq:`long$(); time:`timestamp$(); bid:`float$(); ask:`float$())
stamp:{[t] seq::seq+count t; `seq xcols update seq:.mdp.seq-reverse 1+til count t from t}   / (q-sql resolves names in the root: .mdp.seq)
onquote:{[q] q:stamp q; quote,:q; qcache::qcache upsert `sym xkey q}
enrich1:{[t] (stamp t) lj `sym xkey select sym,bid,ask from qcache}               / the prevailing quote now
enrichb:{[t;q] aj[`sym`seq;t;`sym`seq xasc select sym,seq,bid,ask from q]}         / the prevailing quote as of each trade's arrival
\d .
