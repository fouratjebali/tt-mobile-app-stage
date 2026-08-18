import 'package:flutter/foundation.dart';

import '../../../data/models/bulk_email.dart';
import '../../../data/models/bulk_email_result.dart';
import '../../../data/services/bulk_email_api_service.dart';

class BulkEmailController extends ChangeNotifier {
  final BulkEmailApiService apiService;

  BulkEmailController({required this.apiService});

  List<BulkEmail> generatedEmails = [];

  List<BulkEmailResult> results = [];

  bool isLoading = false;

  String? error;

  Future<void> generateEmails({
    required List<Map<String, String>> recipients,
    required String topic,
    String instructions = '',
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
        instructions: instructions,
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
    final index = generatedEmails.indexWhere((email) => email.id == id);

    if (index != -1) {
      generatedEmails[index] = generatedEmails[index].copyWith(body: newBody);
    }

    notifyListeners();
  }

  void replaceGenerated(List<BulkEmail> emails) {
    generatedEmails = emails;
    notifyListeners();
  }

  Future<void> sendGeneratedDrafts() async {
    if (generatedEmails.isEmpty) {
      return;
    }

    isLoading = true;
    error = null;

    notifyListeners();

    try {
      results = await apiService.sendDrafts(drafts: generatedEmails);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendAll({
    required List<Map<String, String>> recipients,
    required String topic,
    String instructions = '',
  }) async {
    if (recipients.isEmpty || topic.trim().isEmpty) {
      return;
    }

    isLoading = true;
    error = null;

    notifyListeners();

    try {
      results = await apiService.sendAll(
        recipients: recipients,
        topic: topic,
        instructions: instructions,
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
