/ mdp piece 3: per-minute bars. step 07
/ bar: OHLCV per sym and minute, kept up to date trade by trade (onbar); barsb recomputes them from a trade table.
\d .mdp
bar:([sym:`symbol$(); minute:`timestamp$()] o:`float$(); h:`float$(); l:`float$(); c:`float$(); v:`long$(); n:`long$())
onbar:{[t] {[r] k:`sym`minute!(r`sym;0D00:01 xbar r`time); b:bar k;
  bar[k]:$[null b`n; `o`h`l`c`v`n!(r`px;r`px;r`px;r`px;r`qty;1); `o`h`l`c`v`n!(b`o;b[`h]|r`px;b[`l]&r`px;r`px;b[`v]+r`qty;b[`n]+1)]} each t;}
barsb:{[t] select o:first px,h:max px,l:min px,c:last px,v:sum qty,n:count i by sym,minute:0D00:01 xbar time from t}
\d .
