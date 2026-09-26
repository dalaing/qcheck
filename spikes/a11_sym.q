\l spikes/h.q
/ A11: symbol interning — bounded alphabet keeps sym memory flat, unbounded grows
w0:.Q.w[]
b:{`$3?"abc"} each til 100000
w1:.Q.w[]
u:{`$8?.Q.a} each til 100000
w2:.Q.w[]
-1 "info: symw before ",string[w0`symw]," bounded ",string[w1`symw]," unbounded ",string w2`symw;
-1 "info: syms before ",string[w0`syms]," bounded ",string[w1`syms]," unbounded ",string w2`syms;
.h.t["bounded alphabet adds <= 40 symbols"; 40>=(w1`syms)-w0`syms]
.h.t["unbounded adds ~1e5 symbols (never reclaimed)"; 90000<(w2`syms)-w1`syms]
.h.done[]
