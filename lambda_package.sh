#!/bin/bash
#create deployment package for create_url lambda function
cd lambda/create_url
pip install -r requirements.txt -t .
zip -r ../.. create_url.zip .
cd ../..

#create deployment package for redirect_url lambda function
cd lambda/redirect_url
pip install -r requirements.txt -t .
zip -r ../.. redirect_url.zip .
cd ../..

echo "Deployment packages created successfully"
