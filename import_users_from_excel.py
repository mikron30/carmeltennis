import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime



# Initialize Firebase Admin
cred = credentials.Certificate('C:/Users/mzilbers/OneDrive - Intel Corporation/Documents/carmeltennis/potent-howl-228108-firebase-adminsdk-44p85-c5ad0e67dd.json')
firebase_admin.initialize_app(cred)

# Load Excel file

df = pd.read_excel('C:/Users/mzilbers/OneDrive - Intel Corporation/Documents/carmeltennis/carmel_users_2024.xlsx',dtype={5: str})
df.iloc[:, 5] = df.iloc[:, 5].astype(str)
data_json = df.to_dict(orient='records')

# Connect to Firestore (replace with Realtime Database if using that)
db = firestore.client()

# Upload each record to Firestore
for record in data_json:
    db.collection('users_2024').add(record)
