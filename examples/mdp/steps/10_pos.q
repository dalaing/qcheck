/ mdp piece 4: positions and PnL. step 10: the average cost brackets its first product (q has no precedence: c0*a+b is c0*(a+b))
/ (the piece is described at the top of 08_pos.q)
\d .mdp
pos:([sym:`symbol$()] qty:`long$(); cost:`float$(); real:`float$())
sgn:{$[x>0; 1; x<0; -1; 0]}
onfill:{[f] {[r] p:pos r`sym; q0:0^p`qty; c0:0^p`cost; r0:0^p`real; m:inst[r`sym;`mult]; q:r[`qty]*$[`buy=r`side; 1; -1]; px:r`px;
  $[(q0=0) or sgn[q0]=sgn q; [c:((c0*abs q0)+px*abs q)%abs q0+q; pos[r`sym]:`qty`cost`real!(q0+q;c;r0)];                    / opening or adding
    abs[q]<=abs q0; [pos[r`sym]:`qty`cost`real!(q0+q;$[q0=neg q; 0f; c0];r0+m*abs[q]*(px-c0)*sgn q0)];                     / reducing or closing
    [pos[r`sym]:`qty`cost`real!(q0+q;px;r0+m*abs[q0]*(px-c0)*sgn q0)]]} each f;}                                              / flipping
/ mark-to-market: unrealised at a mark per sym, and the identity every book must satisfy
unreal:{[mk] m:exec sym!mult from .mdp.inst; exec sum m[sym]*qty*(mk sym)-cost from .mdp.pos}
\d .
