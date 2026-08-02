from airflow.sdk import dag, task

@dag(
    dag_id = "first_dag",
)
def first_dag():
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
first_dag()
