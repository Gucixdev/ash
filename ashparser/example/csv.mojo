"""
ashparser example: RFC 4180 CSV parser with quoted field support.

A "real-world" CSV field may contain the separator itself if wrapped in
double-quotes.  Double-quotes inside a quoted field are escaped by doubling:
    "say ""hello"""   →   say "hello"

Grammar (RFC 4180 simplified):
    record = field ("," field)*
    field  = quoted | unquoted
    quoted = '"' (non-quote | '""')* '"'
    unquoted = (non-comma, non-newline)*

Demo: employee records with commas in address fields.
"""
from ashparser.input  import Input
from ashparser.prim   import take_while, byte
from ashparser.comb   import sep_by
from ashparser.result import ParseResult


# ── predicates ────────────────────────────────────────────────────────────────

@parameter
def _not_comma_or_nl(b: UInt8) -> Bool:
    return b != 44 and b != 10 and b != 13   # not ',' '\n' '\r'

@parameter
def _not_dquote(b: UInt8) -> Bool:
    return b != 34   # not '"'


# ── field parsers ─────────────────────────────────────────────────────────────

def quoted_field(inp: Input) -> ParseResult[String]:
    """Parse a double-quoted CSV field; "" inside is an escaped quote."""
    if inp.is_empty() or inp.peek() != 34:   # '"'
        var out = ParseResult[String].failure(inp, "expected '\"'")
        return out^

    var pos = inp.pos + 1   # skip opening quote
    var end = inp.len
    var ptr = inp._ptr()
    var buf = List[UInt8]()

    while pos < end:
        var b = ptr[pos]
        if b == 34:   # '"'
            if pos + 1 < end and ptr[pos + 1] == 34:
                # escaped double-quote: "" → "
                buf.append(34)
                pos += 2
            else:
                # closing quote
                pos += 1
                break
        else:
            buf.append(b)
            pos += 1

    buf.append(0)
    var s = String(StringSlice(ptr=buf.unsafe_ptr(), length=len(buf) - 1))
    var out = ParseResult[String].success(s, inp.at(pos))
    return out^


@parameter
def unquoted_field(inp: Input) -> ParseResult[String]:
    """Unquoted field: everything up to the next comma or line ending."""
    var r = take_while[_not_comma_or_nl](inp)
    return r^


def csv_field(inp: Input) -> ParseResult[String]:
    """Parse either a quoted or unquoted CSV field."""
    if not inp.is_empty() and inp.peek() == 34:
        return quoted_field(inp)
    return unquoted_field(inp)


@parameter
def comma(inp: Input) -> ParseResult[UInt8]:
    var r = byte[UInt8(44)](inp)
    return r^


# ── record parser ─────────────────────────────────────────────────────────────

def parse_record(line: String) -> List[String]:
    """Parse one CSV line into fields.  Returns an empty list on error."""
    var inp = Input.from_string(line)
    var fields = List[String]()
    if inp.is_empty():
        return fields^

    # First field
    var r0 = csv_field(inp)
    if not r0.ok:
        return fields^
    fields.append(r0.get())
    var cur = r0.rest

    # Remaining fields
    while not cur.is_empty() and cur.peek() == 44:   # ','
        cur = cur.advance(1)
        var rn = csv_field(cur)
        if not rn.ok:
            break
        fields.append(rn.get())
        cur = rn.rest

    return fields^


# ── main ──────────────────────────────────────────────────────────────────────

def main() raises:
    print("── CSV with quoted field support ────────────────────────────────")

    var rows = List[String]()
    # Basic
    rows.append(String("Alice,30,Warsaw"))
    # Quoted field containing comma (address with city)
    rows.append(String('Bob,25,"Krakow, ul. Florianska 12"'))
    # Escaped double-quote inside quoted field
    rows.append(String('Carol,28,"She said ""hello"" to us"'))
    # All fields quoted
    rows.append(String('"Dave","31","Warsaw"'))
    # Empty fields
    rows.append(String("Eve,,"))
    # Mixed: unquoted then quoted
    rows.append(String('Frank,27,"New York, NY 10001"'))

    print("{'name', 'age', 'address/notes'}")
    print(String("-") * 60)

    for i in range(len(rows)):
        var row  = rows[i]
        var flds = parse_record(row)
        print(String("[") + String(i + 1) + "]  raw: " + row)
        for j in range(len(flds)):
            print("      [" + String(j) + "] " + repr(flds[j]))
        print("")
