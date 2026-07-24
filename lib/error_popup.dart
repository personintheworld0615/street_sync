import 'dart:async';

import 'package:flutter/material.dart';

/// Brief error toast: red X + message, auto-dismisses after [duration].
Future<void> showErrorPopup(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (dialogContext) {
      return _ErrorPopup(message: message, duration: duration);
    },
  );
}

class _ErrorPopup extends StatefulWidget {
  const _ErrorPopup({
    required this.message,
    required this.duration,
  });

  final String message;
  final Duration duration;

  @override
  State<_ErrorPopup> createState() => _ErrorPopupState();
}

class _ErrorPopupState extends State<_ErrorPopup> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.red.shade600,
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF152033),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
