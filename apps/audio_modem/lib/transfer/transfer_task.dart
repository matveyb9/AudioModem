// AudioModem Flutter shell state: presentation owns user-visible task phases; Rust owns protocol and codec behavior.

enum TransferTaskPhase {
  idle,
  preparing,
  verifying,
  completed,
  rejected,
  cancelled,
  unavailable,
}

class TransferTaskState {
  const TransferTaskState._({
    required this.phase,
    required this.message,
    this.detail,
  });

  const TransferTaskState.idle()
    : phase = TransferTaskPhase.idle,
      message = 'Готово к новой передаче.',
      detail = null;

  factory TransferTaskState.preparing(String message) =>
      TransferTaskState._(phase: TransferTaskPhase.preparing, message: message);

  factory TransferTaskState.verifying(String message) =>
      TransferTaskState._(phase: TransferTaskPhase.verifying, message: message);

  factory TransferTaskState.completed(String message, {String? detail}) =>
      TransferTaskState._(
        phase: TransferTaskPhase.completed,
        message: message,
        detail: detail,
      );

  factory TransferTaskState.rejected(String message, {String? detail}) =>
      TransferTaskState._(
        phase: TransferTaskPhase.rejected,
        message: message,
        detail: detail,
      );

  factory TransferTaskState.cancelled(String message) =>
      TransferTaskState._(phase: TransferTaskPhase.cancelled, message: message);

  factory TransferTaskState.unavailable(String message) => TransferTaskState._(
    phase: TransferTaskPhase.unavailable,
    message: message,
  );

  final TransferTaskPhase phase;
  final String message;
  final String? detail;

  bool get isBusy =>
      phase == TransferTaskPhase.preparing ||
      phase == TransferTaskPhase.verifying;

  bool get isTerminal =>
      phase == TransferTaskPhase.completed ||
      phase == TransferTaskPhase.rejected ||
      phase == TransferTaskPhase.cancelled ||
      phase == TransferTaskPhase.unavailable;

  String get label => switch (phase) {
    TransferTaskPhase.idle => 'ОЖИДАНИЕ',
    TransferTaskPhase.preparing => 'ПОДГОТОВКА',
    TransferTaskPhase.verifying => 'ПРОВЕРКА',
    TransferTaskPhase.completed => 'ГОТОВО',
    TransferTaskPhase.rejected => 'ОТКЛОНЕНО',
    TransferTaskPhase.cancelled => 'ОТМЕНЕНО',
    TransferTaskPhase.unavailable => 'НЕДОСТУПНО',
  };
}
