class AgentEvent {
  final String type;
  final String content;

  AgentEvent({
    required this.type,
    required this.content,
  });

  factory AgentEvent.fromJson(Map<String, dynamic> json) {
    return AgentEvent(
      type: json['type']?.toString() ?? 'unknown',
      content: json['content']?.toString() ?? '',
    );
  }
}