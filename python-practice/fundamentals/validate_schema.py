'''

Write a function validate_schema(record, schema) that:

Takes a dict record and a list schema of required keys
Returns True if all schema keys exist in record and no value is None
Returns False otherwise


schema = ["date", "symbol", "side", "entry", "exit"]

record1 = {"date": "2026-06-01", "symbol": "TSLA", "side": "LONG", "entry": 180.0, "exit": 185.0}
record2 = {"date": "2026-06-01", "symbol": "NVDA", "side": "LONG", "entry": None, "exit": 420.0}
record3 = {"date": "2026-06-01", "symbol": "AMD"}
'''


def validate_schema(record, schema):
    for key in schema:
        if key not in record:  # schema key missing from record?
            return False
        if record[key] is None:  # schema key exists but value is None?
            return False
    return True

'''
     Alternate good solution for senior level:
        return all( key in record and record[key] is not None for key in schema)
     '''
'''
You have a list of model evaluation scores. Using lambda and built-in functions only — no loops — write one line each for:

Sort scores descending by f1_score
Filter only models where accuracy > 0.85
Extract just the model names

# 1. Sorted descending by f1_score
[LightGBM, XGBoost, RandomForest, LogReg]

# 2. Filtered accuracy > 0.85
[XGBoost, LightGBM]

# 3. Model names only
["XGBoost", "RandomForest", "LogReg", "LightGBM"]
'''

scores = [
    {"model": "XGBoost",      "accuracy": 0.91, "f1_score": 0.89},
    {"model": "RandomForest", "accuracy": 0.83, "f1_score": 0.85},
    {"model": "LogReg",       "accuracy": 0.78, "f1_score": 0.76},
    {"model": "LightGBM",     "accuracy": 0.93, "f1_score": 0.92},
]

filtered  = list(filter(lambda score: score["accuracy"] > 0.85, scores))
extracted = list(map(lambda score: score["model"], scores))
sort = sorted(scores, key = lambda score:score["f1_score"], reverse = True)

print(sort)
print(filtered)
print(extracted)

if __name__ == "__main__":
    schema = ["date", "symbol", "side", "entry", "exit"]

    record1 = {"date": "2026-06-01", "symbol": "TSLA", "side": "LONG", "entry": 180.0, "exit": 185.0}
    record2 = {"date": "2026-06-01", "symbol": "NVDA", "side": "LONG", "entry": None, "exit": 420.0}
    record3 = {"date": "2026-06-01", "symbol": "AMD"}

    validate1 = (validate_schema(record1, schema))
    validate2 = (validate_schema(record2, schema))

    print(validate1)
    print(validate2)



