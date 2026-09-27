/ mdp run 2: renames. step 22: merging a long under the old name with a short under the new one closes the overlap,
/ and closing realises PnL — step 20 added the quantities and averaged the costs, which is right only when the two
/ positions have the same sign. Needs the pieces, 16_upd.q and 17_amend.q loaded.
/ A rename old->new takes effect from a day (piece 1's ren and canon). The contract: an event is stored under the
/ name current when it arrives (upd canonicalises as of today), so a closed day keeps the names it had; the live
/ state — the quote cache and the positions — follows the rename at the close that rolls into the effective day,
/ the old name's entry merging into the new name's. rename[old;new;eff] is the reference-data update: the new
/ name inherits the instrument's terms.
\d .mdp
rename:{[o;n;e] ren,:`old`new`eff!(o;n;e); inst[n]:inst o;}
upd:{[t;x] x:update sym:.mdp.canon'[sym;.mdp.today] from x;
  $[t=`quote; onquote x; t=`trade; ontrade update px:.mdp.round'[sym;px] from x; t=`fill; onfill x; '"mdp: unknown table ",string t]}
mergeq:{[o;n] a:qcache o; b:qcache n; if[(null b`seq) or a[`seq]>b`seq; qcache[n]:a]; qcache::delete from qcache where sym=o;}   / the later quote wins
mergepos:{[o;n] a:pos o; b:pos n; if[null b`qty; b:`qty`cost`real!(0;0f;0f)]; qa:a`qty; qb:b`qty; q:qa+qb; r:(a`real)+b`real;
  c:$[0=q; 0f; (sgn[qa]=sgn qb) or 0 in (qa;qb); (((abs qa)*a`cost)+(abs qb)*b`cost)%(abs qa)+abs qb;   / same way, or one flat: average in
    (abs qa)>abs qb; a`cost; b`cost];                                                                    / opposite ways: the larger side remains, at its cost
  if[(qa*qb)<0; k:(abs qa)&abs qb; lc:$[qa>0; a`cost; b`cost]; sc:$[qa>0; b`cost; a`cost]; r+:inst[n;`mult]*k*sc-lc];   / and the overlap is closed: sold at sc, bought at lc
  pos[n]:`qty`cost`real!(q;c;r); pos::delete from pos where sym=o;}
roll:{[] ks:exec sym from qcache; o:ks where ks<>canon'[ks;today]; mergeq'[o;canon'[o;today]];
  ks:exec sym from pos; o:ks where ks<>canon'[ks;today]; mergepos'[o;canon'[o;today]];}
\d .
.mdp.eod0:.mdp.eod
.mdp.eod:{[d] .mdp.eod0 d; .mdp.roll[]}
