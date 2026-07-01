"""
ashparser example: parse a flat YAML block mapping.

  name: ashparser
  version: 1
  author: drbongo

Parses "key: value" lines; value is the rest of the line (trimmed).
Skips comment and blank lines.
"""
from ashparser.input  import Input
from ashparser.prim   import take_while
from ashparser.p      import P, PIdent, PWs, p_byte


@parameter
def _not_newline(b: UInt8) -> Bool:
    return b != 10 and b != 13


def consume_newline(inp: Input) -> Input:
    if inp.is_empty():
        return inp
    var b = inp.peek()
    if b == 13:
        var n = inp.advance(1)
        if not n.is_empty() and n.peek() == 10:
            return n.advance(1)
        return n
    if b == 10:
        return inp.advance(1)
    return inp


def skip_line(inp: Input) -> Input:
    return P[String, take_while[_not_newline]]()(inp).rest


def rtrim_len(s: String) -> Int:
    var n = s.byte_length()
    while n > 0:
        var b = s.unsafe_ptr()[n - 1]
        if b == 32 or b == 9:
            n -= 1
        else:
            break
    return n


def main() raises:
    var src = String(
        "# ashparser config\n"
        "name: ashparser\n"
        "version: 1\n"
        "author: drbongo\n"
        "license: MIT\n"
        "\n"
        "# build settings\n"
        "debug: false\n"
    )
    print("input:")
    print(src)
    print("parsed key-value pairs:")

    var inp = Input.from_string(src)
    while not inp.is_empty():
        var cur = PWs()(inp).rest
        if cur.is_empty():
            break
        var b = cur.peek()
        if b == 10 or b == 13:
            inp = consume_newline(cur); continue
        if b == 35:   # '#'
            inp = consume_newline(skip_line(cur)); continue

        var rk = PIdent()(cur)
        if not rk.ok:
            inp = consume_newline(skip_line(cur)); continue

        # ws? ':' ws?
        var col = PWs().p_then(p_byte[UInt8(58)]()).p_skip(PWs())(rk.rest)
        if not col.ok:
            inp = consume_newline(skip_line(cur)); continue

        var rval = P[String, take_while[_not_newline]]()(col.rest)
        var raw = rval.get()

        var vlen = rtrim_len(raw)
        var vptr = UnsafePointer[UInt8, ImmutAnyOrigin](
            unsafe_from_address=Int(raw.unsafe_ptr())
        )
        var value = String(StringSlice(ptr=vptr, length=vlen))

        print("  " + rk.get() + ": " + value)
        inp = consume_newline(rval.rest)
