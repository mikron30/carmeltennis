import firebase_admin
from firebase_admin import credentials, auth

# Initialize the Firebase app
cred = credentials.Certificate('C:/Users/mzilbers/OneDrive - Intel Corporation/Documents/carmeltennis/potent-howl-228108-firebase-adminsdk-44p85-c5ad0e67dd.json')
firebase_admin.initialize_app(cred)

# Predefined password for all users (ensure this meets Firebase's password policy)
default_password = 'carmeltennis'

# Path to the text file containing email addresses
email_file_path = 'C:/Users/mzilbers/OneDrive - Intel Corporation/Documents/carmeltennis/carmel_users_2024.txt'

# Function to add a user to Firebase Authentication
def add_user_to_firebase(email, password):
    try:
        user = auth.create_user(
            email=email,
            email_verified=False,
            password=password,
            disabled=False
        )
        print('Successfully created new user: {0}'.format(user.uid))
    except Exception as e:
        print('Error creating user {0}: {1}'.format(email, e))

# Read email addresses from file and create users
with open(email_file_path, 'r') as file:
    for email in file:
        email = email.strip()  # Remove any leading/trailing whitespace
        if email:  # Ensure the email is not empty
            add_user_to_firebase(email, default_password)
