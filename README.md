# Presentation

This project will install the following components on a Google Cloud Project:
- An autopilot GKE cluster
- Emissary Edge-Stack (Ambassador) with an external Load Balancer
- Cert Manager
- A valid SSL certificate for Ambassador's external Load Balancer
- An Ambassador demo mapping targetting http-bin
- A Firebase application
- An hello-world web application
- Firebase JWT Authentication to target the hello-world application through Ambassador Filters

# Pre-requisite

- a Google Cloud Platform project with a valid Billing Account for which you are owner
- a network and subnetwork configured for the region you'll be deploying in

# Create a terraform.tfvars file and set the values for at least
```
GCP_PROJECT="<your_gcp_project_id_here>"
CERT_EMAIL="<your_email_here>"
```
If needed, configure as well the rest of the variables if there are specifics for your project (see all the variables in the variables.tf file)

# Set your env variables
export PROJECT_ID=<your_gcp_project_id_here>

# Authenticate with gcloud sdk and set the project value

```
gcloud auth login
gcloud config set project $PROJECT_ID
```

# Create a service account and a key use it for deployment
```
gcloud iam service-accounts create terraform
gcloud iam service-accounts keys create account.json --iam-account=terraform@${PROJECT_ID}.iam.gserviceaccount.com
```
**Warning** Make sure account.json ".gitignore" is in your conf file

# Give permissions to your service account
```
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:terraform@${PROJECT_ID}.iam.gserviceaccount.com --role roles/owner

gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:terraform@${PROJECT_ID}.iam.gserviceaccount.com --role roles/firebase.admin
```
# Run Terraform scripts
- Authenticate with this service account to Terraform
```
export GOOGLE_APPLICATION_CREDENTIALS=account.json 
```
- Run Terraform
```
terraform plan
terraform apply
```
This might take a while. During the apply process, Terraform should stop and ask you to perform an apply operation. Carefully read the instructions before going to the next steps.
If the plan fails try to run it again, sometimes synchronizations issues happen.

# Configure Authentication in Firebase

Authentication management still misses a Terraform API, so you have to enable it manually in the Firebase Console. 
Firebase authentication is the only thing we found no way to automate.
- Go to Firebase console: https://console.firebase.google.com/
- Select your project
- Go to Authentication > Sign-in method
- Choose ADD
- Select email/password

# Authenticate to Firebase

1. Retrieve the bucket name where the Firebase config was generated
```
 export FIREBASE_CONFIG_BUCKET=`terraform output firebase_config_bucket | sed -e 's:"::g'`
````
2. Download the firebase-config.json file
```
gsutil cp gs://${FIREBASE_CONFIG_BUCKET}/firebase-config.json .
```
3. Authenticate with Firebase
- create and use a virtual env
```
python -m venv create venv
source venv/bin/activate
```
- install dependencies
```
pip3 install -r requirements.txt 
```
- run the login application and authenticate using your firebase users 
```
python3 firebase_auth.py
```
- When authent is successful, you'll get 2 JWT Tokens, one is Firebase generic token, the other one is a custom token. Save them both into env variables:
```
export JWT_TOKEN="eyJhbGciOiJ...."
export JWT_CUSTOM_TOKEN="eyJhbGciOi..."
```
- Use them to target ambassador Hello-World backend, get the curl command lines to execute from Terraform outputs:
```
terraform output -raw hello_world_jwt_backend
terraform output -raw hello_world_jwt_custom_backend
```

If all went well, you should see the following outputs for both curl commands:
```
Hello, world!
Version: 1.0.0
Hostname: hello-world-<pod_number>
```