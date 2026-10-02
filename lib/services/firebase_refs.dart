import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../config/app_config.dart';

/// Single access point for the Firestore instance so the (optional) named
/// database id is applied everywhere.
FirebaseFirestore get appFirestore => FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: AppConfig.firestoreDatabaseId,
    );
