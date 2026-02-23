import 'package:flutter/material.dart';
import 'package:offline_survival_companion/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:offline_survival_companion/presentation/screens/women_safety/fake_call_screen.dart';
import 'package:offline_survival_companion/presentation/widgets/safety/silent_sos_button.dart';
import 'package:offline_survival_companion/services/safety/voice_sos_service.dart';
import 'package:offline_survival_companion/services/emergency/emergency_service.dart';
import 'package:provider/provider.dart';

class WomenSafetyDashboard extends StatelessWidget {
  const WomenSafetyDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Women Safety & Empowerment'),
        backgroundColor: AppTheme.surfaceDark,
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 32),
            const Center(
              child: SilentSOSButton(size: 140),
            ),
            const SizedBox(height: 32),
            Text(
              'Active Security Tools',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textLight,
                  ),
            ),
            const SizedBox(height: 16),
            _buildSecurityGrid(context),
            _buildVoiceToggle(context),
            _buildSurvivalModeToggle(context),
            const SizedBox(height: 32),
            Text(
              'Empowerment & Knowledge',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textLight,
                  ),
            ),
            const SizedBox(height: 16),
            _buildEmpowermentList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.accentBlue, AppTheme.accentBlue.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.security, color: Colors.white, size: 40),
          SizedBox(height: 12),
          Text(
            'Your Safety, Your Power',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'All tools work 100% offline for your protection.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _SafetyCard(
          title: 'Fake Call',
          subtitle: 'Situational Exit',
          icon: Icons.phone_callback,
          color: Colors.orange,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FakeCallScreen()),
          ),
        ),
        _SafetyCard(
          title: 'Safety Timer',
          subtitle: 'Automatic SOS',
          icon: Icons.timer,
          color: Colors.purple,
          onTap: () => context.push('/safety-timer'),
        ),
      ],
    );
  }

  Widget _buildVoiceToggle(BuildContext context) {
    return Consumer<VoiceSosService>(
      builder: (context, service, child) {
        return Container(
          margin: const EdgeInsets.only(top: 16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: service.isEnabled ? AppTheme.accentBlue : Colors.white10,
            ),
          ),
          child: SwitchListTile(
            title: const Text(
              'Voice SOS Activation',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              service.isListening 
                  ? 'Listening for "Help Help Help"...' 
                  : 'Triggers SOS hands-free via safe word.',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            value: service.isEnabled,
            activeColor: AppTheme.accentBlue,
            secondary: Icon(
              service.isListening ? Icons.mic : Icons.mic_none,
              color: service.isEnabled ? AppTheme.accentBlue : Colors.grey,
            ),
            onChanged: (value) => service.setEnabled(value),
          ),
        );
      },
    );
  }

  Widget _buildSurvivalModeToggle(BuildContext context) {
    return Consumer<EmergencyService>(
      builder: (context, service, child) {
        return Container(
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: service.isSurvivalMode ? AppTheme.primaryRed : Colors.white10,
            ),
          ),
          child: SwitchListTile(
            title: const Text(
              'Survival Mode (Battery Saver)',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Disables background sync and non-essential tools to extend battery life in emergencies.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            value: service.isSurvivalMode,
            activeColor: AppTheme.primaryRed,
            secondary: Icon(
              Icons.bolt,
              color: service.isSurvivalMode ? AppTheme.primaryRed : Colors.grey,
            ),
            onChanged: (value) => service.setSurvivalMode(value),
          ),
        );
      },
    );
  }

  Widget _buildEmpowermentList(BuildContext context) {
    return Column(
      children: [
        _EmpowermentTile(
          title: 'Self-Defense Guide',
          subtitle: 'Techniques & Release Maneuvers',
          icon: Icons.front_hand,
          color: AppTheme.successGreen,
          onTap: () => context.push('/self-defense'),
        ),
        const SizedBox(height: 12),
        _EmpowermentTile(
          title: 'Legal Aid & Helplines',
          subtitle: 'Offline Directory of Support',
          icon: Icons.gavel,
          color: AppTheme.accentBlue,
          onTap: () => context.push('/helpline-directory'),
        ),
        const SizedBox(height: 12),
        _EmpowermentTile(
          title: 'Safe Points',
          subtitle: 'Police & Hospitals Nearby',
          icon: Icons.map,
          color: AppTheme.primaryRed,
          onTap: () => context.push('/maps'),
        ),
      ],
    );
  }
}

class _SafetyCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SafetyCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmpowermentTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _EmpowermentTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[400]),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      tileColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
