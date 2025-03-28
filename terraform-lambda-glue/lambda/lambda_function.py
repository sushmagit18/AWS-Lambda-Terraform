import boto3

def lambda_handler(event, context):
    glue_client = boto3.client('glue')
    
    # Start a Glue job
    response = glue_client.start_job_run(JobName='HelloWorld')
    
    return {
        'statusCode': 200,
        'body': f"Glue job started with ID {response['JobRunId']}"
    }
