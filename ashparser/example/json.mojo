"""
ashparser example: full JSON parser.

Parses the complete JSON grammar (RFC 8259):
  value  = null | true | false | number | string | array | object
  array  = "[" (value ("," value)*)? "]"
  object = "{" (string ":" value ("," string ":" value)*)? "}"
  number = [-] int ["." frac] [("e"|"E") [sign] digits]
  string = double-quoted with \\ \" \\n \\t \\r escapes

Output type is String (pretty-printed JSON), sidestepping recursive
value types — the parser drives all the interesting combinator logic.

Demo input — a realistic API response:
    {
      "id": 42,
      "name": "ashparser",
      "stable": true,
      "score": -3.14,
      "tags": ["mojo", "parsing", "zero-copy"],
      "meta": {"author": "drbongo", "year": 2025}
    }
"""
from ashparser.input  import Input, SourceMap
from ashparser.prim   import tag, byte, ws, digits, quoted_string, satisfy
from ashparser.result import ParseResult


# ── byte predicates ───────────────────────────────────────────────────────────

@parameter
def _is_digit(b: UInt8) -> Bool:
    return b >= 48 and b <= 57

@parameter
def _is_digit19(b: UInt8) -> Bool:
    return b >= 49 and b <= 57  # 1-9 (non-zero leading digit)


# ── skip optional whitespace ──────────────────────────────────────────────────

def skip_ws(inp: Input) -> Input:
    var pos = inp.pos
    var end = inp.len
    var ptr = inp._ptr()
    while pos < end:
        var b = ptr[pos]
        if b != 32 and b != 9 and b != 10 and b != 13:
            break
        pos += 1
    return inp.at(pos)


# ── json_number ───────────────────────────────────────────────────────────────
# Returns the raw number string (int or float).

def json_number(inp: Input) -> ParseResult[String]:
    var pos = inp.pos
    var end = inp.len
    var ptr = inp._ptr()

    # optional minus
    if pos < end and ptr[pos] == 45:  # '-'
        pos += 1

    # integer part
    if pos >= end:
        var out = ParseResult[String].failure(inp, "json_number: expected digit")
        return out^
    if ptr[pos] == 48:  # '0' — only lone zero allowed
        pos += 1
    elif _is_digit19(ptr[pos]):
        while pos < end and _is_digit(ptr[pos]):
            pos += 1
    else:
        var out = ParseResult[String].failure(inp, "json_number: invalid")
        return out^

    # optional fractional
    if pos < end and ptr[pos] == 46:  # '.'
        pos += 1
        if pos >= end or not _is_digit(ptr[pos]):
            var out = ParseResult[String].failure(inp, "json_number: expected frac digit")
            return out^
        while pos < end and _is_digit(ptr[pos]):
            pos += 1

    # optional exponent
    if pos < end and (ptr[pos] == 101 or ptr[pos] == 69):  # 'e' or 'E'
        pos += 1
        if pos < end and (ptr[pos] == 43 or ptr[pos] == 45):  # '+' or '-'
            pos += 1
        if pos >= end or not _is_digit(ptr[pos]):
            var out = ParseResult[String].failure(inp, "json_number: expected exp digit")
            return out^
        while pos < end and _is_digit(ptr[pos]):
            pos += 1

    var out = ParseResult[String].success(inp.slice_str(inp.pos, pos), inp.at(pos))
    return out^


# ── forward declarations (recursive descent) ──────────────────────────────────
# json_value, json_array, json_object call each other — regular def, not @parameter.

def json_value(inp: Input) -> ParseResult[String]:
    var cur = skip_ws(inp)
    if cur.is_empty():
        var out = ParseResult[String].failure(inp, "json_value: unexpected EOF")
        return out^

    var b = cur.peek()

    # null
    if b == 110:  # 'n'
        var r = tag["null"](cur)
        if r.ok:
            var out = ParseResult[String].success(String("null"), r.rest)
            return out^

    # true
    if b == 116:  # 't'
        var r = tag["true"](cur)
        if r.ok:
            var out = ParseResult[String].success(String("true"), r.rest)
            return out^

    # false
    if b == 102:  # 'f'
        var r = tag["false"](cur)
        if r.ok:
            var out = ParseResult[String].success(String("false"), r.rest)
            return out^

    # string
    if b == 34:  # '"'
        var r = quoted_string(cur)
        if r.ok:
            var out = ParseResult[String].success('"' + r.get() + '"', r.rest)
            return out^

    # array
    if b == 91:  # '['
        return json_array(cur)

    # object
    if b == 123:  # '{'
        return json_object(cur)

    # number (leading digit or minus)
    if b == 45 or (b >= 48 and b <= 57):
        return json_number(cur)

    var out = ParseResult[String].failure(inp, "json_value: unexpected byte " + String(Int(b)))
    return out^


def json_array(inp: Input) -> ParseResult[String]:
    """Parse "[" ws (value (ws "," ws value)*)? ws "]"."""
    if inp.is_empty() or inp.peek() != 91:  # '['
        var out = ParseResult[String].failure(inp, "json_array: expected '['")
        return out^

    var cur = skip_ws(inp.advance(1))
    var result = String("[")

    if not cur.is_empty() and cur.peek() == 93:  # immediate ']'
        var out = ParseResult[String].success(result + "]", cur.advance(1))
        return out^

    # first element
    var r0 = json_value(cur)
    if not r0.ok:
        var out = ParseResult[String].failure(inp, r0.msg)
        return out^
    result += r0.get()
    cur = skip_ws(r0.rest)

    # subsequent elements
    while not cur.is_empty() and cur.peek() == 44:  # ','
        cur = skip_ws(cur.advance(1))
        var rn = json_value(cur)
        if not rn.ok:
            var out = ParseResult[String].failure(inp, rn.msg)
            return out^
        result += ", " + rn.get()
        cur = skip_ws(rn.rest)

    if cur.is_empty() or cur.peek() != 93:  # ']'
        var out = ParseResult[String].failure(inp, "json_array: expected ']'")
        return out^

    var out = ParseResult[String].success(result + "]", cur.advance(1))
    return out^


def json_object(inp: Input) -> ParseResult[String]:
    """Parse "{" ws (string ws ":" ws value (ws "," ws string ws ":" ws value)*)? ws "}"."""
    if inp.is_empty() or inp.peek() != 123:  # '{'
        var out = ParseResult[String].failure(inp, "json_object: expected '{'")
        return out^

    var cur = skip_ws(inp.advance(1))
    var result = String("{")

    if not cur.is_empty() and cur.peek() == 125:  # immediate '}'
        var out = ParseResult[String].success(result + "}", cur.advance(1))
        return out^

    # first key-value pair
    var rk0 = quoted_string(cur)
    if not rk0.ok:
        var out = ParseResult[String].failure(inp, "json_object: expected key string")
        return out^
    cur = skip_ws(rk0.rest)
    if cur.is_empty() or cur.peek() != 58:  # ':'
        var out = ParseResult[String].failure(inp, "json_object: expected ':'")
        return out^
    cur = skip_ws(cur.advance(1))
    var rv0 = json_value(cur)
    if not rv0.ok:
        var out = ParseResult[String].failure(inp, rv0.msg)
        return out^
    result += '"' + rk0.get() + '": ' + rv0.get()
    cur = skip_ws(rv0.rest)

    # subsequent pairs
    while not cur.is_empty() and cur.peek() == 44:  # ','
        cur = skip_ws(cur.advance(1))
        var rkn = quoted_string(cur)
        if not rkn.ok:
            var out = ParseResult[String].failure(inp, "json_object: expected key")
            return out^
        cur = skip_ws(rkn.rest)
        if cur.is_empty() or cur.peek() != 58:
            var out = ParseResult[String].failure(inp, "json_object: expected ':'")
            return out^
        cur = skip_ws(cur.advance(1))
        var rvn = json_value(cur)
        if not rvn.ok:
            var out = ParseResult[String].failure(inp, rvn.msg)
            return out^
        result += ", " + '"' + rkn.get() + '": ' + rvn.get()
        cur = skip_ws(rvn.rest)

    if cur.is_empty() or cur.peek() != 125:  # '}'
        var out = ParseResult[String].failure(inp, "json_object: expected '}'")
        return out^

    var out = ParseResult[String].success(result + "}", cur.advance(1))
    return out^


# ── main ──────────────────────────────────────────────────────────────────────

def main() raises:
    # ── Test 1: realistic API response ───────────────────────────────────────
    var src1 = String(
        '{"id": 42, "name": "ashparser", "stable": true, '
        '"score": -3.14, "tags": ["mojo", "parsing", "zero-copy"], '
        '"meta": {"author": "drbongo", "year": 2025}}'
    )
    print("── Test 1: API response ─────────────────────────────────────────")
    print("input : " + src1)
    var inp1 = Input.from_string(src1)
    var r1   = json_value(inp1)
    if r1.ok:
        print("parsed: " + r1.get())
        print("rest  : " + String(r1.rest.remaining()) + " bytes remaining")
    else:
        var sm = SourceMap(inp1)
        print("ERROR : " + r1.message_ctx_fast(sm))

    # ── Test 2: nested arrays ─────────────────────────────────────────────────
    print("\n── Test 2: nested arrays ────────────────────────────────────────")
    var src2 = String('[[1, 2, 3], [true, null, false], ["a", "b"]]')
    print("input : " + src2)
    var inp2 = Input.from_string(src2)
    var r2   = json_value(inp2)
    if r2.ok:
        print("parsed: " + r2.get())
    else:
        print("ERROR : " + r2.msg)

    # ── Test 3: numbers — int, negative, float, scientific ────────────────────
    print("\n── Test 3: numbers ──────────────────────────────────────────────")
    var nums = List[String]()
    nums.append(String("0"))
    nums.append(String("-99"))
    nums.append(String("3.14"))
    nums.append(String("-2.718e+10"))
    nums.append(String("1E100"))
    for i in range(len(nums)):
        var r = json_number(Input.from_string(nums[i]))
        print("  " + nums[i] + "  →  " + (r.get() if r.ok else "FAIL: " + r.msg))

    # ── Test 4: error reporting with SourceMap ────────────────────────────────
    print("\n── Test 4: error with line:col ──────────────────────────────────")
    var src4 = String('{\n  "key": INVALID\n}')
    print("input : " + src4)
    var inp4 = Input.from_string(src4)
    var r4   = json_value(inp4)
    if not r4.ok:
        var sm4 = SourceMap(inp4)
        print("ERROR : " + r4.message_ctx_fast(sm4))

    # ── Test 5: empty object and array ────────────────────────────────────────
    print("\n── Test 5: empty containers ─────────────────────────────────────")
    var empties = List[String]()
    empties.append(String("{}"))
    empties.append(String("[]"))
    empties.append(String('{"x": []}'))
    for i in range(len(empties)):
        var r = json_value(Input.from_string(empties[i]))
        print("  " + empties[i] + "  →  " + (r.get() if r.ok else "FAIL: " + r.msg))
