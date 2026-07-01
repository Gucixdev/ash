# Whale Strategy Workflow

Identify large-order ("whale") activity on a target instrument, visualise the
price shape around each anomalous bar, and decide whether the signal is tradeable
or likely to cause false positives.

---

## Steps

### 1. Fetch price history

```
skill: price_fetch
input: <SYMBOL>        # e.g. BTC-USD, AAPL
```

Then retrieve 30–90 days of close prices:

```
skill: exec
input: curl -s "https://query1.finance.yahoo.com/v8/finance/chart/<SYMBOL>?interval=1d&range=90d" \
       | python3 -c "import json,sys; d=json.load(sys.stdin); \
         print(','.join(str(x) for x in d['chart']['result'][0]['indicators']['quote'][0]['close'] if x))"
```

### 2. Detect whale activity

```
skill: whalecheck
input: <CSV_FROM_STEP_1>
```

Expected output fields:
- `whale_bars` — number of outlier bars
- `max_move` — largest single-bar absolute move
- `threshold` — 2.5σ cutoff used

**Decision gate**: if `whale_bars == 0`, exit — no whale activity, run standard `scan` workflow instead.

### 3. Visualise price shape

```
skill: chart
input: <CSV_FROM_STEP_1>
```

Cross-reference the ASCII chart with the whale-bar index reported in step 2.
Look for:
- Isolated spike then immediate reversion → likely stop-hunt / liquidity grab
- Sustained new level after spike → genuine accumulation / distribution

### 4. Generate trading signal on clean window

Strip whale bars from the series if they are stop-hunt artefacts, then re-run:

```
skill: signal_detect
input: <FILTERED_CSV>
```

### 5. Validate signal with backtest

```
skill: backtest
input: prices:<FILTERED_CSV> fast:5 slow:20
```

Compare PnL with and without filtering whale bars.  
Accept strategy if `pnl > 0` and `trades >= 3`.

### 6. Record DSL facts

```
skill: decide
input: Accept strategy if backtest PnL positive and trades >= 3
```

Record to world model:
```
<SYMBOL> > whale_filtered_signal
<SYMBOL> ~ threshold:<THRESHOLD_VALUE>
strategy >> accept if pnl > 0 && trades >= 3
```

---

## Acceptance criteria

| Criterion                         | Gate                              |
|-----------------------------------|-----------------------------------|
| Whale detected                    | `whale_bars >= 1`                |
| Chart shows recoverable spike     | Visual inspection — not sustained |
| Filtered signal agrees            | `signal != HOLD`                  |
| Backtest profitable               | `pnl > 0`                         |
| Sufficient trade count            | `trades >= 3`                     |

If any gate fails, escalate to manual review or reject the instrument.

---

## Required skills

- `price_fetch` — live quote fetch
- `whalecheck` — statistical outlier detection
- `chart` — ASCII visualisation
- `signal_detect` — SMA crossover + RSI signal
- `backtest` — historical PnL simulation
- `decide` — verdict gate
