import 'package:flutter/material.dart';

import '../../../app/theme/liquid_glass.dart';
import 'widgets/settings_scaffold.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'About',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Center(
            child: GlassCard(
              radius: 28,
              alpha: 0.07,
              padding: const EdgeInsets.all(24),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 40, color: kAccent),
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text('ilqeyte',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text('0.1.0 · mobile preview',
                style: TextStyle(color: kSecondaryText, fontSize: 13)),
          ),
          const SizedBox(height: 28),
          const _AboutSection(
            title: 'What it is',
            body: 'A native agentic coding harness. Your phone is the body; a cloud '
                'model you control is the brain. Conversations, tools and memory '
                'live on-device in SQLite — only prompts and completions ever '
                'leave.',
          ),
          const _AboutSection(
            title: 'Your data',
            body: 'API keys are held by the platform secure vault, never in the '
                'database or in plain text. Generated files stay inside the app '
                'sandbox under workspace/.',
          ),
          const _AboutSection(
            title: 'Tools',
            body: 'Every side-effecting tool asks before it acts. Approve what you '
                'recognize, deny what you don’t — the agent is told you declined '
                'and adapts.',
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(body,
              style: const TextStyle(
                  color: kSecondaryText, fontSize: 13.5, height: 1.55)),
        ],
      ),
    );
  }
}
