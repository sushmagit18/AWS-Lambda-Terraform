def lambda_handler(event, context):
    import boto3
    import json

    # Ensure the bucket exists in the correct region
    bucket_name = "myuploadbucket040104"
    file_key = "sample.txt"

    s3 = boto3.client('s3', region_name='us-east-1')

    try:
        # Upload a sample file to the S3 bucket
        s3.put_object(Bucket=bucket_name, Key=file_key, Body="This is a sample file.")

        return {
            "statusCode": 200,
            "body": json.dumps({"message": f"File {file_key} uploaded successfully to {bucket_name}."})
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
