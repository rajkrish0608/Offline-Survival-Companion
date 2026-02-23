import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:offline_survival_companion/core/theme/app_theme.dart';
import 'package:offline_survival_companion/services/storage/local_storage_service.dart';
import 'package:offline_survival_companion/presentation/bloc/app_bloc/app_bloc.dart';
import 'package:uuid/uuid.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = context.read<AppBloc>().state;
    final userId = state is AppReady ? state.userId : 'local';
    final storage = context.read<LocalStorageService>();
    final contacts = await storage.getEmergencyContacts(userId);
    if (mounted) {
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
    }
  }

  Future<void> _showAddDialog(
      {Map<String, dynamic>? existing, required String currentUserId}) async {
    final nameCtrl =
        TextEditingController(text: existing?['name'] as String? ?? '');
    final phoneCtrl =
        TextEditingController(text: existing?['phone'] as String? ?? '');
    final relCtrl = TextEditingController(
        text: existing?['relationship'] as String? ?? '');
    bool isPrimary = (existing?['is_primary'] as int? ?? 0) == 1;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(existing == null ? 'Add Contact' : 'Edit Contact'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: relCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Relationship (e.g. Spouse, Friend)',
                    prefixIcon: Icon(Icons.people),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Primary Contact'),
                  subtitle: const Text('Gets SMS first in an emergency'),
                  value: isPrimary,
                  onChanged: (v) => setDlg(() => isPrimary = v),
                  activeThumbColor: AppTheme.accentBlue,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                if (name.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Name and phone are required')),
                  );
                  return;
                }

                final contact = {
                  'id': existing?['id'] ?? const Uuid().v4(),
                  'user_id': currentUserId,
                  'name': name,
                  'phone': phone,
                  'relationship': relCtrl.text.trim(),
                  'is_primary': isPrimary ? 1 : 0,
                  'verified': 0,
                  'created_at': DateTime.now().millisecondsSinceEpoch,
                };

                final storage = context.read<LocalStorageService>();
                await storage.addEmergencyContact(contact);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact saved successfully')),
                  );
                }
                Navigator.pop(ctx);
                await _load();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(String contactId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Contact?'),
        content:
            const Text('This contact will no longer receive SOS messages.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final storage = context.read<LocalStorageService>();
      await storage.deleteEmergencyContact(contactId);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppBloc>().state;
    final userId = state is AppReady ? state.userId : 'local';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'About SOS contacts',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('How it works'),
                  content: const Text(
                    'When SOS is activated, a location SMS is automatically sent to ALL contacts listed here.\n\nMark one as Primary to prioritize them.',
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('OK')),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.contact_phone_outlined,
                          size: 72, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('No emergency contacts yet',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.grey)),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap + to add someone to notify during an emergency',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _contacts.length,
                  itemBuilder: (context, i) {
                    final c = _contacts[i];
                    final isPrimary = (c['is_primary'] as int? ?? 0) == 1;
                    return Dismissible(
                      key: Key(c['id'] as String),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        await _delete(c['id'] as String);
                        return false; // we handle state ourselves
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isPrimary
                                ? Colors.red.withOpacity(0.15)
                                : AppTheme.accentBlue.withOpacity(0.12),
                            child: Icon(
                              Icons.person,
                              color: isPrimary
                                  ? Colors.red
                                  : AppTheme.accentBlue,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(c['name'] as String? ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              if (isPrimary) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('★ PRIMARY',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '${c['phone']}${(c['relationship'] as String?)?.isNotEmpty == true ? ' • ${c['relationship']}' : ''}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _showAddDialog(existing: c, currentUserId: userId),
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(currentUserId: userId),
        backgroundColor: Colors.red,
        heroTag: 'contacts_add_fab',
        icon: const Icon(Icons.add),
        label: const Text('Add Contact'),
      ),
    );
  }
}
