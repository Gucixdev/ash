"""
ashparser example: parse a self-closing XML element with attributes.

  <node id="1" name="root" active="true"/>

Prints: tag name + each attribute key-value pair.
No nesting, no text content, no CDATA.
"""
from ashparser.input  import Input
from ashparser.prim   import take_while
from ashparser.p      import P, PIdent, PWs, p_byte


@parameter
def _not_quote(b: UInt8) -> Bool:
    return b != 34   # not '"'


alias AttrVal = P[String, take_while[_not_quote]]


def main() raises:
    var srcs = List[String]()
    srcs.append(String("""<node id="1" name="root" active="true"/>"""))
    srcs.append(String("""<link href="https://example.com" rel="noopener"/>"""))
    srcs.append(String("""<br/>"""))

    for si in range(len(srcs)):
        var src = srcs[si]
        print("input: " + src)
        var inp = Input.from_string(src)

        var open = p_byte[UInt8(60)]()(inp)   # '<'
        if not open.ok:
            print("  error: expected '<'"); continue

        var rname = PIdent()(open.rest)
        if not rname.ok:
            print("  error: expected tag name"); continue

        print("  tag: " + rname.get())

        # ="content"  →  attribute value string
        var attr_p = p_byte[UInt8(61)]().p_then(p_byte[UInt8(34)]()).p_then(AttrVal()).p_skip(p_byte[UInt8(34)]())

        var cur = rname.rest
        while True:
            var c = PWs()(cur).rest
            if c.is_empty():
                break
            var b = c.peek()
            if b == 47 or b == 62:   # '/' or '>'
                break

            var rk = PIdent()(c)
            if not rk.ok:
                break

            var rv = attr_p(rk.rest)
            if not rv.ok:
                break

            print("  attr: " + rk.get() + " = \"" + rv.get() + "\"")
            cur = rv.rest

        var c2 = PWs()(cur).rest
        var slash = p_byte[UInt8(47)]()(c2)
        var end_r = slash.rest if slash.ok else c2
        var gt = p_byte[UInt8(62)]()(end_r)
        if gt.ok:
            print("  (well-formed)")
        print()
