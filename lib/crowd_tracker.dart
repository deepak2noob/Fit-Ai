import 'package:flutter/material.dart';
import 'db_helper.dart';

class CrowdTrackerPage extends StatefulWidget {
  const CrowdTrackerPage({Key? key}) : super(key: key);

  @override
  State<CrowdTrackerPage> createState() => _CrowdTrackerPageState();
}

class _CrowdTrackerPageState extends State<CrowdTrackerPage> {
  List<Map<String, dynamic>> gyms = [];

  @override
  void initState() {
    super.initState();
    _loadGyms();
  }

  Future<void> _loadGyms() async {
    final data = await DBHelper.getGyms();
    setState(() {
      gyms = data;
    });
  }

  Future<void> _addGym() async {
    await DBHelper.insertGym({
      'name': 'Gym ${gyms.length + 1}',
      'location': 'Location ${gyms.length + 1}',
      'crowd': (gyms.length + 1) * 5,
    });
    _loadGyms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crowd Tracker'),
      ),
      body: gyms.isEmpty
          ? const Center(child: Text("No gyms added yet."))
          : ListView.builder(
              itemCount: gyms.length,
              itemBuilder: (context, index) {
                final gym = gyms[index];
                return ListTile(
                  title: Text(gym['name']),
                  subtitle: Text("Location: ${gym['location']}"),
                  trailing: Text("Crowd: ${gym['crowd']}"),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addGym,
        child: const Icon(Icons.add),
      ),
    );
  }
}
