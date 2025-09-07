const amplifyconfig = ''' {
    "UserAgent": "aws-amplify-cli/2.0",
    "Version": "1.0",
    "auth": {
        "plugins": {
            "awsCognitoAuthPlugin": {
                "UserAgent": "aws-amplify-cli/0.1.0",
                "Version": "0.1.0",
                "IdentityManager": {
                    "Default": {}
                },
                "CognitoUserPool": {
                    "Default": {
                        "PoolId": "us-east-1_aUtqQtNcJ",
                        "AppClientId": "5or7m2e6ovvr8jmk9pj07j7pjj",
                        "Region": "us-east-1"
                    }
                },
                "Auth": {
                    "Default": {
                        "authenticationFlowType": "USER_PASSWORD_AUTH",
                        "socialProviders": [],
                        "usernameAttributes": ["EMAIL"],
                        "signupAttributes": ["EMAIL"],
                        "passwordProtectionSettings": {
                            "passwordPolicyMinLength": 8,
                            "passwordPolicyCharacters": []
                        },
                        "mfaConfiguration": "OFF",
                        "mfaTypes": ["SMS"],
                        "verificationMechanisms": ["EMAIL"]
                    }
                }
            }
        }
    }
}''';
