# IAM Role for Lambda with S3 and API Gateway permissions
resource "aws_iam_role" "lambda_s3_api_role" {
  name = "LambdaS3ApiRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# IAM Policy for S3 and API Gateway Access
resource "aws_iam_policy" "s3_api_access_policy" {
  name        = "LambdaS3ApiPolicy"
  description = "Allows Lambda to access S3 and API Gateway"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::my-project2-bucket",
          "arn:aws:s3:::my-project2-bucket/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = "execute-api:Invoke"
        Resource = "arn:aws:execute-api:*:*:*/*/*/*"
      }
    ]
  })
}

# Attach Policy to IAM Role
resource "aws_iam_role_policy_attachment" "lambda_s3_api_attach" {
  role       = aws_iam_role.lambda_s3_api_role.name
  policy_arn = aws_iam_policy.s3_api_access_policy.arn
}

# S3 Bucket
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "my-project2-bucket-${random_id.bucket_suffix.hex}"
}
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Lambda Function
resource "aws_lambda_function" "lambda_function" {
  function_name = "S3LambdaFunction"
  role          = aws_iam_role.lambda_s3_api_role.arn
  runtime       = "python3.8"
  handler       = "lambda_function.lambda_handler"
  filename      = "../lambda_function.zip"
  source_code_hash = filebase64sha256("../lambda_function.zip")
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "api_gateway" {
  name        = "S3LambdaApi"
  description = "API Gateway for Lambda Function"
}

# API Gateway Resource
resource "aws_api_gateway_resource" "api_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "s3lambda"
}

# API Gateway Method (GET)
resource "aws_api_gateway_method" "api_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.api_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# API Gateway Integration with Lambda
resource "aws_api_gateway_integration" "api_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.api_resource.id
  http_method = aws_api_gateway_method.api_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.lambda_function.arn}/invocations"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration.api_integration
  ]
  
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  stage_name  = "prod"
}

# Lambda Permission for API Gateway to Invoke Lambda
resource "aws_lambda_permission" "lambda_permission_api_gateway" {
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "apigateway.amazonaws.com"
}
