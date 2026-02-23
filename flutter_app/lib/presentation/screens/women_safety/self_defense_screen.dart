import 'package:flutter/material.dart';
import 'package:offline_survival_companion/core/theme/app_theme.dart';

class SelfDefenseScreen extends StatelessWidget {
  const SelfDefenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Self-Defense Guide')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHero(context),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Essential Techniques'),
          _TechniqueCard(
            title: 'Wrist Grab Release',
            difficulty: 'Easy',
            description: 'Rotate your wrist towards the attacker\'s thumb. This is the weakest point of the grip.',
            steps: [
              'Keep your fingers spread and hand firm.',
              'Locate the attacker\'s thumb.',
              'Rotate your arm forcefully against the thumb opening.',
              'Pull away and create distance immediately.',
            ],
            icon: Icons.front_hand,
          ),
          _TechniqueCard(
            title: 'Bear Hug Release',
            difficulty: 'Medium',
            description: 'If grabbed from behind, drop your weight and strike the groin or feet.',
            steps: [
              'Drop your center of gravity immediately.',
              'Strike backwards with your head or elbows.',
              'Stomp forcefully on the attacker\'s foot.',
              'Run to a safe, well-lit area.',
            ],
            icon: Icons.accessibility_new,
          ),
          _TechniqueCard(
            title: 'Using Your Voice',
            difficulty: 'Basic',
            description: 'The "Verbal Judo" technique to deter attackers and attract attention.',
            steps: [
              'Maintain a strong, upright posture.',
              'Use a deep, loud command voice.',
              'Yell "STOP" or "NO" rather than just screaming.',
              'Call out specific descriptions of the attacker.',
            ],
            icon: Icons.record_voice_over,
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Strategic Advice'),
          _AdviceTile(
            title: 'Situational Awareness',
            text: 'Keep your head up, avoid distractions like phones in isolated areas, and trust your instincts.',
          ),
          _AdviceTile(
            title: 'Escape is the Goal',
            text: 'Self-defense is about creating a window of 3-5 seconds to escape, not winning a fight.',
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.successGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield, color: AppTheme.successGreen, size: 48),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Empower Yourself',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
                Text(
                  'Quick, effective moves for emergency situations.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
      ),
    );
  }
}

class _TechniqueCard extends StatelessWidget {
  final String title;
  final String difficulty;
  final String description;
  final List<String> steps;
  final IconData icon;

  const _TechniqueCard({
    required this.title,
    required this.difficulty,
    required this.description,
    required this.steps,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: Icon(icon, color: AppTheme.accentBlue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Difficulty: $difficulty', style: const TextStyle(fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description, style: const TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(height: 16),
                ...steps.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${entry.key + 1}. ', style: TextStyle(color: AppTheme.accentBlue, fontWeight: FontWeight.bold)),
                      Expanded(child: Text(entry.value)),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdviceTile extends StatelessWidget {
  final String title;
  final String text;
  const _AdviceTile({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(text, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }
}
