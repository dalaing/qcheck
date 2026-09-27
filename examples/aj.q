/ q examples/aj.q — an as-of join checked against a naive one, over generated quotes and trades. Run it from the
/ repository root; EXAMPLES.md ("A generator of your own") and COOKBOOK.md ("An as-of join against a naive one")
/ talk through the output.
\l qc.q
.qc.cfg[`db]:`                                   / no failure database: every run of this script searches afresh

/ The quotes and the trades should share their symbols: drawn separately from any realistic universe, a trade
/ would seldom find a quote. So a symbol list is drawn first (one to three one-letter symbols) and both tables
/ take their sym column from it.
syms:.qc.lst[1 3] .qc.symc["abc";1 1]

/ A table of at least one row: sym from the list s, time non-decreasing (mono: each row adds 0..9 to the one
/ before, so the table is sorted by construction), and one more column, named nm and drawn from g.
tbl:{[s;nm;g] .qc.tabr[1 0W] (`sym`time,nm)!(.qc.elem s; .qc.mono[.qc.int 0 9;.qc.int 0 9]; g)}

/ A generator of your own is a function that draws: this one draws the symbols, then a quote table and a trade
/ table over them, and returns the pair as a dict. (d is the argument every generator is called with; ignore it.)
pair:{[d] s:.qc.draw syms; `q`t!(.qc.draw tbl[s;`px;.qc.int 0 9]; .qc.draw tbl[s;`qty;.qc.int 0 9])}

/ The naive join: for each trade, the price of a quote for its sym at or before its time. It takes the first
/ such quote where an as-of join takes the last. That is the bug.
naive:{[t;q] f:{[q;s;tm] $[count r:exec px from q where sym=s,time<=tm; first r; 0N]}[q]; update px:"j"$f'[sym;time] from t}

/ .qc.eq is ~ with an explanation: when the two sides differ, the report says where and how.
-1 "aj against a naive as-of join that takes the first quote, not the last:";
.qc.check[pair; {.qc.eq[aj[`sym`time;x`t;x`q]; naive[x`t;x`q]]}];
exit 0
