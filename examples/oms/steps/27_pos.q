/ oms piece 4: positions and PnL. step 27: closing through zero brings in cur*pb, negative for a short, where step 25
/ had neg[cur]*pb (entry 12). Step 25 measured the profit in the base currency against what the position cost in the
/ base, converted as of each fill, so that realised plus unrealised is what the desk counts in cash; step 23 opened a
/ position with a realised PnL of zero; step 22 made pnl of no positions an empty report. The piece is
/ described in 13_pos.q; what changes: the position keeps costb, the base-currency cost of its open quantity, a fill
/ that reduces it realises what it brings in less the share of costb it releases, and unrealised is the open quantity
/ marked, less costb. The average cost in the instrument's currency stays, for the desk to see.
\d .oms
pos:([sym:`symbol$()] qty:`long$(); cost:`float$(); costb:`float$(); real:`float$())   / costb: what the open quantity cost in the base, converted as of each fill
sgn:{[side] $[`buy=side; 1; -1]}
onpos:{[t;s;side;q;p] if[null pos[s;`qty]; pos[s]:`qty`cost`costb`real!(0;0f;0f;0f)]; o:pos s; d:sgn[side]*q; cur:o`qty; pb:tobase[t;inst[s;`ccy];p];   / pb: the fill's price in the base, as of the fill
  $[(cur=0) or (signum cur)=signum d; [pos[s;`qty`cost`costb]:(cur+d; ((cur*o`cost)+d*p)%cur+d; (o`costb)+d*pb)];   / adding: the average moves, the basis grows
    abs[d]<=abs cur; [f:neg[d]%cur; pos[s;`real]:o[`real]+(neg[d]*pb)-f*o`costb; pos[s;`qty`costb]:(cur+d;(1-f)*o`costb); if[0=cur+d; pos[s;`cost]:0f]];   / reducing: what it brings in, less the share of the basis it releases
    [pos[s;`real]:o[`real]+(cur*pb)-o`costb; pos[s;`qty`cost`costb]:(cur+d;p;(cur+d)*pb)]]}     / through zero: close it all (cur*pb is what closing brings in, negative for a short), open the rest at p
onfill0:onfill
onfill:{[t;id;q;p] onfill0[t;id;q;p]; o:order id; onpos[t;o`sym;o`side;q;p]}
unreal:{[t;s] o:pos s; $[0=o`qty; 0f; tobase[t;inst[s;`ccy];o[`qty]*mid[t;s]]-o`costb]}   / the open quantity marked at the mid as of t, less what it cost
pnl:{[t] s:exec sym from pos; ([sym:s] real:pos[([]sym:s);`real]; unreal:"f"$unreal[t] each s)}   / (a table of keys: indexing pos by a list of syms fails when the list is empty)
\d .
