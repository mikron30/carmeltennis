import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase Admin
cred = credentials.Certificate('C:/Users/mzilbers/OneDrive - Intel Corporation/Documents/carmeltennis/potent-howl-228108-firebase-adminsdk-44p85-c5ad0e67dd.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

# Reference to the users_2024 collection
users_collection = db.collection('users_2024')

# Fetch all documents in the collection
users = users_collection.stream()

# Update each document
for user in users:
    user_id = user.id
    users_collection.document(user_id).update({
        'isFirstLogin': True
    })

print("All users have been updated with isFirstLogin=True.")
