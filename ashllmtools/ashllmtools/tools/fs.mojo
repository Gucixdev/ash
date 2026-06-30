"""ashllmtools.tools.fs — lazytools: filesystem read/write/exist/list/tree/info."""

from pathlib import Path
from std.memory import UnsafePointer
from ashllmtools.tools.shell import shell_run


def file_exists(path: String) -> Bool:
    """True iff the path exists on disk."""
    return Path(path).exists()


def read_text(path: String) -> String:
    """Read entire file as a String. Returns "" on error."""
    try:
        return Path(path).read_text()
    except:
        return String("")


def write_text(path: String, content: String) raises:
    """Write content to path (creates or overwrites)."""
    Path(path).write_text(content)


def list_dir(path: String) -> List[String]:
    """List immediate children of a directory. Empty list on error."""
    var r = shell_run("ls -1 " + path + " 2>/dev/null")
    var result = List[String]()
    if not r.ok or r.stdout == "":
        return result
    var s = r.stdout
    var ptr = s.unsafe_ptr()
    var start = 0
    for i in range(s.byte_length()):
        if ptr[i] == UInt8(10):  # '\n'
            if i > start:
                result.append(String(StringSlice(ptr=ptr + start, length=i - start)))
            start = i + 1
    if start < s.byte_length():
        result.append(String(StringSlice(ptr=ptr + start, length=s.byte_length() - start)))
    return result


def show_tree(path: String, max_depth: Int = 3) -> String:
    """
    Return a directory tree rooted at path.
    Uses `tree` if available, falls back to `find` for a plain listing.
    max_depth controls how many levels deep to recurse.
    """
    # Try tree(1) first — prettier output
    var tree_r = shell_run(
        "tree -L " + String(max_depth) + " --noreport " + path + " 2>/dev/null"
    )
    if tree_r.ok and tree_r.stdout != "":
        return tree_r.stdout

    # Fallback: find with depth limit + indent
    var find_r = shell_run(
        "find " + path
        + " -maxdepth " + String(max_depth)
        + " 2>/dev/null | sort"
    )
    if not find_r.ok or find_r.stdout == "":
        return path + " (empty or not found)"
    return find_r.stdout


def file_info(path: String) -> String:
    """
    Return metadata for a file or directory:
      type, size, permissions, modification time, line count (files only).
    Uses stat(1) + wc -l.
    """
    # stat output
    var stat_r = shell_run(
        "stat --printf='type=%F\nsize=%s bytes\nperm=%A\nmtime=%y\n' "
        + path + " 2>/dev/null"
    )
    if not stat_r.ok or stat_r.stdout == "":
        return "file_info: not found: " + path

    var out = stat_r.stdout

    # Add line count for regular files
    var wc_r = shell_run("wc -l < " + path + " 2>/dev/null")
    if wc_r.ok and wc_r.stdout != "":
        var lc = _trim(wc_r.stdout)
        if lc != "":
            out = out + "lines=" + lc + "\n"

    # Add human-readable size via du -sh
    var du_r = shell_run("du -sh " + path + " 2>/dev/null")
    if du_r.ok and du_r.stdout != "":
        var parts = _split_tab(du_r.stdout)
        if len(parts) >= 1:
            out = out + "disk_usage=" + parts[0] + "\n"

    return out


def system_info() -> String:
    """
    Return a compact system snapshot:
      OS, kernel, hostname, CPU count, RAM, disk usage, load average.
    """
    var out = String("")

    # OS / kernel
    var uname = shell_run("uname -srm 2>/dev/null")
    if uname.ok:
        out = out + "kernel=" + _trim(uname.stdout) + "\n"

    # Hostname
    var host = shell_run("hostname 2>/dev/null")
    if host.ok:
        out = out + "hostname=" + _trim(host.stdout) + "\n"

    # CPU
    var cpu = shell_run(
        "grep -c '^processor' /proc/cpuinfo 2>/dev/null"
    )
    if cpu.ok and cpu.stdout != "":
        out = out + "cpu_cores=" + _trim(cpu.stdout) + "\n"

    var cpu_model = shell_run(
        "grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2"
    )
    if cpu_model.ok and cpu_model.stdout != "":
        out = out + "cpu_model=" + _trim(cpu_model.stdout) + "\n"

    # RAM
    var mem = shell_run("free -h 2>/dev/null | awk '/^Mem:/ {print $2\" total, \"$3\" used, \"$7\" available\"}'")
    if mem.ok and mem.stdout != "":
        out = out + "ram=" + _trim(mem.stdout) + "\n"

    # Disk
    var disk = shell_run("df -h . 2>/dev/null | awk 'NR==2 {print $2\" total, \"$3\" used, \"$4\" free, \"$5\" use%\"}'")
    if disk.ok and disk.stdout != "":
        out = out + "disk=" + _trim(disk.stdout) + "\n"

    # Load average
    var load = shell_run("cat /proc/loadavg 2>/dev/null | cut -d' ' -f1-3")
    if load.ok and load.stdout != "":
        out = out + "load_avg=" + _trim(load.stdout) + "\n"

    # Uptime
    var up = shell_run("uptime -p 2>/dev/null")
    if up.ok and up.stdout != "":
        out = out + "uptime=" + _trim(up.stdout) + "\n"

    return out if out != "" else String("system_info: unavailable")


# ── private helpers ───────────────────────────────────────────────────────────

def _trim(s: String) -> String:
    """Strip leading/trailing whitespace and newlines."""
    var ptr = s.unsafe_ptr()
    var bl  = s.byte_length()
    var lo  = 0
    var hi  = bl
    while lo < hi and (ptr[lo] == UInt8(32) or ptr[lo] == UInt8(9)
                       or ptr[lo] == UInt8(10) or ptr[lo] == UInt8(13)):
        lo += 1
    while hi > lo and (ptr[hi - 1] == UInt8(32) or ptr[hi - 1] == UInt8(9)
                       or ptr[hi - 1] == UInt8(10) or ptr[hi - 1] == UInt8(13)):
        hi -= 1
    if lo >= hi:
        return String("")
    return String(StringSlice(ptr=ptr + lo, length=hi - lo))


def _split_tab(s: String) -> List[String]:
    """Split on tab character."""
    var result = List[String]()
    var ptr    = s.unsafe_ptr()
    var bl     = s.byte_length()
    var start  = 0
    for i in range(bl):
        if ptr[i] == UInt8(9):  # '\t'
            if i > start:
                result.append(String(StringSlice(ptr=ptr + start, length=i - start)))
            start = i + 1
    if start < bl:
        result.append(String(StringSlice(ptr=ptr + start, length=bl - start)))
    return result
