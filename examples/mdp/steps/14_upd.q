/ mdp assembly: one entry point. step 14. Needs the five pieces loaded (02_ref, 06_quotes, 07_bars, 10_pos, 13_eod).
/ upd[table;rows] is what a feed handler calls: quotes to the cache and the day's quote table, trades rounded to the
/ tick, enriched, kept and barred, fills to positions. eod[d] (piece 5) closes the day.
\d .mdp
upd:{[t;x] $[t=`quote; onquote x; t=`trade; ontrade update px:round'[sym;px] from x; t=`fill; onfill x; '"mdp: unknown table ",string t]}
\d .
