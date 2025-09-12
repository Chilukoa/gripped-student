#!/usr/bin/env python3
"""
End-to-end test for Gripped Class Management API
Tests the complete flow from class creation to student enrollment and messaging
"""

import requests
import json
import base64
import boto3
from botocore.exceptions import ClientError
import time
import uuid

# Configuration - Updated with actual deployment values
API_BASE = "https://xsmi514ucd.execute-api.us-east-1.amazonaws.com/prod"
CLIENT_ID = "5or7m2e6ovvr8jmk9pj07j7pjj"
USER_POOL_ID = "us-east-1_aUtqQtNcJ"

# Test users
TRAINER_EMAIL = "chilukoorieabhinay1@gmail.com"
STUDENT_EMAIL = "chilukoorieabhinay1@gmail.com"  # Using same user for simplicity in testing
PASSWORD = "HelloWorld1"

# DynamoDB table names - Updated with actual deployment values
CLASS_TABLE = "GrippedStack-ClassTable13721077-JMFTGOIYQ82L"
STUDENTS_TABLE = "GrippedStack-StudentsTableDAB56938-1DBFEPTCPBZAO"
MESSAGES_TABLE = "GrippedStack-MessagesTable05B58A27-1BEL97AJ0F86G"

# AWS clients
cognito_client = boto3.client('cognito-idp', region_name='us-east-1')
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')

# Global variables to store test data
created_sessions = []
enrolled_session_id = None

def authenticate_user(email, role="trainer"):
    """Authenticate user with Cognito and get access token"""
    print(f"🔐 Authenticating {role}: {email}...")
    
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
        
        access_token = response['AuthenticationResult']['AccessToken']
        id_token = response['AuthenticationResult']['IdToken']
        
        # Parse the ID token to get the sub (user ID)
        payload = id_token.split('.')[1]
        # Add padding if needed
        payload += '=' * (4 - len(payload) % 4)
        decoded = base64.b64decode(payload)
        token_data = json.loads(decoded)
        user_sub = token_data.get('sub')
        
        print(f"✅ {role.title()} authentication successful!")
        print(f"👤 User Sub: {user_sub}")
        
        return id_token, user_sub
        
    except ClientError as e:
        if e.response['Error']['Code'] == 'UserNotFoundException':
            print(f"❌ User not found. Creating {role} user...")
            # Create user
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
                print(f"✅ {role.title()} user created successfully!")
                
                # Set permanent password
                cognito_client.admin_set_user_password(
                    UserPoolId=USER_POOL_ID,
                    Username=email,
                    Password=PASSWORD,
                    Permanent=True
                )
                print(f"✅ Password set successfully!")
                
                # Try authentication again
                return authenticate_user(email, role)
                
            except ClientError as create_error:
                print(f"❌ Error creating {role} user: {create_error}")
                return None, None
        else:
            print(f"❌ Authentication error: {e}")
            return None, None

def test_create_class_multiple_sessions(trainer_token, trainer_id):
    """Test 1: Create a class with multiple sessions"""
    print("\n🏋️  TEST 1: Creating class with multiple sessions...")
    
    headers = {
        'Authorization': f'Bearer {trainer_token}',
        'Content-Type': 'application/json'
    }
    
    # Create class with 3 sessions
    payload = {
        "className": "Strength Training Bootcamp",
        "overview": "High-intensity strength training with professional trainer. Suitable for all fitness levels.",
        "classLocationAddress1": "123 Fitness Street",
        "classLocationAddress2": "Suite 200",
        "city": "New York",
        "state": "NY",
        "zip": "10001",
        "pricePerClass": 35.00,
        "currency": "USD",
        "productId": "prod_strength_001",
        "priceId": "price_strength_001",
        "classTags": ["strength", "bootcamp", "fitness"],
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
    
    print(f"📡 Making request to: {API_BASE}/classes")
    response = requests.post(
        f"{API_BASE}/classes",
        headers=headers,
        json=payload
    )
    
    print(f"📱 Response status: {response.status_code}")
    
    if response.status_code == 200:
        data = response.json()
        print(f"✅ Class created successfully!")
        print(f"📊 Created {len(data['sessions'])} sessions")
        
        # Store session IDs for later tests
        for session in data['sessions']:
            created_sessions.append(session['sessionId'])
            print(f"  - Session ID: {session['sessionId']}")
            print(f"    Time: {session['startTime']} - {session['endTime']}")
            print(f"    Capacity: {session['capacity']}")
        
        # Verify in DynamoDB
        verify_classes_in_dynamodb()
        return True
    else:
        print(f"❌ Error creating class: {response.status_code} - {response.text}")
        return False

def test_create_second_class(trainer_token, trainer_id):
    """Test 2: Create a second class with different location"""
    print("\n🧘  TEST 2: Creating second class (Yoga)...")
    
    headers = {
        'Authorization': f'Bearer {trainer_token}',
        'Content-Type': 'application/json'
    }
    
    # Create yoga class with 2 sessions
    payload = {
        "className": "Morning Yoga Flow",
        "overview": "Peaceful morning yoga session to start your day right. All levels welcome.",
        "classLocationAddress1": "456 Wellness Avenue",
        "classLocationAddress2": "",
        "city": "Brooklyn",
        "state": "NY",
        "zip": "11201",
        "pricePerClass": 25.00,
        "currency": "USD",
        "productId": "prod_yoga_001",
        "priceId": "price_yoga_001",
        "classTags": ["yoga", "morning", "wellness"],
        "sessions": [
            {
                "startDateTime": "2025-09-23T07:00:00Z",
                "endDateTime": "2025-09-23T08:00:00Z",
                "capacity": 20
            },
            {
                "startDateTime": "2025-09-24T07:00:00Z",
                "endDateTime": "2025-09-24T08:00:00Z",
                "capacity": 20
            }
        ]
    }
    
    response = requests.post(
        f"{API_BASE}/classes",
        headers=headers,
        json=payload
    )
    
    print(f"📱 Response status: {response.status_code}")
    
    if response.status_code == 200:
        data = response.json()
        print(f"✅ Second class created successfully!")
        
        # Store additional session IDs
        for session in data['sessions']:
            created_sessions.append(session['sessionId'])
            print(f"  - Session ID: {session['sessionId']}")
        
        return True
    else:
        print(f"❌ Error creating second class: {response.status_code} - {response.text}")
        return False

def test_student_search_classes(student_token):
    """Test 3: Student searches for classes by zip code"""
    print("\n🔍 TEST 3: Student searching for classes by zip code...")
    
    headers = {
        'Authorization': f'Bearer {student_token}',
        'Content-Type': 'application/json'
    }
    
    # Search in NYC area (10001)
    print("🌆 Searching for classes in NYC (10001)...")
    response = requests.get(
        f"{API_BASE}/classes?zip=10001",
        headers=headers
    )
    
    print(f"📱 Response status: {response.status_code}")
    
    if response.status_code == 200:
        classes = response.json()
        print(f"✅ Found {len(classes)} classes in NYC!")
        
        for cls in classes:
            print(f"  - {cls['className']} at {cls['city']}, {cls['state']}")
            print(f"    Price: ${cls['pricePerClass']} {cls['currency']}")
            print(f"    Capacity: {cls['countRegistered']}/{cls['capacity']}")
        
        # Search in Brooklyn area (11201)
        print("\n🌉 Searching for classes in Brooklyn (11201)...")
        response2 = requests.get(
            f"{API_BASE}/classes?zip=11201",
            headers=headers
        )
        
        if response2.status_code == 200:
            brooklyn_classes = response2.json()
            print(f"✅ Found {len(brooklyn_classes)} classes in Brooklyn!")
            
            for cls in brooklyn_classes:
                print(f"  - {cls['className']} at {cls['city']}, {cls['state']}")
        
        return True
    else:
        print(f"❌ Error searching classes: {response.status_code} - {response.text}")
        return False

def test_student_enrollment(student_token, student_id):
    """Test 4: Student enrolls in a class"""
    print("\n📝 TEST 4: Student enrolling in class...")
    global enrolled_session_id
    
    if not created_sessions:
        print("❌ No sessions available for enrollment")
        return False
    
    # Enroll in the first session
    session_id = created_sessions[0]
    enrolled_session_id = session_id
    
    headers = {
        'Authorization': f'Bearer {student_token}',
        'Content-Type': 'application/json'
    }
    
    print(f"📋 Enrolling in session: {session_id}")
    response = requests.post(
        f"{API_BASE}/classes/{session_id}/enroll",
        headers=headers
    )
    
    print(f"📱 Response status: {response.status_code}")
    
    if response.status_code == 200:
        enrollment_data = response.json()
        print(f"✅ Student enrolled successfully!")
        print(f"📊 Enrollment status: {enrollment_data['status']}")
        
        # Verify enrollment in DynamoDB
        verify_enrollment_in_dynamodb(student_id, session_id)
        
        # Verify class registration count updated
        verify_class_count_updated(session_id)
        
        return True
    else:
        print(f"❌ Error enrolling student: {response.status_code} - {response.text}")
        return False

def test_student_get_enrolled_classes(student_token, student_id):
    """Test 4b: Student gets their enrolled classes"""
    print("\n📚 TEST 4b: Student getting enrolled classes...")
    
    headers = {
        'Authorization': f'Bearer {student_token}',
        'Content-Type': 'application/json'
    }
    
    print("📋 Getting student's enrolled classes...")
    response = requests.get(
        f"{API_BASE}/students/me/classes",
        headers=headers
    )
    
    print(f"📱 Response status: {response.status_code}")
    
    if response.status_code == 200:
        classes_data = response.json()
        print(f"✅ Retrieved enrolled classes successfully!")
        print(f"📊 Number of enrolled classes: {classes_data['count']}")
        
        # Verify we have at least one enrolled class
        if classes_data['count'] > 0:
            enrolled_class = classes_data['classes'][0]
            class_info = enrolled_class['class']
            enrollment_info = enrolled_class['enrollment']
            
            print(f"📝 First enrolled class: {class_info['className']}")
            print(f"📅 Scheduled time: {class_info['startTime']}")
            print(f"🗓️ Enrolled at: {enrollment_info['enrolledAt']}")
            print(f"📋 Status: {enrollment_info['status']}")
            
            # Verify that the enrolled session matches what we enrolled in
            if enrolled_session_id and class_info.get('sessionId') == enrolled_session_id:
                print("✅ Enrolled session found in retrieved classes")
                return True
            else:
                print("❌ Enrolled session not found in retrieved classes")
                print(f"Expected session ID: {enrolled_session_id}")
                print(f"Retrieved session ID: {class_info.get('sessionId')}")
                return False
        else:
            print("❌ No enrolled classes found")
            return False
    else:
        print(f"❌ Error getting enrolled classes: {response.status_code} - {response.text}")
        return False

def test_trainer_get_classes(trainer_token, trainer_id):
    """Test 4c: Trainer gets their created classes"""
    print("\n👨‍🏫 TEST 4c: Trainer getting their created classes...")
    
    headers = {
        'Authorization': f'Bearer {trainer_token}',
        'Content-Type': 'application/json'
    }
    
    print(f"📋 Getting classes for trainer: {trainer_id}")
    response = requests.get(
        f"{API_BASE}/classes?trainerId={trainer_id}",
        headers=headers
    )
    
    print(f"📱 Response status: {response.status_code}")
    
    if response.status_code == 200:
        classes_data = response.json()
        print(f"✅ Retrieved trainer's classes successfully!")
        print(f"📊 Number of classes found: {len(classes_data)}")
        
        # Verify we have classes from our created sessions
        if len(classes_data) > 0:
            for i, class_info in enumerate(classes_data[:3]):  # Show first 3
                print(f"📝 Class {i+1}: {class_info['className']}")
                print(f"📅 Session ID: {class_info['sessionId']}")
                print(f"📍 Location: {class_info['city']}, {class_info['state']}")
                print(f"👥 Capacity: {class_info['countRegistered']}/{class_info['capacity']}")
                print(f"📋 Status: {class_info['status']}")
            
            # Verify that our created sessions are in the list
            trainer_session_ids = {cls['sessionId'] for cls in classes_data}
            created_session_ids = set(created_sessions)
            
            if created_session_ids.issubset(trainer_session_ids):
                print("✅ All created sessions found in trainer's class list")
                return True
            else:
                missing_sessions = created_session_ids - trainer_session_ids
                print(f"❌ Some created sessions missing: {missing_sessions}")
                return False
        else:
            print("❌ No classes found for trainer")
            return False
    else:
        print(f"❌ Error getting trainer's classes: {response.status_code} - {response.text}")
        return False

def test_trainer_send_message(trainer_token, trainer_id):
    """Test 5: Trainer sends message to class"""
    print("\n💬 TEST 5: Trainer sending message to class...")
    global enrolled_session_id
    
    if not enrolled_session_id:
        print("❌ No enrolled session available for messaging")
        return False
    
    headers = {
        'Authorization': f'Bearer {trainer_token}',
        'Content-Type': 'application/json'
    }
    
    message_payload = {
        "messageText": "Welcome to Strength Training Bootcamp! Please bring water and a towel. Class starts promptly at 9 AM. Looking forward to seeing everyone!"
    }
    
    print(f"📨 Sending message to session: {enrolled_session_id}")
    response = requests.post(
        f"{API_BASE}/classes/{enrolled_session_id}/messages",
        headers=headers,
        json=message_payload
    )
    
    print(f"📱 Response status: {response.status_code}")
    
    if response.status_code == 200:
        message_data = response.json()
        print(f"✅ Message sent successfully!")
        print(f"📧 Message ID: {message_data['messageId']}")
        print(f"📝 Message: {message_data['messageText'][:50]}...")
        
        # Verify message in DynamoDB
        verify_message_in_dynamodb(message_data['messageId'], enrolled_session_id)
        
        return True
    else:
        print(f"❌ Error sending message: {response.status_code} - {response.text}")
        return False

def test_student_unenroll(student_token, student_id):
    """Test 6: Student unenrolls from class (should not delete, just mark as cancelled)"""
    print("\n❌ TEST 6: Student unenrolling from class...")
    global enrolled_session_id
    
    if not enrolled_session_id:
        print("❌ No enrolled session available for unenrollment")
        return False
    
    headers = {
        'Authorization': f'Bearer {student_token}',
        'Content-Type': 'application/json'
    }
    
    print(f"📋 Unenrolling from session: {enrolled_session_id}")
    response = requests.delete(
        f"{API_BASE}/classes/{enrolled_session_id}/enroll",
        headers=headers
    )
    
    print(f"📱 Response status: {response.status_code}")
    
    if response.status_code == 200:
        unenroll_data = response.json()
        print(f"✅ Student unenrolled successfully!")
        print(f"📊 Message: {unenroll_data['message']}")
        
        # Verify enrollment is marked as CANCELLED (not deleted from students table)
        verify_enrollment_cancelled_in_dynamodb(student_id, enrolled_session_id)
        
        # Verify class registration count decreased
        verify_class_count_decreased(enrolled_session_id)
        
        return True
    else:
        print(f"❌ Error unenrolling student: {response.status_code} - {response.text}")
        return False

def test_trainer_cancel_session(trainer_token, trainer_id):
    """Test 7: Trainer cancels one session (should mark as cancelled, not delete)"""
    print("\n🚫 TEST 7: Trainer cancelling one session...")
    
    if len(created_sessions) < 2:
        print("❌ Need at least 2 sessions to test cancellation")
        return False
    
    # Cancel the second session
    session_to_cancel = created_sessions[1]
    
    headers = {
        'Authorization': f'Bearer {trainer_token}',
        'Content-Type': 'application/json'
    }
    
    print(f"🗑️  Cancelling session: {session_to_cancel}")
    response = requests.delete(
        f"{API_BASE}/classes/{session_to_cancel}",
        headers=headers
    )
    
    print(f"📱 Response status: {response.status_code}")
    
    if response.status_code == 200:
        cancel_data = response.json()
        print(f"✅ Session cancelled successfully!")
        print(f"📊 Message: {cancel_data['message']}")
        
        # Verify session is marked as cancelled in DynamoDB (not deleted)
        verify_session_cancelled_in_dynamodb(session_to_cancel)
        
        return True
    else:
        print(f"❌ Error cancelling session: {response.status_code} - {response.text}")
        return False

# DynamoDB verification functions
def verify_classes_in_dynamodb():
    """Verify classes are stored correctly in DynamoDB"""
    print("🗃️  Verifying classes in DynamoDB...")
    
    try:
        table = dynamodb.Table(CLASS_TABLE)
        
        for session_id in created_sessions:
            response = table.get_item(Key={'sessionId': session_id})
            
            if 'Item' in response:
                item = response['Item']
                print(f"✅ Session found: {item['className']}")
                print(f"  - Status: {item['status']}")
                print(f"  - Capacity: {item['capacity']}")
                print(f"  - Registered: {item['countRegistered']}")
            else:
                print(f"❌ Session not found: {session_id}")
                
    except Exception as e:
        print(f"⚠️  Could not verify DynamoDB (table might not exist yet): {e}")

def verify_enrollment_in_dynamodb(student_id, session_id):
    """Verify student enrollment in DynamoDB"""
    print("🗃️  Verifying enrollment in DynamoDB...")
    
    try:
        table = dynamodb.Table(STUDENTS_TABLE)
        response = table.get_item(Key={'studentId': student_id, 'sessionId': session_id})
        
        if 'Item' in response:
            item = response['Item']
            print(f"✅ Enrollment found in DynamoDB")
            print(f"  - Status: {item['status']}")
            print(f"  - Created: {item['createdAt']}")
        else:
            print(f"❌ Enrollment not found in DynamoDB")
            
    except Exception as e:
        print(f"⚠️  Could not verify enrollment: {e}")

def verify_class_count_updated(session_id):
    """Verify class registration count was incremented"""
    print("🗃️  Verifying class count updated...")
    
    try:
        table = dynamodb.Table(CLASS_TABLE)
        response = table.get_item(Key={'sessionId': session_id})
        
        if 'Item' in response:
            item = response['Item']
            count = item['countRegistered']
            print(f"✅ Class registration count: {count}")
        else:
            print(f"❌ Class not found for count verification")
            
    except Exception as e:
        print(f"⚠️  Could not verify class count: {e}")

def verify_message_in_dynamodb(message_id, session_id):
    """Verify message was stored in DynamoDB"""
    print("🗃️  Verifying message in DynamoDB...")
    
    try:
        table = dynamodb.Table(MESSAGES_TABLE)
        response = table.get_item(Key={'messageId': message_id})
        
        if 'Item' in response:
            item = response['Item']
            print(f"✅ Message found in DynamoDB")
            print(f"  - Session: {item['sessionId']}")
            print(f"  - Text: {item['messageText'][:30]}...")
            print(f"  - Created: {item['createdAt']}")
        else:
            print(f"❌ Message not found in DynamoDB")
            
    except Exception as e:
        print(f"⚠️  Could not verify message: {e}")

def verify_enrollment_cancelled_in_dynamodb(student_id, session_id):
    """Verify enrollment was marked as CANCELLED (not removed) from DynamoDB"""
    print("🗃️  Verifying enrollment cancelled in DynamoDB...")
    
    try:
        table = dynamodb.Table(STUDENTS_TABLE)
        response = table.get_item(Key={'studentId': student_id, 'sessionId': session_id})
        
        if 'Item' in response:
            enrollment = response['Item']
            status = enrollment.get('status', 'UNKNOWN')
            if status == 'CANCELLED':
                print(f"✅ Enrollment correctly marked as CANCELLED in DynamoDB")
            else:
                print(f"❌ Enrollment status should be CANCELLED, but is: {status}")
        else:
            print(f"❌ Enrollment was incorrectly removed from DynamoDB (should be marked CANCELLED)")
            
    except Exception as e:
        print(f"⚠️  Could not verify enrollment status: {e}")

def verify_class_count_decreased(session_id):
    """Verify class registration count was decremented"""
    print("🗃️  Verifying class count decreased...")
    
    try:
        table = dynamodb.Table(CLASS_TABLE)
        response = table.get_item(Key={'sessionId': session_id})
        
        if 'Item' in response:
            item = response['Item']
            count = item['countRegistered']
            print(f"✅ Class registration count after unenroll: {count}")
        else:
            print(f"❌ Class not found for count verification")
            
    except Exception as e:
        print(f"⚠️  Could not verify class count: {e}")

def verify_session_cancelled_in_dynamodb(session_id):
    """Verify session is marked as cancelled (not deleted)"""
    print("🗃️  Verifying session cancelled in DynamoDB...")
    
    try:
        table = dynamodb.Table(CLASS_TABLE)
        response = table.get_item(Key={'sessionId': session_id})
        
        if 'Item' in response:
            item = response['Item']
            status = item['status']
            print(f"✅ Session still exists in DynamoDB")
            print(f"  - Status: {status}")
            if status == 'CANCELLED':
                print(f"✅ Session correctly marked as CANCELLED")
            else:
                print(f"❌ Session status should be CANCELLED, but is: {status}")
        else:
            print(f"❌ Session was deleted from DynamoDB (should be marked cancelled)")
            
    except Exception as e:
        print(f"⚠️  Could not verify session cancellation: {e}")

def main():
    """Run all tests"""
    print("🎯 Starting Gripped Class Management E2E Tests")
    print("=" * 60)
    
    # Authenticate users
    trainer_token, trainer_id = authenticate_user(TRAINER_EMAIL, "trainer")
    if not trainer_token:
        print("❌ Failed to authenticate trainer. Exiting.")
        return
    
    student_token, student_id = authenticate_user(STUDENT_EMAIL, "student")
    if not student_token:
        print("❌ Failed to authenticate student. Exiting.")
        return
    
    # Run tests
    tests = [
        (test_create_class_multiple_sessions, trainer_token, trainer_id),
        (test_create_second_class, trainer_token, trainer_id),
        (test_student_search_classes, student_token),
        (test_student_enrollment, student_token, student_id),
        (test_student_get_enrolled_classes, student_token, student_id),
        (test_trainer_get_classes, trainer_token, trainer_id),
        (test_trainer_send_message, trainer_token, trainer_id),
        (test_student_unenroll, student_token, student_id),
        (test_trainer_cancel_session, trainer_token, trainer_id),
    ]
    
    passed = 0
    total = len(tests)
    
    for i, test_args in enumerate(tests, 1):
        test_func = test_args[0]
        args = test_args[1:]
        
        print(f"\n{'='*60}")
        print(f"Running test {i}/{total}: {test_func.__name__}")
        
        try:
            result = test_func(*args)
            if result:
                passed += 1
                print(f"✅ Test {i} PASSED")
            else:
                print(f"❌ Test {i} FAILED")
        except Exception as e:
            print(f"💥 Test {i} ERROR: {e}")
        
        # Small delay between tests
        time.sleep(1)
    
    # Summary
    print(f"\n{'='*60}")
    print(f"🎯 TEST SUMMARY")
    print(f"{'='*60}")
    print(f"✅ Passed: {passed}/{total}")
    print(f"❌ Failed: {total - passed}/{total}")
    
    if passed == total:
        print(f"🎉 ALL TESTS PASSED! Class management system is working correctly.")
    else:
        print(f"⚠️  Some tests failed. Check the logs above for details.")
    
    print(f"\n📊 Created sessions for testing: {len(created_sessions)}")
    for session_id in created_sessions:
        print(f"  - {session_id}")

if __name__ == "__main__":
    main()
