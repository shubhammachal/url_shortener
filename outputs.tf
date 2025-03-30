output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.url_shortener.api_endpoint
}

output "create_function_name" {
  description = "Name of the Lambda function for creating short URLs"
  value       = aws_lambda_function.create.function_name
}

output "redirect_function_name" {
  description = "Name of the Lambda function for redirecting short URLs"
  value       = aws_lambda_function.redirect.function_name
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.url_shortener.name
}

output "url_pattern" {
  description = "Pattern for shortened URLs"
  value       = "https://${var.domain_name}/{short_id}"
}

output "website_endpoint" {
  description = "S3 website endpoint"
  value       = aws_s3_bucket_website_configuration.website.website_endpoint
}

output "website_domain" {
  description = "S3 website domain"
  value       = aws_s3_bucket.website.bucket_regional_domain_name
}

output "website_url" {
  description = "Website URL"
  value       = "http://${aws_s3_bucket_website_configuration.website.website_endpoint}"
}