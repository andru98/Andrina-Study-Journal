# Multi-Timeframe Backtest Pipeline

## What is this?
A data engineering pipeline that backtests 
trading strategies across multiple timeframes
using Bronze/Silver/Gold medallion architecture.

## Strategies Tested
- 9 EMA cross above VWAP
- VWAP reclaim + 9 EMA hold
- Multi-timeframe confluence scoring

## Tickers
- SPY (S&P 500 ETF)
- TSLA (Tesla)

## Timeframes
- 5 minute
- 15 minute  
- 1 hour
- 1 day

## Architecture
yfinance API
↓
Bronze (raw OHLCV data)
↓
Silver (indicators + confluence scores)
↓
Gold (backtest results + equity curve)

## Tech Stack
- Python 3.12
- pandas, numpy (data manipulation)
- yfinance (data ingestion)
- pyarrow (parquet storage)
- matplotlib (visualization)
- streamlit (dashboard)

## Project Status
- [x] Project structure created
- [ ] Data ingestion
- [ ] Indicator calculation
- [ ] Signal generation
- [ ] Backtesting engine
- [ ] Analytics and visualization

## Why I Built This
I have been trading for a year seriously and would like to follow a solid system by backtesting the 
the strategies I have been using for options trading (intraday trading) and analyze if the
strategy would work for me for potential consistent profit making machine. Since i am a aspiring
data engineer I am implementing a pipeline for it using medallion architecture and having a dashbaord as 
as a final serving layer which helps me visualize my R:R winrate and other factors that help me decide.