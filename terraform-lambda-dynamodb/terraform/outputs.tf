# Optional - Define outputs for debugging
output "lambda_function_arn" {
  value = aws_lambda_function.lambda_function.arn
}

output "api_gateway_url" {
  value = aws_api_gateway_rest_api.project2_api.execution_arn
}
