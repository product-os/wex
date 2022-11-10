# Workflow EXperimenter

Make testing workflows easier by providing a configurable interface on how to run the workflow, what to check for after, and support for [reusable workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows).

## How

By using [act](https://github.com/nektos/act) to run the workflow, we can than perform checks to see if the right steps were ran. Additionally, this repo allows for testing reusable workflows which is [not yet available in act yet](https://github.com/nektos/act/issues/826).

## Why

Reusable workflows are meant to be deployed across many repositories. Imagine if 1 change breaks that workflow and now several repos are affected ? This tries to give you the tools to prevent that. Plus, running actions/workflows is really painful to manually test!
