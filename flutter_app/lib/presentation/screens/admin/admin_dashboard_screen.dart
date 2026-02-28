import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:offline_survival_companion/core/theme/app_theme.dart';
import 'package:offline_survival_companion/services/admin/admin_service.dart';
import 'package:offline_survival_companion/services/storage/local_storage_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isUnlocked = false;
  final TextEditingController _pinController = TextEditingController();
  String _pinError = '';
  static const String _defaultPin = '0000';

  late TabController _tabController;

  // Analytics state
  Map<String, dynamic> _analytics = {};
  bool _analyticsLoading = true;

  // Vault state
  List<Map<String, dynamic>> _vaultFiles = [];
  bool _vaultLoading = true;
  String _vaultSearch = '';

  // Legal export state
  List<Map<String, dynamic>> _users = [];
  String? _selectedUserId;
  bool _exportLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _tryUnlock() async {
    if (_pinController.text == _defaultPin) {
      setState(() {
        _isUnlocked = true;
        _pinError = '';
      });
      _loadAllData();
    } else {
      setState(() => _pinError = 'Incorrect PIN. Default is 0000.');
    }
  }

  Future<void> _loadAllData() async {
    final adminService = AdminService(context.read<LocalStorageService>());
    final analytics = await adminService.getAnalytics();
    final vaultFiles = await adminService.getVaultFiles();
    final users = await adminService.getAllUsers();
    if (mounted) {
      setState(() {
        _analytics = analytics;
        _analyticsLoading = false;
        _vaultFiles = vaultFiles;
        _vaultLoading = false;
        _users = users;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: const Text('Admin Dashboard',
            style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surfaceDark,
        iconTheme: const IconThemeData(color: AppTheme.textLight),
        bottom: _isUnlocked
            ? TabBar(
                controller: _tabController,
                labelColor: AppTheme.accentBlue,
                unselectedLabelColor: AppTheme.textSecondary,
                indicatorColor: AppTheme.accentBlue,
                tabs: const [
                  Tab(icon: Icon(Icons.bar_chart), text: 'Analytics'),
                  Tab(icon: Icon(Icons.folder_special), text: 'Vault Review'),
                  Tab(icon: Icon(Icons.gavel), text: 'Legal Export'),
                ],
              )
            : null,
      ),
      body: _isUnlocked ? _buildDashboard() : _buildPinGate(),
    );
  }

  // ─── PIN Gate ───────────────────────────────────────────────────────────
  Widget _buildPinGate() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.admin_panel_settings, size: 80, color: AppTheme.accentBlue),
            const SizedBox(height: 24),
            Text('Admin Access',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: AppTheme.textLight, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Enter 4-digit admin PIN',
                style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 32),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: const TextStyle(color: AppTheme.textLight, letterSpacing: 8),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '••••',
                hintStyle: TextStyle(color: AppTheme.textSecondary),
                counterText: '',
                errorText: _pinError.isEmpty ? null : _pinError,
              ),
              onSubmitted: (_) => _tryUnlock(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _tryUnlock,
                icon: const Icon(Icons.lock_open),
                label: const Text('Unlock'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Main Dashboard ──────────────────────────────────────────────────────
  Widget _buildDashboard() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildAnalyticsTab(),
        _buildVaultReviewTab(),
        _buildLegalExportTab(),
      ],
    );
  }

  // ─── Tab 1: Analytics ────────────────────────────────────────────────────
  Widget _buildAnalyticsTab() {
    if (_analyticsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Text('System KPIs — Last 24 Hours',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          _kpiCard(
            icon: Icons.sos,
            iconColor: AppTheme.primaryRed,
            label: 'SOS Events (24h)',
            value: '${_analytics['total_sos_today'] ?? 0}',
          ),
          const SizedBox(height: 12),
          _kpiCard(
            icon: Icons.star,
            iconColor: AppTheme.warningYellow,
            label: 'Most Used Feature',
            value: _analytics['top_feature'] ?? '—',
          ),
          const SizedBox(height: 12),
          _kpiCard(
            icon: Icons.timer,
            iconColor: AppTheme.successGreen,
            label: 'Avg Survival Duration',
            value: _formatDuration(_analytics['avg_survival_duration_ms']),
          ),
          const SizedBox(height: 12),
          _kpiCard(
            icon: Icons.devices,
            iconColor: AppTheme.accentBlue,
            label: 'Active Devices (24h)',
            value: '${_analytics['active_devices'] ?? 0}',
          ),
          const SizedBox(height: 24),
          Text('Note: Only aggregated totals are displayed. No individual movement data is tracked.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _kpiCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        color: AppTheme.textLight,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(dynamic ms) {
    if (ms == null) return '—';
    final d = Duration(milliseconds: (ms as num).toInt());
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }

  // ─── Tab 2: Vault Review ─────────────────────────────────────────────────
  Widget _buildVaultReviewTab() {
    if (_vaultLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final filtered = _vaultFiles.where((f) {
      if (_vaultSearch.isEmpty) return true;
      final owner = (f['owner_username'] ?? '').toString().toLowerCase();
      final name = (f['file_name'] ?? '').toString().toLowerCase();
      return owner.contains(_vaultSearch.toLowerCase()) ||
          name.contains(_vaultSearch.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            style: const TextStyle(color: AppTheme.textLight),
            decoration: InputDecoration(
              hintText: 'Search by username or filename…',
              hintStyle: const TextStyle(color: AppTheme.textSecondary),
              prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
              filled: true,
              fillColor: AppTheme.surfaceDark,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
            onChanged: (v) => setState(() => _vaultSearch = v),
          ),
        ),
        if (filtered.isEmpty)
          const Expanded(
              child: Center(
                  child: Text('No vault files found.',
                      style: TextStyle(color: AppTheme.textSecondary))))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final doc = filtered[i];
                return _vaultCard(doc);
              },
            ),
          ),
      ],
    );
  }

  Widget _vaultCard(Map<String, dynamic> doc) {
    final type = (doc['document_type'] ?? 'FILE').toString().toUpperCase();
    final createdMs = doc['created_at'] as int? ?? 0;
    final date = DateTime.fromMillisecondsSinceEpoch(createdMs);

    IconData icon = Icons.description;
    Color color = Colors.grey;
    if (type.contains('JPG') || type.contains('PNG') || type.contains('PHOTO')) {
      icon = Icons.image;
      color = Colors.blue;
    } else if (type.contains('VIDEO') || type.contains('MP4')) {
      icon = Icons.videocam;
      color = Colors.orange;
    } else if (type.contains('AUDIO') || type.contains('M4A')) {
      icon = Icons.audiotrack;
      color = Colors.green;
    } else if (type.contains('PDF')) {
      icon = Icons.picture_as_pdf;
      color = Colors.red;
    }

    return Card(
      color: AppTheme.surfaceDark,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.borderDark)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(doc['file_name'] ?? 'Unknown',
            style: const TextStyle(color: AppTheme.textLight)),
        subtitle: Text(
          'User: ${doc['owner_username'] ?? doc['user_id'] ?? '—'}'
          '\n${date.toLocal().toString().split('.')[0]}',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.open_in_new, color: AppTheme.textSecondary, size: 18),
        onTap: () async {
          final path = doc['file_path'];
          if (path != null && await File(path).exists()) {
            await OpenFilex.open(path);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('File not found on device')));
            }
          }
        },
      ),
    );
  }

  // ─── Tab 3: Legal Export ─────────────────────────────────────────────────
  Widget _buildLegalExportTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
          ),
          child: const Row(
            children: [
              Icon(Icons.gavel, color: Colors.amber),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Use only in response to a valid court order or legal notice. Always consult your legal counsel before exporting.',
                  style: TextStyle(color: Colors.amber, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Select User', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderDark),
          ),
          child: DropdownButton<String>(
            value: _selectedUserId,
            isExpanded: true,
            dropdownColor: AppTheme.surfaceDark,
            hint: const Text('Choose user…', style: TextStyle(color: AppTheme.textSecondary)),
            style: const TextStyle(color: AppTheme.textLight),
            underline: const SizedBox.shrink(),
            items: _users.map((u) {
              return DropdownMenuItem<String>(
                value: u['id'] as String,
                child: Text(
                    '${u['name'] ?? 'Unknown'} (${u['email'] ?? u['id']})'),
              );
            }).toList(),
            onChanged: (v) => setState(() => _selectedUserId = v),
          ),
        ),
        const SizedBox(height: 24),
        if (_selectedUserId != null) ...[
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _exportLoading ? null : _generateExport,
              icon: _exportLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.archive_outlined),
              label: Text(_exportLoading ? 'Generating Package…' : 'Generate Legal Package'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Package contains: vault files + SOS archives + user profile + SHA-256 file manifest.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Future<void> _generateExport() async {
    if (_selectedUserId == null) return;
    setState(() => _exportLoading = true);
    try {
      final adminService = AdminService(context.read<LocalStorageService>());
      final zipPath = await adminService.exportUserData(_selectedUserId!);
      if (zipPath != null && mounted) {
        await SharePlus.instance.share(
            ShareParams(files: [XFile(zipPath)], subject: 'Legal Evidence Package — User $_selectedUserId'),
          );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data found for this user.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exportLoading = false);
    }
  }
}
