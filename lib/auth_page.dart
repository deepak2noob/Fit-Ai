import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ Added
import 'db_helper.dart';
import 'main.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String _gender = "Male";

  String _status = "";

  // ✅ Get location
  Future<Position> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location services are disabled");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permissions are denied");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permissions are permanently denied");
    }

    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  // ✅ Handle Login
  Future<void> _login() async {
    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || password.isEmpty) {
      setState(() => _status = "Enter name & password");
      return;
    }

    final user = await DBHelper.getUserByName(name);

    if (user == null) {
      setState(() => _status = "User not found");
      return;
    }

    if (user["password"] != password) {
      setState(() => _status = "Incorrect password");
      return;
    }

    try {
      final pos = await _getLocation();
      await DBHelper.updateUserLocation(name, pos.latitude, pos.longitude);

      // ✅ Save login state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("loggedInUser", name);
    } catch (e) {
      setState(() => _status = "Location error: $e");
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainPage()),
      );
    }
  }

  // ✅ Handle Signup
  Future<void> _signup() async {
    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();
    final phone = _phoneController.text.trim();
    final age = int.tryParse(_ageController.text.trim());

    if (name.isEmpty || password.isEmpty || phone.isEmpty || age == null) {
      setState(() => _status = "Fill all fields correctly");
      return;
    }

    try {
      final pos = await _getLocation();

      await DBHelper.insertUser({
        "name": name,
        "password": password,
        "phone": phone,
        "age": age,
        "gender": _gender,
        "latitude": pos.latitude,
        "longitude": pos.longitude,
      });

      // ✅ Save login state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("loggedInUser", name);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainPage()),
        );
      }
    } catch (e) {
      setState(() => _status = "Signup error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? "Login" : "Sign Up")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password"),
              ),
              if (!_isLogin) ...[
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: "Phone Number"),
                ),
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Age"),
                ),
                DropdownButtonFormField<String>(
                  value: _gender,
                  items: const [
                    DropdownMenuItem(value: "Male", child: Text("Male")),
                    DropdownMenuItem(value: "Female", child: Text("Female")),
                    DropdownMenuItem(value: "Other", child: Text("Other")),
                  ],
                  onChanged: (val) {
                    setState(() => _gender = val ?? "Male");
                  },
                  decoration: const InputDecoration(labelText: "Gender"),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLogin ? _login : _signup,
                child: Text(_isLogin ? "Login" : "Sign Up"),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _isLogin = !_isLogin);
                },
                child: Text(_isLogin
                    ? "Don't have an account? Sign Up"
                    : "Already have an account? Login"),
              ),
              const SizedBox(height: 16),
              Text(_status, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
    );
  }
}
