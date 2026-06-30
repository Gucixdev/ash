"""
ashparser example: streaming CSV — parse a file of any size with O(1 MB) RAM.

Uses StreamingInput.next_line() to feed one line at a time to the existing
csv_field combinator. The file is never fully loaded into memory.

Generate a test file and run:
    python3 -c "
    import random
    print('name,score,city')
    for i in range(1_000_000):
        print(f'user_{i},{random.randint(0,9999)},city_{i % 50}')
    " > /tmp/big.csv

    magic run mojo run -I . example/stream_csv.mojo /tmp/big.csv
"""
from sys import argv
from ashparser.input   import Input
from ashparser.result  import ParseResult
from ashparser.prim    import take_while
from ashparser.fileio  import StreamingInput


@parameter
def _not_delim(b: UInt8) -> Bool:
    return b != 44 and b != 10 and b != 13   # not ',', '\n', '\r'


def csv_field(inp: Input) -> ParseResult[String]:
    return take_while[_not_delim](inp)^


def count_fields(line: Input) -> Int:
    """Count comma-separated fields in one line Input."""
    var cur = line
    var n   = 0
    while True:
        var r = csv_field(cur)
        if not r.ok:
            break
        n  += 1
        cur = r.rest
        if cur.is_empty() or cur.peek() != 44:
            break
        cur = cur.advance(1)   # skip ','
    return n


def main() raises:
    var args     = argv()
    var path     = args[1] if len(args) > 1 else "/tmp/big.csv"
    var reader   = StreamingInput.from_file(path)

    var rows     = 0
    var fields   = 0
    var skipped  = True   # skip header

    while reader.has_more():
        var line = reader.next_line()
        if line.remaining() == 0:
            continue
        if skipped:
            skipped = False
            continue   # skip header row
        rows   += 1
        fields += count_fields(line)

    print("File:   " + path)
    print("Rows:   " + String(rows))
    print("Fields: " + String(fields))
    print("Avg fields/row: " + String(fields // rows if rows > 0 else 0))
