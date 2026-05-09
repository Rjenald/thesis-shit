import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/profile_picture_service.dart';

/// Reusable profile avatar widget.
///
/// - Shows the user's saved photo when available; falls back to initials.
/// - When [editable] is true, tapping opens the gallery and saves the pick.
/// - A small camera-badge is shown in the bottom-right corner when editable.
class ProfileAvatar extends StatelessWidget {
  final String username;

  /// Radius of the circle in logical pixels.
  final double radius;

  /// Set true on profile / account pages so the user can change the photo.
  final bool editable;

  /// Accent colour used for the border and initials fallback.
  final Color accentColor;

  const ProfileAvatar({
    super.key,
    required this.username,
    this.radius = 24,
    this.editable = false,
    this.accentColor = const Color(0xFF00E5FF),
  });

  // ── Image picker ───────────────────────────────────────────────────────────

  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null) return;
    await ProfilePictureService().setImage(picked.path);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfilePictureService>(
      builder: (context, svc, _) {
        final avatar = _avatar(svc);
        if (!editable) return avatar;

        // Wrap in a Stack so the camera badge overlays the circle
        return GestureDetector(
          onTap: () => _pickImage(context),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              avatar,
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: radius * 0.58,
                  height: radius * 0.58,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: Colors.black,
                    size: radius * 0.30,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _avatar(ProfilePictureService svc) {
    if (svc.hasImage) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(svc.imagePath!)),
        backgroundColor: Colors.transparent,
      );
    }

    // Initials fallback
    final initial =
        username.isNotEmpty ? username[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: accentColor.withValues(alpha: 0.15),
      child: Text(
        initial,
        style: TextStyle(
          color: accentColor,
          fontSize: radius * 0.75,
          fontWeight: FontWeight.bold,
          fontFamily: 'Roboto',
        ),
      ),
    );
  }
}
