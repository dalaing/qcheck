# Exploration: what should run when the shrinker's passes stall?

Unfinished work, kept so that it can be picked up again. Nothing here is part of the library, and nothing
here is run by `t/run.q` or `spikes/run.sh`. It was written on 2026-09-28 against commit `77af2d9`, whose
shrinker is the "library" arm below.

**Status: the scheme of searches, gates and budgets is not adopted.** It looked right on the sweep and did
not hold up on the real pipeline; see "Where it stands". **Three changes that did hold up were adopted on
2026-09-30** and are in `qc.q`: see "Adopted" at the end, and A29 in docs/DESIGN.md.

Since they were adopted, the arm called `lib` in these scripts is the library as it now stands, the three
changes included, and the other arms put their prototypes on top of it. The figures below and the files in
`results/` are from before, over the library of `77af2d9`, except where they say otherwise. To run them as
they were run, check out `5958523`.

## The question

After A28 (docs/DESIGN.md) the shrinker ends on the same counterexample at every seed for the 42 cases of
`spikes/sweep.q` (43 since `sm_chain` was added to it). The passes move one choice or two. What about three or more that must move together, and what
about state machines, where deleting a step can change what later steps mean?

## What is here

| file | what it is |
|---|---|
| `sweep.q` | the sweep's 42 cases and seven hard ones: `run3`, `run3_neg`, `run4` (values in a row), `sm_kv` (keys one apart share a slot), `sm_lg`, and two state machines modelled on a sabotage of the pipeline, `sm_alias` and `sm_chain` |
| `defs.q` | the prototypes, in `.qc`: the search stages (`pbox`, `ptw`, `frp`), the heuristics (`psh` shift, `prp` repair), the gates (`g3`, `gdep`, `gnest`, `gprt`), the tier, the other way of recording a state machine's command (`smloop1`), duplicates by value and generator (`pdupv`) |
| `arms1_heuristics_or_search.q` | heuristics, exhaustive search within bounds, or both |
| `arms2_recording.q` | the same with a state machine's command recorded as its place among all the commands |
| `arms3_tiers_and_gates.q` | one gate, tiers, a gate for each dear pass |
| `arms4_budget.q` | the budget for the dear passes: 25, 50, 100, 200, 500 |
| `arms5_fix_and_duplicates.q` | the three changes that held up on the pipeline, over the sweep |
| `instr.q` | attempts and shrinks counted pass by pass |
| `arms6_drop.q`, `drop.q` | a pass in the manner of Hedgehog, and a replay that takes the origin for a choice out of its range: see "After adoption" |
| `mdp_kinds.q` | `mdp.q`, showing each counterexample as its error and its steps and not as its choices |
| `mdp.q` | six real bugs and sabotages of `examples/mdp` (LOG.md entries 20 to 23), one process each: `q spikes/explore/mdp.q 0` to `5`, with arms named after the number if not all are wanted |
| `first_finish_in_the_library.diff` | the finish as it was first built into `qc.q`, before it was taken out again |
| `results/` | what each of these printed |

Run from the repository root: `q spikes/explore/arms4_budget.q 60`, or with arms named,
`q spikes/explore/arms4_budget.q 10 none fine100`. The arms files take three to five minutes at sixty seeds.

## What was found

1. **The largest gain was not a search.** A state machine records each command as its place among the commands
   that can run *now*. When a command has a limit (no more than five objects), deleting a step makes it
   available again and every later command number means something else. Recording the place among *all* the
   commands, a command that cannot run standing for the next that can, took `sm_chain` from 28% of seeds right
   to 100% and `sm_alias` from 23% to 82%, with the shrinker unchanged and at no cost in attempts.
2. **Heuristics and search each solve cases the other does not.** Shift and repair: 46 of 49 cases always right.
   The box alone: 45. Both: 47, and with the recording changed, 49. `sm_kv` needs both.
3. **Most attempts confirm that nothing more can be done.** 63% of attempts come after the last useful
   shrink, and four passes (box, repair, trade, runs) take 55% of attempts for under 3% of the shrinks.
4. **Gates and budgets, on the sweep.** Tiers bought almost nothing, since the cache of candidates already
   makes a repeated pass nearly free. A gate for each dear pass took the extra cost on the 42 easy cases from
   25% to 16%; a budget of 100 in place of 500 took it to 11%, with 49 of 49 still right. A budget of 50 was
   not enough.
5. **A search that is exhaustive in the full sense is out of reach for state machines.** The smallest failure
   of `sm_chain` has six steps, and there are over 100,000 shorter traces to rule out first. What works is a
   search that is exhaustive within a small neighbourhood.

## Where it stands

The scheme of finding 4 (recording changed, tiers, a gate for each dear pass, budget 100) was then run on the
real pipeline, six cases at six seeds. "Kinds" is how many different counterexamples the six seeds ended on:

| case | library: kinds | scheme: kinds | library: attempts | scheme: attempts |
|---|---|---|---|---|
| amend without bars | 2 | 2 | 113 | 267 |
| merge loses PnL | 4 | 3 | 253 | 396 |
| oracle joined by stored names | 5 | 4 | 362 | 428 |
| merge keeps the old position | 4 | 3 | 171 | 317 |
| roll forgets the cache | 3 | 3 | 91 | 228 |
| cache keeps the older quote | 5 | 4 | 223 | 356 |

A modest improvement, never one kind, for about 64% more attempts. The sweep had said 49 of 49 for 11%.
The hard cases of the sweep were written after seeing what the shrinker got wrong, and the passes were tuned
against them; the pipeline has causes that the sweep does not contain. Two were found:

- **The same value under different ranges.** A rename and a quote both name instrument `C`, each choosing it
  from a list of a different length. Every pass that moves choices together asks for the same range, so `C`
  never becomes `A`. Grouping duplicates by value and generator alone (`pdupv`, the arm `new2` of `mdp.q`) took
  the total from 19 kinds to 15.
- **Two steps that could go in either order.** `psort` tries a swap of neighbours only when the later one has
  the lesser key as a block, which puts the shorter first. It never tries the swap that would bring the
  lesser command number forward.

## The recording change by itself

Run afterwards (`q spikes/explore/mdp.q 0 lib fix`, and so on to 5; `results/mdp_fix.txt`): the library's
shrinker unchanged, and only the recording of a state machine's command changed.

| | kinds, summed over the six cases | attempts, mean |
|---|---|---|
| library | 23 | 202 |
| recording changed | 20 | 218 |
| the whole scheme | 19 | 332 |
| the whole scheme, duplicates by value and generator | 15 | 326 |

Six kinds would be one counterexample for each case. The recording change gives three of the four kinds that
the whole scheme gains, for 8% more attempts where the scheme costs 64% more. It made no case worse.

## The three changes that held up, at twelve seeds (2026-09-30)

`NS=12 q spikes/explore/mdp.q 0 lib fix fixdup fixdupswap` and so on to 5 (`results/mdp_fixdup_12.txt`,
`results/mdp_swap_12.txt`), and `q spikes/explore/arms5_fix_and_duplicates.q 60` for the sweep
(`results/arms5_60.txt`, `results/arms5_swap_60.txt`). The library's shrinker with nothing else changed but:

- **fix**: a state machine's command recorded as its place among all the commands (`smloop1`);
- **dup**: duplicates grouped by value and generator, whatever their ranges (`pdupv`);
- **swap**: every swap of neighbouring siblings tried, not only those that bring the lesser block forward
  (`psortv`).

| | pipeline: kinds, summed over six cases | pipeline: attempts, mean | pipeline: seconds, mean | sweep: cases always right | sweep: attempts |
|---|---|---|---|---|---|
| library | 32 | 204 | 3.89 | 43 of 49 | 161,298 |
| fix | 26 | 224 | | 44 | 160,779 |
| fix, dup | 20 | 221 | 3.64 | 44 | 161,206 |
| fix, dup, swap | 14 | 215 | 3.55 | 44 | 165,918 |

Six kinds would be one counterexample for each case, and is not to be had: some seeds find a different
failure of the same system (the step with the merge that loses PnL also has the oracle that joins by stored
names), and a shrink keeps to the failure it began with. By case, with all three changes: 3, 3, 3, 2, 1, 2.

The three together more than halve the kinds on the pipeline for 5% more attempts and no more time, change
nothing that the sweep had right, and cost 3% more attempts on the sweep. The hard cases of the sweep that
they do not touch (`run3`, `run3_neg`, `run4`, `sm_kv`) are the ones that need three or more choices moved
together, which is the question of the finish and is still open.

## What to do next

- Put the pipeline's cases, or state machines like them, into the sweep before using it to choose between
  schemes again.
- Return to the question of the finish and its cost: `run3`, `run3_neg`, `run4` and `sm_kv` are still not
  right at every seed.

## Adopted (2026-09-30)

The three changes are in `qc.q`: `smloop` records a command as its place among all the commands, `pdup`
groups by value and generator, `psort` tries the swaps of neighbours that make the two simpler. `sm_chain` is
in `spikes/sweep.q`, so the library's tests and `spikes/a28_sweep.q` run it. The table above is of the
prototypes, which drew a random number for a choice of one command where the library draws none, so at some
seeds they began from other failures than the library does. Library against library, at the same seeds
(`results/library_and_drop_60.txt` and `results/library_and_drop_mdp_12.txt`, the arm `lib`):

| | pipeline: kinds | pipeline: attempts, mean | sweep here: cases always right | sweep here: attempts |
|---|---|---|---|---|
| the library of `77af2d9` | 32 | 204 | 43 of 49 | 161,298 |
| the library with the changes | 14 | 192 | 45 of 49 | 160,626 |

Five things were found on the way in, the last two by a second review, and the library differs from the
prototypes by them; a third review found that a search which keeps the places of the choices it moves could
raise when an accepted candidate recorded fewer choices, which `pdup`'s did and, before this, `rds`, `tgr`
and `osd` could, and each now stops when the length has changed.

1. With `sm_chain` in the library's sweep at sixty seeds, three seeds ended on a trace with two objects that
   it did not need, and `sm_alias` here was right at 49 of 60. The shrinker had lowered a command's number to
   one whose command could not run, which stood for the same command, and that number changed its meaning
   when an earlier step was deleted: the fault that the change was there to remove, one level up. The library
   puts the record right to the number of the command that ran, and both are right at every seed.
2. `psortv` tries every swap, and each that is refused costs an attempt. On a list of 24 distinct values it
   spent the whole budget of 2000 and no value was lowered. The library asks first whether the two would be
   simpler the other way round as they stand, and tries the swap only if so, or if it is one that the
   library of `77af2d9` would have tried. The sweep has no case with a list that long, which is why nothing
   here showed it; a review of the change did.
3. A run that tries every input in turn took the range of all the commands for the width of the choice, so a
   machine with six commands of which one can run looked large and was sampled where it had been exhausted
   in four tests, and the count of tests before a failure changed at some seeds. The library tells the choice
   tree which commands cannot run.
4. `smloop1` gives the choice the origin 0. A step that had no choice of command, one that could run and not
   the first, was then a choice off its origin: every pass tried to lower it, and its number was part of what
   steps are sorted by, so the inputs of thirty such steps were never sorted. The library makes the first
   command that can run the origin.
5. A candidate that lowers a command's number to one that cannot run stands for the command it had and
   replays as the vector in hand, at the cost of an attempt. On a long trace more than half the attempts
   went that way. The library puts such a candidate right before it is run, and runs nothing for one that
   comes to the vector in hand.

Every state machine's recorded choices changed: saved failures and rerun lines from before do not replay. A
fresh run is what it was at the same seed, so the counts of tests in the documents did not change; the
counts of attempts and the rerun lines did, and so did some of the traces that the pipeline's documents show.

## After adoption: a pass that drops steps, and what the remaining kinds are

Hedgehog shrinks a list of actions, and after each shrink drops the actions whose precondition no longer holds.
Here a step whose command can no longer run becomes the next command that can, and stays. `drop.q` has a pass
that does as Hedgehog does: delete a step, and where the replay put another command in place of the one
recorded at a later step, delete that step too and try again (`q spikes/explore/arms6_drop.q 60 lib drop orig`,
`NS=12 q spikes/explore/mdp_kinds.q 0 lib drop` and so on to 5).

| | pipeline: kinds | pipeline: attempts, mean | sweep here: cases always right | sweep here: attempts |
|---|---|---|---|---|
| the library | 14 | 192 | 45 of 49 | 160,626 |
| with the pass | 14 | 167 | 45 of 49 | 160,381 |

The same counterexample at every seed of every case of the pipeline, in 13% fewer attempts; nothing gained
or lost on the sweep. Dropping a step one of whose inputs was clamped as well (`dropc`) made no difference
when it was tried, on the library as it was before its second review. Not adopted. Taking the origin for a replayed choice that
is out of its range, in place of the nearer bound (the arm `orig`, in `results/library_and_drop_60.txt`),
was worse: 43 cases always right for 45, in 82% more attempts (292,073), with the two float cases ending
elsewhere at most seeds.

What the pass could not have changed is what the remaining kinds are. By case the library ends on 3, 3, 3,
2, 1 and 2 (`mdp_kinds.q` shows them), and the eight over are:

- *another failure of the same system*, with another error, found first at that seed (two);
- *another way to the same failure*, which is not one or two choices from the simplest: a trade, a close
  and a bust of the trade where a close and a late trade would do; a late trade and a query of yesterday where
  a trade and a query of today is simpler by a command's number; two renames in a chain (four);
- *a deletion that needs a later choice put right at the same time*: three closes and a late trade, where
  deleting a close leaves the late trade's time past the end of the day that is now yesterday; a rename too
  many, where deleting it changes the name that the next rename gives, and the query asks for the old one
  (two). These are what the repair pass here was for.
