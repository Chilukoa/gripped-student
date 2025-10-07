#!/usr/bin/env python3
"""
Test script for the improved enrollment API with time conflict detection
Tests that enrollment is rejected for overlapping time slots but allowed for different times
"""

import requests
import boto3
import json
from datetime import datetime, timedelta
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

def create_test_class(token, class_data, test_name):
    """Create a test class for enrollment testing"""
    print(f"\n📝 Creating test class: {test_name}")
    
    headers = {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    }
    
    try:
        response = requests.post(f"{API_BASE}/classes", headers=headers, json=class_data)
        
        if response.status_code == 200:
            result = response.json()
            session_id = result.get('sessionId')
            print(f"✅ Created class: {session_id}")
            print(f"   Class: {class_data['className']}")
            print(f"   Time: {class_data['startTime']} to {class_data['endTime']}")
            return session_id
        else:
            print(f"❌ Failed to create class: {response.status_code} - {response.text}")
            return None
            
    except Exception as e:
        print(f"❌ Exception creating class: {e}")
        return None

def enroll_in_class(token, session_id, expected_success=True, test_description=""):
    """Attempt to enroll in a class"""
    print(f"\n🎯 Testing enrollment: {test_description}")
    
    headers = {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    }
    
    try:
        response = requests.post(f"{API_BASE}/classes/{session_id}/enroll", headers=headers)
        
        if expected_success:
            if response.status_code == 200:
                print(f"✅ Enrollment successful (as expected)")
                return True
            else:
                print(f"❌ Enrollment failed when it should have succeeded: {response.status_code} - {response.text}")
                return False
        else:
            if response.status_code == 400:
                result = response.json()
                error_message = result.get('error', 'Unknown error')
                print(f"✅ Enrollment rejected (as expected): {error_message}")
                return True
            else:
                print(f"❌ Enrollment succeeded when it should have failed: {response.status_code}")
                return False
                
    except Exception as e:
        print(f"❌ Exception during enrollment: {e}")
        return False

def unenroll_from_class(token, session_id):
    """Unenroll from a class to clean up"""
    headers = {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    }
    
    try:
        response = requests.delete(f"{API_BASE}/classes/{session_id}/enroll", headers=headers)
        if response.status_code == 200:
            print(f"🧹 Unenrolled from class {session_id}")
        return response.status_code == 200
    except Exception as e:
        print(f"❌ Exception during unenrollment: {e}")
        return False

def main():
    print("🚀 Testing Improved Enrollment API with Time Conflict Detection")
    print("=" * 70)
    
    # Get authentication token
    token = get_cognito_token()
    if not token:
        print("❌ Failed to get authentication token")
        return
    
    print("✅ Successfully authenticated with Cognito")
    
    # Generate test dates/times for tomorrow
    tomorrow = datetime.now() + timedelta(days=1)
    
    # Create test class data with different time slots
    class_1_data = {
        "className": "Morning Yoga - Conflict Test",
        "overview": "Test class for enrollment conflict detection",
        "classLocationAddress1": "123 Test Street",
        "city": "Test City",
        "state": "TX",
        "zip": "75454",
        "startTime": f"{tomorrow.strftime('%Y-%m-%d')}T09:00:00.000Z",
        "endTime": f"{tomorrow.strftime('%Y-%m-%d')}T10:00:00.000Z",
        "capacity": 10,
        "pricePerClass": 25,
        "currency": "USD",
        "classTags": ["test", "yoga"]
    }
    
    class_2_data = {
        "className": "Overlapping Pilates - Conflict Test",
        "overview": "This class overlaps with morning yoga",
        "classLocationAddress1": "456 Another Street",
        "city": "Test City",
        "state": "TX", 
        "zip": "75454",
        "startTime": f"{tomorrow.strftime('%Y-%m-%d')}T09:30:00.000Z",  # Overlaps with class 1
        "endTime": f"{tomorrow.strftime('%Y-%m-%d')}T10:30:00.000Z",
        "capacity": 10,
        "pricePerClass": 30,
        "currency": "USD",
        "classTags": ["test", "pilates"]
    }
    
    class_3_data = {
        "className": "Afternoon Strength - No Conflict",
        "overview": "This class is at a different time",
        "classLocationAddress1": "789 Different Street",
        "city": "Test City",
        "state": "TX",
        "zip": "75454", 
        "startTime": f"{tomorrow.strftime('%Y-%m-%d')}T14:00:00.000Z",  # No overlap
        "endTime": f"{tomorrow.strftime('%Y-%m-%d')}T15:00:00.000Z",
        "capacity": 10,
        "pricePerClass": 35,
        "currency": "USD",
        "classTags": ["test", "strength"]
    }
    
    created_classes = []
    
    try:
        # Create test classes
        session_1 = create_test_class(token, class_1_data, "Morning Yoga (9:00-10:00)")
        session_2 = create_test_class(token, class_2_data, "Overlapping Pilates (9:30-10:30)")
        session_3 = create_test_class(token, class_3_data, "Afternoon Strength (14:00-15:00)")
        
        if not all([session_1, session_2, session_3]):
            print("❌ Failed to create all test classes")
            return
            
        created_classes = [session_1, session_2, session_3]
        
        print("\n" + "=" * 70)
        print("🧪 RUNNING ENROLLMENT TESTS")
        print("=" * 70)
        
        # Test 1: Enroll in first class (should succeed)
        success_1 = enroll_in_class(
            token, session_1, 
            expected_success=True,
            test_description="Enroll in Morning Yoga (first class)"
        )
        
        # Test 2: Try to enroll in overlapping class (should fail)
        success_2 = enroll_in_class(
            token, session_2,
            expected_success=False, 
            test_description="Enroll in Overlapping Pilates (should be rejected due to time conflict)"
        )
        
        # Test 3: Try to enroll in non-overlapping class (should succeed)
        success_3 = enroll_in_class(
            token, session_3,
            expected_success=True,
            test_description="Enroll in Afternoon Strength (different time, should succeed)"
        )
        
        # Test 4: Try to enroll in same class again (should fail - already enrolled)
        success_4 = enroll_in_class(
            token, session_1,
            expected_success=False,
            test_description="Try to enroll in Morning Yoga again (should be rejected - already enrolled)"
        )
        
        print("\n" + "=" * 70)
        print("📊 TEST RESULTS SUMMARY")
        print("=" * 70)
        
        all_tests_passed = all([success_1, success_2, success_3, success_4])
        
        test_results = [
            ("Enroll in first class", success_1, "✅" if success_1 else "❌"),
            ("Reject overlapping enrollment", success_2, "✅" if success_2 else "❌"),
            ("Allow non-overlapping enrollment", success_3, "✅" if success_3 else "❌"),
            ("Reject duplicate enrollment", success_4, "✅" if success_4 else "❌")
        ]
        
        for test_name, result, icon in test_results:
            print(f"{icon} {test_name}: {'PASS' if result else 'FAIL'}")
        
        print(f"\n🎯 Overall Result: {'ALL TESTS PASSED! 🎉' if all_tests_passed else 'SOME TESTS FAILED ❌'}")
        
        # Clean up: Unenroll from classes
        print("\n" + "=" * 70)
        print("🧹 CLEANING UP TEST DATA")
        print("=" * 70)
        
        if success_1:
            unenroll_from_class(token, session_1)
        if success_3:
            unenroll_from_class(token, session_3)
            
    except Exception as e:
        print(f"❌ Test execution error: {e}")
    
    finally:
        # Clean up created classes by setting status to CANCELLED
        print("🗑️  Note: Test classes created will remain in database but are marked for testing")
        print("   They can be manually cleaned up if needed")

if __name__ == "__main__":
    main()
