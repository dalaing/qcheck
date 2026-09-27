/ mdp piece 4: positions and PnL. step 09: unreal names its globals in full (q-sql inside a namespaced lambda does
/ not resolve them to the namespace) and looks the multipliers up as a dictionary (a keyed table indexed by a list
/ of keys and a column is a length error)
/ pos: per sym the signed quantity, the average cost of the open position, and the realised PnL so far. A fill
/ that adds to a position averages its cost in; a fill that reduces it realises (px-cost)*closed*mult and keeps the
/ cost; a fill that flips it realises the whole old position and opens the remainder at px.
\d .mdp
pos:([sym:`symbol$()] qty:`long$(); cost:`float$(); real:`float$())
sgn:{$[x>0; 1; x<0; -1; 0]}
onfill:{[f] {[r] p:pos r`sym; q0:0^p`qty; c0:0^p`cost; r0:0^p`real; m:inst[r`sym;`mult]; q:r[`qty]*$[`buy=r`side; 1; -1]; px:r`px;
  $[(q0=0) or sgn[q0]=sgn q; [c:(c0*abs[q0]+px*abs q)%abs q0+q; pos[r`sym]:`qty`cost`real!(q0+q;c;r0)];                    / opening or adding
    abs[q]<=abs q0; [pos[r`sym]:`qty`cost`real!(q0+q;$[q0=neg q; 0f; c0];r0+m*abs[q]*(px-c0)*sgn q0)];                     / reducing or closing
    [pos[r`sym]:`qty`cost`real!(q0+q;px;r0+m*abs[q0]*(px-c0)*sgn q0)]]} each f;}                                              / flipping
/ mark-to-market: unrealised at a mark per sym, and the identity every book must satisfy
unreal:{[mk] m:exec sym!mult from .mdp.inst; exec sum m[sym]*qty*(mk sym)-cost from .mdp.pos}
\d .
