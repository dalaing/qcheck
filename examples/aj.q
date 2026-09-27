/ q examples/aj.q — an as-of join against a naive one, over quotes and trades that share a drawn symbol list (A20)
\l qc.q
syms:.qc.lst[1 3] .qc.symc["abc";1 1]
tbl:{[s;nm;g] .qc.tabr[1 0W] (`sym`time,nm)!(.qc.elem s; .qc.mono[.qc.int 0 9;.qc.int 0 9]; g)}   / sym from the shared list, time sorted
pair:{[d] s:.qc.draw syms; `q`t!(.qc.draw tbl[s;`px;.qc.int 0 9]; .qc.draw tbl[s;`qty;.qc.int 0 9])}
naive:{[t;q] f:{[q;s;tm] $[count r:exec px from q where sym=s,time<=tm; first r; 0N]}[q]; update px:"j"$f'[sym;time] from t}   / bug: first quote at or before, not last
-1 "aj against a naive as-of join that takes the first quote instead of the last:";
.qc.check[pair; {(aj[`sym`time;x`t;x`q])~naive[x`t;x`q]}];
exit 0
