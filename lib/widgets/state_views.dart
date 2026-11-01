import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/auth_messages.dart';
import 'secondary_button.dart';

/// Indicador de carga centrado.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Cargando…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 14),
            Text(message, style: const TextStyle(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// Mensaje centrado con ícono (estados vacíos y de error).
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: color),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              SecondaryButton(label: actionLabel!, onPressed: onAction!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error al cargar los datos académicos.
class AcademicErrorView extends StatelessWidget {
  const AcademicErrorView({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final detail = error is FirebaseException
        ? firestoreErrorMessage(error as FirebaseException)
        : 'Ocurrió un error inesperado.';
    return MessageView(
      icon: Icons.cloud_off,
      color: AppColors.danger,
      title: 'No se pudieron cargar tus clases',
      message: detail,
    );
  }
}

/// Sin asignaturas matriculadas.
class NoCoursesView extends StatelessWidget {
  const NoCoursesView({super.key});

  @override
  Widget build(BuildContext context) {
    return const MessageView(
      icon: Icons.menu_book_outlined,
      title: 'Aún no tienes asignaturas',
      message:
          'Cuando la universidad o tu docente te matricule en una '
          'asignatura, aparecerá aquí con su horario y tu asistencia.',
    );
  }
}
