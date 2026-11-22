import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/result_share_service.dart';
import 'shareable_result_card.dart';

/// Bottom sheet that previews the result card, then shares it or saves it
/// to the gallery.
///
/// The preview is not decoration. A [RepaintBoundary] only rasterizes what
/// is actually being painted, so capturing reliably means the card has to
/// be on screen — and once it is on screen anyway, showing it to the user
/// first is strictly better than sharing a picture they have not seen.
///
/// The card is laid out at its true size inside the boundary and scaled
/// down for display by the [FittedBox] outside it, so the captured image
/// is always full size no matter how small the sheet renders it.
class ResultShareSheet extends StatefulWidget {
  final ShareableResultCard card;

  /// Caption offered alongside the image. Apps that accept only an image
  /// drop it, which is why the card carries the same information.
  final String shareText;

  /// Used for the shared file's name.
  final String baseName;

  const ResultShareSheet({
    super.key,
    required this.card,
    required this.shareText,
    required this.baseName,
  });

  /// Opens the sheet. Returns when it closes.
  static Future<void> show(
    BuildContext context, {
    required ShareableResultCard card,
    required String shareText,
    required String baseName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ResultShareSheet(
        card: card,
        shareText: shareText,
        baseName: baseName,
      ),
    );
  }

  @override
  State<ResultShareSheet> createState() => _ResultShareSheetState();
}

class _ResultShareSheetState extends State<ResultShareSheet> {
  final _boundaryKey = GlobalKey();
  bool _busy = false;

  Future<void> _run(Future<ShareOutcome> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final outcome = await action();
    if (!mounted) return;
    setState(() => _busy = false);

    final message = outcome.message;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message,
              style: const TextStyle(fontFamily: 'Roboto')),
          backgroundColor:
              outcome.isError ? AppColors.errorRed : AppColors.cardBg,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
    // Closing on success keeps the user where they were; a failure leaves
    // the sheet open so they can simply try again.
    if (!outcome.isError && outcome != ShareOutcome.dismissed) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Leave room for the handle, buttons and the system inset; whatever is
    // left is what the preview is scaled into.
    final previewMaxHeight = (media.size.height * 0.52).clamp(220.0, 560.0);

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.grey.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: previewMaxHeight),
              child: FittedBox(
                // Scales the preview for display only. The boundary inside
                // still lays out at the card's full size, so the capture
                // is unaffected by how small this looks.
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: widget.card,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _button(
                    icon: Icons.download_outlined,
                    label: 'Save',
                    filled: false,
                    onTap: () => _run(() => ResultShareService.saveToGallery(
                          boundaryKey: _boundaryKey,
                          baseName: widget.baseName,
                        )),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _button(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    filled: true,
                    onTap: () => _run(() => ResultShareService.shareImage(
                          boundaryKey: _boundaryKey,
                          baseName: widget.baseName,
                          text: widget.shareText,
                        )),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _button({
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    final fg = filled ? Colors.black : AppColors.white;
    return Opacity(
      opacity: _busy ? 0.5 : 1,
      child: Material(
        color: filled ? AppColors.primaryCyan : AppColors.cardBg,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: _busy ? null : onTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_busy)
                  SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: fg),
                  )
                else
                  Icon(icon, color: fg, size: 19),
                const SizedBox(width: 9),
                Text(label,
                    style: TextStyle(
                        color: fg,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Roboto')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
