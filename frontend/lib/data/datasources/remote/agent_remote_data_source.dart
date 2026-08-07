import 'package:tt_mail_assistant/data/datasources/remote/api_service.dart';

class AgentRemoteDataSource {
  const AgentRemoteDataSource(this._apiService);

  final ApiService _apiService;

  Future<String> chat(String message) async {
    final payload = await _apiService.post(
      '/agent/chat',
      body: {'message': message},
    );

    return payload['response'] as String;
  }
}
