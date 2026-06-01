list_of_trades = [
    {"date": "2026-05-01", "symbol": "TSLA", "side": "LONG", "entry": 180.0, "exit": 185.0},
    {"date": "2026-05-02", "symbol": "NVDA", "side": "SHORT", "entry": 420.0, "exit": 415.0},
    {"date": "2026-05-03", "symbol": "AMD", "side": "LONG", "entry": 150.0, "exit": 148.0},
    {"date": "2026-05-04", "symbol": "TSLA", "side": "LONG", "entry": 182.0, "exit": None},
]

'''
Do this:

Loop through trades
If exit is None → print Skipping incomplete record: TSLA 2026-05-04 and skip it
Calculate PnL → LONG = exit - entry, SHORT = entry - exit
Print each trade like:

[2026-05-01] TSLA | LONG | PnL: +5.0

At the end print:
Total trades processed: 3
Total PnL: +8.0

Rules:

No pandas
f-strings only
Use is None not == None

'''
def print_trades(trades):
    total = 0
    total_pnl = 0
    for trade in trades:
        pnl = 0
        if trade["exit"] is None:
            print (f'Skipping incomplete record: {trade["symbol"] + " " + trade["date"]}')
            continue
        if trade["side"] == "LONG":
            pnl += trade["exit"] - trade["entry"]

        elif trade["side"] == "SHORT":
            pnl += trade["entry"] - trade["exit"]

        total_pnl += pnl


        print(f'[{trade["date"]}] {trade["symbol"]} | {trade["side"]} | PnL: {pnl}')
        total += 1

    print(f'Total trades processed:{total}')
    print (f'Total PnL:{total_pnl}')




if __name__ == '__main__':
    trades = list_of_trades
    print_trades(trades)
