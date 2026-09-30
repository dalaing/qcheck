/ oms piece 6: end of day. step 20: sgn spelled .oms.sgn inside slip's q-sql, which resolves a bare name in the root
/ (entry 11). The piece is described in 17_eod.q. Needs 04_ref.q, 07_quotes.q, 08_orders.q, 13_pos.q and 16_ca.q loaded.
/ At the close the day's fills, quotes and rates are written to the database as a partition for the day, sym parted
/ and in time order within each sym, and the memory tables are emptied for the next day. Two things are carried over:
/ the last quote of each instrument and the last rate of each currency stay in memory, timestamped as they were, so
/ that "as of" the first minutes of the next day still has something to find. Orders live in memory across days,
/ open or not (an OMS's order table is small); a copy of the day's orders is written for the record. Queries that
/ span days read today from memory and the rest from disk: the day's fills, with their slippage against the order's
/ arrival price in basis points.
\d .oms
if[not `hdb in key `.oms; hdb:hsym `$first system"mktemp -d"]
day0:2024.01.02
today:day0
opn:{[d] ("p"$d)+0D09:30}
cls:{[d] ("p"$d)+0D16:00}
save1:{[d;n;t] k:$[`sym in cols t; `sym; `ccy]; (` sv hdb,(`$string d),n,`) set @[.Q.en[hdb] (k,`time) xasc 0!t;k;`p#]}   / one table of one day: enumerated, sorted by sym (or ccy) and time within it, parted on it
remap:{system"l ",1_string hdb;}                                                       / (this makes the database the working directory)
eod:{[d] if[not d=today; '"oms: eod for ",string[d]," when today is ",string today];
  save1[d]'[`execs`quote`fxr`order;(fill;quote;fxr;0!order)];                        / (fill is a keyword: on disk the fills are execs)
  quote::cols[quote] xcols 0!select by sym from `time xasc quote; fxr::cols[fxr] xcols 0!select by ccy from `time xasc fxr; fill::0#fill;   / the carry-over: the last quote and the last rate stay, the columns in their order
  remap[]; today::d+1;}
ondisk:{[d] $[`execs in key `.; d in .Q.pv; 0b]}                                       / a closed day the database holds
slip:{[d;s] f:fillsof[d;s]; o:order ([]id:f`id); update bps:1e4*.oms.sgn'[o`side]*(px-o`arr)%o`arr from f}      / each fill's cost against its order's arrival price, in bps (positive is worse)
\d .
/ the fills of day d for s, from memory or from disk. Defined at the root: inside .oms, execs would be .oms.execs
.oms.fillsof:{[d;s] $[d=.oms.today; select from .oms.fill where sym=s; .oms.ondisk d; select time,id,sym:value sym,qty,px from execs where date=d, sym=s; 0#.oms.fill]}
