import pandas as pd
from spotify_pipeline.utils.logger import get_logger
from spotify_pipeline.utils.decorators import log_execution
from spotify_pipeline.load.s3 import read_silver
logger = get_logger(__name__)


@log_execution
def build_explicit_analysis() -> pd.DataFrame:
    tracks_df = read_silver("tracks")

    # cast explicit to int first
    tracks_df["explicit"] = pd.to_numeric(
            tracks_df["explicit"], errors="coerce"
         ).fillna(0).astype(int)

    total = len(tracks_df)
    explicit_count = tracks_df["explicit"].sum()
    clean_count = total - explicit_count

    result = pd.DataFrame({
            "total_tracks": [total],
            "explicit_count": [explicit_count],
            "clean_count": [clean_count],
            "explicit_pct": [round(explicit_count / total * 100, 2) if total > 0 else 0]
        })

    return result


if __name__ == "__main__":
    df = build_explicit_analysis()
    print(df)
