raw_trades = [
    {"date": "2026-05-01", "symbol": "  tsla  ", "side": "long",  "entry": "180.0", "exit": "185.0"},
    {"date": "2026-05-02", "symbol": "NVDA",     "side": "SHORT", "entry": "420.0", "exit": None},
    {"date": "2026-05-03", "symbol": "amd ",     "side": "LONG",  "entry": "abc",   "exit": "148.0"},
    {"date": "2026-05-04", "symbol": "SPY",      "side": "long",  "entry": "520.0", "exit": "525.0"},
]

'''
Write a clean_trades(trades) function that:

Strips whitespace from symbol and uppercases it → "  tsla  " becomes "TSLA"
Uppercases side → "long" becomes "LONG"
Converts entry and exit to float — if it fails, skip and print "Invalid numeric data: AMD — skipping"
Skips trades where exit is None — print "Missing exit: NVDA — skipping"
Returns a clean list of valid trades only

Expected output:
Missing exit: NVDA — skipping
Invalid numeric data: AMD — skipping
Cleaned: 2 valid trades
'''

def clean_trades(trades):
    trades_cleaned = []
    cleaned = 0
    for trade in trades:

        if trade ['exit'] is None:
            print(f'Missing exit: {trade["symbol"]} - skipping')
            continue
        trade ['symbol'] = trade['symbol'].strip().upper()
        trade['side'] = trade['side'].strip().upper()

        try:
          trade['entry'] = float(trade['entry'])
          trade['exit'] = float(trade['exit'])
        except ValueError:
            print(f'Invalid numeric data: {trade["symbol"]} - skipping')
            continue

        cleaned += 1

        trades_cleaned.append(trade)
    print(f'Cleaned {cleaned} trades')
    return trades_cleaned