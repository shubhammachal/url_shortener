import boto3
import json
import os
import time

# initialize the dynamodb boto3 client
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    try:
        # Get the short_id from path parameters
        if 'pathParameters' in event and event['pathParameters'] and 'short_id' in event['pathParameters']:
            short_id = event['pathParameters']['short_id']
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'short_id is required'})
            }
        
        # get the table name from the environment variable
        table_name = os.environ.get('DYNAMODB_TABLE', 'url_shortener')
        table = dynamodb.Table(table_name)

        # look into dynamodb table
        response = table.get_item(
            Key = {
                'short_id': short_id
            }
        )
        
        # if short_id is found 
        if 'Item' in response:
            original_url = response['Item']['long_url']
            
            # Update click count
            table.update_item(
                Key = {
                    'short_id': short_id
                },
                UpdateExpression = 'SET click_count = click_count + :inc',
                ExpressionAttributeValues = {
                    ':inc': 1
                }
            )
            
            # return HTTP 301 response
            return {
                'statusCode': 301,
                'headers': {
                    'Location': original_url,
                    'Access-Control-Allow-Origin': '*'  # Add CORS header
                },
                'body': ''  # Empty body for redirects
            }
            
        # if short id not found
        return { 
            'statusCode': 404,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'  # Add CORS header
            },
            'body': json.dumps({'error': 'short_id not found'})
        }
    except Exception as e:
        # Log the error and return an error response
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'  # Add CORS header
            },
            'body': json.dumps({
                'error': f"Internal server error: {str(e)}"
            })
        }