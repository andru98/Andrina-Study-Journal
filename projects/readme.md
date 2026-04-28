# Capstone Projects

Two end-to-end production-grade data engineering
projects — built from scratch using the full modern
DE stack. Each project targets a specific domain
where my background creates a unique advantage.

---

## Project 1 — Airline Revenue Intelligence Platform

**Status:** In progress (Target: October 2026)
**Domain:** Airline revenue management
**Folder:** `airline-revenue-platform/`

### What it does
Real-time airline revenue intelligence platform
simulating the data infrastructure behind pricing
and demand decisions.

### Architecture
```
Kafka (booking events)
    ↓
Delta Lake — Bronze / Silver / Gold
(medallion architecture)
    ↓
dbt transformations
    ↓
Airflow orchestration
    ↓
XGBoost demand forecasting model
    ↓
Streamlit dashboard
```

### Stack
Apache Kafka · Delta Lake · Apache Spark ·
dbt · Apache Airflow · XGBoost · Streamlit ·
Azure / AWS · Python · SQL

### Why this project
2+ years working with airline revenue management
data from the analytics side. This project builds
the engineering infrastructure behind the insights
I used to consume — closing the loop from analyst
to engineer.

---

## Project 2 — Healthcare Data Pipeline with Agentic AI

**Status:** Planned (Target: December 2026)
**Domain:** Health and life sciences
**Folder:** `healthcare-data-pipeline/`

### What it does
End-to-end clinical/genomics data pipeline with
an LLM-powered natural language query interface —
allowing researchers to ask questions about the
data in plain English.

### Architecture
```
Public clinical / genomics data ingestion
    ↓
DE pipeline (Spark + dbt + Airflow)
    ↓
Vector database (Milvus)
    ↓
RAG system + LLM integration
    ↓
Agentic query interface
```

### Stack
Apache Spark · dbt · Airflow · Milvus ·
LangChain · RAG · LLM (Claude / OpenAI) ·
Python · FastAPI · Docker

### Why this project
Biochemistry degree + health domain knowledge
combined with production DE and agentic AI.
A combination almost no other DE candidate has.

---

## Structure

```
projects/
├── airline-revenue-platform/
│   ├── README.md
│   ├── ingestion/
│   ├── pipeline/
│   ├── transformation/
│   ├── ml/
│   └── dashboard/
└── healthcare-data-pipeline/
    ├── README.md
    ├── ingestion/
    ├── pipeline/
    ├── vector-store/
    └── agentic-layer/
```

---

## Connect

- DE study: See `data-engineering` repo
- DS study: See `data-science` repo
