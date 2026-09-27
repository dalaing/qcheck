/ q examples/sm_table.q — a state machine test of a stack kept in a table, with a bug planted in pop. Run it from
/ the repository root; README.md ("State machines") and EXAMPLES.md talk through the output.
\l qc.q
.qc.cfg[`db]:`                                   / no failure database: every run of this script searches afresh

/ The real system: a stack kept in a global table. push appends a row; pop removes the last row and returns its
/ value, except that once more than two items are stacked it returns the first item. That is the bug.
S:([]v:`long$())
push:{`S insert enlist x;}
pop:{r:$[2<count S; first S`v; last S`v]; delete from `S where i=count[S]-1; r}

/ The model: a list of longs, the last item the top of the stack. It starts empty (m0, below).
/ The commands, one per row. Each column holds a function:
cmds:([cmd:`push`pop]
  pre: ({1b};             {0<count x});                     / model -> can this command run? no pop from an empty stack
  gen: ({.qc.int 0 9};    {::});                            / model -> the generator of its input; :: for none
  run: (push;             pop);                             / input -> output: the call on the real system
  post:({[m;i;o] 1b};     {[m;i;o] o=last m});              / model before, input, output -> was the output right?
  upd: ({[m;i;o] m,i};    {[m;i;o] -1_m}))                  / model before, input, output -> the model after

/ .qc.sm[h] cmds is a generator: drawing from it runs one sequence of commands. h holds the model's first value
/ and init, which empties the real stack before every sequence. The postconditions are the test, so the property
/ given to check is :: and the report is the trace: the shortest sequence that makes pop answer wrongly.
-1 "a stack in a table, checked against a list (pop is wrong once three items are stacked):";
.qc.check[.qc.sm[`m0`init!(`long$();{S::0#S})] cmds; ::];
exit 0
