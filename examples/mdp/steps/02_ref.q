/ mdp piece 1: reference data. step 02 — canon follows the latest effective rename and stops when a name repeats
/ (a reversion A->B, B->A made step 01's loop spin: the rename generator produced one, and a hung run is the
/ only report a property can give for it)
\d .mdp
inst:([sym:`symbol$()] tick:`float$(); lot:`long$(); mult:`long$())     / price increment, lot size, contract multiplier
ren:([]old:`symbol$(); new:`symbol$(); eff:`date$())                     / old renamed to new, effective from eff
round:{[s;px] t:inst[s;`tick]; t*floor 0.5+px%t}                          / px to the nearest tick of s
lots:{[s;q] l:inst[s;`lot]; l*q div l}                                    / q rounded down to whole lots of s
nxt:{[s;d] r:exec new from `eff xasc select from ren where old=s,eff<=d; $[count r; last r; s]}   / the name s became on d, if any
canon:{[s;d] seen:(); while[$[s in seen; 0b; not s~n:nxt[s;d]]; seen,:s; s:n]; s}   / follow renames until none applies or a name repeats
\d .
