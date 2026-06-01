'''

1. calculate_pnl(side, entry, exit)
   → LONG  = exit - entry
   → SHORT = entry - exit
   → raises ValueError if side is not LONG or SHORT

2. is_valid_trade(trade: dict)
   → returns True if all keys exist and exit is not None
   → returns False otherwise

3. summarize_trades(trades: list)
   → calls is_valid_trade and calculate_pnl internally
   → returns a dict: {"total": 3, "pnl": 8.0, "skipped": 1}
'''

trades = [
    {"date": "2026-05-01", "symbol": "TSLA", "side": "LONG",  "entry": 180.0, "exit": 185.0},
    {"date": "2026-05-02", "symbol": "NVDA", "side": "SHORT", "entry": 420.0, "exit": 415.0},
    {"date": "2026-05-03", "symbol": "AMD",  "side": "LONG",  "entry": 150.0, "exit": 148.0},
    {"date": "2026-05-04", "symbol": "TSLA", "side": "LONG",  "entry": 182.0, "exit": None},
]


def calculate_pnl(side, entry, exit):
   if side == "LONG":
      pnl = exit - entry
      return pnl
   elif side == "SHORT":
      pnl = entry - exit
      return pnl
   else:
      raise ValueError('side must be LONG or SHORT')

def is_valid_trade(trade:dict):
   required_keys = ["date", "symbol", "side", "entry", "exit"]
   for key in required_keys:
      if key not in trade:
         return False
   if trade["exit"] is None:
        return False
   return True

def summarize_trades(trades:list):
          total = 0
          pnl = 0
          skipped = 0
          for trade in trades:
              valid_trade = is_valid_trade(trade)   
              if valid_trade:
                  total_pnl = calculate_pnl(trade["side"], trade["entry"], trade["exit"])
                  total += 1
                  pnl += total_pnl
              else:
                  skipped += 1
              
          return {"total": total, "pnl": pnl, "skipped": skipped}

if __name__ == '__main__':
   trades = [
   {"date": "2026-05-01", "symbol": "TSLA", "side": "LONG",  "entry": 180.0, "exit": 185.0},
   {"date": "2026-05-02", "symbol": "NVDA", "side": "SHORT", "entry": 420.0, "exit": 415.0},
   {"date": "2026-05-03", "symbol": "AMD",  "side": "LONG",  "entry": 150.0, "exit": 148.0},
   {"date": "2026-05-04", "symbol": "TSLA", "side": "LONG",  "entry": 182.0, "exit": None}, ]

   results = summarize_trades(trades)
   print(results)