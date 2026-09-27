\l spikes/h.q
\l spikes/sweep.q
/ A28: a shrinker should end on the same counterexample whatever the seed, and on the simplest one. Every case
/ of the sweep, at thirty seeds, against the simplest counterexample found for it at any of them.
NS:30
A:.s.run "i"$1+til NS
S:0!.s.score[.s.ref A;A]
system"c 60 200"
show select name,runs,kinds,atref,attempts,top:60 sublist/:top from S
-1 "cases: ",string[count S],"  always the same: ",string[sum 1=S`atref],"  attempts: ",string sum S`attempts;
.h.t["every case fails at most of the seeds, so that there is something to shrink"; all (NS*0.9)<=S`runs]
.h.t["every case ends on one counterexample, whatever the seed"; all 1=S`kinds]
.h.t["and that one is the simplest that any seed found"; all 1=S`atref]
.h.t["the whole sweep takes under 70000 attempts (55 for each shrink)"; 70000>sum S`attempts]
.h.done[]
