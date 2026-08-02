from airflow.sdk import dag, task
from airflow.providers.standard.operators.bash import BashOperator

@dag(
    dag_id = "bash_dag",
)
def bash_dag():
    @task.python
    def first_task():
            print("this is the first task")

    @task.python
    def second_task():
        print("this is the second task")


    @task.bash
    def bash_task_modern() -> str:
        return "echo https://airflow.apache.org/"


    bash_task_old_school = BashOperator(
        task_id = "bash_task_old_school",
        bash_command = "echo https://airflow.apache.org/"
    )

# Defining task dependencies
    first = first_task()
    second = second_task()
    bash_modern = bash_task_modern()
    bash_old_school = bash_task_old_school

    first >> second >> bash_modern >> bash_old_school

#Instantiating the DAG
bash_dag()