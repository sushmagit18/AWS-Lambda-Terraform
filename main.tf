

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name               = "lambda_execution_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com",
          "glue.amazonaws.com"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

# Attach AWSLambdaBasicExecutionRole
resource "aws_iam_policy_attachment" "lambda_basic_policy" {
  name       = "lambda_basic_policy"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

// Bucket used for Glue scripts and general services
resource "aws_s3_bucket" "data_bucket" {
  bucket = "mystoragebucket040104"
}

// Bucket used exclusively for file uploads via the process_s3 Lambda
resource "aws_s3_bucket" "upload_bucket" {
  bucket = "myuploadbucket040104"
}

# DynamoDB Table
resource "aws_dynamodb_table" "records_table" {
  name         = "RecordsTable"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# Lambda Functions
resource "aws_lambda_function" "process_dynamodb" {
  function_name = "ProcessDynamoDB"
  runtime       = "python3.8"
  role          = aws_iam_role.lambda_role.arn
  handler       = "process_dynamodb.lambda_handler"
  filename      = "process_dynamodb.zip"

  source_code_hash = filebase64sha256("process_dynamodb.zip")
}

resource "aws_lambda_function" "process_s3" {
  function_name    = "ProcessS3"
  runtime          = "python3.8"
  role             = aws_iam_role.lambda_role.arn
  handler          = "process_s3.lambda_handler"
  filename         = "process_s3.zip"
  source_code_hash = filebase64sha256("process_s3.zip")
  publish          = true
}

resource "aws_lambda_function" "start_glue" {
  function_name = "StartGlueJob"
  runtime       = "python3.8"
  role          = aws_iam_role.lambda_role.arn
  handler       = "start_glue.lambda_handler"
  filename      = "start_glue.zip"
  source_code_hash = filebase64sha256("start_glue.zip")
  publish          = true
}

# API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name        = "MyAPI"
  description = "API Gateway for my AWS workflow"
}

resource "aws_api_gateway_resource" "records" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "records"
}

resource "aws_api_gateway_method" "get_records" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.records.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_records" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.records.id
  http_method             = aws_api_gateway_method.get_records.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.process_dynamodb.invoke_arn
}

resource "aws_api_gateway_resource" "glue" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "glue"
}

resource "aws_api_gateway_method" "post_glue" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.glue.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_glue" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.glue.id
  http_method             = aws_api_gateway_method.post_glue.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.start_glue.invoke_arn
}

// New S3 Resource
resource "aws_api_gateway_resource" "s3" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "s3"
}

// GET Method on /s3
resource "aws_api_gateway_method" "get_s3" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.s3.id
  http_method   = "GET"
  authorization = "NONE"
}

// AWS Service Integration with S3 to perform ListBucket operation
resource "aws_api_gateway_integration" "s3_get" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.s3.id
  http_method             = aws_api_gateway_method.get_s3.http_method
  type                    = "AWS"
  integration_http_method = "GET"
  uri                     = "arn:aws:apigateway:${var.region != "" ? var.region : "us-east-1"}:s3:path/${aws_s3_bucket.data_bucket.bucket}"

  // Pass query parameter to list objects (ListBucket - ListType V2)
  request_parameters = {
    "integration.request.querystring.list-type" = "'2'"
  }

  // Use the IAM role to sign the request
  credentials = aws_iam_role.apigw_s3_role.arn
}

// Method Response for 200 OK
resource "aws_api_gateway_method_response" "get_s3_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.s3.id
  http_method = aws_api_gateway_method.get_s3.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
}

// Integration Response for 200 OK
resource "aws_api_gateway_integration_response" "get_s3_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.s3.id
  http_method = aws_api_gateway_method.get_s3.http_method
  status_code = aws_api_gateway_method_response.get_s3_response.status_code
  response_templates = {
    "application/json" = ""
  }

  depends_on = [aws_api_gateway_integration.s3_get]
}

// POST method on /s3 to obtain a pre-signed URL for file upload
resource "aws_api_gateway_method" "post_s3" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.s3.id
  http_method   = "POST"
  authorization = "NONE"
}

// Integration for the POST method to invoke the process_s3 Lambda
resource "aws_api_gateway_integration" "lambda_s3" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.s3.id
  http_method             = aws_api_gateway_method.post_s3.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.process_s3.invoke_arn
}

// Lambda permission to allow API Gateway to invoke process_s3
resource "aws_lambda_permission" "apigw_lambda_s3" {
  statement_id  = "AllowAPIGatewayInvokeS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_s3.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# Deploy API (Ensure API Gateway has methods before deploying)
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  

  triggers = {
    redeployment = sha1(jsonencode({
      glue_integration_uri    = aws_api_gateway_integration.lambda_glue.uri,
      records_integration_uri = aws_api_gateway_integration.lambda_records.uri,
      s3_integration_uri      = aws_api_gateway_integration.lambda_s3.uri
    }))
  }

  depends_on = [
    aws_api_gateway_integration.lambda_records,
    aws_api_gateway_integration.lambda_glue,
    aws_api_gateway_integration.lambda_s3
  ]
}

# AWS Glue Job
resource "aws_glue_job" "glue_job" {
  name     = "HelloWorldJob"
  role_arn = aws_iam_role.lambda_role.arn
  command {
    script_location = "s3://${aws_s3_bucket.data_bucket.bucket}/scripts/glue_script.py"
    name            = "glueetl"
  }
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_dynamodb.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_lambda_glue" {
  statement_id  = "AllowAPIGatewayInvokeGlue"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_glue.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_iam_policy" "dynamodb_policy" {
  name        = "lambda_dynamodb_policy"
  description = "Policy for Lambda to perform PutItem on RecordsTable"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ],
        Resource = aws_dynamodb_table.records_table.arn
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "lambda_dynamodb_policy_attach" {
  name       = "lambda_dynamodb_policy_attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = aws_iam_policy.dynamodb_policy.arn
}

resource "aws_iam_policy" "glue_policy" {
  name        = "lambda_glue_policy"
  description = "Policy for Lambda to execute a Glue job"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:GetJobRuns"
        ],
        "Resource": "arn:aws:glue:us-east-1:571600854327:job/HelloWorld"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "glue_policy_attachment" {
  name       = "lambda_glue_policy_attach"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = aws_iam_policy.glue_policy.arn
}

// Policy to allow updating Lambda function code and configuration
resource "aws_iam_policy" "lambda_update_policy" {
  name        = "lambda_update_policy"
  description = "Policy for updating Lambda function code and configuration"
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:PublishVersion"
        ],
        Resource : "*"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "lambda_update_policy_attach" {
  name       = "lambda_update_policy_attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = aws_iam_policy.lambda_update_policy.arn
}

// (Optional) Policy to allow updating S3 bucket policy, if needed
resource "aws_iam_policy" "s3_policy_update" {
  name        = "s3_policy_update"
  description = "Policy to allow updating the bucket policy for data_bucket"
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "s3:PutBucketPolicy",
          "s3:GetBucketPolicy",
          "s3:ListBucket"
        ],
        Resource : aws_s3_bucket.data_bucket.arn
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "s3_policy_update_attach" {
  name       = "s3_policy_update_attachment"
  roles      = [aws_iam_role.lambda_role.name] // Adjust if you want to allow a different role/admin user to update S3 policies
  policy_arn = aws_iam_policy.s3_policy_update.arn
}

// IAM Role for API Gateway to access S3
resource "aws_iam_role" "apigw_s3_role" {
  name = "apigw_s3_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "apigateway.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

// Attach an inline policy to allow listing the bucket
resource "aws_iam_role_policy" "apigw_s3_role_policy" {
  name = "apigw_s3_role_policy"
  role = aws_iam_role.apigw_s3_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:ListBucket"],
        Resource = [aws_s3_bucket.data_bucket.arn]
      }
    ]
  })
}

// S3 Bucket Policy to allow the API Gateway IAM role to list objects
resource "aws_s3_bucket_policy" "data_bucket_policy" {
  bucket = aws_s3_bucket.data_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowAPIGatewayList",
        Effect = "Allow",
        Principal = {
          AWS = aws_iam_role.apigw_s3_role.arn
        },
        Action   = "s3:ListBucket",
        Resource = aws_s3_bucket.data_bucket.arn
      }
    ]
  })
}

