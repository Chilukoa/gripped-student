#!/usr/bin/env python3
"""
Test script for geospatial search API functionality
Tests the new /classes/search endpoint for trainer discovery
"""

import requests
import boto3
import json
from botocore.exceptions import ClientError

# Configuration
API_BASE = "https://xsmi514ucd.execute-api.us-east-1.amazonaws.com/prod"
COGNITO_REGION = "us-east-1"
USER_POOL_ID = "us-east-1_aUtqQtNcJ"
CLIENT_ID = "5or7m2e6ovvr8jmk9pj07j7pjj"
USERNAME = "abhismashes@gmail.com"
PASSWORD = "HelloWorld1"

def get_cognito_token():
    """Get Cognito JWT token for API authentication"""
    client = boto3.client('cognito-idp', region_name=COGNITO_REGION)
    
    try:
        response = client.admin_initiate_auth(
            UserPoolId=USER_POOL_ID,
            ClientId=CLIENT_ID,
            AuthFlow='ADMIN_NO_SRP_AUTH',
            AuthParameters={
                'USERNAME': USERNAME,
                'PASSWORD': PASSWORD
            }
        )
        
        return response['AuthenticationResult']['IdToken']
    except ClientError as e:
        print(f"❌ Error getting Cognito token: {e}")
        return None

def test_search_api(token, test_name, query_params):
    """Test the geospatial search API with given parameters"""
    print(f"\n🔍 Testing: {test_name}")
    print(f"Query params: {query_params}")
    
    headers = {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    }
    
    try:
        url = f"{API_BASE}/classes/search"
        response = requests.get(url, headers=headers, params=query_params)
        
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            results = result.get('results', [])
            total_found = result.get('totalFound', 0)
            search_location = result.get('searchLocation', {})
            radius = result.get('radiusMiles', 0)
            
            print(f"✅ Success! Found {total_found} classes")
            print(f"Search location: {search_location.get('latitude', 'N/A')}, {search_location.get('longitude', 'N/A')}")
            print(f"Radius: {radius} miles")
            
            # Show date filter if applied
            date_filter = result.get('dateFilter')
            if date_filter:
                print(f"Date filter: {date_filter}")
            
            # Display first few results with distances
            for i, class_result in enumerate(results[:3]):  # Show first 3 results
                distance = class_result.get('distanceMiles', 'N/A')
                class_title = class_result.get('classTitle', 'N/A')
                trainer_name = class_result.get('trainerName', 'N/A')
                tags = class_result.get('tags', [])
                address = class_result.get('address', 'N/A')
                city = class_result.get('city', 'N/A')
                state = class_result.get('state', 'N/A')
                zip_code = class_result.get('zip', 'N/A')
                price = class_result.get('price', 'N/A')
                start_time = class_result.get('startDateTime', 'N/A')
                end_time = class_result.get('endDateTime', 'N/A')
                print(f"  {i+1}. {class_title} - {distance} miles")
                print(f"     Trainer: {trainer_name}")
                print(f"     Tags: {tags}")
                print(f"     Location: {address}, {city}, {state} {zip_code}")
                print(f"     Price: ${price}")
                print(f"     Schedule: {start_time} to {end_time}")
                print()
        else:
            print(f"❌ Error: {response.status_code}")
            print(f"Response: {response.text}")
            
    except Exception as e:
        print(f"❌ Exception: {e}")

def main():
    print("🚀 Testing Geospatial Search API")
    print("=" * 50)
    
    # Get authentication token
    token = get_cognito_token()
    if not token:
        print("❌ Failed to get authentication token")
        return
    
    print("✅ Successfully authenticated with Cognito")
    
    # Test cases
    test_cases = [
        {
            "name": "Search for strength in 75454 (check classTags match)",
            "params": {
                "query": "strength",
                "zipCode": "75454",
                "radiusMiles": "30"
            }
        },
        {
            "name": "Search for Pilates (capital P) in 75454",
            "params": {
                "query": "Pilates",
                "zipCode": "75454",
                "radiusMiles": "30"
            }
        },
        {
            "name": "Search for pilates (lowercase) in 75454",
            "params": {
                "query": "pilates",
                "zipCode": "75454",
                "radiusMiles": "30"
            }
        },
        {
            "name": "Search for Pilates on specific date (2025-10-01)",
            "params": {
                "query": "pilates",
                "zipCode": "75454",
                "radiusMiles": "30",
                "date": "2025-10-01"
            }
        },
        {
            "name": "Search for Pilates on different date (2025-10-08)",
            "params": {
                "query": "pilates",
                "zipCode": "75454",
                "radiusMiles": "30",
                "date": "2025-10-08"
            }
        },
        {
            "name": "Search for geospatial test in San Francisco (94129)",
            "params": {
                "query": "geospatial",
                "zipCode": "94129",
                "radiusMiles": "20"
            }
        },
        {
            "name": "Debug: Check if ZIP 75454 coordinates lookup works",
            "params": {
                "query": "test",  # Any query, just to test coordinate lookup
                "zipCode": "75454",
                "radiusMiles": "1000"  # Very large radius to catch anything
            }
        }
    ]
    
    # Run all test cases
    for test_case in test_cases:
        test_search_api(token, test_case["name"], test_case["params"])
    
    print("\n" + "=" * 50)
    print("🎯 Geospatial Search API Testing Complete!")

if __name__ == "__main__":
    main()
