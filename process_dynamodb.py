import json
import boto3
import uuid
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('RecordsTable')

def lambda_handler(event, context):
    try:
        # Parse the request body
        body = json.loads(event['body']) if 'body' in event else event

        # Ensure 'data' key exists in the payload
        if 'data' not in body:
            return {
                "statusCode": 400,
                "body": json.dumps({"message": "Missing 'data' field in request body"})
            }

        # Insert record into DynamoDB
        item = {
            "id": str(uuid.uuid4()),
            "data": body['data'],
            "timestamp": datetime.utcnow().isoformat()
        }
        table.put_item(Item=item)

        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Data stored successfully", "item": item})
        }
    
    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"message": "Internal server error", "error": str(e)})
        }