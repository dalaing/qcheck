/ mdp piece 1: reference data — instruments and symbol renames. step 01
\d .mdp
inst:([sym:`symbol$()] tick:`float$(); lot:`long$(); mult:`long$())     / price increment, lot size, contract multiplier
ren:([]old:`symbol$(); new:`symbol$(); eff:`date$())                     / old renamed to new, effective from eff
round:{[s;px] t:inst[s;`tick]; t*floor 0.5+px%t}                          / px to the nearest tick of s
lots:{[s;q] l:inst[s;`lot]; l*q div l}                                    / q rounded down to whole lots of s
canon:{[s;d] while[count r:exec new from ren where old=s,eff<=d; s:first r]; s}   / the name s goes by on date d
\d .
