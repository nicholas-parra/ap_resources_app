import 'dart:developer';

import 'package:flutter/material.dart';
// Import Firebase Core 
import 'package:firebase_core/firebase_core.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Import the generated Firebase options file 
import 'firebase_options.dart'; 
// Your other imports for app pages/widgets 

void main() async {
  // Ensure that plugin services are initialized so that `availableCameras()` 
  // can be called before `runApp()` 
  WidgetsFlutterBinding.ensureInitialized(); 
  // Initialize Firebase 
  await Firebase.initializeApp( 
    options: DefaultFirebaseOptions.currentPlatform, 
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: HomePage()
    );
  }
}

class HomePage extends StatelessWidget {
  new({super.key});

  final services = Services();
  // User? user;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("Flutter Demo Home Page"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: .center,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Email',
              )
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Password',
              )
            ),
            ElevatedButton(
              onPressed: () async {
                FocusManager.instance.primaryFocus?.unfocus(); 
                final result = await services.signInWithEmail(_emailController.text, _passwordController.text);
                if (result == null) {
                  final msg = "Failed to sign in";
                  final notification = SnackBar(content: Text(msg));
                  ScaffoldMessenger.of(context).showSnackBar(notification);
                } else {
                  final msg = "Signed in! UID: ${result.uid}";
                  final notification = SnackBar(content: Text(msg));
                  ScaffoldMessenger.of(context).showSnackBar(notification);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => SecondScreen())
                  );
                }
              },
              child: Text("Sign In")
            ),
            SizedBox(height:50),
          ],
        ),
      )
    );
  }
}

class SecondScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: RecordsScreen()
    );
  }
}

class RecordsScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final services = Services();
  List<Map<String, dynamic>> records = [];
  final _messageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("Flutter Demo Records Page"),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.05,
          vertical: MediaQuery.of(context).size.width * 0.05,
        ),
        child: Center(
          child: Column( 
            mainAxisAlignment: .center,
            children: [
              TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Message',
                )
              ),
              ElevatedButton(
                onPressed: () async {
                  FocusManager.instance.primaryFocus?.unfocus(); 
                  services.addRecord(_messageController.text);
                  String msg = "Added record to database";
                  final notification = SnackBar(content: Text(msg));
                  ScaffoldMessenger.of(context).showSnackBar(notification);
                  final newRecords = await services.retrieveRecords();
                  setState(() {
                    records = newRecords;
                  });
                },
                child: Text("Add Record")
              ),
              ElevatedButton(
                onPressed: () async {
                  String msg = "Retrieving records from database";
                  final notification = SnackBar(content: Text(msg));
                  ScaffoldMessenger.of(context).showSnackBar(notification);
                  final newRecords = await services.retrieveRecords();
                  setState(() {
                    records = newRecords;
                  });
                },
                child: Text("Load Records")
              ),
              ElevatedButton(
                onPressed: () async {
                  String msg = "Deleting records from database";
                  final notification = SnackBar(content: Text(msg));
                  ScaffoldMessenger.of(context).showSnackBar(notification);
                  services.deleteRecords();
                  setState(() {
                    records = [];
                  });
                },
                child: Text("Delete Records")
              ),
              SizedBox(height:50),
              Expanded(child:
                ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Card(child:
                      Text('UID ${records[index]["ownerUid"]}\nMessage ${records[index]["message"]}')
                    );
                  }
                )
              )
            ],
          ),
        )
      )
    );
  }
}

class Services {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  static final Services _instance = Services._internal();
  factory Services() { return _instance; }
  Services._internal();

  void addRecord(String msg) async {
    final user = _auth.currentUser!;

    await _db.collection('demoRecords')
      .add({
        'ownerUid': user.uid,
        'message': msg,
        'createdAt': FieldValue.serverTimestamp(),
      });
  }

  Future<List<Map<String, dynamic>>> retrieveRecords() async {
    final user = _auth.currentUser!;

    final snapshot = await _db.collection('demoRecords')
      .where('ownerUid', isEqualTo: user.uid)
      .get();

    List<Map<String, dynamic>> records = [];
    for (final doc in snapshot.docs) { records.add(doc.data()); }
    return records;
  }

  void deleteRecords() async {
    final user = _auth.currentUser!;

    final snapshots = await _db.collection('demoRecords')
      .where('ownerUid', isEqualTo: user.uid)
      .get();

    for (var doc in snapshots.docs) {
      await doc.reference.delete();
    }
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final UserCredential credential =
          await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      log('Auth error: ${e.code} - ${e.message}');
      return null;
    }
  }

  void logOut() async {
    await _auth.signOut(); 
  }
}