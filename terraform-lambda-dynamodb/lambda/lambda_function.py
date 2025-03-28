# Python script for Lambda function

import json
import boto3
import os

dynamodb = boto3.client("dynamodb")

def lambda_handler(event, context):
    table_name = os.environ["TABLE_NAME"]
    
    try:
        response = dynamodb.put_item(
            TableName=table_name,
            Item={
                "id": {"S": "123"},
                "data": {"S": "Sample Data"}
            }
        )
        return {
            "statusCode": 200,
            "body": json.dumps("Data inserted successfully!")
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps(f"Error: {str(e)}")
        }