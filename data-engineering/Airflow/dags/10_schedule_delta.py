from airflow.sdk import dag, task
from pendulum import datetime,duration
from airflow.timetables.trigger import DeltaTriggerTimetable

@dag(
    dag_id = "delta_schedule",
    start_date= datetime(year=2026, month=7, day=26, tz ="America/New_York"),
    schedule=DeltaTriggerTimetable(duration(days= 3)),
    end_date = datetime(year=2026, month=8 , day=2, tz ="America/New_York"),
    is_paused_upon_creation=False,
    catchup = True
)
def delta_schedule_dag():
    @task.python
    def first_task():
            print("this is the first task")

    @task.python
    def second_task():
        print("this is the second task")

    @task.python
    def third_task():
        print("this is the third task")

    first = first_task()
    second = second_task()
    third = third_task()

    first >> second >> third

#Instantiating the DAG
delta_schedule_dag()