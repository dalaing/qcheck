/ oms piece 5: corporate actions. step 15: the open orders are updated with a functional update over the table's value
/ (step 14 amended several columns of a keyed table at once by index, which q refuses; entry 10). The piece is described
/ in 14_ca.q. Needs 04_ref.q, 07_quotes.q, 08_orders.q and 13_pos.q loaded.
/ A split, r new shares for each old one, arrives before the market opens on its day. Everything that is a quantity
/ of the instrument is multiplied by r and everything that is a price of it is divided: the position and its average
/ cost, and the open orders, their quantity, what is left, their limit and their arrival price. Fills already made
/ and quotes already seen are history and stay as they were. Only whole ratios for now: a reverse split, or a 3 for
/ 2, can leave a fraction of a share, and what the desk does with fractions is not decided here.
\d .oms
ca:([]time:`timestamp$(); sym:`symbol$(); ratio:`long$())                           / the splits applied, for the record
split:{[t;s;r] if[(r<2) or r<>"j"$r; '"oms: split ratio ",string[r]," is not a whole number of 2 or more"]; if[null inst[s;`ccy]; '"oms: unknown instrument ",string s];
  if[not null pos[s;`qty]; pos[s;`qty`cost]:(pos[s;`qty]*r; pos[s;`cost]%r)];
  order::![order;((=;`sym;enlist s);(in;`st;enlist `new`ack`part));0b;`qty`leaves`px`arr!((*;`qty;r);(*;`leaves;r);(%;`px;r);(%;`arr;r))];   / (functional: q-sql on the bare name would look for order in the root; and :: not :, which would make order a local)
  `.oms.ca insert (t;s;r);}
\d .
