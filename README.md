# Event Planner Version 0.1
## What is it?

This app allows your to input the current state of the event you are in and it will create an event plan for you. This plan consists of a schedule of upgrades (and possibly toggles for *lost in time* and *through the portal* events).

## How does it work?

There are two important parts to this solver.
1. A simulation framework  
1. A tree-search engine

The simulation framework attempts to make a nearly 1-1 replica to the game's event framework. One noteable difference is that the simulation *averages out* the discrete nature of how creatures produce resources. In the game the creates produce resources in a batch every few seconds. The simulation framework instead produces a steady rate of resources. This is to simplify the model to make creating a plan simpler

The tree-search engine first seeds the search with a random simulation, and then attempts to improve on that plan with a *small* change. This is repeated until it no longer can find a small change that improves on the plan.

A *small* change in this context is perturbing the plan by moving a few upgrades(toggles) earlier or later.

# FAQ

## How good is it? 

[See for yourself!](gui.ipynb) It is certainly better than the author.

## Why does it sometimes give a different plan with the same information?

There are a few reasons why this might be the case. The search algorithm starts with a random strategy, and then tries to improve that strategy. Different initial strategies may converge to different final strategies. In addition, the search algorithm only samples a few hundred random perturbations of nearby strategies before it is satisfied with the current strategy. It may also be the case that from this sample, it did not find an improvement one time, but found it another time

## Why does it take so long to load?

This server is deployed using [mybinder.org](https://mybinder.org). Whenever the codebase changes the entire environment needs to be rebuilt. But each machine on Kubernetes that is spun up to deliver this app also needs to download the build from a cache. This takes time. There are plans to move the server to keroku for quicker access.

## What is this planner good at?

This planner excels at finding small improvements to a strategy.

## What is this planner bad at?

This planner gives no guarantee to finding the best possible solution.

## I found a mistake / I have a suggestion!

Good! The best way to contact me is on discord: @tadpole#3755.

## Your code smells!

I agree! Do you want to contribute? Put up a PR!

# Full Plans

[Here](best_solutions.ipynb) is a compilation of precompiled plans.
