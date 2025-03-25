variable "aws_region" {
  description = "AWS region"
  type = string
  default     = "us-east-1"
}
variable "environment" {
  description = "Environment"
  type = string
  default     = "dev"
}
variable "dynamodb_table_name" {
  description = "DynamoDB table name"
  type = string
  default     = "url_shortener"
  
}
variable "domain_name" {   
    description = "value of domain name"
    type = string
    default     = "shorturl.com"
  
}