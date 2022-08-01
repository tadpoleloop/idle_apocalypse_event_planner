# Event Planner Version 0.1
## What is it?

This app allows your to input the current state of the event you are in and it will create an event plan for you. This plan consists of a schedule of upgrades (and possibly toggles for *lost in time* and *through the portal* events).

## How does it work?

There are two important parts to this solver.
1. A simulation framework  
1. A tree-search engine

The simulation framework attempts to make a nearly 1-1 replica to the game's event framework. One noteable difference is that the simulation *averages out* the discrete nature of how creatures produce resources. In the game, the creatures produce resources in a batch every few seconds. In the simulation framework, the creatures produce a steady rate of resources. This is to simplify the model to make creating a plan simpler.

The tree-search engine first seeds the search with a random simulation, and then attempts to improve on that plan with a *small* change. This is repeated until it can no longer find a small change that improves on the plan.

A *small* change, in this context, is perturbing the plan by moving a few upgrades(toggles) earlier or later.

# FAQ

## How good is it? 

[See for yourself!](https://mybinder.org/v2/gh/tadpoleloop/idle_apocalypse/HEAD?urlpath=voila%2Frender%2Fgui.ipynb) It is certainly better than the author.

## Why does it sometimes give a different plan with the same information?

There are a few reasons why this might be the case. The search algorithm starts with a random strategy, and then tries to improve that strategy. Different initial strategies may converge to different final strategies. In addition, the search algorithm only samples a few hundred random similar strategies before it is satisfied with the current strategy. It may also be the case that from this sample, it did not find an improvement oon one run, but found an improvement on another run.

You can run the planner several times if you are not satisfied with the result.

## Why does it take so long to load?

This server is deployed using [mybinder.org](https://mybinder.org). Whenever the codebase changes, the entire environment needs to be rebuilt. But each machine on Kubernetes that is spun up to deliver this app also needs to download the build from a cache. This takes time. There are plans to move the server to keroku for quicker access.

## What is *urgency*?

***Urgency*** is an arbitrary measure of how important an upgrade is to upgrade immediately. Roughly, it is proportionally how much longer it will take to reach the goal if that upgrade is delayed. E.g. if the urgency is 50% and you are one hour late to upgrade, then the event will take approximately half an hour longer to complete. Due to the nature of how it is calculated, ***urgency*** in events with toggles (*Lost in Time* and *Through the Portal*) may not be accurately reflected.

Feel completely free to ignore that column all-together.

## What is this planner good at?

This planner excels at finding small improvements to a strategy.

## What is this planner bad at?

This planner gives no guarantee to finding the best possible solution.

## I found a mistake / I have a suggestion!

Good! The best way to contact me is on discord: @tadpole#3755.

## Your code smells!

I agree! Do you want to contribute? Put up a PR!

# Full Plans

[Here](https://tadpoleloop.github.io/idle_apocalypse_event_planner/best_solutions.html) is a compilation of precompiled plans.
