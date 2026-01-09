import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_reminder/components/Backend_Integration/Firebase_Backend.dart';
import 'package:tablet_reminder/components/Backend_Integration/models/user_model.dart';
import 'package:tablet_reminder/components/Backend_Integration/Firebase_cloud_messaging_backend.dart';



class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Stream<User?> authStatesChange() => _firebaseAuth.authStateChanges();

  // ✅ Get User Email
  String getUserEmail() => _firebaseAuth.currentUser?.email ?? 'User';

  // ✅ Fetch Patient Group ID Efficiently
  Future<String?> getPatientGroupID(String uid) async {
    final firestore = FirebaseFirestore.instance;
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    print("📡 Fetching patientGroupID for user: $uid from 'patientGroups' collection...");

    // 🔥 Step 1: Check if the user exists in any patient group in 'patientGroups' collection
    QuerySnapshot querySnapshot = await firestore
        .collection('patientGroups')
        .where('caregivers', arrayContains: uid) // ✅ Finds where the user is a caregiver
        .limit(1) // Only get the first match
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      String patientGroupID = querySnapshot.docs.first.id; // ✅ Get the patient group document ID
      print("✅ Found patientGroupID in 'patientGroups' collection: $patientGroupID");

      // ✅ Store patientGroupID in SharedPreferences for faster access
      await prefs.setString('patientGroupID', patientGroupID);
      return patientGroupID;
    }

    // 🔥 Step 2: If Firestore has no patient group, remove old SharedPreferences data
    print("❌ No patient group found for user. Clearing SharedPreferences...");
    await prefs.remove('patientGroupID');
    return null;
  }

  String generateNonce([int length = 32]) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _updateUserFirestore(UserCredential userCredential, String fullName, String signInMethod) async {
    final user = userCredential.user;
    if (user == null) return;

    final firebaseBackend = FirebaseBackend();

    // Get existing user data to preserve patientGroupID
    UserModel? existingUser = await firebaseBackend.getUserData(user.uid);

    await firebaseBackend.createOrUpdateUser(
      uid: user.uid,
      email: user.email ?? "No Email",
      fullName: fullName,
      signInMethod: signInMethod,
      patientGroupID: existingUser?.patientGroupID, // Preserve existing patientGroupID
    );

    print("✅ User data updated in Firestore!");
  }
  Future<String?> _fetchUserFullName(String? uid) async {
    if (uid == null) return null;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (userDoc.exists && userDoc.data()?['fullName'] != null) {
      print("✅ Found existing full name in Firestore: ${userDoc['fullName']}");
      return userDoc['fullName'];
    }

    print("⚠️ No existing full name found in Firestore.");
    return null; // If no name is found, return null
  }

  Future<UserCredential?> loginWithApple(BuildContext context) async {
    try {
      // ✅ Step 1: Trigger Apple Sign-In
      print("🔄 Starting Apple Sign-In process...");
      final rawNonce = generateNonce();
      final hashedNonce = sha256ofString(rawNonce);

      if (FirebaseAuth.instance.currentUser != null) {
        print("⚠️ A user is already signed in: ${FirebaseAuth.instance.currentUser!.uid}");
        print("🔄 Signing out current user before proceeding...");
        await FirebaseAuth.instance.signOut(); // 🔥 Ensure a fresh sign-in
      }

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName
        ],
        webAuthenticationOptions: WebAuthenticationOptions(
          redirectUri: Uri.parse('https://tablet-reminder-app-111204.firebaseapp.com/__/auth/handler'),
          clientId: 'com.anandkamma.tabletreminder',
        ),        nonce: hashedNonce,
        state: generateNonce(),
      );
      print("✅ Apple Sign-In Successful: ${appleCredential}");
      print("🔍 Identity Token: ${appleCredential.identityToken}");
      print("🔍 Authorization Code: ${appleCredential.authorizationCode}");
      print("🔍 Raw Nonce: $rawNonce");
      print("🔍 Hashed Nonce: $hashedNonce");

      if (appleCredential.identityToken == null) {
        print("❌ Error: Apple Sign-In did not return an identityToken.");
        return null;
      }

      // ✅ Step 2: Create OAuth credential using the Apple token
      final oAuthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
        rawNonce: rawNonce,
      );

      // ✅ Step 3: Sign in with Firebase
      print("🔄 Signing in with Firebase...");
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(oAuthCredential);
      print("✅ Firebase Sign-In Successful! User: ${userCredential.user?.uid}");

      // Initialize FCM and save token
      try {
        await FCMService().initialize();
      } catch (e) {
        print('⚠️ FCM initialization failed (non-critical): $e');
      }

      String? fullName = await _fetchUserFullName(userCredential.user?.uid);

      // ✅ Step 4: Handle missing full name (if Apple doesn't provide it)
      if (fullName == null || fullName.isEmpty) {
        // ✅ If no name exists in Firestore, check if Apple provided one
        fullName = appleCredential.givenName != null
            ? "${appleCredential.givenName} ${appleCredential.familyName}".trim()
            : null;

        // ✅ If Apple didn't provide a name, ask the user
        if (fullName == null || fullName.isEmpty) {
          print("⚠️ No name found in Firestore. Asking user...");
          fullName = await _askForUserName(context);
        }

        // ✅ Save the name in Firestore
        await _updateUserFirestore(userCredential, fullName, "Apple");
      }
      return userCredential; // 🔥 Ensure UserCredential is returned

    } catch (e) {
      print("❌ Error during Apple Sign-In: $e");

      if (e.toString().contains('user-mismatch')) {
        print("⚠️ Detected user mismatch error. Signing out and retrying...");
        await FirebaseAuth.instance.signOut();

        try {
          print("🔄 Retrying Apple Sign-In...");
          final rawNonce = generateNonce();
          final hashedNonce = sha256ofString(rawNonce);

          final appleCredential = await SignInWithApple.getAppleIDCredential(
            scopes: [
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
            webAuthenticationOptions: WebAuthenticationOptions(
              redirectUri: Uri.parse('https://tablet-reminder-app-111204.firebaseapp.com/__/auth/handler'),
              clientId: 'com.anandkamma.tabletreminder',
            ),            nonce: hashedNonce,
            state: generateNonce(),
          );

          if (appleCredential.identityToken == null) {
            print("❌ Error: Apple Sign-In did not return an identityToken.");
            return null;
          }

          final oAuthCredential = OAuthProvider('apple.com').credential(
            idToken: appleCredential.identityToken,
            rawNonce: rawNonce,
          );

          print("🔄 Signing in with Firebase after retry...");
          UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(oAuthCredential);
          print("✅ Firebase Sign-In Successful after retry! User: ${userCredential.user?.uid}");

          // Initialize FCM and save token
          try {
            await FCMService().initialize();
          } catch (e) {
            print('⚠️ FCM initialization failed (non-critical): $e');
          }

          // ✅ Handle name input if Apple does not provide it
          String? fullName = appleCredential.givenName != null
              ? "${appleCredential.givenName} ${appleCredential.familyName}".trim()
              : null;

          if (fullName == null || fullName.isEmpty) {
            print("⚠️ Apple did not provide a full name. Asking user...");
            fullName = await _askForUserName(context);
          }

          // ✅ Update Firestore with user data
          await _updateUserFirestore(userCredential, fullName, "Apple");

          return userCredential; // 🔥 Ensure UserCredential is returned after retry

        } catch (retryError) {
          print("❌ Error during retry: $retryError");
          return null;
        }
      }

      return null;
    }
  }

  Future<UserCredential?> _signInWithCredential(OAuthCredential credential, {String signInMethod = ''}) async {
    try {
      UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      User user = userCredential.user!;

      // ✅ Fetch existing user data from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      String? fullName = user.displayName ?? (userDoc.exists ? userDoc['fullName'] ?? 'Unknown User' : 'Unknown User');

      // ✅ Preserve patientGroupID if it exists
      String? existingPatientGroupID;
      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
      if (userDoc.exists && userData != null && userData.containsKey('patientGroupID')) {
        existingPatientGroupID = userDoc['patientGroupID'];
      } else {
        existingPatientGroupID = null; // Prevents error if patientGroupID is missing
      }

      // ✅ Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email ?? "No Email",
        'uid': user.uid,
        'fullName': fullName,
        'signInMethod': signInMethod,
        if (existingPatientGroupID != null) 'patientGroupID': existingPatientGroupID, // Preserve patientGroupID
      }, SetOptions(merge: true));

      // ✅ Fetch & store Patient Group ID if missing
      await getPatientGroupID(user.uid);

      return userCredential;
    } catch (e) {
      print("❌ Error during Sign-In: $e");
      return null;
    }
  }

  // ✅ Google Login (Uses `_signInWithCredential`)
  Future<UserCredential?> loginWithGoogle(BuildContext context) async {
    try {
      await GoogleSignIn.instance.signOut();
      await FirebaseAuth.instance.signOut();
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential cred = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken);

      // ✅ Step 3: Authenticate with Firebase
      UserCredential? userCredential = await _signInWithCredential(cred, signInMethod: 'Google');
      if (userCredential == null) {
        print("❌ Google Sign-In Failed!");
        return null;
      }
      print("✅ Google Sign-In Successful: ${userCredential.user?.uid}");

      // Initialize FCM and save token
      try {
        await FCMService().initialize();
      } catch (e) {
        print('⚠️ FCM initialization failed (non-critical): $e');
      }


      await Future.delayed(Duration(milliseconds: 500)); // Ensure Firestore sync

      return userCredential;
    } catch (e) {
      print("❌ Error during Google Sign-In: $e");
      return null;
    }
  }

  // ✅ Logout
  Future<void> signout() async {
    await _firebaseAuth.signOut();
  }

  // ✅ Ask for User Name if missing
  Future<String> _askForUserName(BuildContext context) async {
    TextEditingController nameController = TextEditingController();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          "Enter Your Name",
          style: GoogleFonts.dmSerifText(
            color: Theme.of(context).colorScheme.inversePrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isDarkMode ? Colors.black : Colors.grey.shade500,
                offset: const Offset(4, 4),
                blurRadius: 10,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                offset: const Offset(-4, -4),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: TextField(
            controller: nameController,
            autofocus: true,
            cursorColor: Theme.of(context).colorScheme.inversePrimary,
            style: GoogleFonts.dmSerifText(
              color: Theme.of(context).colorScheme.inversePrimary,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: "Full Name",
              hintStyle: GoogleFonts.dmSerifText(
                color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.4),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () {
              String enteredName = nameController.text.trim();
              if (enteredName.isNotEmpty) {
                Navigator.pop(context, enteredName);
              }
            },
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode ? Colors.black : Colors.grey.shade500,
                    offset: const Offset(4, 4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                    offset: const Offset(-4, -4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  "Submit",
                  style: GoogleFonts.dmSerifText(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.inversePrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ) ?? "User";
  }

}