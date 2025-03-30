import boto3
import time
import hashlib
import json
import os
# initialize the dynamodb boto3 client
dynamodb = boto3.resource('dynamodb')

# base 62 chars
CHARS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

# base 62 encoding
def base62_encode(num, chars=CHARS):
    '''converting to base 62'''
    if num == 0:
        return CHARS[0]
    
    arr = []
    while num:
        rem = num % 62
        arr.append(chars[rem])
        num //= 62
    return ''.join(arr[::-1])

def lambda_handler(event, context):
    try:
        # Parse the request body - Handle both string and dict formats
        if 'body' in event:
            if isinstance(event['body'], str):
                body = json.loads(event['body'])
            else:
                body = event['body']
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'No body found in request'})
            }
        
        # get the original long url
        long_url = body.get('url')  

        if not long_url:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'URL is required'})
            }
        
        # get the table name from the environment variable
        table_name = os.environ.get('DYNAMODB_TABLE', 'url_shortener')
        table = dynamodb.Table(table_name)

        # generate a unique id for the short url
        hash_input = long_url + str(time.time())
        hash_output = hashlib.md5(hash_input.encode()).hexdigest()

        # convert first 8 characters of the hash to int and then to base 62
        number = int(hash_output[:8], 16)   
        short_id = base62_encode(number)

        # store in dynamodb
        table.put_item(
            Item = {
                'short_id': short_id,
                'long_url': long_url,
                'created_at': int(time.time()),
                'click_count': 0
            }
        )

        domain = os.environ.get('DOMAIN', 'yourtinyurl.com')
        # return shortened url
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'  # Add CORS header
            },
            'body': json.dumps({
                'short_url': f"https://{domain}/{short_id}",
                'short_id': short_id
            })
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
