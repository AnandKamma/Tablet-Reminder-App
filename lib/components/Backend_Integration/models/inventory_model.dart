class InventoryModel {
  final int pillsPerRefill; // How many pills filled at a time
  final bool refillReminderEnabled;
  final int? refillReminderQuantity; // At what quantity to remind

  InventoryModel({
    required this.pillsPerRefill,
    required this.refillReminderEnabled,
    this.refillReminderQuantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'pillsPerRefill': pillsPerRefill,
      'refillReminderEnabled': refillReminderEnabled,
      if (refillReminderQuantity != null) 'refillReminderQuantity': refillReminderQuantity,
    };
  }

  factory InventoryModel.fromMap(Map<String, dynamic> map) {
    return InventoryModel(
      pillsPerRefill: map['pillsPerRefill'] ?? 0,
      refillReminderEnabled: map['refillReminderEnabled'] ?? false,
      refillReminderQuantity: map['refillReminderQuantity'],
    );
  }
}