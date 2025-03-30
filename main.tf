#provider
provider "aws" {    
    region = var.aws_region
  
}

#S3 bucket for storing the state file
resource "aws_s3_bucket" "website" {
    bucket = var.website_bucket_name
    tags = {
        name = "url-shortener-website"
        Environment = var.environment
    }  
}

#configure the bucket for website hosting
resource "aws_s3_bucket_website_configuration" "website" {
    bucket = aws_s3_bucket.website.id
    index_document {
        suffix = "index.html"
        
    }

}

#S3 bucket policy to allow public access to the files
resource "aws_s3_bucket_policy" "website_policy" {
    bucket = aws_s3_bucket.website.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Sid = "PublicReadGetObject"
                Effect = "Allow"
                Principal = "*"
                Action = "s3:GetObject"
                Resource = "arn:aws:s3:::${aws_s3_bucket.website.bucket}/*"
            }
        ]
    })
  
}
#configure the bucket to allow public read access
resource "aws_s3_bucket_public_access_block" "website" {
    bucket = aws_s3_bucket.website.id
    block_public_acls = false
    block_public_policy = false
    ignore_public_acls = false
    restrict_public_buckets = false 
  
}
#uplod the website files to the bucket
resource "aws_s3_object" "index_html" {
    bucket = aws_s3_bucket.website.id
    key = "website/index.html"
    source = "${path.module}/website/index.html"
    content_type  = "text/html"

    #etag is used to track changes to the file
    etag = filemd5("${path.module}/website/index.html")
  
}

#CORS configuration for the bucket
resource "aws_s3_bucket_cors_configuration" "website" {
    bucket = aws_s3_bucket.website.id
    cors_rule {
        allowed_headers = ["*"]
        allowed_methods = ["GET"]
        allowed_origins = ["*"]
        expose_headers = ["ETag"]
        max_age_seconds = 3000
    }
}

#dynamodb_table
resource "aws_dynamodb_table" "url_shortener" {
    name           = var.dynamodb_table_name
    billing_mode   = "PAY_PER_REQUEST"
    hash_key       = "short_id"
    attribute {
        name = "short_id"
        type = "S"
    }
    tags = {
        name = "url-shortener-table"
        Environment = var.environment
    }
}

# IAM Role for Lambda Functions
#local rsource identifier "lambda-exec"
# name assigned to the role "url_shortener_lambda_role"
#jsonencode function is used to convert the JSON object into a string and it is a terraform function
#who can assume this role? lambda.amazonaws.com
resource "aws_iam_role" "lambda_exec" {
  name = "url_shortener_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

#iam poilcy for dynamodb 
resource "aws_iam_policy" "lambda_dynamodb" {
    name = "lambda_dynamodb_policy"
    description = "allow lambda to access dynamodb"
    policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.url_shortener.arn
      }
    ]
  })
}
  

#simple logging policy for lambda to log to cloudwatch
resource "aws_iam_policy" "lambda_logging" {
    name = "lambda_logging_policy"
    description = "allow lambda to log to cloudwatch"
    policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
  
}

#attach dynamodb policy to lambda role
resource "aws_iam_policy_attachment" "lambda_dynamodb" {
    name       = "lambda_dynamodb_attachment"
    policy_arn = aws_iam_policy.lambda_dynamodb.arn
    roles      = [aws_iam_role.lambda_exec.name]
}


#attach logging policy to lambda role
resource "aws_iam_policy_attachment" "lambda_logging" {
    name = "lambda_logging_attachment"
    policy_arn = aws_iam_policy.lambda_logging.arn
    roles = [aws_iam_role.lambda_exec.name]
  
}


#AWS Lambda requires code to be packaged before deployment
#When you deploy through the AWS Console, 
#the packaging happens automatically behind the scenes, 
#but with infrastructure as code tools like Terraform, you need to handle this explicitly.

#The following code block creates a ZIP archive of the lambda function create code
data "archive_file" "create_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/create_url"
  output_path = "${path.module}/lambda/create_url/create_url.zip"
}

#The following code block creates a create lambda function
resource "aws_lambda_function" "create" {
    function_name = "create_url"
    filename = data.archive_file.create_lambda.output_path
    source_code_hash = data.archive_file.create_lambda.output_base64sha256
    handler = "app.lambda_handler"
    runtime = "python3.9"
    role = aws_iam_role.lambda_exec.arn
    timeout = 10

    environment {
        variables = {
            DYNAMODB_TABLE = aws_dynamodb_table.url_shortener.name
            DOMAIN = var.domain_name
        }
    }
  
}
#now we will create a zip file for the lambda function that will be used to get the url
data "archive_file" "redirect_lambda"{
    type = "zip"
    source_dir = "${path.module}/lambda/redirect_url"
    output_path = "${path.module}/lambda/redirect_url/redirect_url.zip"
}
#creating the lambda function that will be used to get the url
resource "aws_lambda_function" "redirect" {
    function_name = "redirect_url"
    filename = data.archive_file.redirect_lambda.output_path
    source_code_hash = data.archive_file.redirect_lambda.output_base64sha256
    handler = "app.lambda_handler"
    role = aws_iam_role.lambda_exec.arn
    runtime = "python3.9"
    timeout = 10

    environment {
        variables = {
            DYNAMODB_TABLE = aws_dynamodb_table.url_shortener.name
            DOMAIN = var.domain_name
        }
    }
}

#API Gateway
resource "aws_apigatewayv2_api" "url_shortener" {
  name = "url-shortener-api"
  protocol_type = "HTTP"
  
}
# API Gateway Stage
#stage is a deployment env for api
#way to manage diff stages of api
#
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.url_shortener.id
  name        = "$default"
  auto_deploy = true
}
#create url integration
resource "aws_apigatewayv2_integration" "create" {
  api_id = aws_apigatewayv2_api.url_shortener.id
  integration_type = "AWS_PROXY"
  integration_method = "POST"
  integration_uri = aws_lambda_function.create.invoke_arn 
}

#create url route
resource "aws_apigatewayv2_route" "create" {
  api_id = aws_apigatewayv2_api.url_shortener.id
  route_key = "POST /create"
  target = "integrations/${aws_apigatewayv2_integration.create.id}"
}

# Redirect URL integration
resource "aws_apigatewayv2_integration" "redirect" {
  api_id             = aws_apigatewayv2_api.url_shortener.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.redirect.invoke_arn
}
#redirect url route
resource "aws_apigatewayv2_route" "redirect" {
  api_id = aws_apigatewayv2_api.url_shortener.id
  route_key = "GET /{short_id}"
  target = "integrations/${aws_apigatewayv2_integration.redirect.id}"
}


#lambda permissions for api gateway
resource "aws_lambda_permission" "create" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.url_shortener.execution_arn}/*/*/create"
  
}
#lambda permission for redirect
resource "aws_lambda_permission" "redirect" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.redirect.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.url_shortener.execution_arn}/*/*/{short_id}"  # Fixed to match route
}