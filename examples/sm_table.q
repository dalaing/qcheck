/ q examples/sm_table.q — a state machine against a kdb table, with a planted bug
\l qc.q
S:([]v:`long$())                                            / the real system: a stack kept in a table
push:{`S insert enlist x;}
pop:{r:$[2<count S; first S`v; last S`v]; delete from `S where i=count[S]-1; r}   / bug: returns the first item once the stack holds more than two
cmds:([cmd:`push`pop]
  pre: ({1b};             {0<count x});                     / model -> can this command run?
  gen: ({.qc.int 0 9};    {::});                            / model -> input spec
  run: (push;             pop);                             / input -> output, acting on the real system
  post:({[m;i;o] 1b};     {[m;i;o] o=last m});              / model before, input, output -> ok?
  upd: ({[m;i;o] m,i};    {[m;i;o] -1_m}))                  / model before, input, output -> model after
-1 "a stack in a table against a list model (pop is wrong once three items are stacked):";
.qc.check[.qc.sm[`m0`init!(`long$();{S::0#S})] cmds; ::];
exit 0
