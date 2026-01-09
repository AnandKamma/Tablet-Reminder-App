class ScheduleModel {
  final List<String> daysOfWeek; // ["Monday", "Tuesday", ...] or ["All"]
  final List<String> times; // ["08:00 AM", "02:00 PM", "08:00 PM"]
  final bool reminderEnabled;
  final bool alarmEnabled;

  ScheduleModel({
    required this.daysOfWeek,
    required this.times,
    required this.reminderEnabled,
    required this.alarmEnabled,
  });

  Map<String, dynamic> toMap() {
    return {
      'daysOfWeek': daysOfWeek,
      'times': times,
      'reminderEnabled': reminderEnabled,
      'alarmEnabled': alarmEnabled,
    };
  }

  factory ScheduleModel.fromMap(Map<String, dynamic> map) {
    return ScheduleModel(
      daysOfWeek: List<String>.from(map['daysOfWeek'] ?? []),
      times: List<String>.from(map['times'] ?? []),
      reminderEnabled: map['reminderEnabled'] ?? false,
      alarmEnabled: map['alarmEnabled'] ?? false,
    );
  }
}