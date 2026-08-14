import 'package:flutter/foundation.dart';

import '../../../data/models/bulk_email.dart';
import '../../../data/models/bulk_email_result.dart';
import '../../../data/services/bulk_email_api_service.dart';

class BulkEmailController extends ChangeNotifier {
  final BulkEmailApiService apiService;

  BulkEmailController({
    required this.apiService,
  });

  List<BulkEmail> generatedEmails = [];

  List<BulkEmailResult> results = [];

  bool isLoading = false;

  String? error;

  Future<void> generateEmails({
    required List<String> recipients,
    required String topic,
  }) async {
    if (recipients.isEmpty || topic.trim().isEmpty) {
      return;
    }

    isLoading = true;
    error = null;

    notifyListeners();

    try {
      generatedEmails = await apiService.generateEmails(
        recipients: recipients,
        topic: topic,
      );
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> editGenerated({
    required String id,
    required String newBody,
  }) async {
    try {
      final updatedEmail = await apiService.editGenerated(
        id: id,
        newBody: newBody,
      );

      final index = generatedEmails.indexWhere(
            (email) => email.id == id,
      );

      if (index != -1) {
        generatedEmails[index] = updatedEmail;
      }

      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendAll() async {
    if (generatedEmails.isEmpty) {
      return;
    }

    isLoading = true;
    error = null;

    notifyListeners();

    try {
      results = await apiService.sendAll(
        emails: generatedEmails,
      );
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    generatedEmails = [];
    results = [];
    error = null;

    notifyListeners();
  }
}