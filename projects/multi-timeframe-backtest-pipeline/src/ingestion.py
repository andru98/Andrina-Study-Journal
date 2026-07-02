import yaml
import yfinance as yf


def load_config():
    with open("config.yaml", "r") as f:
        return yaml.safe_load(f)


def explore_data():
    df = yf.download("SPY", period="5d", interval="5m")
    df.columns = df.columns.get_level_values(0)  # flatten first
    df.index = df.index.tz_convert("America/New_York").tz_localize(None) # then remove timezone

    print("Shape:", df.shape)
    print("\nFirst 5 rows:")
    print(df.head())
    print("\nColumn data types:")
    print(df.dtypes)
    print("\nNull counts:")
    print(df.isnull().sum())

def fetch_data(ticker, timeframe, config):
    # 1. validate ticker
    # 2. validate timeframe
    # 3. check if bronze file exists
    # 4. call yfinance with retry logic
    # 5. validate returned data
    # 6. return dataframe
def validate_data(df, ticker, timeframe):
    # 1. empty check
    # 2. row count within expected range
    # 3. null check on critical columns
    # 4. date range covers expected period
    # 5. log all findings
    # return True if valid, False if not
def save_to_bronze(df, ticker, timeframe, config):
    # 1. flatten MultiIndex
    # 2. convert timezone
    # 3. build file path
    # 4. save as parquet
    # 5. log success

def main():
    config = load_config()
    tickers = config["tickers"]
    timeframes = config["timeframes"]

    print(f"Tickers: {tickers}")
    print(f"Timeframes: {timeframes}")

    for ticker in tickers:
        for timeframe in timeframes:
            try:
                df = fetch_data(ticker, timeframe, config)
                save_to_bronze(df, ticker, timeframe, config)
            except Exception as e:
                print(f"Failed: {ticker} {timeframe} — {e}")
                continue
    explore_data()


if __name__ == "__main__":
    main()