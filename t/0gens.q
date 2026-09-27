/ the generator registry: one row per public generator in a representative configuration. every contract in
/ t/contracts.q runs over every row, so a new generator is covered by adding a row here.
/ columns: name, gen, origin (its minimal value), ok (a predicate on one value), typed (type stable), canary (has d)
/ a constant is the one generator that records no choice; the registry says so with .g.NOCH
.g.cm:([cmd:enlist `a] run:enlist {[a] ::})
.g.org:{$[x="c"; "a"; x="s"; `; x="g"; 0Ng; x$0]}
.g.rows:(
  (`int09;.qc.int 0 9;0;{x within 0 9};1b;1b);
  (`intneg;.qc.int -9 9;0;{x within -9 9};1b;1b);
  (`intfull;.qc.int -0W 0W;0;{-7h=type x};1b;1b);
  (`intfn;.qc.int {0,x};0;{x within 0 100};1b;1b);
  (`intlin;.qc.int .qc.lin[0;1000];0;{x within 0 1000};1b;1b);
  (`flt01;.qc.flt 0 1;0f;{x within 0 1f};1b;1b);
  (`fltneg;.qc.flt -5 -2;-2f;{x within -5 -2f};1b;1b);
  (`dbl;.qc.dbl;0f;{(not null x) and -9h=type x};1b;1b);
  (`bool;.qc.bool;0b;{-1h=type x};1b;1b);
  (`bit;.qc.bit 0.2;0b;{-1h=type x};1b;1b);
  (`elem;.qc.elem `a`b`c;`a;{x in `a`b`c};1b;1b);
  (`one;.qc.one (.qc.int 0 9;.qc.sym);0;{(-11h=type x) or $[-7h=type x; x within 0 9; 0b]};0b;1b);
  (`freq;.qc.freq[1 3] (0;1);0;{x in 0 1};1b;1b);
  (`such;.qc.such[{x>=0}] .qc.int -9 9;0;{x within 0 9};1b;1b);
  (`const;.qc.const 42;42;{x=42};1b;1b);
  (`sized;.qc.sized {.qc.int 0,x};0;{x within 0 100};1b;1b);
  (`small;.qc.small .qc.list .qc.int 0 9;();{(x~()) or 7h=type x};0b;1b);
  (`list;.qc.list .qc.int 0 9;();{(x~()) or 7h=type x};0b;1b);
  (`lst35;.qc.lst[3 5] .qc.int 0 9;0 0 0;{(7h=type x) and (count x) within 3 5};1b;1b);
  (`listsym;.qc.list .qc.sym;();{(x~()) or 11h=type x};0b;1b);
  (`rec;.qc.rec[2 2;.qc.int 0 9;{(x 0;x 1)}];0;{1b};0b;1b);
  (`recb;.qc.recb[0 3;.qc.int 0 9;{(`n;x)}];0;{1b};0b;1b);
  (`spc;.qc.spc[(0N;0W);.qc.int 0 9];0;{(null x) or (x=0W) or x within 0 9};1b;1b);
  (`gid;.qc.gid;0Ng;{-2h=type x};1b;1b);
  (`chr;.qc.chr;"a";{x in .qc.AZ};1b;1b);
  (`chrc;.qc.chrc "xyz";"x";{x in "xyz"};1b;1b);
  (`str;.qc.str;"";{10h=type x};1b;1b);
  (`strc;.qc.strc["ab";2 4];"aa";{(10h=type x) and (count x) within 2 4};1b;1b);
  (`sym;.qc.sym;`;{(-11h=type x) and 3>=count string x};1b;1b);
  (`symc;.qc.symc["z";1 2];`z;{x in `z`zz};1b;1b);
  (`vecj;.qc.vec[0 5]"j";`long$();{7h=type x};1b;1b);
  (`vecs;.qc.vec[1 3]"s";enlist `;{11h=type x};1b;1b);
  (`tab;.qc.tab `a`b!(.qc.int 0 9;.qc.sym);flip `a`b!(`long$();`symbol$());{98h=type x};1b;1b);
  (`tabr;.qc.tabr[2 2] `a`b!(.qc.int 0 9;.qc.bool);([]a:0 0;b:00b);{(98h=type x) and 2=count x};1b;1b);
  (`ktab;.qc.ktab[`a;1 1] `a`b!(.qc.int 0 9;.qc.bool);([a:enlist 0]b:enlist 0b);{99h=type x};1b;1b);
  (`sm;.qc.sm[enlist[`m0]!enlist 0] .g.cm;.qc.smt;{98h=type x};1b;1b);
  (`mono;.qc.mono[.qc.int 0 9;.qc.int 1 9];0;{x within 0 9};1b;1b);
  (`uniq;.qc.uniq .qc.int 0 9;0;{x within 0 9};1b;1b);
  (`dep;.qc.dep {[r] .qc.int 0 9};0;{x within 0 9};1b;1b);
  (`atr;.qc.atr[`s] .qc.list .qc.int 0 9;();{(x~()) or 7h=type x};0b;1b);
  (`tabc;.qc.tab `t`k`a!(.qc.mono[.qc.int 0 9;.qc.int 0 9];.qc.uniq .qc.elem `a`b`c;.qc.dep {[r] .qc.int (0;r`t)});flip `t`k`a!(`long$();`symbol$();`long$());{98h=type x};1b;1b);
  (`schema;.qc.schema ([]a:1 2;b:`x`y);([]a:`long$();b:`symbol$());{98h=type x};1b;1b);
  (`bulk;.qc.bulk[0 99;0 1000];`long$();{(7h=type x) and all x within 0 99};1b;1b);
  (`tstamp;.qc.ts[2024.01.01;2024.12.31];2024.01.01D00:00:00.000000000;{x within 2024.01.01D0 2024.12.31D0};1b;1b);
  (`dates;.qc.dates[2024.01.01;2024.12.31];2024.01.01;{x within 2024.01.01 2024.12.31};1b;1b);
  (`val;.qc.val;0b;{1b};0b;1b);
  (`gidf;.qc.gidf;"G"$"00000000-0000-0000-0000-000000000001";{(-2h=type x) and not null x};1b;1b);
  (`btab;.qc.btab[0 50] `a`b!(0 9;("d";0 9));flip `a`b!(`long$();`date$());{(98h=type x) and (7h=type x`a) and 14h=type x`b};1b;1b))
.g.rows,:{[c] (`$"t",c;.qc.t c;.g.org c;{[c;x] (neg .Q.t?c)=type x}[c];1b;1b)} each "bgxhijefcspmdznuvt"
.g.rows,:{[c] (`$"tf",c;.qc.tf c;$[c="s"; `a; c="g"; "G"$"00000000-0000-0000-0000-000000000001"; .g.org c];{[c;x] ((neg .Q.t?c)=type x) and not null x}[c];1b;1b)} each "bgxhijefcspmdznuvt"   / (tf s has no empty symbol: its origin is `a; tf g has no null guid: its origin ends in 1)
.g.T:flip `name`gen`origin`ok`typed`canary!flip .g.rows
.g.NOCH:enlist `const
.t.t["registry: every public generator name appears"; all (`int`flt`dbl`bit`bool`elem`one`freq`such`const`sized`small`list`lst`rec`recb`spc`gid`chr`chrc`str`strc`sym`symc`vec`tab`tabr`ktab`sm`t`mono`uniq`dep`atr`schema`bulk`btab`tf`ts`dates`val`gidf) in key `.qc]
.t.t["registry: has a row per type char for t and tf, and no duplicate names"; (all (`$"t",/:"bgxhijefcspmdznuvt") in .g.T`name) and (all (`$"tf",/:"bgxhijefcspmdznuvt") in .g.T`name) and (count .g.T)=count distinct .g.T`name]
