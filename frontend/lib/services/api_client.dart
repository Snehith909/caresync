import 'package:dio/dio.dart';

class CareSyncApiClient {
  CareSyncApiClient({
    String? baseUrl,
    String? userId,
    String userRole = 'PATIENT',
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl ?? 'http://localhost:8000',
           connectTimeout: const Duration(seconds: 10),
           receiveTimeout: const Duration(seconds: 10),
           headers: {
             'Accept': 'application/json',
             'X-User-Id': ?userId,
             'X-User-Role': userRole,
           },
         ),
       );

  final Dio _dio;

  Future<Map<String, dynamic>> healthCheck() async {
    final response = await _dio.get<Map<String, dynamic>>('/health');
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> saveCondition({
    required String patientId,
    required String description,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/patients/$patientId/condition',
      data: {'description': description},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> uploadPrescription({
    required String patientId,
    required String filePath,
  }) async {
    final formData = FormData.fromMap({
      'document': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/prescriptions/upload',
      queryParameters: {'patient_id': patientId},
      data: formData,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> uploadConditionImage({
    required String patientId,
    required List<int> bytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/patients/$patientId/condition-image',
      data: formData,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> transcribeAudio({
    required List<int> bytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'audio': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/voice/transcribe',
      data: formData,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> submitCarePlan({
    required String patientId,
    required String condition,
    required List<int> prescriptionBytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'condition': condition,
      'prescription': MultipartFile.fromBytes(
        prescriptionBytes,
        filename: filename,
      ),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/patients/$patientId/care-plans/submit',
      data: formData,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> getPatientCarePlans(String patientId) async {
    final response = await _dio.get<List<dynamic>>(
      '/patients/$patientId/care-plans',
    );
    return response.data ?? <dynamic>[];
  }

  Future<List<dynamic>> getTodayMedication(String patientId) async {
    final response = await _dio.get<List<dynamic>>(
      '/patients/$patientId/today',
    );
    return response.data ?? <dynamic>[];
  }

  Future<Map<String, dynamic>> getAdherence(String patientId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/patients/$patientId/adherence',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getCarePlan(String planId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/care-plans/$planId',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> askAboutCarePlan({
    required String patientId,
    required String question,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/patients/$patientId/voice',
      data: {'question': question},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> recordMedication({
    required String eventId,
    required String status,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/medications/$eventId/status',
      data: {'status': status},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createCompanionCheckIn({
    required String patientId,
    required String category,
    required String response,
    String? details,
  }) async {
    final result = await _dio.post<Map<String, dynamic>>(
      '/patients/$patientId/companion/check-ins',
      data: {
        'category': category,
        'response': response,
        if (details != null && details.trim().isNotEmpty) 'details': details,
      },
    );
    return result.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> askCompanion({
    required String patientId,
    required String question,
    required String language,
  }) async {
    final result = await _dio.post<Map<String, dynamic>>(
      '/patients/$patientId/companion/conversations',
      data: {'question': question, 'language': language},
    );
    return result.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> prepareHealthSummary({
    required String patientId,
  }) async {
    final result = await _dio.post<Map<String, dynamic>>(
      '/patients/$patientId/companion/summaries',
    );
    return result.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> submitHealthSummary({
    required String patientId,
    required String summaryId,
  }) async {
    final result = await _dio.post<Map<String, dynamic>>(
      '/patients/$patientId/companion/summaries/$summaryId/submit',
    );
    return result.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> contactDoctor({
    required String patientId,
    required String message,
  }) async {
    final result = await _dio.post<Map<String, dynamic>>(
      '/patients/$patientId/companion/doctor-requests',
      data: {'message': message, 'request_type': 'COMPANION'},
    );
    return result.data ?? <String, dynamic>{};
  }
}
