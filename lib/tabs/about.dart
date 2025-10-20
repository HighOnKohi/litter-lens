import 'package:flutter/material.dart';
import '../services/local_file_helper.dart';

class AboutTab extends StatefulWidget {
  const AboutTab({Key? key}) : super(key: key);

  @override
  _AboutTabState createState() => _AboutTabState();
}

class _AboutTabState extends State<AboutTab> {
  List<Map<String, dynamic>> _submissions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await LocalFileHelper.readAllSubmissions();
    setState(() => _submissions = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Local File Submissions')),
      body: _submissions.isEmpty
          ? const Center(child: Text('No local submissions found.'))
          : ListView.builder(
              itemCount: _submissions.length,
              itemBuilder: (context, index) {
                final item = _submissions[index];
                return ListTile(
                  title: Text(
                    "${item['streetName']} - Bin ${item['binNumber']}",
                  ),
                  subtitle: Text(
                    "Fullness: ${item['fullnessLevel']} | "
                    "Lat: ${item['latitude']} | Lon: ${item['longitude']} | "
                    "Date: ${DateTime.parse(item['recordedDate']).toIso8601String().split('T')[0]}",
                  ),
                );
              },
            ),
    );
  }
}
