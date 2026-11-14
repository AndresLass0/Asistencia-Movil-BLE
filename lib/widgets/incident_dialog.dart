import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/auth_messages.dart';
import '../core/ui_messages.dart';
import '../models/course.dart';
import '../services/student_backend.dart';

/// Pide una descripción y guarda un reporte de incidencia para el docente.
Future<void> showIncidentDialog(
  BuildContext context, {
  required String uid,
  required Course course,
  String? sessionId,
  StudentBackend backend = const FirebaseStudentBackend(),
}) async {
  final message = await showDialog<String>(
    context: context,
    builder: (_) => _IncidentDialog(courseName: course.name),
  );
  if (message == null || !context.mounted) return;
  try {
    await backend.reportIncident(
      uid: uid,
      courseId: course.id,
      sessionId: sessionId,
      message: message,
      teacherUid: course.teacherUid,
    );
    if (context.mounted) {
      showAppMessage(
        context,
        'Incidencia enviada al docente de ${course.name}.',
      );
    }
  } on FirebaseException catch (e) {
    if (context.mounted) showAppMessage(context, firestoreErrorMessage(e));
  } on TimeoutException {
    if (context.mounted) {
      showAppMessage(
        context,
        'Sin conexión. La incidencia se enviará cuando vuelvas a estar en línea.',
      );
    }
  }
}

class _IncidentDialog extends StatefulWidget {
  const _IncidentDialog({required this.courseName});

  final String courseName;

  @override
  State<_IncidentDialog> createState() => _IncidentDialogState();
}

class _IncidentDialogState extends State<_IncidentDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _ctrl.text.trim().length >= 5;
    return AlertDialog(
      title: const Text('Reportar incidencia'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Asignatura: ${widget.courseName}'),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLength: 500,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Describe el problema (mín. 5 caracteres)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: valid ? () => Navigator.pop(context, _ctrl.text) : null,
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}
