import 'package:flutter/material.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'db_helper.dart';

class GymBuddyPage extends StatefulWidget {
  const GymBuddyPage({super.key});

  @override
  State<GymBuddyPage> createState() => _GymBuddyPageState();
}

class _GymBuddyPageState extends State<GymBuddyPage> {
  List<Map<String, dynamic>> _buddies = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBuddies();
  }

  Future<void> _loadBuddies() async {
    final currentUser = await DBHelper.getCurrentUser(); // ✅ logged-in user
    if (currentUser == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    final allUsers = await DBHelper.getAllUsers(); // ✅ fetch everyone
    final List<Map<String, dynamic>> others = [];

    for (var user in allUsers) {
      if (user["name"] != currentUser["name"]) {
        final dist = _calculateDistance(
          currentUser["latitude"],
          currentUser["longitude"],
          user["latitude"],
          user["longitude"],
        );
        others.add({
          "name": user["name"],
          "phone": user["phone"] ?? "N/A",
          "age": user["age"] ?? "-",
          "gender": user["gender"] ?? "-",
          "distance": dist,
        });
      }
    }

    setState(() {
      _buddies = others;
      _loading = false;
    });
  }

  // ✅ Haversine distance formula (km)
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Earth radius in km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  // ✅ Tap-to-call helper
  Future<void> _callNumber(String phone) async {
    final Uri uri = Uri(scheme: "tel", path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot launch phone dialer")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gym Buddies Nearby")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buddies.isEmpty
              ? const Center(child: Text("No buddies found nearby"))
              : ListView.builder(
                  itemCount: _buddies.length,
                  itemBuilder: (context, index) {
                    final buddy = _buddies[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: const Icon(Icons.person, color: Colors.blue),
                        title: Text(buddy["name"]),
                        subtitle: Text(
                          "Age: ${buddy["age"]}, Gender: ${buddy["gender"]}\n"
                          "Distance: ${buddy["distance"].toStringAsFixed(2)} km",
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.phone, color: Colors.green),
                          onPressed: buddy["phone"] != "N/A"
                              ? () => _callNumber(buddy["phone"])
                              : null,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
