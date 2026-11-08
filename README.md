# Beacon

Beacon uses Firebase Authentication for sign-in, Cloud Firestore for profiles
and hunt state, and Firebase Storage for hunt reference and evidence photos.
The app initializes the Firebase options in `lib/firebase_options.dart` and
uses the Firebase-backed services by default. Unit tests can still inject the
in-memory mock services.

## Firebase setup

The checked-in Firebase options target project `beacon-407bc`. In Firebase
Console:

1. Enable Email/Password and Google under **Authentication > Sign-in method**.
2. Add `localhost` and the production host under
   **Authentication > Settings > Authorized domains**.
   For Android Google Sign-In, configure the app's SHA fingerprints and OAuth
   client in Firebase Console.
3. In **Firestore Database**, click **Create database**, create the default
   `(default)` database in **Native mode**, and select a region. The project
   currently configured in the app is `beacon-407bc`; creating a database in a
   different Firebase project will not fix the app. Then deploy the rules and
   Cloud Functions from the repository root:
   `firebase deploy --only firestore:rules,firestore:indexes,storage,functions`.
   The callables read private target coordinates and return only hunter
   distance/bearing or hints allowed by the timed/proximity rules.
   The Firestore collection-group index is required to find hunts a user has
   joined.
4. Ensure Firebase Functions is enabled for the project. Firebase may require
   the Blaze billing plan to deploy callable functions.
5. For photo uploads, set up Firebase Storage in the same project and confirm
   the bucket `beacon-407bc.firebasestorage.app` exists. Storage rules do not
   configure browser CORS. If Flutter Web photo uploads fail with a CORS
   preflight error, configure the bucket's Cloud Storage CORS policy to allow
   the exact app origin, including its port (for local development, run Flutter
   on a fixed port and allow that `http://localhost:<port>` origin). The
   included `storage.cors.json` allows the development origin on port 59559;
   apply it with
   `gcloud storage buckets update gs://beacon-407bc.firebasestorage.app --cors-file=storage.cors.json`
   and run Flutter Web with `flutter run -d chrome --web-port=59559`. Update the
   CORS file if you use a different local or production origin. Do not loosen
   Storage rules to work around a CORS error; Firebase Authentication and the
   Storage rules still enforce access.

For local function and rule testing, run `npm install` in `functions/` and use
the Firebase Emulator Suite (JDK 21 or newer is required by the current Firebase
CLI). Add the authorized emulator configuration before connecting the Flutter
app to a local emulator.

## Hunt behavior

Hunters can resume hunts they created or joined from **Your Current Hunts**
after signing in again. Real hunt state and unlocked-hint progress are stored
in Firestore. The hunt's persisted start time is the timer reference.

Hint 1 unlocks one minute after the hunt starts, Hint 2 after two minutes, and
Hint 3 after three minutes. Entering the 30-meter radius immediately unlocks
all remaining hints; an unlocked hint stays available after leaving the radius.
The three Cloud Functions used for hint access, proximity, and hunt history
must be deployed for these real-hunt features to work.

Five clearly labelled demo profiles use temporary in-memory hunt state and
simulated locations. They do not write to Firebase and do not represent live
GPS or synchronized multiplayer.
"# beacon_1.0" 
