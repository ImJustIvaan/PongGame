import 'package:flutter/material.dart';

class UserUtils {
  /// Checks if the given username belongs to the verified account 'imjustivaan' (case-insensitive).
  static bool isVerified(String? username) {
    if (username == null) return false;
    return username.trim().toLowerCase() == 'imjustivaan';
  }

  /// Glowing verified checkmark badge widget.
  static Widget verifiedBadge({double size = 16}) {
    return Tooltip(
      message: 'Verified Player',
      child: Container(
        margin: const EdgeInsets.only(left: 5),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x9900E5FF),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          Icons.verified,
          color: const Color(0xFF00E5FF),
          size: size,
        ),
      ),
    );
  }
}
