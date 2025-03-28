# Lambda function code
import json
import boto3
import os

s3 = boto3.client('s3')

def lambda_handler(event, context):
    bucket_name = os.getenv('BUCKET_NAME', 'my-lambda-bucket')
    file_key = "test-file.txt"

    # Writing to S3
    s3.put_object(Bucket=bucket_name, Key=file_key, Body="Hello from Lambda!")

    # Reading from S3
    response = s3.get_object(Bucket=bucket_name, Key=file_key)
    content = response['Body'].read().decode('utf-8')

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Success', 'file_content': content})
    }