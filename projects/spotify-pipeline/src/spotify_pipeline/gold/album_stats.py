import pandas as pd
from spotify_pipeline.utils.logger import get_logger
from spotify_pipeline.utils.decorators import log_execution
from spotify_pipeline.load.s3 import read_silver
logger = get_logger(__name__)

@log_execution
def album_stats():
    albums_df = read_silver("albums")
    tracks_df = read_silver("tracks")
    albums_df = albums_df.rename(columns={"name": "album_name"})
    merged_df = pd.merge(albums_df, tracks_df, on = "album_id", how = "inner")
    agg_df = merged_df.groupby(
        ["album_id", "album_name", "release_date"]
    ).agg(
        total_tracks = ("total_tracks", "first"),
        track_count = ("track_id", "count"),
        avg_duration_seconds = ("duration_in_seconds", "mean"),
        explicit_count = ("explicit", "sum")
    ).reset_index()
    agg_df["release_year"] = pd.to_datetime(
        agg_df["release_date"], errors="coerce"
    ).dt.year.fillna(0).astype(int)
    agg_df = agg_df.sort_values("release_year", ascending=False)
    return agg_df


if __name__ == "__main__":
  df = album_stats()
  print (df.columns.tolist())
  print(df.head())
  print(df.dtypes)



