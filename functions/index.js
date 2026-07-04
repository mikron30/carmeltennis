const {setGlobalOptions} = require("firebase-functions/v2");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");

initializeApp();
setGlobalOptions({region: "europe-west3", maxInstances: 10});

const USERS_COLLECTION = "users_2024";
const MANAGER_NAMES = new Set([
  "אודי אש",
  "רני לפלר",
  "עפר בן ישי",
  "מיקי זילברשטיין",
  "מועדון כרמל",
]);

function normalizedName(data) {
  const firstName = String(data["שם פרטי"] || "").trim();
  const lastName = String(data["שם משפחה"] || "").trim();
  return `${firstName} ${lastName}`.trim().replace(/\s+/g, " ");
}

async function assertManager(request, db) {
  const callerEmail = request.auth && request.auth.token.email;
  if (!callerEmail) {
    throw new HttpsError("unauthenticated", "נדרשת התחברות");
  }

  const callerDocuments = await db
      .collection(USERS_COLLECTION)
      .where("מייל", "==", callerEmail)
      .limit(5)
      .get();
  const isManager = callerDocuments.docs.some((document) =>
    MANAGER_NAMES.has(normalizedName(document.data())),
  );

  if (!isManager) {
    throw new HttpsError("permission-denied", "רק מנהל יכול למחוק משתמשים");
  }
}

exports.deleteUserAccount = onCall(async (request) => {
  const email = typeof request.data?.email === "string" ?
    request.data.email.trim() : "";
  if (!email || !email.includes("@")) {
    throw new HttpsError("invalid-argument", "כתובת המייל אינה תקינה");
  }

  const db = getFirestore();
  await assertManager(request, db);

  const targetDocuments = await db
      .collection(USERS_COLLECTION)
      .where("מייל", "==", email)
      .limit(2)
      .get();
  if (targetDocuments.size > 1) {
    throw new HttpsError(
        "failed-precondition",
        "נמצאו כמה רשומות משתמש עם אותו מייל",
    );
  }

  let authenticationUser;
  try {
    authenticationUser = await getAuth().getUserByEmail(email);
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      throw new HttpsError(
          "not-found",
          "המשתמש לא נמצא ב-Firebase Authentication",
      );
    }
    console.error("Failed to find Authentication user", error);
    throw new HttpsError("internal", "חיפוש המשתמש ב-Authentication נכשל");
  }

  try {
    await getAuth().deleteUser(authenticationUser.uid);
    if (!targetDocuments.empty) {
      await targetDocuments.docs[0].ref.delete();
    }
  } catch (error) {
    console.error("Failed to delete user", {
      uid: authenticationUser.uid,
      error,
    });
    throw new HttpsError("internal", "מחיקת המשתמש נכשלה");
  }

  return {
    deleted: true,
    firestoreRecordDeleted: !targetDocuments.empty,
  };
});
