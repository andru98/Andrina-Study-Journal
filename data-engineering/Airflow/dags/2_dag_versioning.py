from airflow.sdk import dag, task

@dag(
    dag_id = "versioned_dag",
)
def versioned_dag():
    @task.python
    def first_task():
            print("this is the first task")

    @task.python
    def second_task():
        print("this is the second task")

    @task.python
    def third_task():
        print("this is the third task")

    @task.python
    def version_task():
        print("this is the fourth task, to get the new version for practice ")
    first = first_task()
    second = second_task()
    third = third_task()
    fourth = version_task()

    first >> second >> third >> fourth

#Instantiating the DAG
versioned_dag()