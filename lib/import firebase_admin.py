import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
cred = credentials.Certificate('C:/Users/mzilbers/OneDrive - Intel Corporation/Documents/carmeltennis/potent-howl-228108-firebase-adminsdk-44p85-c5ad0e67dd.json')
firebase_admin.initialize_app(cred)

# Initialize Firestore
db = firestore.client()

def add_is_first_login():
    # Reference the users_2024 collection
    users_ref = db.collection('users_2024')

    # Fetch all users from the collection
    users = users_ref.stream()

    for user in users:
        user_data = user.to_dict()

        # Check if 'isFirstLogin' is missing
        if 'isFirstLogin' not in user_data:
            print(f"Updating user: {user_data['email']}, adding 'isFirstLogin = true'")

            # Update the user's document to add 'isFirstLogin' = true
            users_ref.document(user.id).update({
                'isFirstLogin': True
            })

if __name__ == "__main__":
    add_is_first_login()
    print("Completed adding 'isFirstLogin = true' to users who didn't have it.")
