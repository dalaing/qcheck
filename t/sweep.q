/ the seed sweep as tests: a shrink ends on the same counterexample whatever the seed, and on the simplest one that
/ any seed found. Ten seeds over every case of spikes/sweep.q; spikes/a28_sweep.q runs thirty, and
/ spikes/shrink_arms.q is the experiment that chose the passes. loaded by t/run.q
\l spikes/sweep.q
A:.s.run "i"$1+til 10
S:0!.s.score[.s.ref A;A]
.t.t["sweep: every case fails at nine seeds in ten or more, so that there is something to shrink"; all 9<=S`runs]
.t.each[{[r] .t.t["sweep ",string[r`name],": one counterexample at every seed, the simplest found (",(40 sublist r`top),")"; (1=r`kinds) and 1=r`atref]}; S]
.t.t["sweep: under 25000 attempts in all (58 for each shrink)"; 25000>sum S`attempts]
/ the sweep wraps the shrinker to note the key it ends on: put the shrinker back as it was
.qc.shr:.qc.shr1
![`.qc;();0b;enlist `shr1];
