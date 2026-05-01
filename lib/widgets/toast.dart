import 'dart:async';
import 'package:flutter/material.dart';
import '../booking_tokens.dart';

enum ToastKind { good, info, warn }

class ToastController {
  OverlayEntry? _entry;
  Timer? _timer;

  void show(BuildContext context, String message, {ToastKind kind = ToastKind.info}) {
    dismiss();
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (ctx) => _ToastView(message: message, kind: kind),
    );
    overlay.insert(entry);
    _entry = entry;
    _timer = Timer(const Duration(milliseconds: 2400), dismiss);
  }

  void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _ToastView extends StatefulWidget {
  final String message;
  final ToastKind kind;
  const _ToastView({required this.message, required this.kind});

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..forward();
    _slide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = BookingTokens.of(context);
    Color bg;
    Color fg;
    switch (widget.kind) {
      case ToastKind.good:
        bg = tokens.green;
        fg = Colors.white;
        break;
      case ToastKind.warn:
        bg = tokens.clay;
        fg = Colors.white;
        break;
      case ToastKind.info:
        bg = tokens.ink;
        fg = tokens.bg;
        break;
    }
    return Positioned(
      left: 16,
      right: 16,
      bottom: MediaQuery.of(context).padding.bottom + 14,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
