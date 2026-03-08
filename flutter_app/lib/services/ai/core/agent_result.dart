enum ResultStatus { success, fail, partial }

class AgentResult {
  final ResultStatus status;
  final String message;
  final Map<String, dynamic>? data;

  AgentResult({
    required this.status,
    required this.message,
    this.data,
  });

  factory AgentResult.success({String message = 'Success', Map<String, dynamic>? data}) {
    return AgentResult(status: ResultStatus.success, message: message, data: data);
  }

  factory AgentResult.fail({required String message, Map<String, dynamic>? data}) {
    return AgentResult(status: ResultStatus.fail, message: message, data: data);
  }

  @override
  String toString() => 'AgentResult(status: $status, message: $message, data: $data)';
}
