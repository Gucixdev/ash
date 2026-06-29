"""
ashparser example: RFC 4180 CSV parser with quoted field support.

    "field with, comma"  →  field with, comma
    "say ""hi"""         →  say "hi"      (doubled-quote escape)

Unquoted fields: everything up to the next comma or line ending.
"""
from ashparser.input  import Input
from ashparser.prim   import take_while
from ashparser.result import ParseResult


@parameter
def _not_comma_or_nl(b: UInt8) -> Bool:
    return b != 44 and b != 10 and b != 13


def quoted_field(inp: Input) -> ParseResult[String]:
    if inp.is_empty() or inp.peek() != 34:
        var e = ParseResult[String].failure(inp, "expected '\"'")
        return e^
    var p   = inp.pos + 1
    var end = inp.len
    var ptr = inp._ptr()
    var buf = List[UInt8]()
    while p < end:
        var b = ptr[p]
        if b != 34:
            buf.append(b)
            p += 1
        elif p + 1 < end and ptr[p + 1] == 34:
            buf.append(34)
            p += 2                              # "" → single "
        else:
            p += 1
            break                               # closing quote
    buf.append(0)
    var s = String(StringSlice(ptr=buf.unsafe_ptr(), length=len(buf) - 1))
    var e = ParseResult[String].success(s, inp.at(p))
    return e^


def csv_field(inp: Input) -> ParseResult[String]:
    if not inp.is_empty() and inp.peek() == 34:
        return quoted_field(inp)^
    return take_while[_not_comma_or_nl](inp)^


def parse_record(line: String) -> List[String]:
    var cur    = Input.from_string(line)
    var fields = List[String]()
    while True:
        var r = csv_field(cur)
        if not r.ok:
            break
        fields.append(r.get())
        cur = r.rest
        if cur.is_empty() or cur.peek() != 44:
            break
        cur = cur.advance(1)
    return fields^


def main() raises:
    var rows = List[String]()
    rows.append(String("Alice,30,Warsaw"))
    rows.append(String('Bob,25,"Krakow, ul. Florianska 12"'))
    rows.append(String('Carol,28,"She said ""hello"" to us"'))
    rows.append(String('"Dave","31","Warsaw"'))
    rows.append(String("Eve,,"))

    print("name, age, address/notes")
    print(String("-") * 50)
    for i in range(len(rows)):
        var f = parse_record(rows[i])
        print(rows[i])
        for j in range(len(f)):
            print("  [" + String(j) + "] " + f[j])
