/ (a copy of mdp.q that shows each counterexample as its error and its steps, to tell one failure from another)
/ the pipeline's own bugs and sabotages (examples/mdp/LOG.md entries 20 to 23), shrunk by the library as committed
/ and by the proposal, at a few seeds
\l qc.q
.qc.shr0:.qc.shr
system"l spikes/explore/defs.q"
system"l spikes/explore/drop.q"   / the arms drop and dropc (drop.q)
.qc.cfg[`v`db]:(0;`)
L:{system"l examples/mdp/steps/",x}
base:("load_pieces.q";"16_upd.q";"17_amend.q")
cases:(
  (`amend_without_bars; base,enlist "19_sm.q"; ".mdp.amend:{[d;f] t:f .mdp.past d; .mdp.save1[d;`trade;t]; system\"l \",1_string .mdp.hdb;}");
  (`merge_loses_pnl;    base,("20_rename.q";"21_sm.q"); "");
  (`oracle_by_stored;   base,("22_rename.q";"21_sm.q"); "");
  (`merge_keeps_old;    base,("22_rename.q";"23_sm.q"); ".mdp.mergepos:{[o;n] a:.mdp.pos o; .mdp.pos[n]:`qty`cost`real!(a`qty;a`cost;a`real); .mdp.pos::delete from .mdp.pos where sym=o;}");
  (`roll_forgets_cache; base,("22_rename.q";"23_sm.q"); ".mdp.roll:{[] ks:exec sym from .mdp.pos; o:ks where ks<>.mdp.canon'[ks;.mdp.today]; .mdp.mergepos'[o;.mdp.canon'[o;.mdp.today]];}");
  (`cache_keeps_older;  base,("22_rename.q";"23_sm.q"); ".mdp.mergeq:{[o;n] a:.mdp.qcache o; b:.mdp.qcache n; if[null b`seq; .mdp.qcache[n]:a]; .mdp.qcache::delete from .mdp.qcache where sym=o;}"))
trace:{[o] n:raze {$[98h=type x; enlist x; 0h=type x; x; enlist x]} each o`notes; w:where {$[98h=type x; all `step`cmd in cols x; 0b]} each n; $[count w; (o`err)," : "," ; " sv {string[x`cmd],$[(::)~x`arg; ""; " ",.Q.s1 x`arg]} each n first w; .Q.s1 o`choices]}
c0:cases "J"$first .z.x
L each c0 1; if[count c0 2; value c0 2];
one:{[c;a;s]
  .qc.pdup:$[a in `fixdup`fixdupswap`new2; .qc.pdupv; .qc.pdup1]; .qc.psort:$[a=`fixdupswap; .qc.psortv; .qc.psort1]; .qc.smloop:$[a=`lib; .qc.smloop0; .qc.smloop1];
  $[a in `lib`fix`fixdup`fixdupswap; .qc.shr:.qc.shr0; [.qc.shr:.qc.shr1; .qc.PS:(.qc.pblk;.qc.pdisc;.qc.pdel;.qc.pzero;.qc.pdesc;.qc.psort;.qc.pdup;.qc.pmin;.qc.ppr); .qc.FT:FINE; .qc.FB:100]];
  $[a in `drop`dropc`orig`droporig; [if[.qc.arm a; .qc.shr:.qc.shrd]]; .qc.arm `lib]; if[not a in `lib`drop`dropc`orig`droporig; .qc.smloop:.qc.smloop1];
  t0:.z.p; o:.qc.chk[`n`seed`v`db!(300;s;0;`);.qc.sm[.mdp.hooks,enlist[`steps]!enlist 0 60] .mdp.cmds;::];
  `name`arm`seed`why`tests`steps`attempts`s`drops`found!(c 0;a;s;o`why;o`n;$[`falsified=o`why; count " ; " vs trace o; 0N];o`attempts;(.z.p-t0)%1e9;$[`falsified=o`why; sum `drop=o[`hist]`pass; 0];$[`falsified=o`why; trace o; ""])}
seeds:"i"$7,1+til $[count getenv`NS; -1+"J"$getenv`NS; 5]   / NS=12 q spikes/explore/mdp.q 0 lib fix fixdup
ARMS:$[1<count .z.x; `$1_.z.x; `lib`fix`fixdup`new`new2]   / fix: the library's shrinker, the command recorded as its place among all the commands; fixdup: and duplicates grouped by value and generator, whatever their ranges
R:raze {[a] one[c0;a] each seeds} each ARMS
system"c 100 250"
show select failed:sum why=`falsified, kinds:count distinct found where why=`falsified, steps:avg steps, attempts:"j"$avg attempts where why=`falsified, secs:avg s, drops:sum drops by name,arm from R
t:select from R where why=`falsified; g:exec found by arm from t;
{[g;a] c:desc count each group g a; -1 {"  ",string[x]," ",string[z],"x  ",400 sublist y}[a]'[key c;value c];}[g] each key g;
exit 0
