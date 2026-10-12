/ oms piece 5: corporate actions. step 16: an open order's limit, divided by the ratio, is put back on the tick against
/ the order (a buy rounds down, a sell up), since a limit off the tick is not an order the market takes (entry 10). The
/ piece is described in 14_ca.q. Needs 04_ref.q, 07_quotes.q, 08_orders.q and 13_pos.q loaded.
/ A split, r new shares for each old one, arrives before the market opens on its day. Everything that is a quantity
/ of the instrument is multiplied by r and everything that is a price of it is divided: the position and its average
/ cost, and the open orders, their quantity, what is left, their limit and their arrival price. Fills already made
/ and quotes already seen are history and stay as they were. Only whole ratios for now: a reverse split, or a 3 for
/ 2, can leave a fraction of a share, and what the desk does with fractions is not decided here.
\d .oms
ca:([]time:`timestamp$(); sym:`symbol$(); ratio:`long$())                           / the splits applied, for the record
totick:{[side;p;tk] r:tk*?[(),`buy=side; (),floor p%tk; (),ceiling p%tk]; $[0>type p; first r; r]}   / a price put on the tick against the side, a buy down and a sell up; atoms or lists
split:{[t;s;r] if[(r<2) or r<>"j"$r; '"oms: split ratio ",string[r]," is not a whole number of 2 or more"]; if[null inst[s;`ccy]; '"oms: unknown instrument ",string s];
  if[not null pos[s;`qty]; pos[s;`qty`cost]:(pos[s;`qty]*r; pos[s;`cost]%r)];
  tk:inst[s;`tick]; order::![order;((=;`sym;enlist s);(in;`st;enlist `new`ack`part));0b;`qty`leaves`px`arr!((*;`qty;r);(*;`leaves;r);(.oms.totick;`side;(%;`px;r);tk);(%;`arr;r))];   / (functional over the value, and :: not :, which would make order a local; update ... from order would do as well, with totick spelled .oms.totick, since a function named inside q-sql is looked up in the root)
  `.oms.ca insert (t;s;r);}
\d .
