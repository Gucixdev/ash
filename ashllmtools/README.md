# ashllmtools

8-layer LLM agent framework written in Mojo. Zero external dependencies beyond the Mojo standard library — all I/O goes through thin shell wrappers.

## Architecture

```
Layer 1 — agent_state.mojo       State machine: REACT / PLAN / AUTO / PASS / EVAL
Layer 2 — skills.mojo            Named capabilities (14 built-in skills)
Layer 3 — workflow.mojo          Unified decision loop + task decomposition
Layer 4 — memory.mojo            Note / Episodic / Semantic / LongTerm memory
Layer 5 — context_engine.mojo    Priority + authority-ranked context window
Layer 6 — rag/__init__.mojo      RAG pipeline: retrieve → rank → compress → inject
Layer 7 — decision_contract.mojo Risk-rated firewall — gates every action
Layer 8 — world_model.mojo       Environment snapshot: git state, files, assumptions
```

Tool layer (`tools/`):
- `tools/sys/shell.mojo` — `shell_run`, `ShellResult`
- `tools/sys/fs.mojo`    — `read_text`, `write_text`, `file_exists`, `list_files`, ...
- `tools/sys/git.mojo`   — `git_status`, `git_diff_staged`, `git_log`, `git_is_clean`
- `tools/code/diff.mojo` — `diff_staged`, `diff_unstaged`, `diff_branch`, `diff_stat`
- `tools/code/search.mojo` — `search_symbol`, `search_pattern`, `search_files`, `codemap`
- `tools/web/fetch.mojo` — `fetch_url`, `fetch_json`

## Built-in skills

| Name | Category | Description |
|------|----------|-------------|
| `git_status` | sys | Show working tree status |
| `git_diff` | sys | Show staged changes |
| `read_file` | code | Read file content |
| `run_tests` | code | Run test suite (pixi run test) |
| `search` | code | Grep for a symbol across .mojo files |
| `analyze` | cognitive | Line/byte count + structural metrics |
| `reflect` | cognitive | Evaluate output for ERROR/FAIL patterns |
| `plan` | cognitive | Decompose goal into numbered steps |
| `reason` | cognitive | Structural analysis + reasoning type detection |
| `decide` | cognitive | Extract first option; flag destructive keywords |
| `schedule` | cognitive | Order tasks by dependency keywords |
| `bughunt` | code | Grep for panic/error/FIXME patterns |
| `review` | code | Diff stats + flag suspicious patterns |
| `refactor` | code | File metrics: lines, defs, structs, long lines |
| `stresstest` | code | Search for boundary-access and while-True patterns |

## Quick start

```mojo
from workflow import WorkflowEngine, LOOP_DONE
from skills   import SkillRegistry

# Run two tasks in sequence
var w = WorkflowEngine("check repo")
var a = w.add_task("", "git_status")
var b = w.add_task("all clean\n", "reflect")
w.add_dep(b, a)
var r = w.run(max_steps=10)
print(r.reason)   # "goal achieved: check repo"
```

```mojo
# Use SkillRegistry directly
from skills import SkillRegistry

var reg = SkillRegistry()
var r = reg.run("plan", "Step one\nStep two\nStep three")
print(r.output)
# steps:
# 1. Step one
# 2. Step two
# 3. Step three
```

```mojo
# World model snapshot
from world_model import WorldModel

var wm = WorldModel()
wm.sync()
print(wm.describe())   # WorldModel(branch=main, clean=True, syncs=1)
wm.set_assumption("env", "production")
```

## Tests

```bash
cd ashllmtools
mojo run test_llmtools.mojo
```
