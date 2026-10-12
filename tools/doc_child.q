/ doctest child: evaluates the q) lines of one transcript block REPL-style. usage: q tools/doc_child.q inputs.txt -q
\l qc.q
.qc.cfg[`db`seed]:(`;7i)                                 / every transcript session: no db, seed 7
system"c 25 80"
.d.asg:{[s] i:s?":"; $[i=count s; 0b; (i+1<count s) and s[i+1]=":"; 0b; (i>0) and all s[til i] in .Q.a,.Q.A,.Q.n,"._"]}   / name: ... (not ::, not count, whose k form #: ends in a colon)
.d.silent:{[s;r] (s like "*;") or ((::)~r) or .d.asg s}
.d.x:{[s] if[s like "\\*"; :(::)]; r:@[value;s;{(`ERR;x)}]; $[(0h=type r) and (`ERR~first r); -1 "'",last r; not .d.silent[s;r]; -1 (-1_.Q.s r); ::]; }   / (-1 -1_ would be the vector -1 -1)
.d.x each read0 `$":",.z.x 0;
exit 0
