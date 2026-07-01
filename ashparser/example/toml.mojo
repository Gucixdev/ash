"""
ashparser example: parse a flat TOML-like config.

  # comment
  name = "ashcore"
  version = 1
  debug = false

Parses key = value lines; value is a quoted string, integer, or bare word.
Skips comment and blank lines.
"""
from ashparser.input  import Input
from ashparser.prim   import take_while
from ashparser.result import ParseResult
from ashparser.p      import P, PIdent, PWs, PDigits, p_byte


@parameter
def _not_newline(b: UInt8) -> Bool:
    return b != 10 and b != 13

@parameter
def _not_quote(b: UInt8) -> Bool:
    return b != 34   # not '"'


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


def parse_value(inp: Input) -> ParseResult[String]:
    # "quoted string"
    var qr = p_byte[UInt8(34)]().p_then(P[String, take_while[_not_quote]]()).p_skip(p_byte[UInt8(34)]())(inp)
    if qr.ok: return qr^
    # integer digits
    var dr = PDigits()(inp)
    if dr.ok: return dr^
    # bare word (true / false / anything up to end of line)
    return P[String, take_while[_not_newline]]()(inp)^


def main() raises:
    var src = String(
        "# ashcore config\n"
        "name = \"ashcore\"\n"
        "version = 1\n"
        "debug = false\n"
        "author = \"drbongo\"\n"
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

        # ws? '=' ws?
        var eq = PWs().p_then(p_byte[UInt8(61)]()).p_skip(PWs())(rk.rest)
        if not eq.ok:
            inp = consume_newline(skip_line(cur)); continue

        var rv = parse_value(eq.rest)
        if rv.ok:
            print("  " + rk.get() + " = " + rv.get())
            inp = consume_newline(rv.rest)
        else:
            inp = consume_newline(skip_line(cur))
