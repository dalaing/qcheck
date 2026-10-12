/ oms: a stateful test of the quote cache. step 6. Needs 04_ref.q, 05_quotes.q, 01_gen.q and 05_gen.q loaded.
/ Quotes arrive one at a time and the cache must always be the mid as of the latest time seen, which is what the as-of
/ join gives. The model is the quotes seen so far and the clock. Two commands: a quote at or after the clock, and a
/ late one, timed before it, as a feed delivers now and then.
\d .oms
q.m0:`now`q!(g.open; 0#quote)
q.init:{quote::0#quote; lq::0#lq}
q.cmds:([cmd:`quote`late]
  w:   4 1f;
  pre: ({[m] 1b}; {[m] 0<count m`q});
  gen: ({[m] (.qc.ts[m`now;m[`now]+0D00:01]; .qc.elem g.syms; .qc.elem g.syms)};   / time sym (the third is unused: see g.quote)
        {[m] (.qc.ts[g.open;m`now]; .qc.elem g.syms; .qc.elem g.syms)});
  run: ({[a] q:g.quote a 1; onquote[a 0;a 1;q 0;q 1]; (a 0;a 1;q 0;q 1)};
        {[a] q:g.quote a 1; onquote[a 0;a 1;q 0;q 1]; (a 0;a 1;q 0;q 1)});
  post:({[m;a;o] now[o 1]=mid[max m[`now],o 0; o 1]};
        {[m;a;o] now[o 1]=mid[m`now; o 1]});
  upd: ({[m;a;o] m[`now]:o 0; m[`q],:enlist `time`sym`bid`ask!o; m};
        {[m;a;o] m[`q],:enlist `time`sym`bid`ask!o; m}))
q.hooks:`m0`init!(q.m0;q.init)
\d .
