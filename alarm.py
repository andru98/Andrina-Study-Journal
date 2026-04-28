#!/usr/bin/env python3
"""
Daily Schedule Alarm — Andrina Shrestha
Mon-Fri: includes trading session
Sat-Sun: study only, no trading
Usage: python3 ~/anna-study-journey/alarm.py
"""

import subprocess
import time
import datetime
import threading

WEEKDAY_ALARMS = [
    ("07:30", "Book Reading",
     "30 minutes of book reading. Fundamentals of Data Engineering or DDIA."),
    ("08:00", "Pre-market Screening",
     "Check SPY and QQQ. Build your watchlist. Open Claude Code and say start morning scan."),
    ("08:30", "Trading Session START",
     "Market is open. Execute your plan. Stick to your rules."),
    ("09:30", "Trading Session END",
     "Close all positions now. No exceptions. Fill your trading journal."),
    ("09:45", "SQL Practice",
     "SQL time. Two DataLemur problems. 30 minutes."),
    ("10:15", "Study Block 1",
     "Deep study begins. Main topic for this week. 2 hours of full focus."),
    ("11:45", "Short Break",
     "15 minute break. Step away from the screen. Rest your eyes."),
    ("12:00", "Lunch Break",
     "Lunch time. One full hour. No studying. Rest properly."),
    ("13:00", "Study Block 2",
     "Back to study. Hands-on coding in PyCharm. Push to GitHub."),
    ("15:00", "Short Break",
     "15 minute break. Stretch and move your body."),
    ("15:15", "DSA Practice",
     "DSA time. One concept and two LeetCode problems. One hour."),
    ("16:45", "End of Day",
     "Study complete. Run studylog. Update Excel. Commit to GitHub."),
    ("16:45", "End of Day",
 "Study complete. Run: python3 log_study.py — then commit notebooks to GitHub. Done for today."),
]

WEEKEND_ALARMS = [
    ("07:30", "Book Reading",
     "30 minutes of book reading. Good morning Andrina."),
    ("08:00", "Study Block 1",
     "Deep study begins. No trading today. Full focus on main topic."),
    ("10:00", "Short Break",
     "15 minute break. Step away from screen."),
    ("10:15", "Study Block 2",
     "Continue study. Hands-on coding or Krish Naik catch-up."),
    ("12:15", "Lunch Break",
     "Lunch time. 45 minutes. Rest properly."),
    ("13:00", "Study Block 3",
     "Back to study. Project work or Krish Naik session."),
    ("15:00", "Short Break",
     "15 minute break. Stretch and move."),
    ("15:15", "DSA Practice",
     "DSA time. One concept and two problems."),
    ("16:15", "SQL Practice",
     "SQL time. Two DataLemur problems."),
    ("16:45", "End of Day",
     "Study complete. Run studylog. Update Excel. Commit to GitHub."),
    ("17:15", "Done",
     "Well done Andrina. Rest now."),
]

SATURDAY_EXTRA = [
    ("17:30", "Weekly Review",
     "Saturday review. 1) Update README progress numbers. 2) Write LinkedIn post. 3) Schedule for Monday 8am. 4) Plan next week Krish Naik videos. 5) Update Study_Progress_Tracker weekly summary."),
]

def play_sound():
    for _ in range(3):
        subprocess.run(["afplay", "/System/Library/Sounds/Glass.aiff"])
        time.sleep(0.4)

def show_notification(title, message):
    script = f'display notification "{message}" with title "⏰ {title}" sound name "Glass"'
    subprocess.run(["osascript", "-e", script])

def speak_alarm(title, message):
    subprocess.run(["say", "-r", "175", f"{title}. {message}"])

def fire_alarm(title, message):
    print(f"\n{'='*55}")
    print(f"  ⏰  {title}")
    print(f"  {message}")
    print(f"{'='*55}\n")
    t1 = threading.Thread(target=play_sound)
    t2 = threading.Thread(target=show_notification, args=(title, message))
    t3 = threading.Thread(target=speak_alarm, args=(title, message))
    t1.start(); t2.start()
    time.sleep(0.3)
    t3.start()
    t1.join(); t2.join(); t3.join()

def get_todays_alarms():
    today = datetime.datetime.now().weekday()
    if today < 5:
        return WEEKDAY_ALARMS
    else:
        alarms = WEEKEND_ALARMS.copy()
        if today == 5:  # Saturday
            alarms += SATURDAY_EXTRA
        return alarms

def parse_time(time_str):
    now = datetime.datetime.now()
    h, m = map(int, time_str.split(":"))
    return now.replace(hour=h, minute=m, second=0, microsecond=0)

def run_scheduler():
    print("\n" + "="*55)
    print("  ANDRINA'S DAILY SCHEDULE ALARM")
    print("="*55)
    today = datetime.datetime.now()
    print(f"\n  Today: {today.strftime('%A %B %d, %Y')}")

    alarms = get_todays_alarms()
    now = datetime.datetime.now()
    upcoming = [(parse_time(t), t, title, msg)
                for t, title, msg in alarms
                if parse_time(t) > now]

    if not upcoming:
        print("\n  All alarms for today have passed. Run again tomorrow.\n")
        return

    print(f"\n  Upcoming alarms:")
    for _, t, title, _ in upcoming:
        print(f"  {t}  →  {title}")
    print(f"\n  Keep this terminal open. Press Ctrl+C to stop.\n")

    for alarm_time, t, title, message in upcoming:
        now = datetime.datetime.now()
        wait = (alarm_time - now).total_seconds()
        if wait > 0:
            mins = int(wait // 60)
            secs = int(wait % 60)
            print(f"  Waiting for {t} — {title} (in {mins}m {secs}s)")
            time.sleep(wait)
        fire_alarm(title, message)

    print("\n  All alarms done. Great work today Andrina!\n")

if __name__ == "__main__":
    try:
        run_scheduler()
    except KeyboardInterrupt:
        print("\n\n  Alarm stopped.\n")
