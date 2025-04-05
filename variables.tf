variable "table_name" {
  description = "The name of the DynamoDB table"
  type        = string
  default     = "Mydynamotable" # Replace with your desired default table name
}

# Add your variable declarations here

variable "stage_name" {
  description = "The name of the API Gateway stage (e.g., 'prod')"
  type        = string
  default     = "prod" # Replace with your desired default value
}

variable "region" {
  description = "The AWS region to deploy resources"
  default     = "us-east-1"
}
