import 'package:flutter/foundation.dart';

import '../models/care_models.dart';
import '../services/api_client.dart';
import '../services/supabase_patient_service.dart';

class CareSyncState extends ChangeNotifier {
  CareSyncState() : medications = [], followUps = [];

  final List<MedicationItem> medications;
  final List<FollowUp> followUps;
  int selectedTab = 0;
  bool isProcessing = false;
  bool hasCarePlan = false;
  bool isPlanApproved = false;
  String currentCondition = '';
  String preferredLanguage = 'English';
  String? lastVoicePrompt;
  Uint8List? conditionImageBytes;
  String? conditionImageName;
  String? submissionMessage;
  final Map<String, Map<String, MedicationStatus>> _dailyMedicationStatus = {};
  final Set<String> _deliveryRequests = {};
  DateTime? _medicationPlanStartedOn;

  int get takenCount => medications
      .where((medication) => medication.status == MedicationStatus.taken)
      .length;

  int get adherencePercentage => medications.isEmpty
      ? 0
      : ((takenCount / medications.length) * 100).round();

  bool get hasMissedMedication =>
      medications.any((item) => item.status == MedicationStatus.missed);

  bool get hasThreeDayMissedStreak {
    if (medications.isEmpty) return false;
    final today = DateTime.now();
    final days = List<DateTime>.generate(
      3,
      (index) => DateTime(today.year, today.month, today.day - index),
    );
    final startedOn = _medicationPlanStartedOn;
    if (startedOn == null ||
        days.any(
          (day) => day.isBefore(
            DateTime(startedOn.year, startedOn.month, startedOn.day),
          ),
        )) {
      return false;
    }
    return days.every((day) => dayMedicationPercentage(day) == 0);
  }

  String get adherenceReminder =>
      'You have missed medicine doses for 3 days. A reminder should be '
      'reviewed by you and your doctor.';

  bool deliveryRequested(String medicationId) =>
      _deliveryRequests.contains(medicationId);

  void selectTab(int index) {
    selectedTab = index;
    notifyListeners();
  }

  void markMedication(String id, MedicationStatus status) {
    final medication = medications.firstWhere((item) => item.id == id);
    medication.status = status;
    _dailyMedicationStatus.putIfAbsent(_dateKey(DateTime.now()), () => {})[id] =
        status;
    notifyListeners();
  }

  int dayMedicationPercentage(DateTime day) {
    if (medications.isEmpty) return 0;
    final statuses = _dailyMedicationStatus[_dateKey(day)] ?? const {};
    final taken = medications.where(
      (medication) =>
          statuses[medication.id] == MedicationStatus.taken ||
          (isSameDay(day, DateTime.now()) &&
              medication.status == MedicationStatus.taken),
    );
    return ((taken.length / medications.length) * 100).round();
  }

  String dayMedicationStatus(DateTime day) {
    final percentage = dayMedicationPercentage(day);
    if (isSameDay(day, DateTime.now())) return 'Today';
    if (percentage == 100) return 'All doses completed';
    if (percentage == 0) return 'No doses recorded';
    return 'Needs attention';
  }

  int periodTakenCount(String period) => medications
      .where(
        (medication) =>
            periodBucket(medication.period) == periodBucket(period) &&
            medication.status == MedicationStatus.taken,
      )
      .length;

  int periodTotalCount(String period) => medications
      .where(
        (medication) => periodBucket(medication.period) == periodBucket(period),
      )
      .length;

  String periodBucket(String period) {
    final normalized = period.trim().toLowerCase();
    if (normalized == 'afternoon' || normalized == 'noon') return 'noon';
    if (normalized == 'night' || normalized == 'evening') return 'night';
    return 'morning';
  }

  void requestDelivery(String medicationId) {
    _deliveryRequests.add(medicationId);
    notifyListeners();
  }

  Future<void> recordMedication({
    required MedicationItem medication,
    required MedicationStatus status,
    required String patientId,
    required SupabasePatientService service,
  }) async {
    await service.recordAdherence(
      patientId: patientId,
      medicineKey: medication.id.isEmpty ? medication.name : medication.id,
      scheduledFor: DateTime.now(),
      status: status == MedicationStatus.missed ? 'missed' : 'taken',
    );
    markMedication(medication.id, status);
  }

  void addMedication({
    required String name,
    required String dose,
    required String time,
    required String instruction,
    required String period,
  }) {
    _medicationPlanStartedOn ??= DateTime.now();
    medications.add(
      MedicationItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        dose: dose,
        time: time,
        instruction: instruction,
        period: period,
      ),
    );
    notifyListeners();
  }

  Future<void> generateCarePlan() async {
    isProcessing = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    isProcessing = false;
    hasCarePlan = true;
    isPlanApproved = false;
    notifyListeners();
  }

  Future<bool> submitCarePlan({
    required String patientId,
    required CareSyncApiClient api,
  }) async {
    if (currentCondition.trim().isEmpty || conditionImageBytes == null) {
      submissionMessage = 'Add your condition and prescription image first.';
      notifyListeners();
      return false;
    }

    isProcessing = true;
    submissionMessage = null;
    notifyListeners();
    try {
      await api.submitCarePlan(
        patientId: patientId,
        condition: currentCondition.trim(),
        prescriptionBytes: conditionImageBytes!,
        filename: conditionImageName ?? 'prescription.jpg',
      );
      hasCarePlan = true;
      isPlanApproved = false;
      submissionMessage = 'Submitted for doctor review.';
      return true;
    } catch (_) {
      submissionMessage = 'Submission failed. Check the backend and try again.';
      return false;
    } finally {
      isProcessing = false;
      notifyListeners();
    }
  }

  Future<bool> submitPatientUpdate({
    required String patientId,
    required SupabasePatientService service,
  }) async {
    if (currentCondition.trim().isEmpty || conditionImageBytes == null) {
      submissionMessage = 'Add your condition and prescription image first.';
      notifyListeners();
      return false;
    }
    isProcessing = true;
    submissionMessage = null;
    notifyListeners();
    try {
      await service.updateCondition(
        patientId: patientId,
        condition: currentCondition.trim(),
      );
      await service.uploadDocument(
        patientId: patientId,
        bytes: conditionImageBytes!,
        filename: conditionImageName ?? 'prescription.jpg',
        contentType: _contentTypeFor(conditionImageName),
      );
      submissionMessage = 'Condition and prescription sent to your doctor.';
      return true;
    } catch (error) {
      submissionMessage = 'Could not send your update: $error';
      return false;
    } finally {
      isProcessing = false;
      notifyListeners();
    }
  }

  void applyApprovedCarePlan(List<dynamic> plans) {
    final active = plans.whereType<Map<String, dynamic>>().firstWhere(
      (plan) => plan['status'] == 'active',
      orElse: () => <String, dynamic>{},
    );
    if (active.isEmpty) return;
    final generated = active['medications'] as List<dynamic>? ?? const [];
    medications
      ..clear()
      ..addAll(
        generated.whereType<Map<String, dynamic>>().map(
          (medicine) => MedicationItem(
            id:
                medicine['id'] as String? ??
                medicine['name'] as String? ??
                'medication',
            name: medicine['name'] as String? ?? 'Medication',
            dose:
                medicine['dose'] as String? ??
                medicine['strength'] as String? ??
                medicine['dosage'] as String? ??
                '',
            time:
                ((medicine['scheduled_times'] as List<dynamic>?) ?? const [])
                    .map((value) => value.toString())
                    .join(', ')
                    .isEmpty
                ? medicine['frequency'] as String? ?? ''
                : ((medicine['scheduled_times'] as List<dynamic>?) ?? const [])
                      .map((value) => value.toString())
                      .join(', '),
            instruction:
                medicine['food_instruction'] as String? ??
                medicine['directions'] as String? ??
                medicine['instructions'] as String? ??
                '',
            period: 'Today',
          ),
        ),
      );
    hasCarePlan = true;
    isPlanApproved = true;
    _medicationPlanStartedOn ??= DateTime.now();
    notifyListeners();
  }

  String _contentTypeFor(String? filename) {
    final lower = (filename ?? '').toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }

  void updateCondition(String value) {
    currentCondition = value;
    notifyListeners();
  }

  void updateConditionImage(Uint8List? bytes, String? name) {
    conditionImageBytes = bytes;
    conditionImageName = name;
    notifyListeners();
  }

  void updateLanguage(String value) {
    preferredLanguage = value;
    notifyListeners();
  }

  void askVoice(String prompt) {
    lastVoicePrompt = prompt;
    notifyListeners();
  }

  void clearVoicePrompt() {
    lastVoicePrompt = null;
    notifyListeners();
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  bool isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
