/ drop: what Hedgehog does with a step that can no longer run, tried here as a pass (2026-09-30, over the library
/ with A29 in it). Hedgehog shrinks a list of actions, and after each shrink it drops the actions whose precondition
/ no longer holds or whose input refers to something that is gone. This library shrinks choices: when a step before
/ it is deleted, a step whose command cannot run becomes the next command that can (smloop), and an input that
/ pointed at what is gone is clamped to something that is there (ch). The step stays, as something else, and the
/ deletion is refused if that something else disturbs the failure.
/   pdrop   for each step: delete it, and where the replay put another command in place of the one recorded at a
/           later step, delete that step too and try again, for up to DR steps. One attempt for each step dropped;
/           the deletion itself has been tried by pdel and is in the cache
/   DC      1b: a step one of whose choices was clamped on replay is dropped as well (an input that referred to
/           what the deleted step had made)
/   OR      1b: a choice that is out of its range on replay takes the origin of the range, not the nearer bound. A
/           time in yesterday's session, after a close before it is deleted, is past the end of the session that
/           is yesterday now: the nearer bound is the close, the least simple time, and the origin is the open
/ The replay notes in SB the places where it did either, and tstd keeps the first of them for each candidate (KS).
\d .qc
SB:`long$()
KS:(enlist 0#0)!enlist 0N
DR:4
DC:0b
OR:0b
smloop0:smloop
ch0:ch
tst0:tst
smloopd:{[h;c;lo;mx] m:h`m0; h[`init][]; R:(); n:0; go:1b;
  while[go; beg`step; av:where {[f;m] f m}[;m] each c`pre;
    go:$[0=count av; 1=ch[0 0 0;::]; more[n;lo;mx]];
    $[go; [en:$[mn; i<count P; 0b]; DV[count C]:til[count c] except av;
        k:ch[(0;-1+count c;first av);$[1=count av; first av; @[count[c]#0f;av;:;c[av;`w]]]]; if[$[en; not k in av; 0b]; '"qc.discard"];
        j:$[k in av; k; count nx:av where av>k; first nx; first av]; if[not j=k; .[`.qc.C;(count[C]-1;`v);:;j]; SB,:count[C]-1];
        a:draw c[j;`gen] m; end[];
        o:@[c[j;`run];a;{[R;e] note smnote R; '"qc.run ",e}[R,enlist (n;c[j;`cmd];a;::;::;0b)]];
        ok:@[c[j;`post][m;a;];o;{[R;e] note smnote R; '"qc.post ",e}[R,enlist (n;c[j;`cmd];a;o;::;0b)]]; ok:$[(::)~ok; 1b; all ok];
        m2:c[j;`upd][m;a;o]; R,:enlist (n;c[j;`cmd];a;o;m2;ok);
        if[not ok; note smnote R; '"qc.post"];
        iv:@[h`inv;m2;{[R;e] note smnote R; '"qc.inv ",e}[R]]; if[not $[(::)~iv; 1b; all iv]; note smnote R; '"qc.inv"];
        m:m2; n+:1];
      end[]]];
  smtab R}
chd:{[r;w] r:rng r; lo:r 0; hi:r 1; o:r 2; j:i; i+:1;
  v:$[j<count P; $[cf`clamp; $[OR; $[(P j) within (lo;hi); P j; o]; lo|hi&P j]; (P j) within (lo;hi); P j; '"qc.misaligned"]; sh; '"qc.overrun"; mn; o; fresh[lo;hi;o;w]];
  if[DC; if[j<count P; if[not v=P j; SB,:j]]];
  nch+:1; if[cf[`choices]<nch; '"qc.toolarge"];
  C,:(v;lo;hi;o); v}
tstd:{[cand] cand:"j"$cand; n:na; SB::`long$(); r:tst0 cand; if[na>n; KS[cand]:$[count SB; first SB; -1]]; r}
pdrop:{cp::`drop; p:0b; sl:L`step; if[null sl; :0b]; j:0;
  while[j<count tb:`s xasc select s,e from cE where l=sl; s0:tb[j;`s]; w:tb[j;`e]-s0; v:dl[cv;s0;s0+w];
    ps:tb[`s] where tb[`s]>s0; pe:tb[`e] where tb[`s]>s0; ps-:w; pe-:w; ok:0b; go:1b; k:0;
    while[go; n:ns; tst v; ok:ns>n; q:KS v;
      $[ok; go:0b; null q; go:0b; q<0; go:0b; k>=DR; go:0b;
        [m:first where (ps<=q)&q<pe;
         $[null m; go:0b; [s1:ps m; w1:pe[m]-s1; v:dl[v;s1;s1+w1]; ps:ps _ m; pe:pe _ m; f:ps>=s1; ps-:w1*f; pe-:w1*f; k+:1]]]]];
    $[ok; p:1b; j+:1]]; p}
PSD:(pblk;pdisc;pdel;pdrop;pzero;pdesc;psort;pdup;pmin;ppr;ptr;pnd)
shrd:{[gen;prop;o] sgen::gen; sprop::prop; cv::C`v; cC::C; cE::E; cD::DV; cDv::cv; co::o; cerr::o`err; na::0; ns::0;
  K::(enlist 0#0)!enlist 0N; KS::(enlist 0#0)!enlist 0N; H::0#H; bs::cf`sz;
  while[$[na<cf`shrinks; any {x[]} each PSD; 0b]];
  co,`shrinks`attempts`hist!(ns;na;H)}
/ arm sets the replay and the test for an arm, and the script chooses the shrinker (shrd where it returns 1b): `lib the library; `drop the pass, commands only; `dropc the pass, commands and clamped inputs; `orig the library, out of range to the origin; `droporig drop and orig
arm:{[a] d:a in `drop`dropc`droporig; smloop::$[d; smloopd; smloop0]; tst::$[d; tstd; tst0]; ch::$[a=`lib; ch0; chd]; DC::a=`dropc; OR::a in `orig`droporig; d}
\d .
