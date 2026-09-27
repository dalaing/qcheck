/ mdp run 2: renames. step 20. Needs the pieces, 16_upd.q and 17_amend.q loaded.
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
mergepos:{[o;n] a:pos o; b:pos n; q:(0^b`qty)+a`qty;
  c:$[null b`qty; a`cost; 0=q; 0f; (((abs a`qty)*a`cost)+(abs b`qty)*b`cost)%(abs a`qty)+abs b`qty];
  pos[n]:`qty`cost`real!(q;c;(0^b`real)+a`real); pos::delete from pos where sym=o;}
roll:{[] ks:exec sym from qcache; o:ks where ks<>canon'[ks;today]; mergeq'[o;canon'[o;today]];
  ks:exec sym from pos; o:ks where ks<>canon'[ks;today]; mergepos'[o;canon'[o;today]];}
\d .
.mdp.eod0:.mdp.eod
.mdp.eod:{[d] .mdp.eod0 d; .mdp.roll[]}
