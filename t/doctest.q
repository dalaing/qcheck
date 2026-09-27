/ doctests: every ```q block whose lines include q) prompts. the q) lines are inputs; the lines after each are its
/ expected output. a child q evaluates the inputs REPL-style and the captured output must match exactly
/ (trailing blanks trimmed). loaded by t/run.q
dir:.t.tmp "qcdoc"
blocks:{[f] ln:read0 f; o:where ln like "```q"; c:where ln like "```"; b:{[ln;c;o] e:first c where c>o; ln (o+1)+til (e-o)-1}[ln;c] each o;   / (e-o-1 is e-(o-1) in q)
  b where any each b like\:"q)*"}   / pair each ```q opener with the next closer; other fences are not q
rt:{$[0=count x; x; (neg first where not reverse[x]=" ")_x]}   / (rtrim is a keyword)
mm:{[w;g] "    ",(40$w)," | ",g}
runb:{[f;i;b] inf:` sv dir,`$"in",string[i],".txt"; inf 0: {2_x} each b where b like "q)*";
  got:rt each system"/usr/bin/env q tools/doc_child.q ",(1_string inf)," -q < /dev/null 2>&1";
  want:rt each b where not b like "q)*"; ok:got~want;
  if[not ok; n:count[got]|count want; -1 "  ",string[f]," block ",string[i],": expected | got"; -1 mm'[n#want,n#enlist "";n#got,n#enlist ""]];
  ok}
/ QC_FAST=1 q t/run.q skips the blocks that run a state machine (the worked example's, mostly: three fifths of the
/ suite's time) and says how many it skipped; the full run is the one that counts
fast:count getenv `QC_FAST
slow:{[b] any (b like "q)*") and b like "*.qc.sm*"}                                / (an input line that runs a state machine; a like with a * in the middle is nyi, pitfall 5)
doc:{[f] b:blocks f; sk:$[fast; where slow each b; `long$()]; ix:(til count b) except sk;
  .t.t[string[f]," transcripts (",string[count b]," blocks",$[count sk; ", fast: ",string[count sk]," machine blocks skipped"; ""],") produce their stated output"; (0<count ix) and all runb[f]'[ix;b ix]]}
doc each `:README.md`:EXAMPLES.md`:docs/DESIGN.md`:COOKBOOK.md`:examples/mdp/LOG.md
.t.rm dir
