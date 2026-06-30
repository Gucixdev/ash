# code_review

Workflow for reviewing a code change (diff or file).

## Goal

Produce a pass/fail verdict with inline findings for a given diff or file.

## Steps

| # | Task                  | Skill       | Depends on |
|---|-----------------------|-------------|------------|
| 0 | read target file/diff | `read_file` | —          |
| 1 | search for symbol use | `search`    | 0          |
| 2 | review the content    | `review`    | 0          |
| 3 | reflect on verdict    | `reflect`   | 2          |

## Usage

```mojo
var wf = WorkflowEngine("code review: src/main.mojo")
var r0 = wf.add_task("read src/main.mojo",        "read_file")
var r1 = wf.add_task("search for unsafe_ptr use", "search")
var r2 = wf.add_task("review code quality",       "review")
var r3 = wf.add_task("reflect on review result",  "reflect")
wf.add_dep(r1, r0)
wf.add_dep(r2, r0)
wf.add_dep(r3, r2)
var result = wf.run()
```

## Acceptance criteria

- `review` skill returns verdict containing `pass` or `fail`
- `reflect` skill confirms result is not ERROR/FAIL
