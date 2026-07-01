"""
ashparser example: RFC 4180 CSV parser (fluent API).

    "field with, comma"  →  field with, comma
    "say ""hi"""         →  say "hi"      (doubled-quote escape)

Unquoted fields: everything up to the next comma or line ending.
"""
from ashparser.input  import Input
from ashparser.result import ParseResult
from ashparser.prim   import take_while, byte
from ashparser.p      import P


@parameter
def _not_sep(b: UInt8) -> Bool:
    return b != 44 and b != 10 and b != 13   # not ',' '\n' '\r'


@parameter
def _quoted_field(inp: Input) -> ParseResult[String]:
    """RFC 4180 quoted field; "" inside becomes a single "."""
    if inp.is_empty() or inp.peek() != 34:
        return ParseResult[String].failure(inp, "expected '\"'")^
    var p   = inp.pos + 1
    var end = inp.len
    var ptr = inp._ptr()
    var buf = List[UInt8]()
    while p < end:
        var b = ptr[p]
        if b != 34:
            buf.append(b); p += 1
        elif p + 1 < end and ptr[p + 1] == 34:
            buf.append(34); p += 2   # "" → single "
        else:
            p += 1; break            # closing quote
    buf.append(0)
    var s = String(StringSlice(ptr=buf.unsafe_ptr(), length=len(buf) - 1))
    return ParseResult[String].success(s, inp.at(p))^


alias Quoted   = P[String, _quoted_field]
alias Unquoted = P[String, take_while[_not_sep]]
alias Comma    = P[UInt8,  byte[UInt8(44)]]


def parse_record(line: String) -> List[String]:
    var r = (Quoted() | Unquoted()).p_sep_by(Comma()).parse(line)
    return r.get() if r.ok else List[String]()


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
