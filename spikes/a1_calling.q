\l spikes/h.q
/ A1: generator calling convention, composition, generic draw, param names
.h.t["param-less lambda is unary and callable with []"; ({1+1}[]=2) and (value {1+1})[1]~enlist `x]
f:{[lo;hi;d] (lo;hi;d)}
.h.t["projection called with [] receives :: as d"; f[0;9][]~(0;9;::)]
.h.t["config-first: {[r;g;d]}[r] g is a generator"; {[r;g;d] (r;g[])}[0 100][f[0;9]][]~(0 100;(0;9;::))]
.h.t["'[f;g] composition = map"; (('[neg;{x+1}])[3]=-4) and (('[first;f[0;9]])[]=0)]
.h.t["(f g@) idiom = map"; ((neg {x+1}@)[3]=-4) and ((first f[0;9]@)[]=0)]
.h.t["function-ish types are within 100 112h"; all (type each ({x};{x+y}[;1];('[neg;{x}]);+;{x}';{x}/;{x}\;{x}':;+/:;+\:)) within 100 112h]
.h.t["atoms/vectors/tables/dicts are not function-ish"; not any (type each (1;1 2;([]a:1 2);`a`b!1 2;"s")) within 100 112h]
.h.t["generic null is 101h but (::)[] is ::, so draw :: is harmless"; (101h=type (::)) and (::)~(::)[]]
.h.t["param names via value"; (value {[n;xs] n+xs})[1]~`n`xs]
/ prototype of the interpreter
draw:{$[type[x] within 100 112; x[]; 99h=type x; key[x]!.z.s each value x; 0h=type x; .z.s each x; x]}
g:f[0;1]
.h.t["draw: function"; draw[g]~(0;1;::)]
.h.t["draw: dict of gens -> dict"; draw[`a`b!(g;42)]~`a`b!((0;1;::);42)]
.h.t["draw: general list -> tuple"; draw[(g;`k)]~((0;1;::);`k)]
.h.t["draw: nested"; draw[`a`b!((g;(g;1));`c`d!(2;g))]~`a`b!(((0;1;::);((0;1;::);1));`c`d!(2;(0;1;::)))]
.h.t["draw: typed vector / atom / table are constants"; (draw[1 2 3]~1 2 3) and (draw[`s]~`s) and draw[t]~t:([]a:1 2)]
.h.t["draw: general list of constants is identity"; draw[(1;"a";`b)]~(1;"a";`b)]
/ property application
.h.t["general-list spec applies with ."; ({[x;y] x+y} . (1;2))=3]
.h.t["other spec applies with @"; ({x*x} @ 3)=9]
.h.t["pass rule: :: or all booleans"; ((::)~{}[1]) and all[1b] and all[101b]=0b]
/ list collection typing
xs:(); xs,:enlist 1; xs,:enlist 2; ys:(); ys,:enlist 1 2; ys,:enlist 3 4
.h.t["enlist-joined atoms become a typed vector; lists stay general"; (7h=type xs) and 0h=type ys]
j1:@[{x:(); x,:enlist 5; x,:enlist 1 2; x};::;{"ERR"}]; j2:@[{x:(); x:x,enlist 5; x:x,enlist 1 2; x};::;{"ERR"}]
.h.t["in-place x,:y does NOT promote a typed vector to general (type error); x:x,y does"; ("ERR"~j1) and j2~(5;1 2)]
.h.t["dict merge default,override"; ((`n`seed!100 0N),enlist[`n]!enlist 5)~`n`seed!5 0N]
.h.t["dict keyed by long vectors (shrink cache)"; (D[1 2 3]=`a) and 3=count D:((1 2 3;4 5)!`a`b),enlist[4 5 6]!enlist `c]
/ q-specific type facts used by the type zoo
.h.t["epoch origin: `date$0 is 2000.01.01"; (`date$0)=2000.01.01]
.h.t["guid from 16 bytes via 0x0 sv"; (-2h=type 0x0 sv 16#0x01) and 0Ng~0x0 sv 16#0x00]
.h.t["kdb+ version >= 4.0"; .z.K>=4.0]
-1 "info: q ",string[.z.K]," ",string[.z.k]," ",string .z.o;
.h.done[]
