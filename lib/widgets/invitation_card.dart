import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/academic_snapshot.dart';
import 'app_card.dart';

/// Invitación de un docente a una asignatura, con Aceptar y Rechazar.
class InvitationCard extends StatelessWidget {
  const InvitationCard({
    super.key,
    required this.invitation,
    required this.onAccept,
    required this.onDecline,
  });

  final CourseInvitation invitation;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final c = invitation.course;
    final teacher = c.teacherName.isEmpty
        ? 'Un docente'
        : 'Prof. ${c.teacherName}';
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.mail_outline, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invitación a una clase',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$teacher te agregó a ${c.name}'
                      '${c.group.isEmpty ? '' : ' · Grupo ${c.group}'}'
                      '${c.period.isEmpty ? '' : ' (${c.period})'}.',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  child: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onAccept,
                  child: const Text('Aceptar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
