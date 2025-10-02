import 'package:flutter/material.dart';

class TestTab extends StatelessWidget {
  const TestTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dialog Box Example")),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Show the popup
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text("Hello!"),
                  content: const Text("This is a simple dialog box."),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // close dialog
                      },
                      child: const Text("Close"),
                    ),
                  ],
                );
              },
            );
          },
          child: const Text("Open Popup"),
        ),
      ),
    );
  }
}
