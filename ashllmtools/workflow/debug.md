# debug

Workflow for diagnosing and fixing a reported bug.

## Goal

Identify root cause, propose fix, verify with tests.

## Steps

| # | Task                     | Skill       | Depends on |
|---|--------------------------|-------------|------------|
| 0 | read failing test output | `read_file` | —          |
| 1 | hunt for root cause      | `bughunt`   | 0          |
| 2 | search for related code  | `search`    | 1          |
| 3 | run tests to verify      | `run_tests` | 2          |
| 4 | reflect on test result   | `reflect`   | 3          |

## Usage

```mojo
var wf = WorkflowEngine("debug: timeout in network layer")
var r0 = wf.add_task("read test output log",         "read_file")
var r1 = wf.add_task("locate root cause",            "bughunt")
var r2 = wf.add_task("search for timeout handling",  "search")
var r3 = wf.add_task("run test suite",               "run_tests")
var r4 = wf.add_task("reflect on test result",       "reflect")
wf.add_dep(r1, r0)
wf.add_dep(r2, r1)
wf.add_dep(r3, r2)
wf.add_dep(r4, r3)
var result = wf.run()
```

## Acceptance criteria

- `run_tests` output does not contain FAIL or ERROR
- `reflect` returns `verdict=ok`
