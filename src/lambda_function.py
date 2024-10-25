import gzip
import json
import requests
import boto3
import os

# AWS Secrets Manager client
secrets_client = boto3.client('secretsmanager')

def get_secret(secret_name):
    try:
        response = secrets_client.get_secret_value(SecretId=secret_name) 
        secret = response['SecretString']
        return json.loads(secret)
    except Exception as e:
        print(f"Error retrieving secret: {e}")
        raise e

def lambda_handler(event, context):
    # Get the New Relic API key from AWS Secrets Manager
    event_enabled = os.getenv('NEWRELIC_EVENT_BRIDGE_ENABLED')
    if  event_enabled:  
        secret_name = os.getenv('NEWRELIC_SECRET_NAME')
        if not secret_name:
            raise ValueError("Environment variable NEWRELIC_SECRET_NAME is not set")
        secret = get_secret(secret_name)
        api_key = secret.get('new_relic_license_key')  # Adjust the key as stored in Secrets Manager
    
        account_id = os.getenv('NEWRELIC_ACCOUNT_ID') 
        if not account_id:
            raise ValueError("Environment variable NEWRELIC_ACCOUNT_ID is not set")

        url = f"https://insights-collector.newrelic.com/v1/accounts/{account_id}/events"

        # Process SNS event
        for record in event['Records']:
            sns_message = record['Sns']['Message']
            
            # Assuming the SNS message is a JSON string
            json_data = json.loads(sns_message)

            # Convert JSON to bytes and compress using gzip
            json_bytes = json.dumps(json_data).encode('utf-8')
            compressed_data = gzip.compress(json_bytes)

            # Set up headers, including Content-Encoding and API Key
            headers = {
                "Content-Type": "application/json",
                "Api-Key": api_key,
                "Content-Encoding": "gzip"
            }

            # Make the POST request to New Relic API
            response = requests.post(url, headers=headers, data=compressed_data)
            if response.status_code not in [200, 201]:
                raise Exception(f"Failed to send data to New Relic. Status Code: {response.status_code}, Response: {response.text}")

            # Log the response status and content
            print(f"Response Status Code: {response.status_code}")
            print(f"Response Content: {response.text}")
            # Log the response status and content
            print(f"Response Status Code: {response.status_code}")
            print(f"Response Content: {response.text}")

    # Return a response message for Lambda
    return {
        'statusCode': 200,
        'body': 'Success'
    }
