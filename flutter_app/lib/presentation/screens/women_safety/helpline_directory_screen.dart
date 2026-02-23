import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:offline_survival_companion/core/theme/app_theme.dart';

class HelplineDirectoryScreen extends StatelessWidget {
  const HelplineDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legal Aid & Helplines')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoBanner(),
          const SizedBox(height: 24),
          _HelplineSection(
            title: 'National Emergency Helplines',
            items: [
              _HelplineItem(name: 'Women Helpline', number: '1091', description: 'Immediate police assistance for women.'),
              _HelplineItem(name: 'Women Helpline (Domestic)', number: '181', description: 'Support for domestic violence & harassment.'),
              _HelplineItem(name: 'Police Emergency', number: '112', description: 'Single emergency response number.'),
            ],
          ),
          const SizedBox(height: 24),
          _HelplineSection(
            title: 'Legal Aid & Support NGOs',
            items: [
              _HelplineItem(name: 'National Commission for Women', number: '01126944888', description: 'Legal advice & grievance reporting.'),
              _HelplineItem(name: 'Sakti Shalini', number: '01124373737', description: 'Support for victims of gender-based violence.'),
              _HelplineItem(name: 'Jagori', number: '01126692700', description: 'Legal and psychological support.'),
            ],
          ),
          const SizedBox(height: 24),
          _HelplineSection(
            title: 'Medical Assistance',
            items: [
              _HelplineItem(name: 'Ambulance', number: '102', description: 'Emergency medical services.'),
              _HelplineItem(name: 'Health Helpline', number: '104', description: 'Medical advice and assistance.'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentBlue.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info, color: Colors.blue),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'One-tap dial for all helplines. No internet connection required for calls.',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelplineSection extends StatelessWidget {
  final String title;
  final List<_HelplineItem> items;

  const _HelplineSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
        ),
        const SizedBox(height: 12),
        ...items,
      ],
    );
  }
}

class _HelplineItem extends StatelessWidget {
  final String name;
  final String number;
  final String description;

  const _HelplineItem({
    required this.name,
    required this.number,
    required this.description,
  });

  Future<void> _makeCall() async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: number,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(number, style: TextStyle(color: AppTheme.accentBlue, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(description, style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.successGreen.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.call, color: Colors.green),
        ),
        onTap: _makeCall,
      ),
    );
  }
}
