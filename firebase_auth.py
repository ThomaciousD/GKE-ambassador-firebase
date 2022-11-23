import os
import pyrebase
import json
import firebase_admin
from firebase_admin import auth

# ===== ADMIN APP FOR MANAGING USER ===== #

# App initialization
firebase_admin_app = firebase_admin.initialize_app()

# Signup => using firebase_admin
def signup():
    print("Sign up...")
    email = input("Enter email: ")
    password=input("Enter password: ")
    try:
        # More properties for user creation can be found on SDK Admin doc
        user = auth.create_user(email=email, password=password)

        # Create a custom token using userID after creation
        additional_claims = {'profile': "a-user-profile"}
        custom_token = auth.create_custom_token(user.uid, additional_claims)
        print("JWT custom Token :")
        print(custom_token)
    except Exception as e: 
        print(e)
    return


# ===== FIREBASE APP FOR LOGIN USER ===== #
f = open('firebase-config.json')
config = json.load(f)

firebase_app = pyrebase.initialize_app(config)
authentication = firebase_app.auth()

# Login => using firebase (not admin)
def login():
    print("Log in...")
    email=input("Enter email: ")
    password=input("Enter password: ")
    try:
        user = authentication.sign_in_with_email_and_password(email, password)
        print("User authenticated:")
        print("User ID :")
        print(user['localId'])
        print("User token :")
        print(user['idToken'])

        # Create a custom token using userID after authentication (localId = uid)
        additional_claims = {'profile': "a-user-profile"}
        custom_token = auth.create_custom_token(user["localId"], additional_claims)
        print("JWT custom Token :")
        print(custom_token)

    except Exception as e: 
        print("Authentication failed")
        print(e)
    return


# Main
ans=input("Are you a new user? [y/n]")

if ans == 'n':
    login()
elif ans == 'y':
    signup()
