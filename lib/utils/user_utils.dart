import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class UserUtils {
  /// Checks if the given username has owner admin privileges (strictly ImJustIvaan).
  static bool isOwner(String? username) {
    if (username == null) return false;
    return username.trim().toLowerCase() == 'imjustivaan';
  }

  /// Checks if the given username belongs to a verified account (owner or admin-verified).
  static bool isVerified(String? username) {
    if (username == null) return false;
    if (isOwner(username)) return true;
    return StorageService.instance.isLocalVerified(username);
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
