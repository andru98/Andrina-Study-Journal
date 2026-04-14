#!/usr/bin/env python3
"""
Daily Schedule Alarm System — Andrina Shrestha
Runs Monday-Friday with trading session
Runs Saturday-Sunday without trading session
Usage: python3 ~/anna-study-journey/alarm.py
"""

import subprocess
import time
import datetime
import threading

# ── SCHEDULE ─────────────────────────────────────────────────
WEEKDAY_ALARMS = [
    ("08:00", "Morning Review",        "Time to start — morning review and book chapter. 30 minutes."),
    ("08:30", "Trading Session START", "Market open. Launch TradingView and Claude Code. Start morning scan."),
    ("09:30", "Trading Session END",   "Close all positions. Trading session is over. Fill your journal now."),
    ("09:45", "Study Block 1",         "Deep study begins. Main topic for the week. 2 hours of focus."),
    ("11:45", "Short Break",           "15 minute break. Step away from screen."),
    ("12:00", "Lunch Break",           "Lunch time. 1 full hour. Rest your eyes."),
    ("13:00", "Study Block 2",         "Back to study. Hands-on coding and PyCharm. 2 hours."),
    ("15:00", "Short Break",           "15 minute break. Stretch and move."),
    ("15:15", "DSA Practice",          "DSA time. 1 concept plus 2 LeetCode problems. 1 hour."),
    ("16:15", "SQL Practice",          "SQL time. 2 DataLemur problems. 30 minutes."),
    ("16:45", "End of Day",            "Study complete. Run studylog, update Excel, commit to GitHub."),
    ("17:15", "Done for the day",      "Well done Andrina. Rest now. See you tomorrow."),
]

WEEKEND_ALARMS = [
    ("08:00", "Morning Review",    "Time to start — morning review and book chapter. 30 minutes."),
    ("08:30", "Study Block 1",     "Deep study begins. No trading today. Full focus on main topic. 2 hours."),
    ("10:30", "Short Break",       "15 minute break. Step away from screen."),
    ("10:45", "Study Block 2",     "Continue study. Hands-on coding in PyCharm."),
    ("12:45", "Lunch Break",       "Lunch time. 45 minutes. Rest your eyes."),
    ("13:30", "Study Block 3",     "Back to study. Project work or Krish Naik catch-up."),
    ("15:30", "Short Break",       "15 minute break. Stretch and move."),
    ("15:45", "DSA Practice",      "DSA time. 1 concept plus 2 problems."),
    ("16:45", "End of Day",        "Study complete. Run studylog, update Excel, commit to GitHub."),
    ("17:15", "Done for the day",  "Well done Andrina. Rest now."),
]

SUNDAY_EXTRA = [
    ("17:30", "Weekly Review",
     "Sunday weekly review time. Open Excel tracker, fill Weekly Review sheet, paste summary into Claude Code."),
]

# ── ALARM FUNCTIONS ──────────────────────────────────────────
def play_sound():
    """Play Mac system alert sound."""
    subprocess.run(["afplay", "/System/Library/Sounds/Glass.aiff"])
    time.sleep(0.5)
    subprocess.run(["afplay", "/System/Library/Sounds/Glass.aiff"])
    time.sleep(0.5)
    subprocess.run(["afplay", "/System/Library/Sounds/Glass.aiff"])

def show_notification(title, message):
    """Show Mac notification popup."""
    script = f'''
    display notification "{message}" with title "⏰ {title}" sound name "Glass"
    '''
    subprocess.run(["osascript", "-e", script])

def speak_alarm(title, message):
    """Mac speaks the alarm."""
    subprocess.run(["say", "-r", "180", f"{title}. {message}"])

def fire_alarm(title, message):
    """Fire all alarm types simultaneously."""
    print(f"\n{'='*55}")
    print(f"  ⏰  {title}")
    print(f"  {message}")
    print(f"{'='*55}\n")

    # Run sound, notification and speech in parallel
    t1 = threading.Thread(target=play_sound)
    t2 = threading.Thread(target=show_notification, args=(title, message))
    t3 = threading.Thread(target=speak_alarm, args=(title, message))

    t1.start()
    t2.start()
    time.sleep(0.5)
    t3.start()

    t1.join()
    t2.join()
    t3.join()

# ── SCHEDULER ────────────────────────────────────────────────
def get_todays_alarms():
    """Return alarm list based on day of week."""
    today = datetime.datetime.now().weekday()
    # 0=Mon, 1=Tue, 2=Wed, 3=Thu, 4=Fri, 5=Sat, 6=Sun

    if today < 5:  # Monday to Friday
        alarms = WEEKDAY_ALARMS.copy()
        if today == 6:  # Sunday
            alarms += SUNDAY_EXTRA
        return alarms
    else:  # Saturday and Sunday
        alarms = WEEKEND_ALARMS.copy()
        if today == 6:  # Sunday
            alarms += SUNDAY_EXTRA
        return alarms

def parse_time(time_str):
    """Convert HH:MM string to today's datetime."""
    now = datetime.datetime.now()
    hour, minute = map(int, time_str.split(":"))
    return now.replace(hour=hour, minute=minute, second=0, microsecond=0)

def run_scheduler():
    """Main scheduler loop."""
    print("\n" + "="*55)
    print("  ANDRINA'S DAILY SCHEDULE ALARM")
    print("="*55)

    today = datetime.datetime.now()
    day_name = today.strftime("%A %B %d, %Y")
    print(f"\n  Today: {day_name}")

    alarms = get_todays_alarms()

    # Filter out alarms that have already passed
    now = datetime.datetime.now()
    upcoming = []
    for time_str, title, message in alarms:
        alarm_time = parse_time(time_str)
        if alarm_time > now:
            upcoming.append((alarm_time, time_str, title, message))

    if not upcoming:
        print("\n  All alarms for today have passed.")
        print("  Run again tomorrow morning.\n")
        return

    print(f"\n  Upcoming alarms today:")
    for alarm_time, time_str, title, _ in upcoming:
        print(f"  {time_str}  →  {title}")

    print(f"\n  Alarm system running. Do not close this terminal.")
    print(f"  Press Ctrl+C to stop.\n")

    for alarm_time, time_str, title, message in upcoming:
        now = datetime.datetime.now()
        wait_seconds = (alarm_time - now).total_seconds()

        if wait_seconds > 0:
            print(f"  Next alarm: {time_str} — {title} "
                  f"(in {int(wait_seconds//60)} min {int(wait_seconds%60)} sec)")
            time.sleep(wait_seconds)

        fire_alarm(title, message)

    print("\n  All alarms complete. Great work today Andrina!\n")

# ── MAIN ─────────────────────────────────────────────────────
if __name__ == "__main__":
    try:
        run_scheduler()
    except KeyboardInterrupt:
        print("\n\n  Alarm system stopped.\n")
