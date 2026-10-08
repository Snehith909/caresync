import 'package:flutter/material.dart';

enum MedicationStatus { taken, due, upcoming, missed }

class MedicationItem {
  MedicationItem({
    required this.id,
    required this.name,
    required this.dose,
    required this.time,
    required this.instruction,
    required this.period,
    this.status = MedicationStatus.upcoming,
  });

  final String id;
  final String name;
  final String dose;
  final String time;
  final String instruction;
  final String period;
  MedicationStatus status;

  IconData get icon {
    switch (period) {
      case 'Morning':
        return Icons.wb_sunny_outlined;
      case 'Afternoon':
        return Icons.wb_twilight_outlined;
      default:
        return Icons.nights_stay_outlined;
    }
  }

  String get statusLabel {
    switch (status) {
      case MedicationStatus.taken:
        return 'Taken';
      case MedicationStatus.due:
        return 'Due now';
      case MedicationStatus.missed:
        return 'Missed';
      case MedicationStatus.upcoming:
        return 'Upcoming';
    }
  }
}

class FollowUp {
  const FollowUp({
    required this.date,
    required this.title,
    required this.description,
  });

  final String date;
  final String title;
  final String description;
}

class DayProgress {
  const DayProgress({
    required this.day,
    required this.value,
    required this.status,
  });

  final String day;
  final int value;
  final String status;
}
