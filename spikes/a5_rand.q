\l spikes/h.q
/ A5: rand edge cases and a safe uniform draw over any long range
.h.t["rand of negative long is a domain error"; "domain"~.h.err[rand;-5]]
-1 "info: rand 0 -> ",.Q.s1 .h.err[rand;0];
.h.t["rand 0W works"; -7h=type rand 0W]
-1 "info: 1+0W -> ",.Q.s1[1+0W],"  0W-(-0W) -> ",.Q.s1 0W-(-0W);
.h.t["1+0W overflows (to 0N here), so width arithmetic needs a guard"; not (1+0W)>0]
.h.t["rand 0 returns an arbitrary long, never an error: must guard"; -7h=type rand 0]
/ uniform draw: width w=1+hi-lo; when w<=0 the range overflows, so pick a half at random
u:{[lo;hi] $[lo=hi; lo; 0<w:1+hi-lo; lo+rand w; rand 2; lo+rand 0W; hi-rand 0W]}
ok:{[lo;hi] v:u ./: 2000#enlist (lo;hi); all (v>=lo) and v<=hi}
.h.t["u: lo=hi"; 5=u[5;5]]
.h.t["u: small symmetric range in bounds"; ok[-5;5]]
.h.t["u: 0..0W in bounds"; ok[0;0W]]
.h.t["u: full width -0W..0W in bounds"; ok[-0W;0W]]
.h.t["u: -0W..-0W+1 in bounds"; ok[-0W;-0W+1]]
.h.t["u: covers both ends of a small range"; (0 10~asc distinct v) or 11=count distinct v:u ./: 5000#enlist 0 10]
/ mixture for fresh draws: 1/8 boundary-ish (origin, lo, hi, o±1), else uniform over a random bit-width
mag:{[lo;hi;o] $[0=rand 8; lo|hi&(o;lo;hi;o+1;o-1) rand 5; lo|hi&o+(1 -1 rand 2)*"j"$rand 2 xexp 1+rand count 2 vs 0|hi-lo]}   / bit-width bounded by the range width, else clamping piles up at the bounds
xs:{mag[-1000000;1000000;0]} each til 20000   / NB: f[a;b;c] each xs applies the *result*; wrap in a lambda
.h.t["mag: in bounds"; all xs within -1000000 1000000]
-1 "info: mag |v|<10: ",string[avg 10>abs xs],"  |v|<1000: ",string[avg 1000>abs xs],"  at bound: ",string avg 1000000=abs xs;
.h.t["mag: small values are common (>20% under 10)"; 0.2<avg 10>abs xs]
v:rand each 2000#1f
.h.t["float rand uniform in [0,1)"; all (v>=0) and v<1f]
.h.done[]
