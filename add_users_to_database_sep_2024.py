import firebase_admin
from firebase_admin import credentials, auth, firestore

# Initialize the Firebase app
cred = credentials.Certificate('C:/Users/mzilbers/OneDrive - Intel Corporation/Documents/carmeltennis/potent-howl-228108-firebase-adminsdk-44p85-c5ad0e67dd.json')
firebase_admin.initialize_app(cred)

# Firestore client
db = firestore.client()

# Add Users
# Add Users
# Add Users
users_to_add = [
    {'מייל': 'edanielle24e@gmail.com', 'שם פרטי': 'דניאל', 'שם משפחה': 'אטליס', 'טלפון': '054-5989323'},
    {'מייל': 'maurabrachetti@gmail.com', 'שם פרטי': 'מאורה', 'שם משפחה': 'ברקטי', 'טלפון': '054-9903057'},
    {'מייל': 'daniel.greidi@gmail.com', 'שם פרטי': 'דניאל', 'שם משפחה': 'גרידינגר', 'טלפון': '054-8100298'},
    {'מייל': 'imree.c@gmail.com', 'שם פרטי': 'אמרי', 'שם משפחה': 'כהן', 'טלפון': '054-3263277'},
    {'מייל': 'yarincarasenti@gmail.com', 'שם פרטי': 'ירין', 'שם משפחה': 'כרסנטי', 'טלפון': '055-8827206'},
    {'מייל': 'avivleviwork@gmail.com', 'שם פרטי': 'אביב', 'שם משפחה': 'לוי', 'טלפון': '050-6839505'},
    {'מייל': 'sagi.moran@gmail.com', 'שם פרטי': 'שגיא', 'שם משפחה': 'מורן', 'טלפון': '054-4254480'},
    {'מייל': 'drornave@gmail.com', 'שם פרטי': 'דרור', 'שם משפחה': 'נוה', 'טלפון': '054-6264650'},
    {'מייל': 'itamar.nie@gmail.com', 'שם פרטי': 'איתמר', 'שם משפחה': 'נירנברג', 'טלפון': '050-4051973'},
    {'מייל': 'eladpollak123@gmail.com', 'שם פרטי': 'אלעד', 'שם משפחה': 'פולק', 'טלפון': '052-7023235'},
    {'מייל': 'antonina1507@gmail.com', 'שם פרטי': 'אנטונינה', 'שם משפחה': 'קודוחובסקי', 'טלפון': '054-5724388'},
    {'מייל': 'bkozhukhov@gmail.com', 'שם פרטי': 'בוריס', 'שם משפחה': 'קודוחובסקי', 'טלפון': '050-4735684'},
    {'מייל': 'amirstst@gmail.com', 'שם פרטי': 'אמיר', 'שם משפחה': 'שטיינר', 'טלפון': '054-7473976'},
    {'מייל': 'tom.shalev95@gmail.com', 'שם פרטי': 'טום', 'שם משפחה': 'שלו', 'טלפון': '0505576557'}
]

# Remove Users
users_to_remove = [
    {"מייל": "dryakira@gmail.com"},
    {"מייל": "izikmayer12@gmail.com"},
    {"מייל": "barakzarfati14@gmail.com"},
    {"מייל": "n329327@netvision.net.il"}
]

# Default password for new users
DEFAULT_PASSWORD = "carmeltennis"

def add_user_to_firestore(uid, email, first_name, last_name, phone):
    try:
        # Add user to Firestore
        db.collection('users_2024').document(uid).set({
            'מייל': email,
            'שם פרטי': first_name,
            'שם משפחה': last_name,
            'טלפון': phone,
        })
        print(f"Added {email} to Firestore.")
    except Exception as e:
        print(f"Error adding {email} to Firestore: {e}")

def add_user_to_auth(email, first_name, last_name, phone):
    try:
        # Create user in Firebase Authentication
        user = auth.create_user(
            email=email,
            password=DEFAULT_PASSWORD,
            display_name=f"{first_name} {last_name}",
        )
        print(f"Created {email} in Firebase Authentication.")
        return user.uid
    except Exception as e:
        print(f"Error creating {email} in Firebase Authentication: {e}")
        return None

def remove_user_from_auth(email):
    try:
        # Fetch user by email
        user = auth.get_user_by_email(email)
        # Delete the user from Firebase Authentication
        auth.delete_user(user.uid)
        print(f"Deleted {email} from Firebase Authentication.")
    except Exception as e:
        print(f"Error removing {email} from Firebase Authentication: {e}")

def remove_user_from_firestore(email):
    try:
        # Query Firestore for the user's document ID based on email
        users_ref = db.collection('users_2024').where('מייל', '==', email)
        docs = users_ref.stream()

        for doc in docs:
            doc.reference.delete()
            print(f"Removed {email} from Firestore.")
    except Exception as e:
        print(f"Error removing {email} from Firestore: {e}")

def add_users():
    for user in users_to_add:
        # Add to Firebase Authentication
        uid = add_user_to_auth(user['מייל'], user['שם פרטי'], user['שם משפחה'], user['טלפון'])
        if uid:
            # Add to Firestore
            add_user_to_firestore(uid, user['מייל'], user['שם פרטי'], user['שם משפחה'], user['טלפון'])

def remove_users():
    for user in users_to_remove:
        # Remove from Firebase Authentication
        remove_user_from_auth(user['מייל'])
        # Remove from Firestore
        remove_user_from_firestore(user['מייל'])

if __name__ == "__main__":
    print("Adding users...")
    add_users()
    
    print("Removing users...")
    remove_users()
