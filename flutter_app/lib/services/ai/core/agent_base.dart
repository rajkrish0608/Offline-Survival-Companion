import 'dart:async';
import 'agent_result.dart';

enum AgentStatus { idle, running, paused, error, success }

abstract class AgentBase {
  String get agentName;
  AgentStatus _status = AgentStatus.idle;
  AgentStatus get status => _status;

  final _statusController = StreamController<AgentStatus>.broadcast();
  Stream<AgentStatus> get statusStream => _statusController.stream;

  void updateStatus(AgentStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  Future<AgentResult> execute(Map<String, dynamic> params);

  Future<void> pause() async {
    updateStatus(AgentStatus.paused);
  }

  Future<void> resume() async {
    updateStatus(AgentStatus.running);
  }

  void dispose() {
    _statusController.close();
  }
}
