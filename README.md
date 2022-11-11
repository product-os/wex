# Workflow EXperimenter

Make testing workflow changes easier by running them locally, without side effects, and verifying what happened.

```
  __      __
 /  \    /  \ ____ ___  ___
 \   \/\/   // __ \\  \/  /
  \        /\  ___/ >    <
   \__/\  /  \___  >__/\_ \
        \/       \/      \/
Usage:
  wex.sh [--options] [--arguments]
  wex.sh -w workflow.yml -c wex.json --verbose
  wex.sh --version

Options:
  -h --help      Display this help information.
  -D --debug     Log additional information to see what Wex is doing.
  --verbose      Make Workflow runner log more information.

Arguments:
  -w --workflow  Workflow to use.
  -c --config    Config file with experiments.
  --version      Print version.
```

## How

By using [act](https://github.com/nektos/act) to run the workflow, we can use the same runner that Github uses to evaluate a Workflow file. By modifying your workflow to run in a "dryrun" mode by replacing all the steps with logs, we can than check what steps would have ran given an input/event.

For example, you can test that your workflow runs "Generate changelog" step when a pull_request is closed. This test can be done in seconds rather than minutes as the alternative requries you actually run the scenario on real Github runners.

Additionally, this repo allows for testing reusable workflows which is [not yet available in act yet](https://github.com/nektos/act/issues/826).

## Why

Testing workflows by manually creating events is very time consuming. You also have to test various scenarios if your workflows can manage several events...that's 1 manual task too many.

Furthermore, reusable workflows are meant to be deployed across many repositories. Imagine if 1 change breaks that workflow and now several repos are affected ? This tries to give you the tools to prevent that.
