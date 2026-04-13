#!/usr/bin/env python3
"""
Auto Study Logger
Usage: python3 log_study.py
Paste your daily log when prompted, press Enter twice when done.
Script appends to Excel, commits to GitHub automatically.
"""

import sys
import os
import re
from datetime import datetime
from pathlib import Path

# ── CONFIG — update these paths ──────────────────────────────
EXCEL_PATH = Path.home() / "anna-study-journey" / "Study_Progress_Tracker.xlsx"
REPO_PATH  = Path.home() / "anna-study-journey"
# ─────────────────────────────────────────────────────────────

def parse_log(text):
    """Parse the log text into structured fields."""
    text = text.lower()

    # Date
    date_match = re.search(r'(\w+ \d+|\d{1,2}[\/\-]\d{1,2})', text)
    date = datetime.today().strftime('%Y-%m-%d')

    # Month
    month = 'Month 1'
    for i in range(8, 0, -1):
        if f'month {i}' in text:
            month = f'Month {i}'
            break

    # Track
    track = 'DE'
    if 'all' in text and 'track' in text:
        track = 'All'
    elif 'de+ds' in text or ('de' in text and 'ds' in text):
        track = 'DE+DS'
    elif 'agentic' in text or ' ai' in text:
        track = 'AI'
    elif 'ds' in text or 'data science' in text or 'ml' in text:
        track = 'DS'

    # Topics — extract sentence after "topics:" or just use raw
    topics = ''
    for pattern in [r'topics?[:\s]+([^,\n]+)', r'studied[:\s]+([^,\n]+)']:
        m = re.search(pattern, text)
        if m:
            topics = m.group(1).strip()
            break
    if not topics:
        # grab everything before "hours" as topic hint
        m = re.search(r'log[^:]*:(.*?)(?:hours?|$)', text)
        if m:
            topics = m.group(1).strip()[:100]

    # Hours
    hours = 0
    m = re.search(r'(\d+\.?\d*)\s*h(?:our|r)?s?', text)
    if m:
        hours = float(m.group(1))

    # SQL problems
    sql = 0
    m = re.search(r'(\d+)\s*sql', text)
    if m:
        sql = int(m.group(1))

    # GitHub
    github = 'Yes' if any(w in text for w in ['github yes','committed','pushed','git yes']) else \
             'No' if 'github no' in text or 'no github' in text else ''

    # Krish Naik
    krish = 'Yes' if any(w in text for w in ['krish yes','krish naik yes','attended krish']) else \
            'No' if any(w in text for w in ['krish no','no krish']) else ''

    # PyCharm
    pycharm = 'Yes' if any(w in text for w in ['pycharm yes','yes pycharm','pycharm multiple']) else \
              'Multiple' if 'multiple' in text and 'pycharm' in text else \
              'No' if 'pycharm no' in text or 'no pycharm' in text else ''

    # Stuck on
    stuck = ''
    m = re.search(r'stuck\s+on[:\s]+([^,\.\n]+)', text)
    if m:
        stuck = m.group(1).strip()

    # Insight
    insight = ''
    for pattern in [r'insight[:\s]+([^,\.\n]+)', r'learned[:\s]+([^,\.\n]+)',
                    r'clicked[:\s]+([^,\.\n]+)']:
        m = re.search(pattern, text)
        if m:
            insight = m.group(1).strip()
            break

    return {
        'date': date,
        'month': month,
        'track': track,
        'topics': topics.title() if topics else '',
        'hours': hours,
        'sql': sql,
        'github': github,
        'krish': krish,
        'pycharm': pycharm,
        'stuck': stuck.title() if stuck else '',
        'insight': insight.title() if insight else '',
    }


def append_to_excel(data):
    """Append parsed log data to the Daily Log sheet."""
    try:
        from openpyxl import load_workbook
    except ImportError:
        print("Installing openpyxl...")
        os.system("pip install openpyxl --break-system-packages -q")
        from openpyxl import load_workbook

    if not EXCEL_PATH.exists():
        print(f"Excel file not found at {EXCEL_PATH}")
        print("Please copy your Study_Progress_Tracker.xlsx to ~/anna-study-journey/")
        return False

    wb = load_workbook(EXCEL_PATH)
    ws = wb['Daily Log']

    # Find next empty row (after header row 3)
    next_row = 4
    for row in ws.iter_rows(min_row=4, max_col=1):
        if row[0].value is None:
            next_row = row[0].row
            break
    else:
        next_row = ws.max_row + 1

    # Write data
    ws.cell(row=next_row, column=1,  value=data['date'])
    ws.cell(row=next_row, column=2,  value=data['month'])
    ws.cell(row=next_row, column=3,  value=data['track'])
    ws.cell(row=next_row, column=4,  value=data['topics'])
    ws.cell(row=next_row, column=5,  value=data['hours'])
    ws.cell(row=next_row, column=6,  value=data['sql'])
    ws.cell(row=next_row, column=7,  value=data['github'])
    ws.cell(row=next_row, column=8,  value=data['krish'])
    ws.cell(row=next_row, column=9,  value=data['pycharm'])
    ws.cell(row=next_row, column=10, value=data['stuck'])
    ws.cell(row=next_row, column=11, value=data['insight'])

    wb.save(EXCEL_PATH)
    print(f"  Excel updated — row {next_row} written")
    return True


def git_commit(data):
    """Commit and push the updated Excel to GitHub."""
    os.chdir(REPO_PATH)
    msg = f"Day log {data['date']} — {data['track']} — {data['hours']}hrs — {data['sql']} SQL"
    os.system(f'git add "{EXCEL_PATH}"')
    os.system(f'git commit -m "{msg}"')
    os.system('git push')
    print(f"  GitHub committed: {msg}")


def evaluate_progress(data):
    """Give Claude-style progress feedback."""
    print("\n" + "="*55)
    print("  PROGRESS EVALUATION")
    print("="*55)

    warnings = []
    positives = []

    if data['hours'] >= 8:
        positives.append(f"Full 8 hours studied")
    elif data['hours'] >= 6:
        warnings.append(f"Only {data['hours']} hrs — target is 8")
    else:
        warnings.append(f"Only {data['hours']} hrs — significantly below target")

    if data['sql'] >= 2:
        positives.append(f"{data['sql']} SQL problems solved — daily habit maintained")
    elif data['sql'] == 1:
        warnings.append("Only 1 SQL problem — target is 2 minimum")
    else:
        warnings.append("No SQL problems today — daily habit broken")

    if data['github'] == 'Yes':
        positives.append("GitHub committed — streak maintained")
    else:
        warnings.append("No GitHub commit — push something today")

    if data['krish'] == 'Yes':
        positives.append("Krish Naik session attended")

    for p in positives:
        print(f"  ✓ {p}")
    for w in warnings:
        print(f"  ⚠ {w}")

    if not warnings:
        print("\n  Perfect day Anna. Keep this up.")
    elif len(warnings) == 1:
        print(f"\n  Good day overall. Fix: {warnings[0]}")
    else:
        print(f"\n  {len(warnings)} things to improve tomorrow.")

    if data['stuck']:
        print(f"\n  Stuck on: {data['stuck']}")
        print("  → Ask Claude Code: 'explain [topic] with a simple analogy and code example'")

    print("="*55)


def main():
    print("\n" + "="*55)
    print("  ANNA'S DAILY STUDY LOG")
    print("="*55)
    print("\nPaste your log below (press Enter twice when done):\n")
    print("Example:")
    print("  May 1, Month 1, DE, window functions ROW_NUMBER RANK,")
    print("  8 hours, 2 SQL problems, GitHub yes, Krish no,")
    print("  PyCharm yes, stuck on DENSE_RANK,")
    print("  insight PARTITION BY keeps rows unlike GROUP BY")
    print()

    lines = []
    while True:
        try:
            line = input()
            if line == '' and lines and lines[-1] == '':
                break
            lines.append(line)
        except EOFError:
            break

    raw_text = ' '.join(lines)

    if not raw_text.strip():
        print("No log entered. Exiting.")
        return

    print("\nParsing your log...")
    data = parse_log(raw_text)

    print("\nParsed values:")
    print(f"  Date:     {data['date']}")
    print(f"  Month:    {data['month']}")
    print(f"  Track:    {data['track']}")
    print(f"  Topics:   {data['topics']}")
    print(f"  Hours:    {data['hours']}")
    print(f"  SQL:      {data['sql']}")
    print(f"  GitHub:   {data['github']}")
    print(f"  Krish:    {data['krish']}")
    print(f"  PyCharm:  {data['pycharm']}")
    print(f"  Stuck on: {data['stuck']}")
    print(f"  Insight:  {data['insight']}")

    confirm = input("\nLooks correct? (y/n): ").strip().lower()
    if confirm != 'y':
        print("Log cancelled. Run again and re-enter.")
        return

    print("\nWriting to Excel...")
    success = append_to_excel(data)

    if success:
        print("Committing to GitHub...")
        git_commit(data)
        evaluate_progress(data)
        print("\nDone. See you tomorrow Anna.\n")
    else:
        print("Excel write failed — check the file path in the script.")


if __name__ == '__main__':
    main()
