"""
ashparser example: evaluate left-to-right integer arithmetic.

  "3 + 10 * 2 - 5"  →  21
  "100 / 4 + 7"     →  32

Parses: ws? uint (ws op ws uint)* — no precedence, strictly left-to-right.
"""
from ashparser.p import PWs, PDigits, p_satisfy


@parameter
def _is_op(b: UInt8) -> Bool:
    return b == 43 or b == 45 or b == 42 or b == 47   # + - * /


def _digits_to_int(s: String) -> Int:
    var n = 0
    for i in range(s.byte_length()):
        n = n * 10 + Int(s.unsafe_ptr()[i]) - 48
    return n


def eval_expr(src: String) raises -> Int:
    # ws? digits  →  integer string
    var uint_p = PWs().p_then(PDigits())
    # ws op ws  →  operator byte
    var op_p   = PWs().p_then(p_satisfy[_is_op]()).p_skip(PWs())

    var r0 = uint_p.parse(src)
    if not r0.ok:
        raise Error("expected number: " + r0.msg)
    var acc = _digits_to_int(r0.get())
    var cur = r0.rest
    while True:
        var rop = op_p(cur)
        if not rop.ok:
            break
        var rhs = uint_p(rop.rest)
        if not rhs.ok:
            break
        var o = Int(rop.get())
        var v = _digits_to_int(rhs.get())
        cur = rhs.rest
        if o == 43:
            acc = acc + v
        elif o == 45:
            acc = acc - v
        elif o == 42:
            acc = acc * v
        elif o == 47:
            if v == 0:
                raise Error("division by zero")
            acc = acc // v
    return acc


def main() raises:
    var exprs = List[String]()
    exprs.append(String("3 + 10 * 2 - 5"))
    exprs.append(String("100 / 4 + 7"))
    exprs.append(String("1 + 2 + 3 + 4 + 5"))
    exprs.append(String("  42  "))

    for i in range(len(exprs)):
        var result = eval_expr(exprs[i])
        print(exprs[i] + "  =>  " + String(result))
