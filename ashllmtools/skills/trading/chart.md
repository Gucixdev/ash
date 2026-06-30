---
name: chart
category: trading
---

# chart

Render an ASCII price chart (60 columns × 10 rows) from a comma-separated price series.

## Input

Comma-separated close prices (e.g. `100.5,101.2,99.8,...`). Minimum 2 values.

## Output

```
|                           *****                           |
|                      ****       *                         |
|               ******              **                      |
|          *****                       *****                |
|   *******                                  ***            |
+------------------------------------------------------------+
lo=99.80 hi=115.00 bars=60
```

Each column is linearly interpolated to fit 60 display positions. Row 0 = hi, row 9 = lo.

## Use cases

- Quick visual sanity-check of fetched price data.
- Embed in workflow output to annotate signals or whale events.
- Compare price shape before/after backtest window.
