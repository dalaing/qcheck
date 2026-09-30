/ oms piece 4: positions and PnL. step 23: the first fill of an instrument opens its position with a realised PnL of
/ zero, not a null (entry 12). Step 22 made pnl of no positions an empty report. The piece is described in 13_pos.q. Needs 04_ref.q, 07_quotes.q and 08_orders.q loaded.
/ A position per instrument: the signed quantity, the average cost of the open quantity in the instrument's
/ currency, and the realised PnL in the base currency. A fill that adds to the position (same side) moves the average
/ cost; one that reduces it realises (px - cost) on what it closes, converted to the base at the rate as of the fill;
/ one that goes through zero realises on the part it closes and opens the rest at its price. Unrealised PnL is
/ (mark - cost) on the open quantity, the mark being the mid as of the time asked, converted at the rate as of then.
\d .oms
pos:([sym:`symbol$()] qty:`long$(); cost:`float$(); real:`float$())
sgn:{[side] $[`buy=side; 1; -1]}
onpos:{[t;s;side;q;p] if[null pos[s;`qty]; pos[s]:`qty`cost`real!(0;0f;0f)]; o:pos s; d:sgn[side]*q; cur:o`qty; cc:inst[s;`ccy];   / (0^pos s stood here: it gave the arithmetic zeros and left a null real in the row)
  $[(cur=0) or (signum cur)=signum d; [pos[s;`qty`cost]:(cur+d; ((cur*o`cost)+d*p)%cur+d)];   / adding: the average moves
    abs[d]<=abs cur; [pos[s;`real]:o[`real]+tobase[t;cc;(cur-cur+d)*p-o`cost]; pos[s;`qty]:cur+d; if[0=cur+d; pos[s;`cost]:0f]];   / reducing: realise on what is closed
    [pos[s;`real]:o[`real]+tobase[t;cc;cur*p-o`cost]; pos[s;`qty`cost]:(cur+d;p)]]}     / through zero: close it all, open the rest at p
onfill0:onfill
onfill:{[t;id;q;p] onfill0[t;id;q;p]; o:order id; onpos[t;o`sym;o`side;q;p]}
unreal:{[t;s] o:pos s; $[0=o`qty; 0f; tobase[t;inst[s;`ccy];o[`qty]*mid[t;s]-o`cost]]}   / the open quantity marked at the mid as of t
pnl:{[t] s:exec sym from pos; ([sym:s] real:pos[([]sym:s);`real]; unreal:"f"$unreal[t] each s)}   / (a table of keys: indexing pos by a list of syms fails when the list is empty)
\d .
