import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF133F85),
          foregroundColor: Colors.white,
          title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.white,
            isScrollable: true,
            tabs: [
              Tab(text: 'Appointments', icon: Icon(Icons.calendar_month)),
              Tab(text: 'Emergencies', icon: Icon(Icons.emergency)),
              Tab(text: 'Login Records', icon: Icon(Icons.login)),
              Tab(text: 'Walk-ins', icon: Icon(Icons.directions_walk)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AdminDataTabView(nodeName: 'appointments'),
            _AdminDataTabView(nodeName: 'emergencies'),
            _AdminDataTabView(nodeName: 'login_record'),
            _AdminDataTabView(nodeName: 'walk_ins'),
          ],
        ),
      ),
    );
  }
}

class _AdminDataTabView extends StatelessWidget {
  final String nodeName;
  const _AdminDataTabView({required this.nodeName});

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is int) {
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(timestamp));
    }
    return timestamp.toString();
  }

  String _buildSubtitleInfo(Map data) {
    List<String> parts = [];
    data.forEach((key, value) {
      if (key != 'timestamp') {
        parts.add('$key: $value');
      }
    });
    return parts.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref(nodeName).onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return Center(child: Text("No ${nodeName.replaceAll('_', ' ')} found.", style: const TextStyle(fontSize: 18)));
        }

        final rawValue = snapshot.data!.snapshot.value;
        if (rawValue is! Map) {
          return Center(child: Text("No ${nodeName.replaceAll('_', ' ')} found.", style: const TextStyle(fontSize: 18)));
        }

        var dataMap = rawValue;
        var docs = <Map<String, dynamic>>[];
        dataMap.forEach((key, value) {
          if (value is Map) {
            var map = Map<String, dynamic>.from(value);
            map['firebase_key'] = key.toString();
            docs.add(map);
          }
        });

        if (docs.isEmpty) {
          return Center(child: Text("No ${nodeName.replaceAll('_', ' ')} found.", style: const TextStyle(fontSize: 18)));
        }

        // Sort newest first
        docs.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index];
            String key = data['firebase_key'];
            
            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(
                  "${data['patient_name'] ?? 'Unknown'} - ${_formatTimestamp(data['timestamp'])}",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF133F85)),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(_buildSubtitleInfo(data), style: const TextStyle(height: 1.4)),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      tooltip: 'Edit',
                      onPressed: () => _showEditDialog(context, key, data),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete',
                      onPressed: () => _confirmDelete(context, key),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, String key, Map<String, dynamic> data) {
    final formKey = GlobalKey<FormState>();
    Map<String, TextEditingController> controllers = {};

    // Generate Text Controllers for fields excluding timestamps and keys
    data.forEach((k, v) {
      if (k != 'timestamp' && k != 'firebase_key' && (v is String || v is int || v is double)) {
        controllers[k] = TextEditingController(text: v.toString());
      }
    });

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Modify Record"),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: controllers.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: e.value,
                      decoration: InputDecoration(labelText: e.key.toUpperCase(), border: const OutlineInputBorder()),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF133F85), foregroundColor: Colors.white),
            onPressed: () {
              Map<String, dynamic> updates = {};
              controllers.forEach((k, v) {
                updates[k] = (data[k] is int) ? (int.tryParse(v.text) ?? v.text) : v.text;
              });
              FirebaseDatabase.instance.ref(nodeName).child(key).update(updates);
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Record updated successfully")));
            },
            child: const Text("SAVE CHANGES"),
          )
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String key) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Record", style: TextStyle(color: Colors.red)),
        content: const Text("Are you sure you want to permanently delete this record?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              FirebaseDatabase.instance.ref(nodeName).child(key).remove();
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Record deleted")));
            },
            child: const Text("DELETE"),
          )
        ],
      ),
    );
  }
}