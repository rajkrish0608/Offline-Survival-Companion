import 'package:flutter/material.dart';

class VaultScreen extends StatelessWidget {
  const VaultScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vault')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Vault Screen'),
            SizedBox(height: 8),
            Text('Store encrypted documents here'),
          ],
        ),
      ),
    );
  }
}
