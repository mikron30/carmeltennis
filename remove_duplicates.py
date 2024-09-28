import firebase_admin
from firebase_admin import credentials, firestore

# Initialize the Firebase Admin SDK
cred = credentials.Certificate('C:/Users/mzilbers/OneDrive - Intel Corporation/Documents/carmeltennis/potent-howl-228108-firebase-adminsdk-44p85-c5ad0e67dd.json')
firebase_admin.initialize_app(cred)

# Initialize Firestore client
db = firestore.client()

# Reference to the 'users_2024' collection
users_ref = db.collection('users_2024')

def remove_duplicate_users_by_email():
    try:
        # Step 1: Fetch all documents from the 'users_2024' collection
        users = users_ref.get()

        email_to_firestore_ids = {}
        users_to_remove = []

        # Step 2: Iterate through Firestore users and group by email
        for user in users:
            user_data = user.to_dict()
            email = user_data.get('מייל')  # Assuming 'מייל' is the field for email
            user_id = user.id

            if email:
                if email in email_to_firestore_ids:
                    # If email already exists, it's a duplicate
                    users_to_remove.append(user_id)
                else:
                    # Keep the first occurrence of the email
                    email_to_firestore_ids[email] = user_id

        # Step 3: Remove users from Firestore that are duplicates (based on email)
        for user_id in users_to_remove:
            print(f'Removing duplicate user with ID: {user_id}')
            users_ref.document(user_id).delete()

        print(f'Total duplicate users removed: {len(users_to_remove)}')

    except Exception as e:
        print(f"Error while removing duplicate users: {e}")

# Call the function to remove duplicate users based on email
remove_duplicate_users_by_email()
