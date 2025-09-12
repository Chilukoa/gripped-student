#!/usr/bin/env python3
"""
Create test user for Flutter app testing
"""

import requests
import json
import base64
import boto3
from botocore.exceptions import ClientError

# Configuration
API_BASE = "https://xsmi514ucd.execute-api.us-east-1.amazonaws.com/prod"
CLIENT_ID = "5or7m2e6ovvr8jmk9pj07j7pjj"
USER_POOL_ID = "us-east-1_aUtqQtNcJ"
EMAIL = "chilukoorieabhinay1@gmail.com"
PASSWORD = "HelloWorld1"

# AWS clients
cognito_client = boto3.client('cognito-idp', region_name='us-east-1')

def authenticate_user():
    """Authenticate user with Cognito and get access token"""
    print("🔐 Authenticating user...")
    
    try:
        response = cognito_client.admin_initiate_auth(
            UserPoolId=USER_POOL_ID,
            ClientId=CLIENT_ID,
            AuthFlow='ADMIN_NO_SRP_AUTH',
            AuthParameters={
                'USERNAME': EMAIL,
                'PASSWORD': PASSWORD
            }
        )
        
        access_token = response['AuthenticationResult']['AccessToken']
        id_token = response['AuthenticationResult']['IdToken']
        
        print("✅ Authentication successful!")
        return access_token, id_token
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code == 'UserNotFoundException':
            print("❌ User not found. Creating user...")
            create_user()
            return authenticate_user()  # Retry after creating user
        else:
            print(f"❌ Authentication failed: {e}")
            return None, None

def create_user():
    """Create user in Cognito"""
    try:
        print(f"👤 Creating user: {EMAIL}")
        
        # Create user
        cognito_client.admin_create_user(
            UserPoolId=USER_POOL_ID,
            Username=EMAIL,
            UserAttributes=[
                {'Name': 'email', 'Value': EMAIL},
                {'Name': 'email_verified', 'Value': 'true'}
            ],
            TemporaryPassword=PASSWORD,
            MessageAction='SUPPRESS'
        )
        
        # Set permanent password
        cognito_client.admin_set_user_password(
            UserPoolId=USER_POOL_ID,
            Username=EMAIL,
            Password=PASSWORD,
            Permanent=True
        )
        
        print(f"✅ User created successfully!")
        
    except ClientError as e:
        if e.response['Error']['Code'] == 'UsernameExistsException':
            print("✅ User already exists!")
        else:
            print(f"❌ Error creating user: {e}")
            raise

def create_basic_profile(id_token):
    """Create a basic profile so user doesn't need to go through setup"""
    print("👤 Creating basic user profile...")
    
    headers = {
        'Authorization': f'Bearer {id_token}',
        'Content-Type': 'application/json'
    }
    
    # Basic profile data
    profile_data = {
        "role": "trainer",
        "firstName": "John",
        "lastName": "Doe", 
        "displayName": "John Doe",
        "bio": "Certified personal trainer",
        "phone": "+1234567890",
        "specialty": "Weight Training",
        "address1": "123 Main Street",
        "address2": "Apt 4B",
        "city": "New York",
        "state": "NY",
        "zip": "10001",
        "gender": "Male",
        "certifications": ["NASM", "CPR"]
    }
    
    try:
        response = requests.post(
            f"{API_BASE}/profile/me",
            json=profile_data,
            headers=headers
        )
        
        if response.status_code in [200, 201]:
            print("✅ Profile created successfully!")
            return True
        else:
            print(f"❌ Profile creation failed: {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error creating profile: {e}")
        return False

def main():
    print("🚀 Creating Test User for Flutter App")
    print("=" * 50)
    
    # Authenticate (creates user if needed)
    access_token, id_token = authenticate_user()
    
    if not access_token:
        print("❌ Failed to authenticate")
        return
    
    # Create basic profile
    profile_created = create_basic_profile(id_token)
    
    if profile_created:
        print("\n🎉 Test user setup complete!")
        print(f"📧 Email: {EMAIL}")
        print(f"🔑 Password: {PASSWORD}")
        print("🚀 You can now sign in to your Flutter app!")
    else:
        print("\n⚠️  User authenticated but profile creation failed")
        print("You may need to complete profile setup in the app")

if __name__ == "__main__":
    main()
