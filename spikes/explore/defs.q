\d .qc
FB:500
FR:4
FW:16
plc:{[j;v] d:1152921504606846976&"j"$9e18&abs first dst[v;cC[`o] j]; $[d=0; 0; (2*d)-v>cC[`o] j]}   / the place of a value of choice j: 0 1 2 3 4 for o, o+1, o-1, o+2, o-2
lxl:{[a;b] $[a~b; 0b; (a<b) first where not a=b]}                       / lexicographically less
fvl:{[j] k:plc[j;cv j]; ks:$[k<9; til k; distinct asc (til 5),(k div 2),k-2 1];
  w:vat[j]'[1 -1 (0=ks mod 2);(ks+1) div 2]; (w where not null w),cv j}
/ fsr: the candidates that take their values at ix from the sets vl, in order of simplicity, up to the current one
fsr:{[ix;vl;n0] pv:{[j;w] plc[j] each w}'[ix;vl]; od:iasc each pv; vl:vl@'od; pv:pv@'od; p0:plc'[ix;cv ix];
  c:count each vl; m:count ix; k:m#0; s0:ns; v0:cv; go:1b;
  while[go; $[lxl[pv@'k;p0]; tst @[v0;ix;:;vl@'k]; go:0b];
    j:m-1; while[$[j<0; 0b; (c[j]-1)=k j]; k[j]:0; j-:1];
    $[j<0; go:0b; ns>s0; go:0b; FB<=na-n0; go:0b; k[j]+:1]];
  ns>s0}
frp:{n0:na; s0:ns; tb:spans[]; j:0;
  while[$[ns>s0; 0b; j>=count tb; 0b; FB>na-n0]; s:tb[j;`s]; e:tb[j;`e]; v:dl[cv;s;e]; lw:dl[cC`lo;s;e]; hg:dl[cC`hi;s;e]; q:s;
    while[$[ns>s0; 0b; q>=count v; 0b; q>=s+FW; 0b; FB>na-n0];
      if[8>hg[q]-lw q; xs:(lw[q]+til 1+hg[q]-lw q) except v q; m:0; while[$[ns>s0; 0b; m<count xs]; tst @[v;q;:;xs m]; m+:1]];
      q+:1];
    j+:1];
  ns>s0}

pbox:{cp::`box; ix:where not cv=cC`o; if[0=count ix; :0b]; s0:ns;
  vl:fvl each ix; big:FB<prd "f"$count each vl; if[not big; fsr[ix;vl;na]];
  if[ns>s0; :1b];
  if[big; lb:clb[]; g:value group flip (lb ix;cC[`lo] ix;cC[`hi] ix); g:g where 1<count each g; n0:na; w:0;
    while[$[ns>s0; 0b; w>=count g; 0b; FB>na-n0]; if[FB>=prd "f"$count each vl g w; fsr[ix g w;vl g w;n0]]; w+:1]];
  ns>s0}
ptw:{cp::`window; ix:where not cv=cC`o; s0:ns; n0:na; w:0;
  while[$[ns>s0; 0b; w>=count ix; 0b; FB>na-n0]; ii:ix w; js:prt[ii;2];
    if[count js; fsr[ii,js;(enlist fvl ii),{[j] distinct fvl[j],ring[j;cv j;FR;1b]} each js;n0]]; w+:1];
  ns>s0}
prp:{cp::`repair; frp[]}
psh1:{[ii;js] s:sdo ii; d:far ii; ix:ii,js; v:cv ix; n:ns;
  fint {[ix;v;s;d;k] $[k>d; 0b; not all inr'[ix;("f"$v)-s*"f"$k]; 0b; tst @[cv;ix;:;v-s*k]]}[ix;v;s;d]; ns>n}
psh:{cp::`shift; p:0b; ii:0; while[ii<count[cv]-1;
  $[cv[ii]=cC[`o] ii; ii+:1;
    [js:prt[ii;8]; n:ns;
     if[1<count js; psh1[ii;js]];
     if[ns=n; jo:js where not cv[js]=cC[`o] js; if[$[2>count jo; 0b; not jo~js]; psh1[ii;jo]]];
     $[ns>n; p:1b; ii+:1]]]]; p}
g3:{lb:clb[]; ix:where not cv=cC`o; $[0=count ix; 0b; any 2<count each group flip (lb ix;cC[`lo] ix;cC[`hi] ix)]}
smloop0:smloop
smloop1:{[h;c;lo;mx] m:h`m0; h[`init][]; R:(); n:0; go:1b;
  while[go; beg`step; av:where {[f;m] f m}[;m] each c`pre;
    go:$[0=count av; 1=ch[0 0 0;::]; more[n;lo;mx]];
    $[go; [k:ch[(0;-1+count c;0);@[count[c]#0f;av;:;c[av;`w]]]; j:$[k in av; k; count a2:av where av>k; first a2; first av]; a:draw c[j;`gen] m; end[];
        o:@[c[j;`run];a;{[R;e] note smnote R; '"qc.run ",e}[R,enlist (n;c[j;`cmd];a;::;::;0b)]];
        ok:@[c[j;`post][m;a;];o;{[R;e] note smnote R; '"qc.post ",e}[R,enlist (n;c[j;`cmd];a;o;::;0b)]]; ok:$[(::)~ok; 1b; all ok];
        m2:c[j;`upd][m;a;o]; R,:enlist (n;c[j;`cmd];a;o;m2;ok);
        if[not ok; note smnote R; '"qc.post"];
        iv:@[h`inv;m2;{[R;e] note smnote R; '"qc.inv ",e}[R]]; if[not $[(::)~iv; 1b; all iv]; note smnote R; '"qc.inv"];
        m:m2; n+:1];
      end[]]];
  smtab R}
/ gates, each free to compute from the choices and spans in hand
gdep:{lb:clb[]; any 1<count each distinct each (flip (cC`lo;cC`hi)) group lb}        / some generator's choices have ranges that differ: a later choice may depend on an earlier one
gnest:{t:select from cE where 1<e-s; if[2>count t; :0b]; t:`l`d`s xasc t; any (t[`l]=prev t`l)&(t[`d]=prev t`d)&t[`s]=prev t`e}   / two spans of one kind side by side, each of more than one choice
gprt:{ix:where not cv=cC`o; $[0=count ix; 0b; any {0<count prt[x;1]} each ix]}           / some choice off its origin has a partner
CHEAP:(pblk;pdisc;pdel;pzero;pdesc;psort;pdup;pmin;ppr)
PS:(pblk;pdisc;pdel;pzero;pdesc;psort;pdup;pmin;ppr;ptr;pnd)
FT:()
tier:{r:0b; k:0; n0:na; while[$[r; 0b; k>=count FT; 0b; (5*FB)>na-n0]; r:FT[k][]; k+:1]; r}
shr1:{[gen;prop;o] sgen::gen; sprop::prop; cv::C`v; cC::C; cE::E; co::o; cerr::o`err; na::0; ns::0;
  K::(enlist 0#0)!enlist 0N; H::0#H; bs::cf`sz;
  while[$[na>=cf`shrinks; 0b; any {x[]} each PS; 1b; tier[]]];
  co,`shrinks`attempts`hist!(ns;na;H)}
pdup1:pdup
/ psortv: psort, trying every swap of neighbouring siblings and not only those that bring the lesser block forward:
/ try takes a swap only if the whole is simpler, which a longer block with a lesser first choice can make it
psort1:psort
psortv:{cp::`sort; p:0b; j:0;
  while[j<count tb:`s xasc cE; c:chain[tb[j;`s];tb[j;`l];tb[j;`d]];
    $[2>count c; j+:1;
      [ks:bkey'[c`s;c`e]; ix:ordr ks; ok:0b;
       if[not ix~til count ix; ok:try pt[cv;c[0;`s];last c`e;blk[c;ix]]];
       ii:0; while[$[ii>=count[c]-1; 0b; not ok]; ok:try pt[cv;c[ii;`s];c[ii+1;`e];blk[c;(ii+1;ii)]]; ii+:1];
       $[ok; p:1b; j+:1]]]]; p}
pdupv:{cp::`dup; p:0b; lb:clb[]; ix:where cv<>cC`o; g:ix each value group (flip (cv;lb)) ix; g:g where 1<count each g; j:0;
  while[j<count g; ps:g j; ok:try @[cv;ps;:;cC[`o] ps];
    if[not ok; d:("f"$cv ps)-"f"$cC[`o] ps; go:1b; while[go and all 1<abs d; d:floor d%2; go:try @[cv;ps;:;cC[`o][ps]+"j"$d]; ok:ok or go]];
    if[not ok; k:1; while[$[ok; 0b; k<4; all k<cv[ps]-cC[`o] ps; 0b]; ok:try @[cv;ps;:;cC[`o][ps]+k]; k+:1]];
    if[ok; p:1b]; j+:1]; p}
\d .
FINE:({$[.qc.gprt[]; .qc.ptr[]; 0b]};{$[.qc.gnest[]; .qc.pnd[]; 0b]};{$[.qc.g3[]; .qc.psh[]; 0b]};{$[.qc.gdep[]; .qc.prp[]; 0b]};{$[.qc.g3[]; .qc.pbox[]; 0b]})
