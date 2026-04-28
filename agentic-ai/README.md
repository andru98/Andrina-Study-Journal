# Python — Production Engineering Standards

Python practice built to production DE standards —
not notebook Python, not tutorial Python.
Every pattern here maps directly to how Python
is written in senior DE roles at top companies.

**Background:** Experience in airline revenue management
analytics. Transitioning from Jupyter-based DS work
to production-grade pipeline engineering.

**Standard:** Every script in this repo follows the
same conventions a senior engineer would apply in
a production codebase — type hints, error handling,
logging, testing, and clean architecture.

---

## The gap this repo closes

Most data professionals write Python like this:

```python
# notebook style — works, not production
df = pd.read_csv('data.csv')
df2 = df[df['price'] > 100]
print(df2)
```

Senior DE engineers write Python like this:

```python
import logging
from pathlib import Path
from typing import Optional
import pandas as pd

logger = logging.getLogger(__name__)

def filter_by_price(
    filepath: Path,
    min_price: float,
    output_path: Optional[Path] = None
) -> pd.DataFrame:
    """
    Load booking data and filter by minimum price threshold.

    Args:
        filepath: Path to source CSV file
        min_price: Minimum price threshold (exclusive)
        output_path: Optional path to write filtered output

    Returns:
        Filtered DataFrame

    Raises:
        FileNotFoundError: If filepath does not exist
        ValueError: If min_price is negative
    """
    if not filepath.exists():
        raise FileNotFoundError(f"Data file not found: {filepath}")
    if min_price < 0:
        raise ValueError(f"min_price must be non-negative, got {min_price}")

    logger.info(f"Loading data from {filepath}")
    df = pd.read_csv(filepath)

    filtered = df[df['price'] > min_price].copy()
    logger.info(f"Filtered {len(df)} rows to {len(filtered)} rows")

    if output_path:
        filtered.to_csv(output_path, index=False)
        logger.info(f"Written to {output_path}")

    return filtered
```

This repo builds the habits that make the second
version natural — not forced.

---

## Structure

```
python-practice/
├── oop/
│   ├── pipeline_component.py      — base class pattern
│   ├── data_extractor.py          — inheritance example
│   ├── data_transformer.py        — inheritance example
│   ├── trade_journal.py           — domain OOP project
│   └── singleton_config.py        — design pattern
├── patterns/
│   ├── factory_pattern.py         — for pipeline components
│   ├── strategy_pattern.py        — for ML model selection
│   ├── observer_pattern.py        — for pipeline monitoring
│   └── context_manager.py         — for resource management
├── error-handling/
│   ├── custom_exceptions.py       — domain-specific errors
│   ├── retry_decorator.py         — for flaky API calls
│   └── circuit_breaker.py         — for pipeline resilience
├── performance/
│   ├── generators_vs_lists.py     — memory efficiency
│   ├── multiprocessing_basics.py  — parallel processing
│   └── profiling_examples.py      — bottleneck detection
├── testing/
│   ├── test_pipeline_component.py — pytest examples
│   ├── test_data_extractor.py
│   └── conftest.py                — fixtures
├── async/
│   ├── asyncio_basics.py          — concurrent I/O
│   └── async_pipeline_fetch.py    — parallel API calls
└── mini-projects/
    ├── trade_journal/             — full OOP project
    └── pipeline_simulator/        — DE pipeline in Python
```

---

## Production standards — applied to every file

### 1. Type hints — always, everywhere

```python
from typing import List, Dict, Optional, Union, Tuple
from pathlib import Path

# Never this
def process(data, config):
    pass

# Always this
def process(
    data: pd.DataFrame,
    config: Dict[str, Union[str, int, float]]
) -> Tuple[pd.DataFrame, Dict[str, int]]:
    pass
```

### 2. Logging — never print()

```python
import logging

# Configure once at module level
logger = logging.getLogger(__name__)

# Never this in production code
print(f"Processing {len(df)} rows")

# Always this
logger.info(f"Processing {len(df)} rows")
logger.warning(f"Null values detected: {df.isnull().sum()}")
logger.error(f"Pipeline failed: {e}", exc_info=True)
```

### 3. Custom exceptions — domain specific

```python
class PipelineError(Exception):
    """Base exception for all pipeline errors."""
    pass

class DataValidationError(PipelineError):
    """Raised when data fails schema validation."""
    pass

class PartitionNotFoundError(PipelineError):
    """Raised when expected data partition is missing."""
    pass
```

### 4. Context managers — always for resources

```python
from contextlib import contextmanager

@contextmanager
def db_connection(connection_string: str):
    conn = None
    try:
        conn = create_connection(connection_string)
        logger.info("Database connection established")
        yield conn
    except Exception as e:
        logger.error(f"Connection failed: {e}")
        raise
    finally:
        if conn:
            conn.close()
            logger.info("Database connection closed")
```

### 5. Dataclasses — for configuration objects

```python
from dataclasses import dataclass, field
from typing import List

@dataclass
class PipelineConfig:
    source_path: Path
    target_path: Path
    batch_size: int = 1000
    retry_attempts: int = 3
    allowed_null_pct: float = 0.05
    partition_cols: List[str] = field(default_factory=list)

    def validate(self) -> None:
        if not self.source_path.exists():
            raise FileNotFoundError(self.source_path)
        if self.batch_size <= 0:
            raise ValueError("batch_size must be positive")
```

### 6. Testing — pytest for everything

```python
import pytest
from pathlib import Path
from your_module import filter_by_price

class TestFilterByPrice:

    def test_filters_correctly(self, tmp_path, sample_csv):
        result = filter_by_price(sample_csv, min_price=100.0)
        assert all(result['price'] > 100.0)

    def test_raises_on_missing_file(self, tmp_path):
        with pytest.raises(FileNotFoundError):
            filter_by_price(tmp_path / "missing.csv", 100.0)

    def test_raises_on_negative_price(self, sample_csv):
        with pytest.raises(ValueError):
            filter_by_price(sample_csv, min_price=-1.0)

    def test_empty_dataframe_returns_empty(self, empty_csv):
        result = filter_by_price(empty_csv, min_price=0.0)
        assert len(result) == 0
```

---

## OOP architecture — production pipeline pattern

This is the pattern senior DE engineers use to build
reusable, testable pipeline components:

```python
from abc import ABC, abstractmethod
from typing import Any
import logging

logger = logging.getLogger(__name__)

class PipelineComponent(ABC):
    """Abstract base class for all pipeline components."""

    def __init__(self, name: str, config: PipelineConfig):
        self.name = name
        self.config = config
        self._metrics: Dict[str, Any] = {}

    @abstractmethod
    def execute(self, data: pd.DataFrame) -> pd.DataFrame:
        """Execute this pipeline stage."""
        pass

    def run(self, data: pd.DataFrame) -> pd.DataFrame:
        """Run with logging and error handling."""
        logger.info(f"[{self.name}] Starting — {len(data)} rows")
        try:
            result = self.execute(data)
            logger.info(f"[{self.name}] Complete — {len(result)} rows")
            return result
        except Exception as e:
            logger.error(f"[{self.name}] Failed: {e}", exc_info=True)
            raise PipelineError(f"{self.name} failed") from e


class DataValidator(PipelineComponent):
    """Validates data against schema and null thresholds."""

    def execute(self, data: pd.DataFrame) -> pd.DataFrame:
        null_pct = data.isnull().mean()
        violations = null_pct[null_pct > self.config.allowed_null_pct]
        if not violations.empty:
            raise DataValidationError(
                f"Null threshold exceeded: {violations.to_dict()}"
            )
        return data
```

---

## Domain mini-project — TradeJournal

First complete OOP project — connects every concept
to something already familiar:

```python
@dataclass
class Trade:
    symbol: str
    side: str        # 'long' or 'short'
    entry: float
    exit: float
    contracts: int
    emotion: str
    followed_plan: bool

    @property
    def pnl(self) -> float:
        direction = 1 if self.side == 'long' else -1
        return direction * (self.exit - self.entry) * self.contracts

    @property
    def is_winner(self) -> bool:
        return self.pnl > 0


class TradeJournal:
    def __init__(self):
        self._trades: List[Trade] = []
        self._logger = logging.getLogger(__name__)

    def add_trade(self, trade: Trade) -> None:
        self._trades.append(trade)
        self._logger.info(f"Added trade: {trade.symbol} PnL={trade.pnl:.2f}")

    @property
    def total_pnl(self) -> float:
        return sum(t.pnl for t in self._trades)

    @property
    def win_rate(self) -> float:
        if not self._trades:
            return 0.0
        return sum(1 for t in self._trades if t.is_winner) / len(self._trades)

    def trades_by_emotion(self) -> Dict[str, List[Trade]]:
        from collections import defaultdict
        result = defaultdict(list)
        for trade in self._trades:
            result[trade.emotion].append(trade)
        return dict(result)

    def summary(self) -> Dict[str, Any]:
        return {
            'total_trades': len(self._trades),
            'total_pnl': round(self.total_pnl, 2),
            'win_rate': round(self.win_rate, 4),
            'best_trade': max(self._trades, key=lambda t: t.pnl, default=None),
            'worst_trade': min(self._trades, key=lambda t: t.pnl, default=None),
        }
```

This project is not a tutorial exercise. It uses:
dataclasses, properties, type hints, logging,
defaultdict, list comprehensions, and clean OOP
architecture — all patterns that appear in
production DE codebases daily.

---

## Concepts by month

### Month 1 (May) — OOP + fundamentals
- [ ] Abstract base classes + inheritance
- [ ] Dataclasses + properties
- [ ] Type hints — full coverage
- [ ] Custom exceptions hierarchy
- [ ] Context managers
- [ ] Logging setup

### Month 2 (June) — Advanced patterns
- [ ] Decorators — retry, timer, cache
- [ ] Generators — memory-efficient data processing
- [ ] Async/await — concurrent pipeline fetches
- [ ] Design patterns — factory, strategy, observer
- [ ] pytest — unit tests for every component
- [ ] Virtual environments + requirements.txt

---

## Connect

- LinkedIn: https://www.linkedin.com/in/andrina-data/
- DE pipelines: See `data-engineering` repo
- Projects: See `projects` repo
