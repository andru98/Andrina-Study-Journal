import yaml

def load_config():
    with open("config.yaml", "r") as f:
       return yaml.safe_load(f)


def main():
    config = load_config()
    tickers = config["tickers"]
    timeframes = config["timeframes"]

    print(f"Tickers: {tickers}")
    print(f"Timeframes: {timeframes}")

if __name__ =="__main__":
    main()