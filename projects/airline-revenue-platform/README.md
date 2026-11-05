# Airline Revenue Intelligence Platform: Data Ingestion

## Purpose
This project combines public US DOT fare and capacity data with a synthetic booking stream to study airline demand, fares, and load factors on routes that touch Illinois. It will feed a Bronze, Silver, and Gold pipeline on Databricks and a demand forecast. The fares and capacity are real; the bookings are synthetic and calibrated to the real BTS statistics.

## Data sources (US DOT / BTS TranStats)
| Dataset | Table | Filters | Rows |
|---|---|---|---|
| DB1B Market | DB1BMarket | IL (origin or destination), 2025 Q2 | 619,222 |
| T-100 Domestic Segment | Air Carrier Statistics, U.S. Carriers | IL (origin or destination), 2025, all months | 42,771 |

Source: US DOT Bureau of Transportation Statistics, TranStats (transtats.bts.gov).
Downloaded: 2 Nov 2026.

## Sampling note: 10% vs 40%
DB1B is a sample of airline tickets, not every ticket. BTS describes it as a 10% sample of tickets, and carriers began reporting 40% of their tickets from July 2025. 2025 Q2 is the last quarter of the 10% sample.

- Passenger counts and fare totals in the file are about one tenth of the true totals in a 10% quarter, and about four tenths in a 40% quarter.
- Quarters before and after July 2025 are not comparable without an adjustment. Mixing them would show a fake jump in demand of about four times.
- The pipeline will add a `sample_rate` column (0.10 up to 2025 Q2, 0.40 after) and an estimated passenger count, passengers divided by `sample_rate`.
- Average fares are less affected, but a larger sample gives less noise on small routes.

## Folder layout
```
data/raw/        untouched downloads (not in git)
data/processed/  filtered and cleaned outputs
data/logs/       ingestion checks (check.txt)
```

## Validation at ingestion
- Row counts (see data/logs/check.txt)
- T-100 months 1 to 12 all present (3,264 to 3,808 rows per month)
- Header columns recorded for both files

## Known caveats
- DB1B is a 10% ticket sample for this quarter, so counts and revenue are about one tenth of the true totals and do not represent total revenue.
- The geography filter keeps rows where origin OR destination is Illinois.
- T-100 includes zero-departure records; filter DEPARTURES_PERFORMED > 0 later.
- T-100 is segment data (one row per carrier, origin, destination, and month), not itinerary data, so it cannot be summed across connections.
- The T-100 file has seats and passengers but no revenue; revenue comes from DB1B fares.

## How to reproduce
Both files come from transtats.bts.gov (US DOT Bureau of Transportation Statistics).

DB1B Market
1. Open the DB1B table page (Airline Origin and Destination Survey) and click Download next to DB1BMarket.
2. Fields ticked: see the header columns recorded in data/logs/check.txt.
3. Filters: Geography = Illinois (origin or destination), Year = 2025, Quarter = 2.
4. Download, unzip, and move the CSV to data/raw/.

T-100 Domestic Segment
1. From the TranStats home page: Aviation, then Air Carrier Statistics (Form 41 Traffic) for U.S. carriers, then Download next to T-100 Domestic Segment (U.S. Carriers).
2. Fields ticked: see the header columns recorded in data/logs/check.txt.
3. Filters: Geography = Illinois (origin or destination), Year = 2025, all months.
4. Download, unzip, and move the CSVs to data/raw/.

## Data dictionaries
- DB1B table page and field definitions (Table Profile): https://www.transtats.bts.gov/Tables.asp?QO_VQ=EFI
- DB1B record description (product file): https://www.bts.gov/sites/bts.dot.gov/files/DB1B_Record_Description_Product%20for%20bookstore.pdf
- T-100 field definitions: the Table Profile of the T-100 Domestic Segment table on TranStats (transtats.bts.gov).
