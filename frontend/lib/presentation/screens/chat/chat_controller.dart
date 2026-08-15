import 'package:flutter/foundation.dart';

import '../../../data/models/chat_message.dart';
import '../../../data/services/chat_api_service.dart';

class ChatController extends ChangeNotifier {
  final ChatApiService apiService;

  ChatController({required this.apiService});

  final List<ChatMessage> _messages = [];

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  String? _error;

  String? get error => _error;

  Future<void> sendMessage(String text) async {
    final cleanText = text.trim();

    if (cleanText.isEmpty || _isLoading) {
      return;
    }

    _error = null;

    // 1. Ajouter le message utilisateur
    _messages.add(ChatMessage(role: 'user', content: cleanText));

    _isLoading = true;
    notifyListeners();

    try {
      // 2. Historique complet
      final history = _messages.map((message) => message.toJson()).toList();

      // 3. Appel backend
      final result = await apiService.sendMessage(
        message: cleanText,
        conversationHistory: history,
      );

      // 4. Récupérer réponse Agent
      final answer = result['response']?.toString() ?? '';

      if (answer.isNotEmpty) {
        _messages.add(ChatMessage(role: 'assistant', content: answer));
      }
    } catch (e) {
      _error = 'Une erreur est survenue : $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearConversation() {
    _messages.clear();
    _error = null;
    notifyListeners();
  }
}
