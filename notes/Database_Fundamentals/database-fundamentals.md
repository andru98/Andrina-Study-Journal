# Database Fundamentals
### ACID Properties + Normalization (1NF, 2NF, 3NF, BCNF)
*Personal Study Notes — May 2026*

---

# Part 1 — ACID Properties

ACID is a set of four guarantees that every reliable database transaction must follow. Think of it as the promise a database makes to you: *"Whatever happens — power cut, crash, two people updating the same row at the same time — your data stays correct."*

> **Why does this matter?** Without ACID, a bank transfer could deduct money from your account but never add it to the recipient's. Or two people could book the last seat on a flight at the same time and both get confirmations.

---

## A — Atomicity

**One word: All or nothing.**

A transaction is a group of operations that must all succeed together. If even one fails, the whole thing is rolled back — like it never happened.

**Hospital example:**
When a patient is admitted, the system needs to:
1. Create a new patient record
2. Assign a bed
3. Log an admission record

If step 2 fails (no beds available) — the patient record from step 1 gets deleted automatically. You don't end up with a ghost patient floating in the system with no bed and no admission record.

> **Real world analogy:** It's like sending a package. Either it arrives complete — box, bubble wrap, invoice all together — or the whole shipment gets returned. You never get just the bubble wrap.

---

## C — Consistency

**One word: Rules always hold.**

After any transaction, the database must still follow all its defined rules (constraints, relationships, data types). You can't end up in a state that violates those rules.

**Hospital example:**
Say your hospital database has a rule: every patient must be assigned to at least one doctor. Consistency means no transaction can ever leave a patient with zero doctors — even in the middle of a department transfer.

If someone tries to remove the last doctor assignment from a patient without adding a new one, the database rejects it.

> **Quick distinction:** Consistency is about your database rules (foreign keys, NOT NULL, CHECK constraints). Atomicity is about the transaction completing fully. They work together but are different things.

---

## I — Isolation

**One word: Transactions don't see each other's mess.**

When two transactions run at the same time, each one behaves as if it's the only one running. One transaction can't see the half-finished work of another.

**Hospital example:**
Two nurses are updating the same patient's medication list at the same time:
- Nurse A is adding Metformin
- Nurse B is removing Insulin

Without isolation, Nurse B could see the list mid-update (Metformin added, Insulin still there) and make a decision based on that incomplete picture. With isolation, each nurse sees a clean, stable version of the data until the other finishes.

> **Real world analogy:** Like two chefs working on the same recipe at the same time but in separate kitchens. They don't get in each other's way. When both are done, the results are merged cleanly.

---

## D — Durability

**One word: Once committed, it's permanent.**

When a transaction is committed (saved), it stays saved — even if the power goes out immediately after. The database writes to disk in a way that survives crashes.

**Hospital example:**
A doctor saves a critical prescription at 3:00 AM. One second later the server crashes. When the system comes back online, that prescription is still there — exactly as saved. The database doesn't just hold things in memory; it writes to a transaction log on disk before confirming the commit.

> **Real world analogy:** Like signing a contract. Once you both sign and it's filed, it exists permanently. Even if the office burns down, there's a backup in a vault somewhere.

---

## ACID — Quick Reference

| Property | What it means | Fails without it |
|---|---|---|
| Atomicity | All operations succeed or none do | Ghost records — step 1 done, step 2 not done |
| Consistency | Database rules always hold after a transaction | Invalid data states — patient with no doctor |
| Isolation | Concurrent transactions don't interfere | Dirty reads — seeing half-finished updates |
| Durability | Committed data survives crashes | Data loss — confirmed save disappears after crash |

---

# Part 2 — Database Normalization

Normalization is the process of organizing a database so that data isn't repeated unnecessarily and every piece of information lives in exactly one place.

The goal is to avoid **anomalies** — situations where updating, inserting, or deleting data breaks something else.

> **Why bother?** Without normalization, changing a drug's price in one row doesn't change it in other rows where the same drug appears. Now you have inconsistent data — same drug, different prices depending on which row you look at.

---

## The Example We'll Use Throughout

A hospital records every prescription — which patient received which drug.

**The starting table (raw, un-normalized):**

| Visit ID | Patient ID | Patient Name | Drug ID | Drug Name | Drug Category | Category Description | Dosage | Price |
|---|---|---|---|---|---|---|---|---|
| V01 | P1 | Anna | RX1 | Metformin | Antidiabetic | Treats type 2 diabetes | 500mg | $10 |
| V02 | P1 | Anna | RX2 | Insulin | Antidiabetic | Treats type 2 diabetes | 10 units | $50 |
| V03 | P2 | John | RX1 | Metformin | Antidiabetic | Treats type 2 diabetes | 250mg | $10 |

Notice: *Metformin, Antidiabetic, Treats type 2 diabetes, $10 — all repeated multiple times. If Metformin's price changes, you'd need to update every single row that has it.*

---

## First Normal Form (1NF)

**The rule:** Every cell must hold exactly one value. Every row must be unique.

**What goes wrong without it?**
Imagine storing multiple drugs in one cell: `Drug Name = "Metformin, Insulin"`. You can't write a SQL WHERE clause on that. You can't JOIN on it. The column becomes useless from a query standpoint.

**Does our table pass 1NF?**
- Every cell has one value ✓
- Visit ID uniquely identifies each row ✓

**Result:** Our table already passes 1NF. Nothing to change. Primary key = `Visit ID`.

---

## Second Normal Form (2NF)

**The rule:** Every non-key column must depend on the ENTIRE primary key, not just part of it.

*This only matters when you have a composite primary key (two or more columns together).*

**What is a non-key column?**
Non-key columns are every column that isn't part of the primary key. They describe something about the row — they don't identify it.

In a Patients table: `Patient ID` is the key. `Name`, `Age`, `Blood Type` are non-key columns. They describe the patient; they don't identify which patient we're talking about.

**Setting up a composite key:**
Say we remove Visit ID and use `Patient ID + Drug ID` as the composite primary key.

Now test each non-key column — does it need BOTH Patient ID AND Drug ID?

| Column | Needs Patient ID? | Needs Drug ID? | Problem? |
|---|---|---|---|
| Dosage | Yes — different patients get different doses | Yes — dose depends on the drug | None ✓ |
| Patient Name | Yes | No — Anna is Anna regardless of drug | Partial dependency ✗ |
| Drug Name | No — Metformin is always Metformin | Yes | Partial dependency ✗ |
| Drug Category | No | Yes | Partial dependency ✗ |
| Drug Price | No | Yes | Partial dependency ✗ |

Only `Dosage` truly needs both parts of the key. Everything else depends on only one part — that's a **partial dependency**, and 2NF says remove it.

**Fix — split into 3 tables:**

**Patients:**
| Patient ID | Patient Name |
|---|---|
| P1 | Anna |
| P2 | John |

**Drugs:**
| Drug ID | Drug Name | Drug Category | Category Description | Drug Price |
|---|---|---|---|---|
| RX1 | Metformin | Antidiabetic | Treats type 2 diabetes | $10 |
| RX2 | Insulin | Antidiabetic | Treats type 2 diabetes | $50 |

**Prescriptions:**
| Patient ID | Drug ID | Dosage |
|---|---|---|
| P1 | RX1 | 500mg |
| P1 | RX2 | 10 units |
| P2 | RX1 | 250mg |

**Result:** Every non-key column now depends on the full primary key of its own table. 2NF achieved.

---

## Third Normal Form (3NF)

**The rule:** Non-key columns must depend only on the primary key — not on each other.

When a non-key column determines another non-key column, that's called a **transitive dependency**. 3NF says eliminate it.

**The problem in our Drugs table:**

| Drug ID | Drug Name | Drug Category | Category Description | Drug Price |
|---|---|---|---|---|
| RX1 | Metformin | Antidiabetic | Treats type 2 diabetes | $10 |
| RX2 | Insulin | Antidiabetic | Treats type 2 diabetes | $50 |

The primary key is `Drug ID`. Now ask: does any non-key column determine another non-key column?

- `Drug Name → Drug Category` — Metformin is always Antidiabetic. Knowing the name tells you the category.
- `Drug Category → Category Description` — Antidiabetic always means "Treats type 2 diabetes"

So the chain is:

```
Drug ID → Drug Name → Drug Category → Category Description
```

`Drug Category` and `Category Description` are not depending directly on `Drug ID`. They're going through `Drug Name` as a middleman. That's a transitive dependency.

> **The test question:** If Drug Name changes, does Drug Category change too? Yes. Then Drug Category is depending on Drug Name, not on Drug ID directly. 3NF violation.

**Fix — split Drugs into two tables:**

**Drug Categories:**
| Category ID | Category Name | Category Description |
|---|---|---|
| C1 | Antidiabetic | Treats type 2 diabetes |
| C2 | Antibiotic | Treats bacterial infections |

**Drugs (updated):**
| Drug ID | Drug Name | Category ID | Drug Price |
|---|---|---|---|
| RX1 | Metformin | C1 | $10 |
| RX2 | Insulin | C1 | $50 |
| RX3 | Amoxicillin | C2 | $30 |

`Category ID` here is just a foreign key — it links to the Categories table. The category name and description no longer live in the Drugs table.

**Result:** Every non-key column now points directly to its own table's primary key. No middlemen. 3NF achieved.

---

## Final Structure After Full Normalization

Four clean tables, each with a clear purpose:

| Table | Primary Key | What it stores |
|---|---|---|
| Patients | Patient ID | Who the patient is |
| Drug Categories | Category ID | Category name and what it treats |
| Drugs | Drug ID | Drug name, which category, price |
| Prescriptions | Patient ID + Drug ID | Which patient got which drug and at what dosage |

Every dependency chain is now direct:

```
Category ID  →  Category Name, Category Description
Drug ID      →  Drug Name, Category ID (FK), Drug Price
Patient ID   →  Patient Name
Patient ID + Drug ID  →  Dosage
```

No column depends on another non-key column anywhere.

---

## BCNF — The Stricter Version of 3NF

*This comes up at mid-level/senior interviews. 3NF is usually enough for junior roles.*

**The rule:** Every determinant must be a candidate key.

**Quick definitions:**
- **Candidate key** — any column (or combination) that can uniquely identify a row. A table can have multiple.
- **Primary key** — the one candidate key you actually chose.
- **Determinant** — any column that tells you the value of another column.

**When does 3NF pass but BCNF fail?**

Only when a table has multiple overlapping candidate keys. Here's the example:

A hospital where each doctor teaches exactly one subject, and each patient is assigned one doctor per subject:

| Patient ID | Subject | Doctor |
|---|---|---|
| P1 | Cardiology | Dr. Patel |
| P1 | Neurology | Dr. Kim |
| P2 | Cardiology | Dr. Patel |

Two candidate keys exist here:
- `Patient ID + Subject` — every combination is unique ✓
- `Patient ID + Doctor` — also every combination is unique ✓

But notice: `Doctor → Subject` (Dr. Patel always does Cardiology). Doctor is a determinant. Is Doctor alone a candidate key? No — Dr. Patel appears in two rows. So a non-candidate-key column is determining another column. BCNF violation.

**Fix:**

**Doctor_Subject:**
| Doctor | Subject |
|---|---|
| Dr. Patel | Cardiology |
| Dr. Kim | Neurology |

**Patient_Doctor:**
| Patient ID | Doctor |
|---|---|
| P1 | Dr. Patel |
| P1 | Dr. Kim |
| P2 | Dr. Patel |

---

## When to Denormalize

Normalization is great for OLTP systems (banking, hospital records) where data is constantly being written and updated. But for OLAP systems (dashboards, analytics, reporting), too many joins slow things down.

**Denormalization = intentionally introducing some redundancy to make reads faster.**

| Scenario | Normalize? | Why |
|---|---|---|
| Hospital EHR system — frequent inserts/updates | Yes | Data integrity is critical |
| Hospital analytics dashboard — complex aggregations | No (star schema) | Joins across many tables are slow |
| Data that almost never changes | Can denormalize | Low risk of update anomalies |
| High write volume | Yes | One update in one place — much safer |

> **The OLAP alternative:** In data warehouses, the standard is Star Schema — one central Fact table (what you measure) surrounded by Dimension tables (who, what, when, where). Intentionally denormalized for fast reads.

---

## Normalization — Full Summary

| Normal Form | The Rule | Violation Name | How to Fix |
|---|---|---|---|
| 1NF | One value per cell, every row unique | Multi-value cells | Split into separate rows or columns |
| 2NF | Non-key columns depend on the FULL composite key | Partial dependency | Move partial deps to their own table |
| 3NF | Non-key columns depend only on the key, not each other | Transitive dependency | Break the middleman chain |
| BCNF | Every determinant must be a candidate key | Non-candidate-key determinant | Split overlapping candidate key tables |

> **Memory trick:** "The key, the whole key, and nothing but the key."
> - 1NF: there IS a key
> - 2NF: depends on the WHOLE key
> - 3NF: depends on NOTHING BUT the key

---

*Study notes compiled May 2026 — Anna's DE Prep Journey*
