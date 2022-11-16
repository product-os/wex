# Workflow EXperimenter

Make testing workflow changes easier by running them locally, without side effects, and verifying what happened.

```
  __      __
 /  \    /  \ ____ ___  ___
 \   \/\/   // __ \\  \/  /
  \        /\  ___/ >    <
   \__/\  /  \___  >__/\_ \
        \/       \/      \/
Usage: wex.sh [OPTION...]

Integration testing for Github Action workflows.

Mandatory arguments:
  -w --workflow  Workflow to use.
  -c --config    Config file with experiments.

Optional arguments:
  -h --help      Display this help information.
  -D --debug     Log additional information to see what Wex is doing.
  --version      Print version.
  --verbose      Make Workflow runner log more information.
  --logs         Print Workflow logs (Same logs you'd see on Github).

Exit status:
	0 if OK,
	1 if any experiments fail
```

## How

By using [act](https://github.com/nektos/act) to run the workflow, we can use the same runner that Github uses to evaluate a Workflow file. By modifying your workflow to run in a "dryrun" mode by replacing all the steps with logs, we can than check what steps would have ran given an input/event.

For example, you can test that your workflow runs "Generate changelog" step when a pull_request is closed. This test can be done in seconds rather than minutes as the alternative requries you actually run the scenario on real Github runners.

Additionally, this repo allows for testing reusable workflows which is [not yet available in act yet](https://github.com/nektos/act/issues/826).

## Why

Testing workflows by manually creating events is very time consuming. You also have to test various scenarios if your workflows can manage several events...that's 1 manual task too many.

Furthermore, reusable workflows are meant to be deployed across many repositories. Imagine if 1 change breaks that workflow and now several repos are affected ? This tries to give you the tools to prevent that.
