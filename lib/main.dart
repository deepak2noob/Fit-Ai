import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // ✅ Firebase
import 'package:shared_preferences/shared_preferences.dart'; // ✅ For login persistence
import 'auth_page.dart';
import 'gym_buddy.dart';
import 'posture_camera.dart';
import 'crowd_tracker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // ✅ Check if user is already logged in
  final prefs = await SharedPreferences.getInstance();
  final loggedInUser = prefs.getString("loggedInUser");

  runApp(MyApp(
    startPage: loggedInUser == null ? const AuthPage() : const MainPage(),
  ));
}

class MyApp extends StatelessWidget {
  final Widget startPage;
  const MyApp({super.key, required this.startPage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gym Buddy App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: startPage,
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const GymBuddyPage(),
    const PostureCameraPage(),
    const CrowdTrackerPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: "Gym Buddies",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera),
            label: "Posture",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: "Crowd",
          ),
        ],
      ),
    );
  }
}
