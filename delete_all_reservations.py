import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore

# Initialize Firebase Admin SDK
cred = credentials.Certificate('C:/Users/mzilbers/OneDrive - Intel Corporation/Documents/carmeltennis/potent-howl-228108-firebase-adminsdk-44p85-c5ad0e67dd.json')
firebase_admin.initialize_app(cred)

# Get a reference to the Firestore service
db = firestore.client()

def delete_all_reservations(collection_name):
    # Reference to the collection
    collection_ref = db.collection(collection_name)
    docs = collection_ref.stream()

    # Delete documents in batches
    for doc in docs:
        print(f'Deleting document {doc.id}')
        doc.reference.delete()

# Call the function with your collection name
delete_all_reservations('reservations')

print('All reservations have been deleted.')