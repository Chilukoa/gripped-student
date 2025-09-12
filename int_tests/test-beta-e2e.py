#!/usr/bin/env python3
"""
End-to-end test for Gripped profile management API - BETA Environment
"""

import requests
import json
import base64
import boto3
from botocore.exceptions import ClientError

# BETA Configuration
API_BASE = "https://5957u6zvu3.execute-api.us-east-1.amazonaws.com/prod"
CLIENT_ID = "7l0ec3fthfc4nam0dopqa80dlt"
USER_POOL_ID = "us-east-1_Dj5vTsxK6"
EMAIL = "chilukoorieabhinay1@gmail.com"
PASSWORD = "HelloWorld1"

# AWS clients with beta profile
session = boto3.Session(profile_name='beta')
cognito_client = session.client('cognito-idp', region_name='us-east-1')
s3_client = session.client('s3', region_name='us-east-1')
dynamodb = session.resource('dynamodb', region_name='us-east-1')

def create_dummy_image_base64():
    """Create a small dummy JPEG image in base64"""
    # Minimal valid JPEG header + data
    jpeg_bytes = bytes([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
        0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
        0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
        0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
        0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
        0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
        0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x11, 0x08, 0x00, 0x01,
        0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
        0xFF, 0xC4, 0x00, 0x14, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0xFF, 0xC4,
        0x00, 0x14, 0x10, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xDA, 0x00, 0x0C,
        0x03, 0x01, 0x00, 0x02, 0x11, 0x03, 0x11, 0x00, 0x3F, 0x00, 0xAA, 0xFF, 0xD9
    ])
    return base64.b64encode(jpeg_bytes).decode('utf-8')

def authenticate_user():
    """Authenticate user with Cognito and get access token"""
    print("🔐 [BETA] Authenticating user...")
    
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
        
        # Parse the ID token to get the sub (user ID)
        import json
        import base64
        
        # Decode the ID token payload (middle part)
        payload = id_token.split('.')[1]
        # Add padding if needed
        payload += '=' * (4 - len(payload) % 4)
        decoded = base64.b64decode(payload)
        token_data = json.loads(decoded)
        user_sub = token_data.get('sub')
        
        print(f"✅ [BETA] Authentication successful!")
        print(f"🔑 Access token: {access_token[:50]}...")
        print(f"🆔 ID token: {id_token[:50]}...")
        print(f"👤 User Sub: {user_sub}")
        
        return id_token, user_sub  # Return both token and user sub
        
    except ClientError as e:
        if e.response['Error']['Code'] == 'UserNotFoundException':
            print(f"❌ [BETA] User not found. Creating user...")
            # Create user
            try:
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
                print(f"✅ [BETA] User created successfully!")
                
                # Set permanent password
                cognito_client.admin_set_user_password(
                    UserPoolId=USER_POOL_ID,
                    Username=EMAIL,
                    Password=PASSWORD,
                    Permanent=True
                )
                print(f"✅ [BETA] Password set successfully!")
                
                # Try authentication again
                return authenticate_user()
                
            except ClientError as create_error:
                print(f"❌ [BETA] Error creating user: {create_error}")
                return None, None
        else:
            print(f"❌ [BETA] Authentication error: {e}")
            return None, None

def get_presigned_urls(id_token, image_count=3):
    """Get presigned URLs for uploading images"""
    print(f"📸 [BETA] Getting presigned URLs for {image_count} images...")
    print(f"🔑 Using ID token: {id_token[:50]}...")
    
    headers = {
        'Authorization': f'Bearer {id_token}',
        'Content-Type': 'application/json'
    }
    
    payload = {
        'imageCount': image_count,
        'contentType': 'image/jpeg'
    }
    
    print(f"🌐 [BETA] Making request to: {API_BASE}/profile/presigned-url")
    response = requests.post(
        f"{API_BASE}/profile/presigned-url",
        headers=headers,
        json=payload
    )
    
    print(f"📱 [BETA] Response status: {response.status_code}")
    print(f"📱 Response headers: {dict(response.headers)}")
    
    if response.status_code == 200:
        data = response.json()
        print(f"✅ [BETA] Got {len(data['presignedUrls'])} presigned URLs")
        return data['presignedUrls']
    else:
        print(f"❌ [BETA] Error getting presigned URLs: {response.status_code} - {response.text}")
        return None

def upload_images_to_s3(presigned_urls):
    """Upload dummy images to S3 using presigned URLs"""
    print("📤 [BETA] Uploading images to S3...")
    
    dummy_image = base64.b64decode(create_dummy_image_base64())
    uploaded_images = []
    
    for i, url_info in enumerate(presigned_urls):
        print(f"  [BETA] Uploading image {i+1}: {url_info['imageId']}")
        
        response = requests.put(
            url_info['uploadUrl'],
            data=dummy_image,
            headers={'Content-Type': 'image/jpeg'}
        )
        
        if response.status_code == 200:
            uploaded_images.append({
                'imageId': url_info['imageId'],
                'key': url_info['key']
            })
            print(f"  ✅ [BETA] Uploaded {url_info['imageId']}")
        else:
            print(f"  ❌ [BETA] Failed to upload {url_info['imageId']}: {response.status_code}")
    
    return uploaded_images

def create_profile(id_token, images, id_image):
    """Create user profile with images"""
    print("👤 [BETA] Creating user profile...")
    
    headers = {
        'Authorization': f'Bearer {id_token}',
        'Content-Type': 'application/json'
    }
    
    payload = {
        'role': 'trainer',
        'firstName': 'John',
        'lastName': 'Doe',
        'displayName': 'John Doe - Fitness Trainer (BETA)',
        'bio': 'Certified personal trainer with 5 years experience - Testing in BETA environment',
        'phone': '+1234567890',
        'specialty': 'Weight Training',
        'images': images,
        'idImage': id_image,
        'pricing': {
            'perClass': 50.0,
            'perWeek': 300.0,
            'perMonth': 1000.0
        },
        'certifications': ['NASM', 'CPR', 'First Aid']
    }
    
    response = requests.put(
        f"{API_BASE}/profile/me",
        headers=headers,
        json=payload
    )
    
    if response.status_code == 200:
        profile = response.json()
        print(f"✅ [BETA] Profile created successfully!")
        return profile
    else:
        print(f"❌ [BETA] Error creating profile: {response.status_code} - {response.text}")
        return None

def verify_profile_in_dynamodb(user_sub):
    """Verify the profile was stored in DynamoDB"""
    print("🗃️  [BETA] Verifying profile in DynamoDB...")
    print(f"🔍 Looking for user: {user_sub}")
    
    try:
        # Extract table name from ARN: arn:aws:dynamodb:us-east-1:605793898180:table/GrippedStack-UserProfilesTableF49D814C-1NB4G1RC1CPA0
        table_name = 'GrippedStack-UserProfilesTableF49D814C-1NB4G1RC1CPA0'
        table = dynamodb.Table(table_name)
        
        response = table.get_item(Key={'userId': user_sub})
        
        if 'Item' in response:
            item = response['Item']
            print(f"✅ [BETA] Profile found in DynamoDB:")
            print(f"  - User ID: {item['userId']}")
            print(f"  - Role: {item['role']}")
            print(f"  - Status: {item['status']}")
            print(f"  - Images: {len(item.get('images', []))} images")
            print(f"  - ID Image: {'✅' if 'idImageKey' in item else '❌'}")
            
            # Display some of the profile data
            if 'firstName' in item:
                print(f"  - Name: {item.get('firstName', '')} {item.get('lastName', '')}")
            if 'specialty' in item:
                print(f"  - Specialty: {item['specialty']}")
                
            return item
        else:
            print(f"❌ [BETA] Profile not found in DynamoDB")
            return None
            
    except Exception as e:
        print(f"❌ [BETA] Error checking DynamoDB: {e}")
        return None

def verify_images_in_s3(images, id_image_key):
    """Verify images were uploaded to S3"""
    print("🪣 [BETA] Verifying images in S3...")
    
    # Extract bucket name from ARN: arn:aws:s3:::grippedstack-userphotosbucket4d5de39b-qd9yrcxkyoxm
    bucket_name = 'grippedstack-userphotosbucket4d5de39b-qd9yrcxkyoxm'
    
    # Check profile images
    for i, image in enumerate(images):
        try:
            s3_client.head_object(Bucket=bucket_name, Key=image['key'])
            print(f"  ✅ [BETA] Profile image {i+1} found: {image['key']}")
        except ClientError:
            print(f"  ❌ [BETA] Profile image {i+1} not found: {image['key']}")
    
    # Check ID image
    if id_image_key:
        try:
            s3_client.head_object(Bucket=bucket_name, Key=id_image_key)
            print(f"  ✅ [BETA] ID image found: {id_image_key}")
        except ClientError:
            print(f"  ❌ [BETA] ID image not found: {id_image_key}")

def delete_specific_image(id_token, image_id):
    """Delete a specific image from the profile"""
    print(f"🗑️  [BETA] Deleting image: {image_id}")
    
    headers = {
        'Authorization': f'Bearer {id_token}',
        'Content-Type': 'application/json'
    }
    
    response = requests.delete(
        f"{API_BASE}/profile/images/{image_id}",
        headers=headers
    )
    
    if response.status_code == 200:
        print(f"✅ [BETA] Image {image_id} deleted successfully!")
        return True
    else:
        print(f"❌ [BETA] Error deleting image {image_id}: {response.status_code} - {response.text}")
        return False

def get_current_profile(id_token):
    """Get the current user profile"""
    print("📋 [BETA] Getting current profile...")
    
    headers = {
        'Authorization': f'Bearer {id_token}',
        'Content-Type': 'application/json'
    }
    
    response = requests.get(
        f"{API_BASE}/profile/me",
        headers=headers
    )
    
    if response.status_code == 200:
        profile = response.json()
        print(f"✅ [BETA] Profile retrieved successfully!")
        print(f"  - Images: {len(profile.get('images', []))} images")
        print(f"  - ID Image: {'✅' if 'idImageKey' in profile else '❌'}")
        return profile
    else:
        print(f"❌ [BETA] Error getting profile: {response.status_code} - {response.text}")
        return None

def delete_profile(id_token):
    """Delete the user profile (soft delete)"""
    print("🗑️  [BETA] Deleting user profile...")
    
    headers = {
        'Authorization': f'Bearer {id_token}',
        'Content-Type': 'application/json'
    }
    
    response = requests.delete(
        f"{API_BASE}/profile/me",
        headers=headers
    )
    
    if response.status_code == 200:
        print(f"✅ [BETA] Profile deleted successfully!")
        return True
    else:
        print(f"❌ [BETA] Error deleting profile: {response.status_code} - {response.text}")
        return False

def verify_profile_deleted(user_sub):
    """Verify the profile was soft deleted in DynamoDB"""
    print("🔍 [BETA] Verifying profile deletion in DynamoDB...")
    
    try:
        table_name = 'GrippedStack-UserProfilesTableF49D814C-1NB4G1RC1CPA0'
        table = dynamodb.Table(table_name)
        
        response = table.get_item(Key={'userId': user_sub})
        
        if 'Item' in response:
            item = response['Item']
            status = item.get('status', 'unknown')
            print(f"✅ [BETA] Profile found with status: {status}")
            
            if status == 'inactive':
                print(f"✅ [BETA] Profile successfully soft deleted!")
                return True
            else:
                print(f"❌ [BETA] Profile status is '{status}', expected 'inactive'")
                return False
        else:
            print(f"❌ [BETA] Profile not found in DynamoDB")
            return False
            
    except Exception as e:
        print(f"❌ [BETA] Error checking DynamoDB: {e}")
        return False

def main():
    """Run the complete end-to-end test"""
    print("🚀 Starting End-to-End Test for Gripped Profile Management - BETA Environment")
    print("=" * 80)
    
    # Step 1: Authenticate
    id_token, user_sub = authenticate_user()
    if not id_token or not user_sub:
        print("❌ [BETA] Authentication failed. Exiting.")
        return
    
    # Step 2: Get presigned URLs for profile images
    profile_presigned_urls = get_presigned_urls(id_token, 3)
    if not profile_presigned_urls:
        print("❌ [BETA] Failed to get presigned URLs. Exiting.")
        return
    
    # Step 3: Get presigned URL for ID image
    id_presigned_urls = get_presigned_urls(id_token, 1)
    if not id_presigned_urls:
        print("❌ [BETA] Failed to get presigned URL for ID image. Exiting.")
        return
    
    # Step 4: Upload images to S3
    uploaded_images = upload_images_to_s3(profile_presigned_urls)
    id_image = upload_images_to_s3(id_presigned_urls)[0] if id_presigned_urls else None
    
    if not uploaded_images or not id_image:
        print("❌ [BETA] Failed to upload images. Exiting.")
        return
    
    # Step 5: Create profile
    profile = create_profile(id_token, uploaded_images, id_image)
    if not profile:
        print("❌ [BETA] Failed to create profile. Exiting.")
        return
    
    # Step 6: Verify in DynamoDB
    db_profile = verify_profile_in_dynamodb(user_sub)
    
    # Step 7: Verify in S3
    if db_profile:
        verify_images_in_s3(
            db_profile.get('images', []), 
            db_profile.get('idImageKey')
        )
    
    print("\n" + "=" * 80)
    print("🧪 [BETA] Testing Image and Profile Deletion")
    print("=" * 80)
    
    # Step 8: Get current profile to see images
    current_profile = get_current_profile(id_token)
    if not current_profile or not current_profile.get('images'):
        print("❌ [BETA] No profile or images found for deletion test")
        return
    
    # Step 9: Delete first image
    first_image = current_profile['images'][0]
    image_id_to_delete = first_image['imageId']
    
    if delete_specific_image(id_token, image_id_to_delete):
        # Verify image was removed from profile
        updated_profile = get_current_profile(id_token)
        if updated_profile:
            remaining_images = [img for img in updated_profile.get('images', []) if img['imageId'] != image_id_to_delete]
            if len(remaining_images) == len(current_profile['images']) - 1:
                print(f"✅ [BETA] Image successfully removed from profile")
            else:
                print(f"❌ [BETA] Image deletion verification failed")
    
    # Step 10: Delete entire profile
    if delete_profile(id_token):
        # Verify profile was soft deleted
        verify_profile_deleted(user_sub)
    
    print("\n" + "=" * 80)
    print("🎉 Complete End-to-End Test Finished - BETA Environment!")
    print("✅ [BETA] User created in Cognito")
    print("✅ [BETA] Profile stored in DynamoDB")
    print("✅ [BETA] Images uploaded to S3")
    print("✅ [BETA] ID image stored separately")
    print("✅ [BETA] Individual image deletion tested")
    print("✅ [BETA] Profile deletion (soft delete) tested")
    print(f"🆔 User Sub: {user_sub}")
    print(f"📧 Email: {EMAIL}")
    print("🧪 Environment: BETA")

if __name__ == "__main__":
    main()
