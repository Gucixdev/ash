from tools.sys.shell import ShellResult, shell_run, shell_ok
from tools.sys.fs    import (
    file_exists, read_text, write_text, list_dir,
    show_tree, file_info, system_info, scan_log,
)
from tools.sys.git   import (
    git_branch_current,
    git_status,
    git_diff_staged,
    git_log,
    git_is_clean,
)
from skill_types import SkillResult

# ── Skill implementations ─────────────────────────────────────────────────────
# To add a new sys skill:
#   1. Create skills/sys/<name>.md with name/category frontmatter
#   2. Write _skill_<name>() below
#   3. Add one line in dispatch()

def _skill_git_status(inp: String) -> SkillResult:
    var s = git_status()
    return SkillResult.success("working tree clean" if s == "" else s)

def _skill_git_diff(inp: String) -> SkillResult:
    var d = git_diff_staged()
    return SkillResult.success("no staged changes" if d == "" else d)

def _skill_read_file(inp: String) -> SkillResult:
    if not file_exists(inp):
        return SkillResult.failure("file not found: " + inp)
    return SkillResult.success(read_text(inp))

def _skill_run_tests(inp: String) -> SkillResult:
    var dir = inp if inp != "" else String(".")
    var r = shell_run("cd " + dir + " && pixi run test 2>&1")
    if not r.ok:
        return SkillResult.failure("test runner failed to start")
    return SkillResult(True, r.stdout, "")

def _skill_search(inp: String) -> SkillResult:
    var r = shell_run("grep -rn --include='*.mojo' '\\b" + inp + "\\b' . 2>/dev/null")
    if not r.ok or r.stdout == "":
        return SkillResult.failure("symbol not found: " + inp)
    return SkillResult.success(r.stdout)

def dispatch(name: String, inp: String) -> SkillResult:
    if name == "git_status": return _skill_git_status(inp)
    if name == "git_diff":   return _skill_git_diff(inp)
    if name == "read_file":  return _skill_read_file(inp)
    if name == "run_tests":  return _skill_run_tests(inp)
    if name == "search":     return _skill_search(inp)
    return SkillResult.failure("unknown sys skill: " + name)
