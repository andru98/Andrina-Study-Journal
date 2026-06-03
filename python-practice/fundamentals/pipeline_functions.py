

class TradePipeline:
     def __init__(self, raw_trades):
         self.raw_trades = raw_trades
         self.cleaned_trades = []
         self.summary = {}
     
     @staticmethod
     def valid_trades(trade):
         required_keys = ["date", "symbol", "side", "entry", "exit"]
         for key in required_keys:
             if key not in trade:
                 return False
         if trade["exit"] is None:
             return False
         return True

     @staticmethod
     def calculate_pnl(side, entry, exit_price):
        if side == "LONG":
            return exit_price - entry
        elif side == "SHORT":
            return entry - exit_price
        else:
            raise ValueError('side must be LONG or SHORT')

     def clean_trades(self):

        for trade in self.raw_trades:
             if trade['exit'] is None:
                    print(f'Missing exit: {trade["symbol"]} - skipping')
                    continue
             trade['symbol'] = trade['symbol'].strip().upper()
             trade['side'] = trade['side'].strip().upper()

             try:
                 trade['entry'] = float(trade['entry'])
                 trade['exit'] = float(trade['exit'])
             except ValueError:
                 print(f'Invalid numeric data: {trade["symbol"]} - skipping')
                 continue

             self.cleaned_trades.append(trade)


     def summarize_trades(self):
         total = 0
         pnl = 0
         skipped = 0
         for trade in self.cleaned_trades:
             valid_trade = TradePipeline.valid_trades(trade)
             if valid_trade:
                  total_pnl = TradePipeline.calculate_pnl(trade["side"], trade["entry"], trade["exit"])
                  total += 1
                  pnl += total_pnl
             else:
                  skipped += 1

         self.summary = {"total": total, "pnl": pnl, "skipped": skipped}

     def run(self):
         self.clean_trades()
         self.summarize_trades()
         return self.summary

if __name__ == "__main__":
         trades = [
         {"date": "2026-05-01", "symbol": "TESLA", "side": "LONG",  "entry": 180.0, "exit": 185.0},
         {"date": "2026-05-02", "symbol": "NVDA", "side": "SHORT", "entry": 420.0, "exit": 415.0}
          ]

         pipeline = TradePipeline(trades)
         print(pipeline.run())
                                                             