import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import 'auth/auth_gate.dart';
import 'auth/auth_gateway.dart';
import 'models/care_models.dart';
import 'services/api_client.dart';
import 'state/care_sync_state.dart';

String userInitial(CareUser? user) {
  final value = (user?.displayName ?? user?.email ?? '').trim();
  return value.isEmpty ? 'U' : value.substring(0, 1).toUpperCase();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    ChangeNotifierProvider(
      create: (_) => CareSyncState(),
      child: const CareSyncApp(),
    ),
  );
}

class CareSyncApp extends StatelessWidget {
  const CareSyncApp({this.authGateway, super.key});

  final AuthGateway? authGateway;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF167D8D);
    final gateway = authGateway ?? FirebaseAuthGateway();
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
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
      ),
      home: AuthGate(
        gateway: gateway,
        authenticatedBuilder: (_) => CareSyncShell(gateway: gateway),
      ),
    );
  }
}

class CareSyncShell extends StatelessWidget {
  const CareSyncShell({required this.gateway, super.key});

  final AuthGateway gateway;

  static const _tabs = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: 'Week',
    ),
    NavigationDestination(
      icon: Icon(Icons.mic_none),
      selectedIcon: Icon(Icons.mic),
      label: 'Voice',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CareSyncState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CareSync',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => _showNotifications(context),
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_outlined),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(child: Text(userInitial(gateway.currentUser))),
          ),
        ],
      ),
      body: IndexedStack(
        index: state.selectedTab,
        children: [
          HomeTab(gateway: gateway),
          const ProgressTab(),
          const VoiceTab(),
          ProfileTab(gateway: gateway),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: state.selectedTab,
        onDestinationSelected: state.selectTab,
        destinations: _tabs,
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('No notifications yet.'),
          ],
        ),
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({required this.gateway, super.key});

  final AuthGateway gateway;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshApprovedPlan());
  }

  Future<void> _refreshApprovedPlan() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final userId = widget.gateway.currentUser?.id;
    if (userId == null || !mounted) return;
    try {
      final plans = await CareSyncApiClient(
        baseUrl: 'http://10.0.2.2:8000',
        userId: userId,
      ).getPatientCarePlans(userId);
      if (mounted) context.read<CareSyncState>().applyApprovedCarePlan(plans);
    } catch (_) {
      // The local dashboard remains usable while the backend is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CareSyncState>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text('Good morning', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 4),
        Text(
          'Your care, in sync.',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        _AdherenceCard(percentage: state.adherencePercentage),
        const SizedBox(height: 24),
        ConditionUpdateCard(gateway: widget.gateway),
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'Today',
          action: TextButton(
            onPressed: () => _showCarePlan(context),
            child: const Text('View care plan'),
          ),
        ),
        const SizedBox(height: 8),
        if (state.hasMissedMedication) const _EscalationBanner(),
        if (state.medications.isEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.medication_outlined),
              title: const Text('No medications added'),
              subtitle: const Text(
                'Add your medication schedule to get started.',
              ),
              trailing: IconButton(
                tooltip: 'Add medication',
                icon: const Icon(Icons.add),
                onPressed: () => _showAddMedication(context),
              ),
            ),
          )
        else
          ...state.medications.map(
            (medication) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MedicationCard(medication: medication),
            ),
          ),
        const SizedBox(height: 8),
        if (state.medications.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showAddMedication(context),
              icon: const Icon(Icons.add),
              label: const Text('Add medication'),
            ),
          ),
        const SizedBox(height: 8),
        if (state.followUps.isNotEmpty)
          _FollowUpCard(followUp: state.followUps.first),
        const SizedBox(height: 24),
        FilledButton.tonalIcon(
          onPressed: () => context.read<CareSyncState>().selectTab(2),
          icon: const Icon(Icons.mic_none),
          label: const Text('Ask about your care plan'),
        ),
      ],
    );
  }

  void _showCarePlan(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const CarePlanSheet(),
    );
  }

  void _showAddMedication(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddMedicationSheet(),
    );
  }
}

class ConditionUpdateCard extends StatefulWidget {
  const ConditionUpdateCard({required this.gateway, super.key});

  final AuthGateway gateway;

  @override
  State<ConditionUpdateCard> createState() => _ConditionUpdateCardState();
}

class _ConditionUpdateCardState extends State<ConditionUpdateCard> {
  final _controller = TextEditingController();
  final _recorder = AudioRecorder();
  final _imagePicker = ImagePicker();

  bool _isListening = false;
  bool _isTranscribing = false;
  String _voiceHint = 'Tap the mic and describe your condition.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _controller.text = context.read<CareSyncState>().currentCondition;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startVoiceInput() async {
    if (_isListening) {
      await _stopVoiceInput();
      return;
    }
    if (!await _recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required for voice input.'),
        ),
      );
      return;
    }
    final directory = await getTemporaryDirectory();
    if (!mounted) return;
    final path =
        '${directory.path}${Platform.pathSeparator}caresync-condition.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    setState(() {
      _isListening = true;
      _voiceHint = 'Listening... tap again when you are finished.';
    });
  }

  Future<void> _stopVoiceInput() async {
    final path = await _recorder.stop();
    if (path == null) return;
    if (mounted) {
      setState(() {
        _isListening = false;
        _isTranscribing = true;
        _voiceHint = 'Converting your speech to text...';
      });
    }
    try {
      final bytes = await File(path).readAsBytes();
      final response = await CareSyncApiClient(
        baseUrl: 'http://10.0.2.2:8000',
        userId: widget.gateway.currentUser?.id,
      ).transcribeAudio(bytes: bytes, filename: 'condition.wav');
      final words = (response['text'] as String? ?? '').trim();
      if (words.isEmpty) throw StateError('No speech was transcribed.');
      if (!mounted) return;
      _controller.text = words;
      context.read<CareSyncState>().updateCondition(words);
      setState(() => _voiceHint = 'Condition transcribed successfully.');
    } catch (_) {
      if (mounted) {
        setState(
          () => _voiceHint =
              'Transcription failed. Check that the CareSync backend is running.',
        );
      }
    } finally {
      try {
        await File(path).delete();
      } catch (_) {
        // The temporary recording may already have been removed by the platform.
      }
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  Future<void> _pickConditionImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    context.read<CareSyncState>().updateConditionImage(bytes, picked.name);
  }

  void _clearConditionImage() {
    context.read<CareSyncState>().updateConditionImage(null, null);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CareSyncState>();
    if (_controller.text != state.currentCondition && !_isListening) {
      _controller.text = state.currentCondition;
    }
    final hasImage = state.conditionImageBytes != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.medical_information)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update your condition',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Type it, speak it, or attach an image.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 4,
              onChanged: context.read<CareSyncState>().updateCondition,
              decoration: const InputDecoration(
                labelText: 'Current condition',
                hintText: 'Tell us how you feel today...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _pickConditionImage,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Upload image'),
                ),
                OutlinedButton.icon(
                  onPressed: _isTranscribing ? null : _startVoiceInput,
                  icon: Icon(_isListening ? Icons.stop : Icons.mic_none),
                  label: Text(
                    _isListening ? 'Stop and transcribe' : 'Speak condition',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(_voiceHint, style: Theme.of(context).textTheme.bodySmall),
            if (hasImage) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  state.conditionImageBytes!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      state.conditionImageName ?? 'Attached image',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: _clearConditionImage,
                    child: const Text('Remove'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: state.isProcessing
                    ? null
                    : () async {
                        final userId = widget.gateway.currentUser?.id;
                        if (userId == null) return;
                        final careState = context.read<CareSyncState>();
                        final messenger = ScaffoldMessenger.of(context);
                        final submitted = await careState.submitCarePlan(
                          patientId: userId,
                          api: CareSyncApiClient(
                            baseUrl: 'http://10.0.2.2:8000',
                            userId: userId,
                          ),
                        );
                        if (!mounted) return;
                        final message = careState.submissionMessage;
                        if (message != null) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(message),
                              backgroundColor: submitted ? Colors.green : null,
                            ),
                          );
                        }
                      },
                icon: state.isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  state.isProcessing
                      ? 'Sending for doctor review...'
                      : 'Submit to doctor',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdherenceCard extends StatelessWidget {
  const _AdherenceCard({required this.percentage});

  final int percentage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              height: 88,
              width: 88,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: percentage / 100,
                    strokeWidth: 8,
                    backgroundColor: colors.onPrimary.withValues(alpha: .2),
                    color: colors.onPrimary,
                  ),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Medication progress',
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Day 3 of 7 · Keep going, you are doing well.',
                    style: TextStyle(
                      color: colors.onPrimary.withValues(alpha: .9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MedicationCard extends StatelessWidget {
  const MedicationCard({required this.medication, super.key});

  final MedicationItem medication;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isTaken = medication.status == MedicationStatus.taken;
    final isMissed = medication.status == MedicationStatus.missed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  child: Icon(medication.icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medication.period.toUpperCase(),
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        medication.time,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                _StatusChip(status: medication.status),
              ],
            ),
            const Divider(height: 24),
            Text(
              medication.name,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('${medication.dose} · ${medication.instruction}'),
            const SizedBox(height: 16),
            if (isTaken)
              const _ActionFeedback(
                icon: Icons.check_circle,
                text: 'Taken and recorded',
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.read<CareSyncState>().markMedication(
                    medication.id,
                    MedicationStatus.taken,
                  ),
                  icon: const Icon(Icons.check),
                  label: Text(isMissed ? 'Mark as taken now' : 'Mark as taken'),
                ),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () => context.read<CareSyncState>().askVoice(
                  'When should I take ${medication.name}?',
                ),
                icon: const Icon(Icons.mic_none),
                label: const Text('Ask about this medicine'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final MedicationStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, icon, color) = switch (status) {
      MedicationStatus.taken => ('Taken', Icons.check, Colors.green),
      MedicationStatus.due => ('Due now', Icons.schedule, colors.primary),
      MedicationStatus.missed => ('Missed', Icons.warning_amber, Colors.orange),
      MedicationStatus.upcoming => (
        'Upcoming',
        Icons.circle_outlined,
        colors.outline,
      ),
    };
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
    );
  }
}

class _ActionFeedback extends StatelessWidget {
  const _ActionFeedback({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.green),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class ProgressTab extends StatelessWidget {
  const ProgressTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CareSyncState>();
    final days = [
      const DayProgress(day: 'Monday', value: 100, status: 'Taken'),
      const DayProgress(day: 'Tuesday', value: 100, status: 'Taken'),
      const DayProgress(day: 'Wednesday', value: 67, status: 'Needs attention'),
      const DayProgress(day: 'Thursday', value: 100, status: 'Taken'),
      const DayProgress(day: 'Friday', value: 100, status: 'Taken'),
      DayProgress(
        day: 'Saturday',
        value: state.hasMissedMedication ? 50 : 100,
        status: state.hasMissedMedication ? 'Missed dose' : 'Taken',
      ),
      const DayProgress(day: 'Sunday', value: 0, status: 'Today'),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(
          'Weekly medication progress',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'See how consistently you have followed your approved care plan.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  '${state.adherencePercentage}%',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text('This week'),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: state.adherencePercentage / 100,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        ...days.map(
          (day) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: day.value >= 80
                    ? Colors.green.withValues(alpha: .12)
                    : Colors.orange.withValues(alpha: .15),
                child: Icon(
                  day.value >= 80 ? Icons.check : Icons.warning_amber,
                  color: day.value >= 80 ? Colors.green : Colors.orange,
                ),
              ),
              title: Text(day.day),
              subtitle: Text(day.status),
              trailing: Text(
                day.value == 0 ? 'Today' : '${day.value}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        if (state.hasMissedMedication) const _EscalationBanner(),
      ],
    );
  }
}

class VoiceTab extends StatefulWidget {
  const VoiceTab({super.key});

  @override
  State<VoiceTab> createState() => _VoiceTabState();
}

class _VoiceTabState extends State<VoiceTab> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CareSyncState>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(
          'Ask about your care',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ask questions about your approved care plan. CareSync will guide you to your doctor for clinical decisions.',
        ),
        const SizedBox(height: 28),
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.mic,
              size: 46,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'What would you like to know?',
            prefixIcon: Icon(Icons.chat_bubble_outline),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () {
            final question = controller.text.trim();
            if (question.isNotEmpty) {
              context.read<CareSyncState>().askVoice(question);
              controller.clear();
            }
          },
          icon: const Icon(Icons.send),
          label: const Text('Ask CareSync'),
        ),
        const SizedBox(height: 24),
        Text(
          'Try asking',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              [
                    'When is my next medicine?',
                    'Should I take it after food?',
                    'What is my evening medicine?',
                  ]
                  .map(
                    (prompt) => ActionChip(
                      label: Text(prompt),
                      onPressed: () =>
                          context.read<CareSyncState>().askVoice(prompt),
                    ),
                  )
                  .toList(),
        ),
        if (state.lastVoicePrompt != null) ...[
          const SizedBox(height: 24),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: Text('You asked: ${state.lastVoicePrompt}'),
              subtitle: const Text(
                'Your approved care plan contains the schedule. For treatment changes or new symptoms, please contact your doctor.',
              ),
              trailing: IconButton(
                onPressed: context.read<CareSyncState>().clearVoicePrompt,
                icon: const Icon(Icons.close),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({required this.gateway, super.key});

  final AuthGateway gateway;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CareSyncState>();
    final user = gateway.currentUser;
    final displayName = user?.displayName?.trim();
    final name = displayName == null || displayName.isEmpty
        ? user?.email ?? 'User'
        : displayName;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(
          'Profile & care',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  child: Icon(Icons.person, size: 32),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(user?.email ?? 'No email available'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _ProfileAction(
          icon: Icons.description_outlined,
          title: 'Create or update care plan',
          subtitle: 'Upload a new prescription after reassessment',
          onTap: () => _openCarePlan(context),
        ),
        _ProfileAction(
          icon: Icons.event_outlined,
          title: 'Follow-ups',
          subtitle: '${state.followUps.length} upcoming care appointment',
          onTap: () => _showFollowUps(context, state),
        ),
        _ProfileAction(
          icon: Icons.language,
          title: 'Preferred language',
          subtitle: state.preferredLanguage,
          onTap: () => _chooseLanguage(context, state),
        ),
        _ProfileAction(
          icon: Icons.contact_emergency_outlined,
          title: 'Nominee / caregiver',
          subtitle: 'Manage your trusted care contact',
          onTap: () => _showInfo(
            context,
            'Nominee / caregiver',
            'Your nominee receives an alert if repeated medication misses require support.',
          ),
        ),
        _ProfileAction(
          icon: Icons.security_outlined,
          title: 'Privacy and safety',
          subtitle: 'Your doctor-approved plan is the source of truth',
          onTap: () => _showInfo(
            context,
            'Privacy and safety',
            'CareSync assists with understanding and adherence. It does not prescribe, change dosage, or replace your doctor.',
          ),
        ),
        _ProfileAction(
          icon: Icons.logout,
          title: 'Sign out',
          subtitle: 'Sign out of this device',
          onTap: gateway.signOut,
        ),
      ],
    );
  }

  void _openCarePlan(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const CarePlanSheet(),
    );
  }

  void _chooseLanguage(BuildContext context, CareSyncState state) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: ['English', 'Kannada', 'Hindi', 'Tamil']
            .map(
              (language) => ListTile(
                title: Text(language),
                trailing: state.preferredLanguage == language
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  state.updateLanguage(language);
                  Navigator.pop(context);
                },
              ),
            )
            .toList(),
      ),
    );
  }

  void _showFollowUps(BuildContext context, CareSyncState state) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: state.followUps
              .map(
                (followUp) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.event)),
                  title: Text(followUp.title),
                  subtitle: Text('${followUp.date}\n${followUp.description}'),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _showInfo(BuildContext context, String title, String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class CarePlanSheet extends StatefulWidget {
  const CarePlanSheet({super.key});

  @override
  State<CarePlanSheet> createState() => _CarePlanSheetState();
}

class AddMedicationSheet extends StatefulWidget {
  const AddMedicationSheet({super.key});

  @override
  State<AddMedicationSheet> createState() => _AddMedicationSheetState();
}

class _AddMedicationSheetState extends State<AddMedicationSheet> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final doseController = TextEditingController();
  final timeController = TextEditingController();
  final instructionController = TextEditingController();
  String period = 'Morning';

  @override
  void dispose() {
    nameController.dispose();
    doseController.dispose();
    timeController.dispose();
    instructionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add medication',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _requiredField(nameController, 'Medicine name'),
              const SizedBox(height: 12),
              _requiredField(doseController, 'Dose'),
              const SizedBox(height: 12),
              _requiredField(timeController, 'Time'),
              const SizedBox(height: 12),
              _requiredField(instructionController, 'Instructions'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: period,
                decoration: const InputDecoration(labelText: 'Time of day'),
                items: ['Morning', 'Afternoon', 'Night']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => period = value!),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    context.read<CareSyncState>().addMedication(
                      name: nameController.text.trim(),
                      dose: doseController.text.trim(),
                      time: timeController.text.trim(),
                      instruction: instructionController.text.trim(),
                      period: period,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Save medication'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextFormField _requiredField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Enter $label' : null,
    );
  }
}

class _CarePlanSheetState extends State<CarePlanSheet> {
  late final TextEditingController conditionController;

  @override
  void initState() {
    super.initState();
    conditionController = TextEditingController(
      text: context.read<CareSyncState>().currentCondition,
    );
  }

  @override
  void dispose() {
    conditionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CareSyncState>();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create your care plan',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload your prescription or discharge summary. A doctor must approve the generated plan before it becomes active.',
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _showUploadMessage(context),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload prescription / discharge PDF'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _showUploadMessage(context),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Take prescription photo'),
            ),
            const SizedBox(height: 20),
            Text(
              'Current condition',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: conditionController,
              maxLines: 3,
              onChanged: context.read<CareSyncState>().updateCondition,
              decoration: const InputDecoration(
                hintText: 'Tell us how you feel now...',
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => context.read<CareSyncState>().askVoice(
                'I want to describe my current condition.',
              ),
              icon: const Icon(Icons.mic_none),
              label: const Text('Speak your condition'),
            ),
            const SizedBox(height: 12),
            if (state.isProcessing)
              const _ProcessingCarePlan()
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await context.read<CareSyncState>().generateCarePlan();
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate care plan'),
                ),
              ),
            if (state.hasCarePlan && !state.isPlanApproved) ...[
              const SizedBox(height: 16),
              const _ApprovalNotice(),
            ],
          ],
        ),
      ),
    );
  }

  void _showUploadMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Document picker is ready for Firebase Storage integration.',
        ),
      ),
    );
  }
}

class _ProcessingCarePlan extends StatelessWidget {
  const _ProcessingCarePlan();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            LinearProgressIndicator(),
            SizedBox(height: 12),
            Text('Analyzing prescription...'),
            SizedBox(height: 6),
            Text('Reading document · Extracting medicines · Preparing plan'),
          ],
        ),
      ),
    );
  }
}

class _ApprovalNotice extends StatelessWidget {
  const _ApprovalNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: const ListTile(
        leading: Icon(Icons.verified_user_outlined),
        title: Text('Awaiting doctor approval'),
        subtitle: Text(
          'Your doctor will verify the medicines and schedule before activation.',
        ),
      ),
    );
  }
}

class _FollowUpCard extends StatelessWidget {
  const _FollowUpCard({required this.followUp});

  final FollowUp followUp;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.event_outlined)),
        title: Text(followUp.title),
        subtitle: Text('${followUp.date} · ${followUp.description}'),
        isThreeLine: true,
      ),
    );
  }
}

class _EscalationBanner extends StatelessWidget {
  const _EscalationBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.shade50,
      margin: const EdgeInsets.only(bottom: 12),
      child: const ListTile(
        leading: Icon(Icons.warning_amber, color: Colors.orange),
        title: Text('Follow-up required'),
        subtitle: Text(
          'A missed medicine was recorded. Your care team may follow up if misses continue.',
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action});

  final String title;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        action,
      ],
    );
  }
}
