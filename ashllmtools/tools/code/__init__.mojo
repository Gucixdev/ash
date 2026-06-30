from tools.code.search import (
    search_symbol, search_pattern, search_files, codemap,
)
from tools.code.diff   import (
    diff_staged, diff_unstaged, diff_files, diff_branch, diff_stat,
)
from tools.sys.shell import shell_run
from tools.sys.git   import git_diff_staged
from tools.sys.fs    import read_text, file_exists
from decision_contract import _contains
from skill_types import SkillResult

# ── Skill implementations ─────────────────────────────────────────────────────
# To add a new code skill:
#   1. Create skills/code/<name>.md with name/category frontmatter
#   2. Write _skill_<name>() below
#   3. Add one line in dispatch()

def _skill_bughunt(inp: String) -> SkillResult:
    var path = inp if inp != "" else String(".")
    var r1 = shell_run(
        "grep -rn --include='*.mojo' -E 'panic|ERROR|unreachable' "
        + path + " 2>/dev/null | head -30"
    )
    var r2 = shell_run(
        "grep -rn --include='*.mojo' -E 'TODO|FIXME|HACK|XXX' "
        + path + " 2>/dev/null | head -20"
    )
    var hits = r1.stdout if r1.ok else String("")
    var todos = r2.stdout if r2.ok else String("")
    if hits == "" and todos == "":
        return SkillResult.success("bughunt: no patterns found in " + path)
    var out = String("")
    if hits != "": out += "=== error/panic patterns ===\n" + hits
    if todos != "": out += "=== TODO/FIXME ===\n" + todos
    return SkillResult.success(out)

def _skill_review(inp: String) -> SkillResult:
    var diff = git_diff_staged()
    if diff == "": diff = shell_run("git diff HEAD 2>/dev/null").stdout
    if diff == "": return SkillResult.success("review: no changes to review")
    var n = diff.byte_length(); var ptr = diff.unsafe_ptr()
    var added = 0; var removed = 0; var i = 0
    while i < n:
        if ptr[i] == 43 and (i == 0 or ptr[i-1] == 10):
            if not (i+2 < n and ptr[i+1] == 43 and ptr[i+2] == 43): added += 1
        elif ptr[i] == 45 and (i == 0 or ptr[i-1] == 10):
            if not (i+2 < n and ptr[i+1] == 45 and ptr[i+2] == 45): removed += 1
        i += 1
    var warnings = String("")
    if _contains(diff, "unsafe_ptr"):    warnings += " unsafe_ptr"
    if _contains(diff, "external_call"): warnings += " external_call"
    if _contains(diff, "TODO"):          warnings += " TODO"
    var verdict = "ok" if removed + added < 500 else "large_diff"
    var out = "added=" + String(added) + " removed=" + String(removed) + " verdict=" + verdict
    if warnings != "": out += "\nflags:" + warnings
    return SkillResult.success(out)

def _skill_refactor(inp: String) -> SkillResult:
    if inp == "": return SkillResult.failure("refactor: no file path provided")
    if not file_exists(inp): return SkillResult.failure("refactor: file not found: " + inp)
    var content = read_text(inp)
    var n = content.byte_length(); var ptr = content.unsafe_ptr()
    var lines = 0; var long_lines = 0; var line_len = 0
    for i in range(n):
        if ptr[i] == 10:
            lines += 1
            if line_len > 100: long_lines += 1
            line_len = 0
        else:
            line_len += 1
    var r_def    = shell_run("grep -c '^def \\|^    def ' " + inp + " 2>/dev/null")
    var r_struct = shell_run("grep -c '^struct ' " + inp + " 2>/dev/null")
    var out = ("file=" + inp + " lines=" + String(lines) + " bytes=" + String(n)
               + " defs="    + (r_def.stdout    if r_def.ok    else String("?"))
               + " structs=" + (r_struct.stdout if r_struct.ok else String("?")))
    if long_lines > 5: out += "\nhint: " + String(long_lines) + " lines exceed 100 chars"
    return SkillResult.success(out)

def _skill_stresstest(inp: String) -> SkillResult:
    var path = inp if inp != "" else String(".")
    var r1 = shell_run(
        "grep -rn --include='*.mojo' -E "
        + "'\\[0\\]|\\[-1\\]|unsafe_ptr\\(\\)\\[|range\\(0\\)' "
        + path + " 2>/dev/null | head -30"
    )
    var r2 = shell_run("grep -rn --include='*.mojo' 'while True' "
        + path + " 2>/dev/null | head -20")
    var hits = r1.stdout if r1.ok else String("")
    var loops = r2.stdout if r2.ok else String("")
    if hits == "" and loops == "":
        return SkillResult.success("stresstest: no edge-case gaps found in " + path)
    var out = String("")
    if hits != "": out += "=== boundary accesses ===\n" + hits
    if loops != "": out += "=== while True loops ===\n" + loops
    return SkillResult.success(out)

def _skill_exec(inp: String) -> SkillResult:
    if inp == "": return SkillResult.failure("exec: no command provided")
    var r = shell_run(inp + " 2>&1")
    return SkillResult(r.ok, r.stdout, "" if r.ok else "exec failed")

def dispatch(name: String, inp: String) -> SkillResult:
    if name == "bughunt":    return _skill_bughunt(inp)
    if name == "review":     return _skill_review(inp)
    if name == "refactor":   return _skill_refactor(inp)
    if name == "stresstest": return _skill_stresstest(inp)
    if name == "exec":       return _skill_exec(inp)
    return SkillResult.failure("unknown code skill: " + name)
