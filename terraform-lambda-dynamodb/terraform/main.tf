# Terraform configuration (IAM Role, Lambda, DynamoDB)

# IAM Role for Lambda
resource "aws_iam_role" "lambda_dynamodb_role" {
  name = "LambdaDynamoDBRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# IAM Policy for DynamoDB permissions
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "LambdaDynamoDBPolicy"
  description = "IAM policy for Lambda to access DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:DescribeTable"]
        Resource = aws_dynamodb_table.example.arn
      }
    ]
  })
}

# Attach Policy to Role
resource "aws_iam_policy_attachment" "lambda_dynamodb_policy_attach" {
  name       = "LambdaDynamoDBPolicyAttachment"
  roles      = [aws_iam_role.lambda_dynamodb_role.name]
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

# Lambda Function
resource "aws_lambda_function" "lambda_function" {
  function_name = "DynamoDBLambdaFunction"
  role          = aws_iam_role.lambda_dynamodb_role.arn
  runtime       = "python3.8"
  handler       = "lambda_function.lambda_handler"
  filename      = "../lambda_function.zip"
  
  environment {
    variables = {
      TABLE_NAME = var.table_name
    }
  }
}

# DynamoDB Table
resource "aws_dynamodb_table" "example" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "apigateway.amazonaws.com"
}

#API Gateway
resource "aws_api_gateway_rest_api" "project2_api" {
  name        = "DynamoDBLambdaAPI"
  description = "API Gateway for Lambda"
}

resource "aws_api_gateway_resource" "lambda_resource" {
  rest_api_id = aws_api_gateway_rest_api.project2_api.id
  parent_id   = aws_api_gateway_rest_api.project2_api.root_resource_id
  path_part   = "lambda"
}

resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.project2_api.id
  resource_id   = aws_api_gateway_resource.lambda_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.project2_api.id
  resource_id             = aws_api_gateway_resource.lambda_resource.id
  http_method             = aws_api_gateway_method.post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn
}
