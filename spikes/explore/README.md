# Exploration: what should run when the shrinker's passes stall?

Unfinished work, kept so that it can be picked up again. Nothing here is part of the library, and nothing
here is run by `t/run.q` or `spikes/run.sh`. It was written on 2026-09-28 against commit `77af2d9`, whose
shrinker is the "library" arm below.

**Status: not adopted.** A scheme that looked right on the sweep did not hold up on the real pipeline. See
"Where it stands".

## The question

After A28 (docs/DESIGN.md) the shrinker ends on the same counterexample at every seed for the 42 cases of
`spikes/sweep.q`. The passes move one choice or two. What about three or more that must move together, and what
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
| `instr.q` | attempts and shrinks counted pass by pass |
| `mdp.q` | six real bugs and sabotages of `examples/mdp` (LOG.md entries 20 to 23), one process each: `q spikes/explore/mdp.q 0` to `5` |
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

## What to do next

- Run the recording change by itself on `mdp.q`. It has not been isolated there, so how much of the
  improvement above is its doing is not known.
- Put the pipeline's cases, or state machines like them, into the sweep before using it to choose between
  schemes again.
- Try the two fixes to passes: duplicates across ranges, and every swap of neighbouring steps.
- Only then return to the question of the finish and its cost.

## If the recording change is adopted

Every state machine's recorded choices change: saved failures and rerun lines from before it will not
replay, and every state machine session in the documents will change. A fresh run chooses the same commands
as before, so the counts of tests in the documents should not change.
