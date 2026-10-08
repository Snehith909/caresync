import 'package:flutter/material.dart';

void main() {
  runApp(const CareSyncApp());
}

class CareSyncApp extends StatelessWidget {
  const CareSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF167D8D);

    return MaterialApp(
      title: 'CareSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7FAFA),
      ),
      home: const CareSyncHomePage(),
    );
  }
}

class CareSyncHomePage extends StatelessWidget {
  const CareSyncHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CareSync'),
        actions: [
          IconButton(
            onPressed: () {},
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_outlined),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(child: Icon(Icons.person_outline)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Your care, in sync.',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep your health information and next steps in one place.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: theme.colorScheme.primary,
                      size: 32,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your health dashboard is ready',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Upload a medical document to create a personalized care plan.',
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload document'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Coming next',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const _FeatureTile(
              icon: Icons.medication_outlined,
              title: 'Medication reminders',
              description: 'Stay on track with your prescribed medication.',
            ),
            const _FeatureTile(
              icon: Icons.event_outlined,
              title: 'Follow-ups',
              description: 'Keep upcoming appointments and care tasks visible.',
            ),
            const _FeatureTile(
              icon: Icons.auto_awesome_outlined,
              title: 'AI health guidance',
              description:
                  'Understand your care plan in patient-friendly language.',
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(icon),
      ),
      title: Text(title),
      subtitle: Text(description),
    );
  }
}
