import json
import boto3
import uuid
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('RecordsTable')

def lambda_handler(event, context):
    try:
        # Determine HTTP method
        http_method = event.get("httpMethod", "POST")

        if http_method == "POST":
            # Parse request body
            body = json.loads(event['body']) if 'body' in event and event['body'] else {}

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

        elif http_method == "GET":
            # Get 'id' from query string parameters
            query_params = event.get('queryStringParameters', {})
            record_id = query_params.get('id')

            if not record_id:
                return {
                    "statusCode": 400,
                    "body": json.dumps({"message": "Missing 'id' parameter in query"})
                }

            # Retrieve item from DynamoDB
            response = table.get_item(Key={"id": record_id})
            item = response.get("Item")

            if not item:
                return {
                    "statusCode": 404,
                    "body": json.dumps({"message": "Item not found"})
                }

            return {
                "statusCode": 200,
                "body": json.dumps({"item": item})
            }

        else:
            return {
                "statusCode": 405,
                "body": json.dumps({"message": "Method Not Allowed"})
            }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"message": "Internal server error", "error": str(e)})
        }