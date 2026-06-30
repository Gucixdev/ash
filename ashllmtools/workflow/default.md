# default

The unified 8-step decision loop. Every workflow runs this loop.

## Steps

1. **ORIENT** — sync world model to current state
2. **PLAN** — decompose goal into tasks if no plan exists yet
3. **SELECT** — pick the first unblocked PENDING task (respects dependencies)
4. **CONTRACT** — evaluate action through the decision contract (firewall gate)
5. **EXECUTE** — invoke the assigned skill with the task description as input
6. **REFLECT** — classify result as success or failure
7. **UPDATE** — store result in task, mark DONE or BLOCKED
8. **CHECK** — all done → exit DONE; no unblocked tasks → exit BLOCKED; else loop

## Exit conditions

| Code    | Meaning                                          |
|---------|--------------------------------------------------|
| DONE    | all tasks completed, goal achieved               |
| BLOCKED | contract blocked, missing info, or stuck         |
| ERROR   | unrecoverable failure (max_steps exceeded, etc.) |

## Customizing

Add tasks to `WorkflowEngine` before calling `run()`:

```mojo
var wf = WorkflowEngine("my goal")
var a  = wf.add_task("step one", "read_file")
var b  = wf.add_task("step two", "analyze")
wf.add_dep(b, a)   # b depends on a
var r  = wf.run(max_steps=50)
```
