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


def main():
    config = load_config()
    tickers = config["tickers"]
    timeframes = config["timeframes"]

    print(f"Tickers: {tickers}")
    print(f"Timeframes: {timeframes}")

    explore_data()


if __name__ == "__main__":
    main()