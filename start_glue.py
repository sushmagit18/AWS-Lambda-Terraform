import json
import boto3

glue = boto3.client('glue')

def lambda_handler(event, context):
    response = glue.start_job_run(JobName='HelloWorld')
    return {"statusCode": 200, "body": json.dumps(f"Glue job started: {response['JobRunId']}")}