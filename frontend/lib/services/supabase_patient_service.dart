import 'dart:typed_data';

import 'package:storage_client/storage_client.dart';
import '../core/supabase/supabase_client.dart';

class SupabasePatientService {
  const SupabasePatientService();

  Future<Map<String, dynamic>> getPatient() async {
    final userId = CareSyncSupabase.client.auth.currentUser?.id;
    if (userId == null) throw StateError('A signed-in patient is required.');
    final response = await CareSyncSupabase.client
        .from('patients')
        .select()
        .eq('patient_user_id', userId)
        .maybeSingle();
    if (response == null) {
      throw StateError(
        'Your account has not been assigned to a patient record.',
      );
    }
    return response;
  }

  Future<List<dynamic>> getCarePlans(String patientId) {
    return CareSyncSupabase.client
        .from('care_plans')
        .select()
        .eq('patient_id', patientId)
        .order('version', ascending: false);
  }

  Future<void> updateCondition({
    required String patientId,
    required String condition,
  }) async {
    await CareSyncSupabase.client.rpc(
      'update_patient_condition',
      params: {'p_patient_id': patientId, 'p_condition': condition},
    );
  }

  Future<List<dynamic>> getAdherence(String patientId) {
    return CareSyncSupabase.client
        .from('medication_adherence')
        .select()
        .eq('patient_id', patientId)
        .order('scheduled_for', ascending: false);
  }

  Future<void> recordAdherence({
    required String patientId,
    required String medicineKey,
    required DateTime scheduledFor,
    required String status,
    String? carePlanId,
  }) async {
    await CareSyncSupabase.client.rpc(
      'record_medication_adherence',
      params: {
        'p_patient_id': patientId,
        'p_care_plan_id': carePlanId,
        'p_medicine_key': medicineKey,
        'p_scheduled_for': scheduledFor.toUtc().toIso8601String(),
        'p_status': status,
      },
    );
  }

  Future<void> uploadDocument({
    required String patientId,
    required Uint8List bytes,
    required String filename,
    String contentType = 'application/octet-stream',
  }) async {
    final path =
        'patients/$patientId/${DateTime.now().microsecondsSinceEpoch}-$filename';
    await CareSyncSupabase.client.storage
        .from('care-plan-documents')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    try {
      await CareSyncSupabase.client.rpc(
        'register_patient_document',
        params: {
          'p_patient_id': patientId,
          'p_storage_path': path,
          'p_document_type': 'prescription',
        },
      );
    } catch (_) {
      await CareSyncSupabase.client.storage.from('care-plan-documents').remove([
        path,
      ]);
      rethrow;
    }
  }
}
