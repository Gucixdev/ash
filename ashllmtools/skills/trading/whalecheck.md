---
name: whalecheck
category: trading
---

# whalecheck

Detect large-order "whale" activity in a price series using statistical outlier analysis.

## Input

Comma-separated close prices (e.g. `100.5,101.2,99.8,115.0,...`).

## Algorithm

1. Compute absolute bar-to-bar price changes.
2. Calculate mean (μ) and population standard deviation (σ) of those changes.
3. Flag any bar where `|change| > μ + 2.5σ` as a potential whale move.

## Output

```
whale_analysis: bars=N mean_move=X std_move=Y threshold=Z
whale_bars=N max_move=X at_price=Y
alert: N whale move(s) detected (>2.5σ)
```

## Use cases

- Pre-trade check: "Did a whale just move this market?"
- Anomaly detection in historical series before running a backtest.
- Combine with `signal_detect` to filter out whale-distorted signals.
