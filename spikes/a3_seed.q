\l spikes/h.q
/ A3: seeding determinism; replay from the recorded choice vector survives user code calling rand
.s.P:(); .s.i:0; .s.V:`long$()
.s.reset:{[P] .s.P:P; .s.i:0; .s.V:`long$()}
.s.ch:{[lo;hi;o] j:.s.i; .s.i+:1; v:$[j<count .s.P; lo|hi&.s.P j; lo+rand 1+hi-lo]; .s.V,:v; v}
int:{[r;d] .s.ch[r 0;r 1;0]}
lst:{[g;d] xs:(); while[.s.ch[0;1;0]; xs,:enlist g[]]; xs}
gen:lst int 0 9
/ property that consumes RNG itself
prop:{[xs] r:rand 1000; (sum xs)<50}
run:{[P;seed] system"S ",string seed; .s.reset P; x:gen[]; (x;prop x;.s.V)}
a:run[();42]; b:run[();42]
.h.t["same seed, same prefix -> same example and same choices"; a~b]
c:run[a 2;7]                                     / replay recorded choices under a different seed
.h.t["replay from choice vector reproduces the example regardless of seed"; (c[0]~a 0) and c[2]~a 2]
/ user rand between draws: the *values* are recorded so replay is unaffected
gen2:{x:int[0 9][]; r:rand 100; y:int[0 9][]; (x;y)}
d:run[();3]; .s.reset d 2; e:gen2[]
.h.t["interleaved user rand does not break replay"; e~gen2[]]
/ clamp on misalignment: a shorter/edited prefix still yields a valid value
.s.reset 1 99 0; v:gen[]
.h.t["misaligned choice is clamped into range"; v~enlist 9]
/ overrun detection is the engine's job: cursor beyond prefix means fresh draws
.s.reset enlist 1; system"S 1"; w:gen[]
.h.t["past the prefix, draws are fresh (cursor > count P)"; .s.i>count .s.P]
system"S 42"
.h.t["system S (no arg) reports the seed set"; 42=system"S"]
.h.done[]
