import boto3
import json
import os
import time
import hashlib
#intialize the dynamodb boto3 client
dynamodb = boto3.resource('dynamodb')

def redirect_lambda_handler(event, context):
    short_id = event.get('pathParameters').get('short_id')
    if not short_id:
        return{
            'statusCode': 400,
            'body': json.dumps('error: short_id is required')
        }
    
    #get the table name from the environment variable
    table_name = os.environ['DYNAMODB_TABLE']
    table = dynamodb.Table(table_name)

    #look into dynamodb table
    response = table.get_item(
        Key = {
            'short_id': short_id
        }
    )
    #if short_id is found 
    if 'Item' in response:
        original_url = response['Item']['long_url']
        table.update_item(
            Key = {
                'short_id': short_id
            },
            UpdateExpression = 'SET click_count = click_count + :inc',
            ExpressionAttributeValues = {
                ':inc': 1
            }
        )
        #return HTTP 301 response
        return{
            'statusCode': 301,
            'headers': {
                'Location': original_url
            }
        }
    #if short id not found
    return{ 
        'statusCode':404,
        'body' :json.dumps('error: short_id not found') 
    }
