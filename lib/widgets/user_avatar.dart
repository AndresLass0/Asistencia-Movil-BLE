import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Avatar del usuario: foto de Firebase si existe, si no su inicial.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    // Sin Firebase inicializado (error de arranque o pruebas) se muestra "U".
    final user = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser;
    final photo = user?.photoURL;
    final label = (user?.displayName?.isNotEmpty ?? false)
        ? user!.displayName!
        : (user?.email ?? 'U');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        image: photo != null
            ? DecorationImage(image: NetworkImage(photo), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: photo == null
          ? Text(
              (label.isEmpty ? 'U' : label.characters.first).toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.42,
              ),
            )
          : null,
    );
  }
}
