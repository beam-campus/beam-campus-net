%{
  title: "Breeding a solution, and how to tell whether your problem is one of them",
  date: ~D[2026-08-09],
  description: "Some problems can be solved by breeding: make a hundred attempts, keep the best, make copies, repeat. Most cannot. Four questions decide which, and getting them wrong wastes months. We wrote the questions down, and then discovered that our own flagship project currently fails one of them.",
  corpus: :faber,
  tags: ["method", "neuroevolution", "open-science"],
  sources: [51, 52, 54, 57],
  corpus_ref: "faber insights 051, 052, 054, 057"
}
---

Almost everything on this notebook so far has been a report from inside one experiment. This note is different. It is about the question you have to answer *before* the experiment: is this problem even the kind of problem our method can solve?

We got that question wrong often enough, and expensively enough, that we eventually wrote the answer down as a checklist. Here is the checklist, in plain language, along with the mistakes that put each item on it.

## First, what the machine actually does

There are two ways to teach a computer to do something.

The usual way is to correct it. Show it a situation, let it answer, tell it how wrong it was, nudge it slightly less wrong, repeat a million times. This is what almost all modern AI does, and it works beautifully when you can always tell it **which direction is better**. It is like walking downhill in thick fog: you cannot see the valley, but you can feel the slope under your feet, so you keep stepping downhill and you get there.

The other way is breeding. You make a few hundred slightly different brains at random. You give them all the same test. You throw away the ones that did worst, make slightly-changed copies of the ones that did best, and run the test again. Nobody ever tells any brain what it did wrong. There is only a scoreboard, and the scoreboard decides who gets children.

That second way is what our machine does.

## Why you would ever choose the slow way

Breeding is enormously wasteful. It needs millions of attempts where the correcting method needs thousands. So you would only reach for it when the fog-walking trick is unavailable, and there are really only three situations where that is true.

**When there is no slope to feel.** If the score is "did the battery ever run flat, yes or no", then almost everywhere you stand, wiggling your foot changes nothing at all. The ground is perfectly flat until you fall off a cliff. There is no downhill to follow, so fog-walking has nothing to work with. Breeding does not care, because breeding never needed a slope. It only ever needed a scoreboard.

**When downhill leads somewhere bad.** Sometimes the sensible, always-improve-a-little-more path walks you straight into a dead end, and the real solution requires getting temporarily worse first. We tested this properly ([insight 051](/research/notes/abandoning-the-objective)). On a maze built to have exactly that trap, a search chasing "get closer to the goal" solved it 1 time in 40. A strong classical optimiser solved it **0** times in 40. A search that instead chased "do something nobody has done before" solved it **34** times in 40.

**When you want a hundred different answers rather than one best one.** Breeding keeps a whole population around, so it is naturally good at filling a space rather than finding a point. In one experiment a novelty-seeking search covered essentially every distinct behaviour available, 112 of about 112, where a goal-seeking search found 79, and it cost no extra time.

**And one belief we had to give up.** The original hunch was that breeding wins when the world is chaotic and unpredictable. That is almost backwards. Chaos makes every score noisy, so a large share of your effort goes into being fooled by luck. Chaos is not the reason. The three above are the reasons.

## The four questions

We started with seven. Forced to rank them honestly, only four actually turn anyone away.

**1. Does what the agent does change what it sees next?**

This sounds obvious and it eliminates the most ideas. A recording of last year's electricity prices is not an environment, it is a tape. You can play a tape, but you cannot argue with it. If the agent's choices never change what happens next, this is not control, it is prediction wearing a costume, and ordinary methods will beat you using a thousandth of the electricity. A video of a chess game is not chess.

**2. Is the score of a kind that fog-walking cannot handle?**

Yes or no, count-of-times, over-a-threshold, only-worked-out-at-the-very-end. If the score is smooth, say so out loud, name the ordinary method you are going to lose to, and go home.

**3. Can you afford ten million tries?**

Breeding needs somewhere between a million and a hundred million attempts. If one attempt takes a second, ten million attempts take four months. This question is arithmetic rather than opinion, and it is the one people skip.

**4. Is there more than one owner involved?**

This one does not reject the problem. It rejects the *network*. If there is only one party, build the thing, but build it on one machine and stop pretending it needs to be distributed.

Two questions that used to be on the reject list have been demoted to **promises**, because you honestly cannot answer them on day one. One is "is there a fair exam". The other is "is the brain big enough". You commit to checking both, and crucially you say **when** you will check. The last question, "does it need memory", rejects nothing at all; a no just means switch two features off.

## The most expensive mistake, and it is embarrassingly simple

Our drone project ran for months with an exam that was **inside its own homework**.

There were meant to be two sets of practice opponents. One set the drones trained against all day. A second, separate set was the exam, kept sealed, never trained against, and the score on that sealed exam was the only number allowed to be called improvement.

They were the same six opponents. Somewhere between one round in nine and one round in four drew an exam question as a training partner. Four separate documents promised the two sets were different. Nothing in the code checked, so nothing noticed.

This is why the checklist keeps repeating one rule in different words: **a promise written in prose is not a mechanism.** If a property matters, something has to fail loudly when it stops being true. There is now a test that fails if the two sets ever share a single opponent.

## And a second, sadder problem with exams

Once that was fixed, we changed the drones' weapons: their guided missile went from reaching 600 metres to reaching 60. Suddenly, on the exam, **every** reference contestant scored zero on **every** question. Random players, a do-nothing player, all of them, zero across the board.

So is the exam now brilliantly hard, or is it broken? You genuinely cannot tell from the inside. A test where everyone scores zero looks exactly like a perfect test that nobody has reached yet. We cannot grade the exam until we have students good enough to tell the questions apart.

That is why "is there a fair exam" got demoted from a gate to a promise. Our own flagship example is, right now, sitting in exactly that failure. This connects to something an [earlier note](/research/notes/a-ruler-you-can-trust) worked out the hard way: a measuring stick has to be *graded*, or it goes blind without telling you. It turns out there is a second, nastier version of the same trap, where the stick is so hard that everything reads zero and you cannot tell a perfect instrument from a broken one.

## What sharing between machines is actually for

We run several machines, each breeding its own population, raiding each other and keeping the designs that attacked them. The obvious story is: sharing makes everybody better, because you get sparring partners you could never have invented alone.

We measured it, and the obvious story is **not supported**. In a carefully controlled version of the question ([insight 057](/research/notes/two-nets-learn-to-chase)), an opponent that adapts to you turned out to buy nothing that a **varied but frozen** opponent does not. And varied frozen opponents are free. You can generate a thousand random ones on one laptop this afternoon.

So sharing does not earn its keep by supplying variety. Variety is cheap. If it earns its keep at all, it is for a much narrower reason: **another party's real problem cannot be invented at home, at any price.** Random opponents are free. The actual near-miss that happened at somebody else's site last Tuesday is not, and no amount of computing will conjure it up.

Whether that is *enough* to justify the machinery is a question we have not answered, and we are careful not to write as though we had.

## The honest bit at the end

This is a recipe written after cooking one meal.

Everything in the checklist was learned from a single project. A recipe from one meal might be a recipe, or it might just be a description of that one meal with the ingredients crossed out. There is no way to tell from the inside.

So the checklist commits, in advance, to how it will find out. The next project built using it has to keep a diary of everything that goes wrong. If that diary fills up with the **same** mistakes the recipe claims to have already paid for, then it was never a recipe. It was one project's story, and it gets filed as such.

We would rather write that down now, while it can still embarrass us, than discover it quietly later.
