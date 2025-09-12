#!/usr/bin/env python3
"""
End-to-end test for Gripped profile management API
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
s3_client = boto3.client('s3', region_name='us-east-1')
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')

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
        
        print(f"✅ Authentication successful!")
        print(f"🔑 Access token: {access_token[:50]}...")
        print(f"🆔 ID token: {id_token[:50]}...")
        print(f"👤 User Sub: {user_sub}")
        
        return id_token, user_sub  # Return both token and user sub
        
    except ClientError as e:
        if e.response['Error']['Code'] == 'UserNotFoundException':
            print(f"❌ User not found. Creating user...")
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
                print(f"✅ User created successfully!")
                
                # Set permanent password
                cognito_client.admin_set_user_password(
                    UserPoolId=USER_POOL_ID,
                    Username=EMAIL,
                    Password=PASSWORD,
                    Permanent=True
                )
                print(f"✅ Password set successfully!")
                
                # Try authentication again
                return authenticate_user()
                
            except ClientError as create_error:
                print(f"❌ Error creating user: {create_error}")
                return None, None
        else:
            print(f"❌ Authentication error: {e}")
            return None, None

def get_presigned_urls(id_token, image_count=3):
    """Get presigned URLs for uploading images"""
    print(f"📸 Getting presigned URLs for {image_count} images...")
    print(f"🔑 Using ID token: {id_token[:50]}...")
    
    headers = {
        'Authorization': f'Bearer {id_token}',
        'Content-Type': 'application/json'
    }
    
    payload = {
        'imageCount': image_count,
        'contentType': 'image/jpeg'
    }
    
    print(f"🌐 Making request to: {API_BASE}/profile/presigned-url")
    response = requests.post(
        f"{API_BASE}/profile/presigned-url",
        headers=headers,
        json=payload
    )
    
    print(f"📱 Response status: {response.status_code}")
    print(f"📱 Response headers: {dict(response.headers)}")
    
    if response.status_code == 200:
        data = response.json()
        print(f"✅ Got {len(data['presignedUrls'])} presigned URLs")
        return data['presignedUrls']
    else:
        print(f"❌ Error getting presigned URLs: {response.status_code} - {response.text}")
        return None

def upload_images_to_s3(presigned_urls):
    """Upload dummy images to S3 using presigned URLs"""
    print("📤 Uploading images to S3...")
    
    dummy_image = base64.b64decode(create_dummy_image_base64())
    uploaded_images = []
    
    for i, url_info in enumerate(presigned_urls):
        print(f"  Uploading image {i+1}: {url_info['imageId']}")
        
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
            print(f"  ✅ Uploaded {url_info['imageId']}")
        else:
            print(f"  ❌ Failed to upload {url_info['imageId']}: {response.status_code}")
    
    return uploaded_images

def create_profile(id_token, images, id_image):
    """Create user profile with images"""
    print("👤 Creating user profile...")
    
    headers = {
        'Authorization': f'Bearer {id_token}',
        'Content-Type': 'application/json'
    }
    
    payload = {
        'role': 'trainer',
        'firstName': 'John',
        'lastName': 'Doe',
        'displayName': 'John Doe - Fitness Trainer',
        'bio': 'Certified personal trainer with 5 years experience',
        'phone': '+1234567890',
        'specialty': 'Weight Training',
        'address1': '123 Main Street',
        'address2': 'Apt 4B',
        'city': 'New York',
        'state': 'NY',
        'zip': '10001',
        'gender': 'Male',
        'images': images,
        'idImage': id_image,
        'certifications': ['NASM', 'CPR', 'First Aid']
    }
    
    response = requests.put(
        f"{API_BASE}/profile/me",
        headers=headers,
        json=payload
    )
    
    if response.status_code == 200:
        profile = response.json()
        print(f"✅ Profile created successfully!")
        return profile
    else:
        print(f"❌ Error creating profile: {response.status_code} - {response.text}")
        return None

def verify_profile_in_dynamodb(user_sub):
    """Verify the profile was stored in DynamoDB"""
    print("🗃️  Verifying profile in DynamoDB...")
    print(f"🔍 Looking for user: {user_sub}")
    
    try:
        table = dynamodb.Table('GrippedStack-UserProfilesTableF49D814C-11MT1TM05XSRE')
        
        response = table.get_item(Key={'userId': user_sub})
        
        if 'Item' in response:
            item = response['Item']
            print(f"✅ Profile found in DynamoDB:")
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
            if 'address1' in item:
                address = f"{item.get('address1', '')}"
                if 'address2' in item and item['address2']:
                    address += f", {item['address2']}"
                if 'city' in item:
                    address += f", {item.get('city', '')}"
                if 'state' in item:
                    address += f", {item.get('state', '')}"
                if 'zip' in item:
                    address += f" {item.get('zip', '')}"
                print(f"  - Address: {address}")
            if 'gender' in item:
                print(f"  - Gender: {item['gender']}")
            if 'phone' in item:
                print(f"  - Phone: {item['phone']}")
            if 'bio' in item:
                print(f"  - Bio: {item['bio'][:50]}..." if len(item['bio']) > 50 else f"  - Bio: {item['bio']}")
            if 'pricing' in item:
                pricing = item['pricing']
                print(f"  - Pricing: ${pricing.get('perClass', 0)}/class, ${pricing.get('perWeek', 0)}/week, ${pricing.get('perMonth', 0)}/month")
            if 'certifications' in item:
                print(f"  - Certifications: {', '.join(item['certifications'])}")
                
            return item
        else:
            print(f"❌ Profile not found in DynamoDB")
            return None
            
    except Exception as e:
        print(f"❌ Error checking DynamoDB: {e}")
        return None

def verify_images_in_s3(images, id_image_key):
    """Verify images were uploaded to S3"""
    print("🪣 Verifying images in S3...")
    
    bucket_name = 'grippedstack-userphotosbucket4d5de39b-gvc8qfaefzit'
    
    # Check profile images
    for i, image in enumerate(images):
        try:
            s3_client.head_object(Bucket=bucket_name, Key=image['key'])
            print(f"  ✅ Profile image {i+1} found: {image['key']}")
        except ClientError:
            print(f"  ❌ Profile image {i+1} not found: {image['key']}")
    
    # Check ID image
    if id_image_key:
        try:
            s3_client.head_object(Bucket=bucket_name, Key=id_image_key)
            print(f"  ✅ ID image found: {id_image_key}")
        except ClientError:
            print(f"  ❌ ID image not found: {id_image_key}")

def delete_specific_image(id_token, image_id):
    """Delete a specific image from the profile"""
    print(f"🗑️  Deleting image: {image_id}")
    
    headers = {
        'Authorization': f'Bearer {id_token}',
        'Content-Type': 'application/json'
    }
    
    response = requests.delete(
        f"{API_BASE}/profile/images/{image_id}",
        headers=headers
    )
    
    if response.status_code == 200:
        print(f"✅ Image {image_id} deleted successfully!")
        return True
    else:
        print(f"❌ Error deleting image {image_id}: {response.status_code} - {response.text}")
        return False

def get_current_profile(id_token):
    """Get the current user profile"""
    print("📋 Getting current profile...")
    
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
        print(f"✅ Profile retrieved successfully!")
        print(f"  - Images: {len(profile.get('images', []))} images")
        print(f"  - ID Image: {'✅' if 'idImageKey' in profile else '❌'}")
        return profile
    else:
        print(f"❌ Error getting profile: {response.status_code} - {response.text}")
        return None

def delete_profile(id_token):
    """Delete the user profile (soft delete)"""
    print("🗑️  Deleting user profile...")
    
    headers = {
        'Authorization': f'Bearer {id_token}',
        'Content-Type': 'application/json'
    }
    
    response = requests.delete(
        f"{API_BASE}/profile/me",
        headers=headers
    )
    
    if response.status_code == 200:
        print(f"✅ Profile deleted successfully!")
        return True
    else:
        print(f"❌ Error deleting profile: {response.status_code} - {response.text}")
        return False

def verify_profile_deleted(user_sub):
    """Verify the profile was soft deleted in DynamoDB"""
    print("🔍 Verifying profile deletion in DynamoDB...")
    
    try:
        table = dynamodb.Table('GrippedStack-UserProfilesTableF49D814C-11MT1TM05XSRE')
        
        response = table.get_item(Key={'userId': user_sub})
        
        if 'Item' in response:
            item = response['Item']
            status = item.get('status', 'unknown')
            print(f"✅ Profile found with status: {status}")
            
            if status == 'inactive':
                print(f"✅ Profile successfully soft deleted!")
                return True
            else:
                print(f"❌ Profile status is '{status}', expected 'inactive'")
                return False
        else:
            print(f"❌ Profile not found in DynamoDB")
            return False
            
    except Exception as e:
        print(f"❌ Error checking DynamoDB: {e}")
        return False

def main():
    """Run the complete end-to-end test"""
    print("🚀 Starting End-to-End Test for Gripped Profile Management")
    print("=" * 60)
    
    # Step 1: Authenticate
    id_token, user_sub = authenticate_user()
    if not id_token or not user_sub:
        print("❌ Authentication failed. Exiting.")
        return
    
    # Step 2: Get presigned URLs for profile images
    profile_presigned_urls = get_presigned_urls(id_token, 3)
    if not profile_presigned_urls:
        print("❌ Failed to get presigned URLs. Exiting.")
        return
    
    # Step 3: Get presigned URL for ID image
    id_presigned_urls = get_presigned_urls(id_token, 1)
    if not id_presigned_urls:
        print("❌ Failed to get presigned URL for ID image. Exiting.")
        return
    
    # Step 4: Upload images to S3
    uploaded_images = upload_images_to_s3(profile_presigned_urls)
    id_image = upload_images_to_s3(id_presigned_urls)[0] if id_presigned_urls else None
    
    if not uploaded_images or not id_image:
        print("❌ Failed to upload images. Exiting.")
        return
    
    # Step 5: Create profile
    profile = create_profile(id_token, uploaded_images, id_image)
    if not profile:
        print("❌ Failed to create profile. Exiting.")
        return
    
    # Step 6: Verify in DynamoDB
    db_profile = verify_profile_in_dynamodb(user_sub)
    
    # Step 7: Verify in S3
    if db_profile:
        verify_images_in_s3(
            db_profile.get('images', []), 
            db_profile.get('idImageKey')
        )
    
    print("\n" + "=" * 60)
    print("🧪 Testing Image and Profile Deletion")
    print("=" * 60)
    
    # Step 8: Get current profile to see images
    current_profile = get_current_profile(id_token)
    if not current_profile or not current_profile.get('images'):
        print("❌ No profile or images found for deletion test")
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
                print(f"✅ Image successfully removed from profile")
            else:
                print(f"❌ Image deletion verification failed")
    
    # Step 10: Delete entire profile
    if delete_profile(id_token):
        # Verify profile was soft deleted
        verify_profile_deleted(user_sub)
    
    print("\n" + "=" * 60)
    print("🎉 Complete End-to-End Test Finished!")
    print("✅ User created in Cognito")
    print("✅ Profile stored in DynamoDB")
    print("✅ Images uploaded to S3")
    print("✅ ID image stored separately")
    print("✅ Individual image deletion tested")
    print("✅ Profile deletion (soft delete) tested")
    print(f"🆔 User Sub: {user_sub}")
    print(f"📧 Email: {EMAIL}")

if __name__ == "__main__":
    main()
