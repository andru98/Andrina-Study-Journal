import pandas as pd
import numpy as np
from spotify_pipeline.utils.logger import get_logger
from spotify_pipeline.utils.decorators import log_execution
from spotify_pipeline.load.s3 import read_silver
logger = get_logger(__name__)

@log_execution
def top_artists()-> pd.DataFrame:
    artists_df = read_silver("artists")
    tracks_df = read_silver("tracks")

    artists_df = artists_df.rename(columns={"name": "artist_name"})
    merged_df = pd.merge(artists_df, tracks_df, on="artist_id", how = 'left')
    merged_df["explicit"] = pd.to_numeric(
        merged_df["explicit"], errors="coerce"
    ).fillna(0).astype(int)
    agg_df = merged_df.groupby(
        ["artist_id", "artist_name"]
    ).agg(
          track_count =("track_id", "count"),
          avg_duration_seconds =("duration_in_seconds", "mean"),
          explicit_count=("explicit", "sum")
    ).reset_index()

    agg_df["explicit_pct"] = np.where(
         agg_df["track_count"]>0,
        (agg_df["explicit_count"]/agg_df["track_count"] * 100).round(2), 0)
    agg_df = agg_df[agg_df["track_count"]>0]
    final_df = agg_df.sort_values("track_count", ascending=False)
    return final_df


if __name__ == "__main__":
    df = top_artists()
    print(df)
