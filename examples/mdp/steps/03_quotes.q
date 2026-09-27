/ mdp piece 2: quotes and enrichment. step 03
/ quote: the day's quotes as they arrive; qcache: the last quote per sym. A trade is enriched two ways: as it
/ arrives, from the cache (enrich1); or in a batch, as of its time from the day's quotes (enrichb, an aj).
\d .mdp
quote:([]time:`timestamp$(); sym:`symbol$(); bid:`float$(); ask:`float$())
qcache:([sym:`symbol$()] time:`timestamp$(); bid:`float$(); ask:`float$())
onquote:{[q] quote,:q; qcache::qcache upsert `sym xkey q}                        / several rows: the last per sym wins
enrich1:{[t] t lj `sym xkey select sym,bid,ask from qcache}                       / the prevailing quote now
enrichb:{[t;q] aj[`sym`time;t;`sym`time xasc q]}                                  / the prevailing quote as of each trade's time
\d .
