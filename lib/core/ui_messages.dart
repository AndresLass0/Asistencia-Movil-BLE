import 'package:flutter/material.dart';

/// Muestra un mensaje breve (SnackBar) reemplazando el que esté visible.
void showAppMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
