
# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_glue_api_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect: "Allow",
        Principal: {
          Service: "lambda.amazonaws.com"
        },
        Action: "sts:AssumeRole"
      }
    ]
  })
}

# IAM Policy for Glue and CloudWatch Logs
resource "aws_iam_policy" "lambda_glue_policy" {
  name        = "lambda_glue_policy"
  description = "Policy to allow Lambda to start/stop Glue jobs and write logs"
  policy      = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect   : "Allow",
        Action   : [
          "glue:StartJobRun",
          "glue:StopJobRun",
          "glue:GetJobRun"
        ],
        Resource : "*"
      },
      {
        Effect   : "Allow",
        Action   : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource : "*"
      }
    ]
  })
}

# Attach Policy to IAM Role
resource "aws_iam_role_policy_attachment" "lambda_glue_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_glue_policy.arn
}

# Lambda Function
resource "aws_lambda_function" "glue_lambda" {
  function_name = "start_stop_glue_jobs"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"

  # Path to your Lambda code zip file
  filename      = "../lambda_function.zip"

  source_code_hash = filebase64sha256("../lambda_function.zip")
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "glue_api" {
  name        = "GlueLambdaAPI"
  description = "API Gateway for starting/stopping Glue jobs"
}

# API Gateway Resource (/startglue)
resource "aws_api_gateway_resource" "start_glue_resource" {
  rest_api_id = aws_api_gateway_rest_api.glue_api.id
  parent_id   = aws_api_gateway_rest_api.glue_api.root_resource_id
  path_part   = "startglue"
}

# API Gateway Method (POST)
resource "aws_api_gateway_method" "start_glue_method" {
  rest_api_id   = aws_api_gateway_rest_api.glue_api.id
  resource_id   = aws_api_gateway_resource.start_glue_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# API Gateway Integration (Lambda Proxy)
resource "aws_api_gateway_integration" "start_glue_integration" {
  rest_api_id             = aws_api_gateway_rest_api.glue_api.id
  resource_id             = aws_api_gateway_resource.start_glue_resource.id
  http_method             = aws_api_gateway_method.start_glue_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.glue_lambda.invoke_arn
}

# Lambda Permission for API Gateway Invocation
resource "aws_lambda_permission" "allow_apigateway_invoke" {
  statement_id    = "AllowAPIGatewayInvoke"
  action          = "lambda:InvokeFunction"
  function_name   = aws_lambda_function.glue_lambda.function_name
  principal       = "apigateway.amazonaws.com"
  source_arn      = "${aws_api_gateway_rest_api.glue_api.execution_arn}/*/*"
}

# API Gateway Deployment (with Stage)
resource "aws_api_gateway_deployment" "glue_deployment" {
  rest_api_id              = aws_api_gateway_rest_api.glue_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.start_glue_resource.id,
      aws_api_gateway_method.start_glue_method.id,
      aws_api_gateway_integration.start_glue_integration.id,
    ]))
  }

  depends_on = [
    aws_api_gateway_integration.start_glue_integration,
    aws_lambda_permission.allow_apigateway_invoke,
    aws_lambda_function.glue_lambda,
    aws_iam_role.lambda_role,
    aws_iam_policy.lambda_glue_policy,
    aws_iam_role_policy_attachment.lambda_glue_policy_attachment,
    aws_api_gateway_method.start_glue_method,
    aws_api_gateway_resource.start_glue_resource,
    aws_api_gateway_rest_api.glue_api,
  ]
}

# API Gateway Stage Configuration
resource "aws_api_gateway_stage" "glue_stage" {
  stage_name   = var.stage_name # Replace with your stage name (e.g., 'prod')
  deployment_id = aws_api_gateway_deployment.glue_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.glue_api.id
}

output "api_endpoint_url" {
  value       = "${aws_api_gateway_stage.glue_stage.invoke_url}/startglue"
}
