#!/usr/bin/env python3
"""
End-to-end test for Gripped class management API - BETA Environment
"""

import requests
import json
import base64
import boto3
from botocore.exceptions import ClientError
import time

# BETA Environment Configuration
API_BASE = "https://5957u6zvu3.execute-api.us-east-1.amazonaws.com/prod"
CLIENT_ID = "7l0ec3fthfc4nam0dopqa80dlt"
USER_POOL_ID = "us-east-1_Dj5vTsxK6"

# Test user credentials
TRAINER_EMAIL = "chilukoorieabhinay1@gmail.com"
STUDENT_EMAIL = "chilukoorieabhinay1@gmail.com"  # Using same user for simplicity in testing
PASSWORD = "HelloWorld1"

# AWS clients with beta profile
session = boto3.Session(profile_name='beta')
cognito_client = session.client('cognito-idp', region_name='us-east-1')
dynamodb = session.resource('dynamodb', region_name='us-east-1')

# DynamoDB Table Names - Actual deployed table names from BETA environment
CLASS_TABLE = "GrippedStack-ClassTable13721077-1GEC9Z6585L3A"
STUDENTS_TABLE = "GrippedStack-StudentsTableDAB56938-1DHMKV6J51QMX"
MESSAGES_TABLE = "GrippedStack-MessagesTable05B58A27-Q8CZ3H71F8G1"
DEVICES_TABLE = "GrippedStack-DevicesTableD0A940EE-1EV0TYCCOPAP4"

# Global variables to track test data
created_sessions = []
enrolled_session_id = None
trainer_token = None
student_token = None
trainer_id = None
student_id = None

def authenticate_user(email, role="trainer"):
    """Authenticate user with Cognito and get access token"""
    print(f"🔐 [BETA] Authenticating {role}: {email}...")
    
    try:
        response = cognito_client.admin_initiate_auth(
            UserPoolId=USER_POOL_ID,
            ClientId=CLIENT_ID,
            AuthFlow='ADMIN_NO_SRP_AUTH',
            AuthParameters={
                'USERNAME': email,
                'PASSWORD': PASSWORD
            }
        )
        
        id_token = response['AuthenticationResult']['IdToken']
        
        # Parse the ID token to get the sub (user ID)
        payload = id_token.split('.')[1]
        payload += '=' * (4 - len(payload) % 4)
        decoded = base64.b64decode(payload)
        token_data = json.loads(decoded)
        user_sub = token_data.get('sub')
        
        print(f"✅ [BETA] {role.title()} authentication successful!")
        print(f"👤 User Sub: {user_sub}")
        
        return id_token, user_sub
        
    except ClientError as e:
        if e.response['Error']['Code'] == 'UserNotFoundException':
            print(f"❌ [BETA] User not found. Creating user...")
            try:
                cognito_client.admin_create_user(
                    UserPoolId=USER_POOL_ID,
                    Username=email,
                    UserAttributes=[
                        {'Name': 'email', 'Value': email},
                        {'Name': 'email_verified', 'Value': 'true'}
                    ],
                    TemporaryPassword=PASSWORD,
                    MessageAction='SUPPRESS'
                )
                print(f"✅ [BETA] User created successfully!")
                
                # Set permanent password
                cognito_client.admin_set_user_password(
                    UserPoolId=USER_POOL_ID,
                    Username=email,
                    Password=PASSWORD,
                    Permanent=True
                )
                print(f"✅ [BETA] Password set successfully!")
                
                # Retry authentication
                return authenticate_user(email, role)
                
            except Exception as create_error:
                print(f"❌ [BETA] Failed to create user: {create_error}")
                return None, None
        else:
            print(f"❌ [BETA] Authentication error: {e}")
            return None, None

def test_create_class_multiple_sessions(trainer_token, trainer_id):
    """Test 1: Create class with multiple sessions - BETA"""
    print("\n🏋️  [BETA] TEST 1: Creating class with multiple sessions...")
    
    class_data = {
        "className": "Strength Training Bootcamp",
        "overview": "High-intensity strength training with Josh. Build muscle, burn fat, and get stronger!",
        "classLocationAddress1": "456 Fitness Plaza",
        "classLocationAddress2": "Floor 2",
        "city": "New York",
        "state": "NY",
        "zip": "10001",
        "pricePerClass": 35.00,
        "currency": "USD",
        "productId": "prod_strength_beta_001",
        "priceId": "price_strength_beta_001",
        "classTags": ["strength", "bootcamp", "high-intensity"],
        "sessions": [
            {
                "startDateTime": "2025-09-20T09:00:00Z",
                "endDateTime": "2025-09-20T10:00:00Z",
                "capacity": 15
            },
            {
                "startDateTime": "2025-09-21T09:00:00Z",
                "endDateTime": "2025-09-21T10:00:00Z",
                "capacity": 15
            },
            {
                "startDateTime": "2025-09-22T09:00:00Z",
                "endDateTime": "2025-09-22T10:00:00Z",
                "capacity": 12
            }
        ]
    }
    
    headers = {
        'Authorization': f'Bearer {trainer_token}',
        'Content-Type': 'application/json'
    }
    
    print(f"📡 [BETA] Making request to: {API_BASE}/classes")
    response = requests.post(f"{API_BASE}/classes", json=class_data, headers=headers)
    print(f"📱 Response status: {response.status_code}")
    
    if response.status_code == 200:
        data = response.json()
        sessions = data.get('sessions', [])
        print(f"✅ [BETA] Class created successfully!")
        print(f"📊 Created {len(sessions)} sessions")
        
        for session in sessions:
            session_id = session['sessionId']
            created_sessions.append(session_id)
            print(f"  - Session ID: {session_id}")
            print(f"    Time: {session['startTime']} - {session['endTime']}")
            print(f"    Capacity: {session['capacity']}")
        
        # Verify in DynamoDB
        verify_classes_in_dynamodb(sessions)
        return True
    else:
        print(f"❌ [BETA] Error creating class: {response.status_code} - {response.text}")
        return False

def test_create_second_class(trainer_token, trainer_id):
    """Test 2: Create second class (Yoga) - BETA"""
    print("\n🧘  [BETA] TEST 2: Creating second class (Yoga)...")
    
    class_data = {
        "className": "Morning Yoga Flow",
        "overview": "Start your day with peaceful yoga flow. All levels welcome.",
        "classLocationAddress1": "789 Wellness Center",
        "city": "Brooklyn",
        "state": "NY", 
        "zip": "11201",
        "pricePerClass": 25.00,
        "currency": "USD",
        "productId": "prod_yoga_beta_001",
        "priceId": "price_yoga_beta_001",
        "classTags": ["yoga", "morning", "relaxation"],
        "sessions": [
            {
                "startDateTime": "2025-09-23T07:00:00Z",
                "endDateTime": "2025-09-23T08:00:00Z",
                "capacity": 10
            },
            {
                "startDateTime": "2025-09-24T07:00:00Z",
                "endDateTime": "2025-09-24T08:00:00Z",
                "capacity": 10
            }
        ]
    }
    
    headers = {
        'Authorization': f'Bearer {trainer_token}',
        'Content-Type': 'application/json'
    }
    
    response = requests.post(f"{API_BASE}/classes", json=class_data, headers=headers)
    print(f"📱 Response status: {response.status_code}")
    
    if response.status_code == 200:
        data = response.json()
        sessions = data.get('sessions', [])
        print(f"✅ [BETA] Second class created successfully!")
        
        for session in sessions:
            session_id = session['sessionId']
            created_sessions.append(session_id)
            print(f"  - Session ID: {session_id}")
        
        return True
    else:
        print(f"❌ [BETA] Error creating second class: {response.status_code} - {response.text}")
        return False

def test_student_search_classes(student_token, student_id):
    """Test 3: Student searching for classes by zip code - BETA"""
    print("\n🔍 [BETA] TEST 3: Student searching for classes by zip code...")
    
    headers = {
        'Authorization': f'Bearer {student_token}',
        'Content-Type': 'application/json'
    }
    
    # Search in NYC
    print("🌆 [BETA] Searching for classes in NYC (10001)...")
    response = requests.get(f"{API_BASE}/classes?zip=10001", headers=headers)
    print(f"📱 Response status: {response.status_code}")
    
    if response.status_code == 200:
        classes = response.json()
        print(f"✅ [BETA] Found {len(classes)} classes in NYC!")
        for cls in classes:
            print(f"  - {cls['className']} at {cls['city']}, {cls['state']}")
            if 'pricePerClass' in cls:
                print(f"    Price: ${cls['pricePerClass']} {cls['currency']}")
            if 'capacity' in cls and 'countRegistered' in cls:
                print(f"    Capacity: {cls['countRegistered']}/{cls['capacity']}")
    
    # Search in Brooklyn  
    print("\n🌉 [BETA] Searching for classes in Brooklyn (11201)...")
    response = requests.get(f"{API_BASE}/classes?zip=11201", headers=headers)
    
    if response.status_code == 200:
        classes = response.json()
        print(f"✅ [BETA] Found {len(classes)} classes in Brooklyn!")
        for cls in classes:
            print(f"  - {cls['className']} at {cls['city']}, {cls['state']}")
        return True
    else:
        print(f"❌ [BETA] Error searching classes: {response.status_code} - {response.text}")
        return False

def test_student_enrollment(student_token, student_id):
    """Test 4: Student enrolls in class - BETA"""
    print("\n📝 [BETA] TEST 4: Student enrolling in class...")
    
    if not created_sessions:
        print("❌ [BETA] No created sessions available for enrollment")
        return False
    
    global enrolled_session_id
    enrolled_session_id = created_sessions[0]
    
    headers = {
        'Authorization': f'Bearer {student_token}',
        'Content-Type': 'application/json'
    }
    
    print(f"📋 [BETA] Enrolling in session: {enrolled_session_id}")
    response = requests.post(f"{API_BASE}/classes/{enrolled_session_id}/enroll", headers=headers)
    print(f"📱 Response status: {response.status_code}")
    
    if response.status_code == 200:
        data = response.json()
        print(f"✅ [BETA] Student enrolled successfully!")
        print(f"📊 Enrollment status: {data.get('status', 'UNKNOWN')}")
        
        # Verify enrollment in DynamoDB
        verify_enrollment_in_dynamodb(student_id, enrolled_session_id)
        
        # Verify class count updated
        verify_class_count_updated(enrolled_session_id)
        
        return True
    else:
        print(f"❌ [BETA] Error enrolling student: {response.status_code} - {response.text}")
        return False

def test_student_get_enrolled_classes(student_token, student_id):
    """Test 4b: Student gets their enrolled classes - BETA"""
    print("\n📚 [BETA] TEST 4b: Student getting enrolled classes...")
    
    headers = {
        'Authorization': f'Bearer {student_token}',
        'Content-Type': 'application/json'
    }
    
    print("📋 [BETA] Getting student's enrolled classes...")
    response = requests.get(
        f"{API_BASE}/students/me/classes",
        headers=headers
    )
    
    print(f"📱 Response status: {response.status_code}")
    
    if response.status_code == 200:
        classes_data = response.json()
        print(f"✅ [BETA] Retrieved enrolled classes successfully!")
        print(f"📊 Number of enrolled classes: {classes_data['count']}")
        
        # Verify we have at least one enrolled class
        if classes_data['count'] > 0:
            enrolled_class = classes_data['classes'][0]
            class_info = enrolled_class['class']
            enrollment_info = enrolled_class['enrollment']
            
            print(f"📝 [BETA] First enrolled class: {class_info['className']}")
            print(f"📅 Scheduled time: {class_info['startTime']}")
            print(f"🗓️ Enrolled at: {enrollment_info['enrolledAt']}")
            print(f"📋 Status: {enrollment_info['status']}")
            
            # Verify that the enrolled session matches what we enrolled in
            if enrolled_session_id and class_info.get('sessionId') == enrolled_session_id:
                print("✅ [BETA] Enrolled session found in retrieved classes")
                return True
            else:
                print("❌ [BETA] Enrolled session not found in retrieved classes")
                print(f"Expected session ID: {enrolled_session_id}")
                print(f"Retrieved session ID: {class_info.get('sessionId')}")
                return False
        else:
            print("❌ [BETA] No enrolled classes found")
            return False
    else:
        print(f"❌ [BETA] Error getting enrolled classes: {response.status_code} - {response.text}")
        return False

def test_trainer_get_classes(trainer_token, trainer_id):
    """Test 4c: Trainer gets their created classes - BETA"""
    print("\n👨‍🏫 [BETA] TEST 4c: Trainer getting their created classes...")
    
    headers = {
        'Authorization': f'Bearer {trainer_token}',
        'Content-Type': 'application/json'
    }
    
    print(f"📋 [BETA] Getting classes for trainer: {trainer_id}")
    response = requests.get(
        f"{API_BASE}/classes?trainerId={trainer_id}",
        headers=headers
    )
    
    print(f"📱 Response status: {response.status_code}")
    
    if response.status_code == 200:
        classes_data = response.json()
        print(f"✅ [BETA] Retrieved trainer's classes successfully!")
        print(f"📊 Number of classes found: {len(classes_data)}")
        
        # Verify we have classes from our created sessions
        if len(classes_data) > 0:
            for i, class_info in enumerate(classes_data[:3]):  # Show first 3
                print(f"📝 [BETA] Class {i+1}: {class_info['className']}")
                print(f"📅 Session ID: {class_info['sessionId']}")
                print(f"📍 Location: {class_info['city']}, {class_info['state']}")
                print(f"👥 Capacity: {class_info['countRegistered']}/{class_info['capacity']}")
                print(f"📋 Status: {class_info['status']}")
            
            # Verify that our created sessions are in the list
            trainer_session_ids = {cls['sessionId'] for cls in classes_data}
            created_session_ids = set(created_sessions)
            
            if created_session_ids.issubset(trainer_session_ids):
                print("✅ [BETA] All created sessions found in trainer's class list")
                return True
            else:
                missing_sessions = created_session_ids - trainer_session_ids
                print(f"❌ [BETA] Some created sessions missing: {missing_sessions}")
                return False
        else:
            print("❌ [BETA] No classes found for trainer")
            return False
    else:
        print(f"❌ [BETA] Error getting trainer's classes: {response.status_code} - {response.text}")
        return False

def test_trainer_send_message(trainer_token, trainer_id):
    """Test 5: Trainer sends message to class - BETA"""
    print("\n💬 [BETA] TEST 5: Trainer sending message to class...")
    
    if not enrolled_session_id:
        print("❌ [BETA] No enrolled session for messaging")
        return False
    
    message_data = {
        "messageText": "Welcome to Strength Training Bootcamp! Please bring water and a towel. See you soon!"
    }
    
    headers = {
        'Authorization': f'Bearer {trainer_token}',
        'Content-Type': 'application/json'
    }
    
    print(f"📨 [BETA] Sending message to session: {enrolled_session_id}")
    response = requests.post(f"{API_BASE}/classes/{enrolled_session_id}/messages", json=message_data, headers=headers)
    print(f"📱 Response status: {response.status_code}")
    
    if response.status_code == 200:
        data = response.json()
        message_id = data.get('messageId', 'unknown')
        print(f"✅ [BETA] Message sent successfully!")
        print(f"📧 Message ID: {message_id}")
        print(f"📝 Message: {message_data['messageText'][:50]}...")
        
        # Verify message in DynamoDB
        verify_message_in_dynamodb(message_id, enrolled_session_id)
        
        return True
    else:
        print(f"❌ [BETA] Error sending message: {response.status_code} - {response.text}")
        return False

def test_student_unenroll(student_token, student_id):
    """Test 6: Student unenrolls from class (should mark as cancelled) - BETA"""
    print("\n❌ [BETA] TEST 6: Student unenrolling from class...")
    
    if not enrolled_session_id:
        print("❌ [BETA] No enrolled session available for unenrollment")
        return False
    
    headers = {
        'Authorization': f'Bearer {student_token}',
        'Content-Type': 'application/json'
    }
    
    print(f"📋 [BETA] Unenrolling from session: {enrolled_session_id}")
    response = requests.delete(f"{API_BASE}/classes/{enrolled_session_id}/enroll", headers=headers)
    print(f"📱 Response status: {response.status_code}")
    
    if response.status_code == 200:
        unenroll_data = response.json()
        print(f"✅ [BETA] Student unenrolled successfully!")
        print(f"📊 Message: {unenroll_data['message']}")
        
        # Verify enrollment is marked as CANCELLED (not deleted from students table)
        verify_enrollment_cancelled_in_dynamodb(student_id, enrolled_session_id)
        
        # Verify class registration count decreased
        verify_class_count_decreased(enrolled_session_id)
        
        return True
    else:
        print(f"❌ [BETA] Error unenrolling student: {response.status_code} - {response.text}")
        return False

def test_trainer_cancel_session(trainer_token, trainer_id):
    """Test 7: Trainer cancels one session (should mark as cancelled, not delete) - BETA"""
    print("\n🚫 [BETA] TEST 7: Trainer cancelling one session...")
    
    if len(created_sessions) < 2:
        print("❌ [BETA] Need at least 2 sessions to test cancellation")
        return False
    
    # Cancel the second session
    session_to_cancel = created_sessions[1]
    
    headers = {
        'Authorization': f'Bearer {trainer_token}',
        'Content-Type': 'application/json'
    }
    
    print(f"🗑️  [BETA] Cancelling session: {session_to_cancel}")
    response = requests.delete(f"{API_BASE}/classes/{session_to_cancel}", headers=headers)
    print(f"📱 Response status: {response.status_code}")
    
    if response.status_code == 200:
        cancel_data = response.json()
        print(f"✅ [BETA] Session cancelled successfully!")
        print(f"📊 Message: {cancel_data['message']}")
        
        # Verify session is marked as cancelled in DynamoDB (not deleted)
        verify_session_cancelled_in_dynamodb(session_to_cancel)
        
        return True
    else:
        print(f"❌ [BETA] Error cancelling session: {response.status_code} - {response.text}")
        return False

# DynamoDB Verification Functions
def verify_classes_in_dynamodb(sessions):
    """Verify classes were created in DynamoDB - BETA"""
    print("🗃️  [BETA] Verifying classes in DynamoDB...")
    
    try:
        table = dynamodb.Table(CLASS_TABLE)
        for session in sessions:
            response = table.get_item(Key={'sessionId': session['sessionId']})
            if 'Item' in response:
                class_item = response['Item']
                print(f"✅ [BETA] Session found: {class_item['className']}")
                print(f"  - Status: {class_item.get('status', 'UNKNOWN')}")
                print(f"  - Capacity: {class_item.get('capacity', 'UNKNOWN')}")
                print(f"  - Registered: {class_item.get('countRegistered', 0)}")
            else:
                print(f"❌ [BETA] Session not found: {session['sessionId']}")
                
    except Exception as e:
        print(f"⚠️  [BETA] Could not verify classes in DynamoDB: {e}")

def verify_enrollment_in_dynamodb(student_id, session_id):
    """Verify enrollment was created in DynamoDB - BETA"""
    print("🗃️  [BETA] Verifying enrollment in DynamoDB...")
    
    try:
        table = dynamodb.Table(STUDENTS_TABLE)
        response = table.get_item(Key={'studentId': student_id, 'sessionId': session_id})
        
        if 'Item' in response:
            enrollment = response['Item']
            print(f"✅ [BETA] Enrollment found in DynamoDB")
            print(f"  - Status: {enrollment.get('status', 'UNKNOWN')}")
            print(f"  - Created: {enrollment.get('createdAt', 'UNKNOWN')}")
        else:
            print(f"❌ [BETA] Enrollment not found in DynamoDB")
            
    except Exception as e:
        print(f"⚠️  [BETA] Could not verify enrollment: {e}")

def verify_enrollment_cancelled_in_dynamodb(student_id, session_id):
    """Verify enrollment was marked as CANCELLED (not removed) from DynamoDB - BETA"""
    print("🗃️  [BETA] Verifying enrollment cancelled in DynamoDB...")
    
    try:
        table = dynamodb.Table(STUDENTS_TABLE)
        response = table.get_item(Key={'studentId': student_id, 'sessionId': session_id})
        
        if 'Item' in response:
            enrollment = response['Item']
            status = enrollment.get('status', 'UNKNOWN')
            if status == 'CANCELLED':
                print(f"✅ [BETA] Enrollment correctly marked as CANCELLED in DynamoDB")
            else:
                print(f"❌ [BETA] Enrollment status should be CANCELLED, but is: {status}")
        else:
            print(f"❌ [BETA] Enrollment was incorrectly removed from DynamoDB (should be marked CANCELLED)")
            
    except Exception as e:
        print(f"⚠️  [BETA] Could not verify enrollment status: {e}")

def verify_class_count_updated(session_id):
    """Verify class registration count was incremented - BETA"""
    print("🗃️  [BETA] Verifying class count updated...")
    
    try:
        table = dynamodb.Table(CLASS_TABLE)
        response = table.get_item(Key={'sessionId': session_id})
        
        if 'Item' in response:
            class_item = response['Item']
            count = class_item.get('countRegistered', 0)
            print(f"✅ [BETA] Class registration count: {count}")
        else:
            print(f"❌ [BETA] Class not found for count verification")
            
    except Exception as e:
        print(f"⚠️  [BETA] Could not verify class count: {e}")

def verify_class_count_decreased(session_id):
    """Verify class registration count was decremented - BETA"""
    print("🗃️  [BETA] Verifying class count decreased...")
    
    try:
        table = dynamodb.Table(CLASS_TABLE)
        response = table.get_item(Key={'sessionId': session_id})
        
        if 'Item' in response:
            class_item = response['Item']
            count = class_item.get('countRegistered', 0)
            print(f"✅ [BETA] Class registration count after unenroll: {count}")
        else:
            print(f"❌ [BETA] Class not found for count verification")
            
    except Exception as e:
        print(f"⚠️  [BETA] Could not verify class count: {e}")

def verify_message_in_dynamodb(message_id, session_id):
    """Verify message was stored in DynamoDB - BETA"""
    print("🗃️  [BETA] Verifying message in DynamoDB...")
    
    try:
        table = dynamodb.Table(MESSAGES_TABLE)
        response = table.get_item(Key={'messageId': message_id})
        
        if 'Item' in response:
            message = response['Item']
            print(f"✅ [BETA] Message found in DynamoDB")
            print(f"  - Session: {message.get('sessionId', 'UNKNOWN')}")
            print(f"  - Text: {message.get('messageText', '')[:30]}...")
            print(f"  - Created: {message.get('createdAt', 'UNKNOWN')}")
        else:
            print(f"❌ [BETA] Message not found in DynamoDB")
            
    except Exception as e:
        print(f"⚠️  [BETA] Could not verify message: {e}")

def verify_session_cancelled_in_dynamodb(session_id):
    """Verify session is marked as cancelled (not deleted) - BETA"""
    print("🗃️  [BETA] Verifying session cancelled in DynamoDB...")
    
    try:
        table = dynamodb.Table(CLASS_TABLE)
        response = table.get_item(Key={'sessionId': session_id})
        
        if 'Item' in response:
            class_item = response['Item']
            status = class_item.get('status', 'UNKNOWN')
            print(f"✅ [BETA] Session still exists in DynamoDB")
            print(f"  - Status: {status}")
            if status == 'CANCELLED':
                print(f"✅ [BETA] Session correctly marked as CANCELLED")
            else:
                print(f"❌ [BETA] Session status should be CANCELLED, but is: {status}")
        else:
            print(f"❌ [BETA] Session was incorrectly deleted from DynamoDB")
            
    except Exception as e:
        print(f"⚠️  [BETA] Could not verify session cancellation: {e}")

def main():
    """Main test runner for BETA environment"""
    global trainer_token, student_token, trainer_id, student_id
    
    print("🎯 Starting Gripped Class Management E2E Tests - BETA Environment")
    print("=" * 70)
    
    # Check if table names are still placeholders
    if "PLACEHOLDER" in CLASS_TABLE:
        print("⚠️  WARNING: Table names still contain placeholders!")
        print("   Please update the table names at the top of this file with actual")
        print("   deployed table names from your BETA CDK stack outputs.")
        print("   Example: cdk deploy --profile beta --outputs-file cdk-outputs-beta.json")
        print()
    
    # Authenticate users
    trainer_token, trainer_id = authenticate_user(TRAINER_EMAIL, "trainer")
    if not trainer_token:
        print("❌ [BETA] Failed to authenticate trainer. Exiting.")
        return
    
    student_token, student_id = authenticate_user(STUDENT_EMAIL, "student")
    if not student_token:
        print("❌ [BETA] Failed to authenticate student. Exiting.")
        return
    
    # Test tracking
    tests = [
        ("test_create_class_multiple_sessions", test_create_class_multiple_sessions, (trainer_token, trainer_id)),
        ("test_create_second_class", test_create_second_class, (trainer_token, trainer_id)),
        ("test_student_search_classes", test_student_search_classes, (student_token, student_id)),
        ("test_student_enrollment", test_student_enrollment, (student_token, student_id)),
        ("test_student_get_enrolled_classes", test_student_get_enrolled_classes, (student_token, student_id)),
        ("test_trainer_get_classes", test_trainer_get_classes, (trainer_token, trainer_id)),
        ("test_trainer_send_message", test_trainer_send_message, (trainer_token, trainer_id)),
        ("test_student_unenroll", test_student_unenroll, (student_token, student_id)),
        ("test_trainer_cancel_session", test_trainer_cancel_session, (trainer_token, trainer_id))
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_name, test_func, args) in enumerate(tests, 1):
        print(f"\n{'='*60}")
        print(f"Running test {i}/{len(tests)}: {test_name}")
        print()
        
        try:
            result = test_func(*args)
            if result:
                print(f"✅ [BETA] Test {i} PASSED")
                passed += 1
            else:
                print(f"❌ [BETA] Test {i} FAILED")
                failed += 1
        except Exception as e:
            print(f"❌ [BETA] Test {i} FAILED with exception: {e}")
            failed += 1
    
    # Summary
    print(f"\n{'='*60}")
    print("🎯 [BETA] TEST SUMMARY")
    print("=" * 60)
    print(f"✅ Passed: {passed}/{len(tests)}")
    print(f"❌ Failed: {failed}/{len(tests)}")
    
    if failed == 0:
        print("🎉 [BETA] ALL TESTS PASSED! Class management system is working correctly.")
    else:
        print(f"⚠️  [BETA] {failed} test(s) failed. Please check the output above for details.")
    
    if created_sessions:
        print(f"\n📊 [BETA] Created sessions for testing: {len(created_sessions)}")
        for session_id in created_sessions:
            print(f"  - {session_id}")

if __name__ == "__main__":
    main()
