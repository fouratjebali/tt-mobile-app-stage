class ErrorMessage {
  const ErrorMessage._();

  static String fromApi({required int statusCode, required String message}) {
    final cleaned = _clean(message);
    final lower = cleaned.toLowerCase();

    if (statusCode == 401 || statusCode == 403) {
      return 'Your session expired. Please sign in again.';
    }
    if (statusCode == 404) {
      return 'We could not find this item anymore. Refresh and try again.';
    }
    if (statusCode == 409) {
      return 'This action is not ready yet. Refresh and try again.';
    }
    if (statusCode >= 500) {
      if (_mentionsAgentUnavailable(lower)) {
        return 'The draft service is not ready yet. Please try again in a moment.';
      }
      if (lower.contains('gmail')) {
        return 'Gmail could not complete this action. Please try again.';
      }
      return 'One of the services is not ready. Please try again in a moment.';
    }
    if (lower.contains('taking too long') || lower.contains('timeout')) {
      return 'This is taking longer than expected. Please try again.';
    }
    if (_mentionsAgentUnavailable(lower)) {
      return 'The draft service is not ready yet. Please try again in a moment.';
    }
    if (cleaned.isEmpty || cleaned == '{}') {
      return 'Something went wrong. Please try again.';
    }

    return cleaned;
  }

  static String fromException(Object error) {
    if (error is UserFacingException) {
      return error.message;
    }

    final raw = error.toString();
    final apiMatch = RegExp(r'ApiException\((\d+)\):\s*(.*)').firstMatch(raw);
    if (apiMatch != null) {
      return fromApi(
        statusCode: int.tryParse(apiMatch.group(1) ?? '') ?? 0,
        message: apiMatch.group(2) ?? '',
      );
    }

    return fromApi(statusCode: 0, message: raw);
  }

  static String _clean(String message) {
    var cleaned = message.trim();
    cleaned = cleaned.replaceFirst(RegExp(r'^Exception:\s*'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'^ApiException\(\d+\):\s*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.length > 180) {
      cleaned = '${cleaned.substring(0, 180).trim()}...';
    }
    return cleaned;
  }

  static bool _mentionsAgentUnavailable(String value) {
    return value.contains('agent') &&
        (value.contains('unavailable') ||
            value.contains('connection') ||
            value.contains('refused'));
  }
}

class UserFacingException implements Exception {
  const UserFacingException(this.message, {this.statusCode = 0});

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
