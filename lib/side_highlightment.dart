
import 'package:cancellation_token/cancellation_token.dart';
import 'package:flutter/material.dart';

class SideHighlightment extends StatefulWidget {
  const SideHighlightment({
    super.key,
    required this.highlightTrigger, required this.cancelationTrigger, required this.isLeft, required this.appearTime,
  });
  final ValueNotifier<bool> highlightTrigger;
  final ValueNotifier<bool> cancelationTrigger;
  
  final bool isLeft;
  
  final int appearTime;

  @override
  State<SideHighlightment> createState() => _SideHighlightmentState();
}

class _SideHighlightmentState extends State<SideHighlightment> {
  
  static const int _repeatedTriggerDelay = 150;
  static const int _fadeOutDuration = 200;
  static const int _fadeInDuration = 0;

  DateTime? _lastTriggerTime;
  bool _visible = false;
  bool _isCancelled = true;
  CancellationToken _cancellationToken = CancellationToken();

  @override
  void initState() {
    super.initState();
    widget.highlightTrigger.addListener(_onHighlightTrigger);
    widget.cancelationTrigger.addListener(_onCancelationTrigger);
    _visible = false;
  }

  @override
  Widget build(BuildContext context) {
    var colorScheme = Theme.of(context).colorScheme;

    if (_isCancelled) {
      return const SizedBox.shrink();
    }

    var direction = !widget.isLeft;

    return Positioned(
      left: direction ? null : 0,
      right: direction ? 0 : null,
      top: 0,
      bottom: 0,
      width: 40,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _visible ? 1.0 : 0.0,
          duration: _visible
              ? const Duration(milliseconds: _fadeInDuration)
              : const Duration(milliseconds: _fadeOutDuration),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: direction
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                end: direction
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                colors: [
                  colorScheme.primaryFixedDim.withAlpha(180),
                  colorScheme.primary.withAlpha(0),
                ],
                stops: const [0.0, 1.0],
              ),
              borderRadius: BorderRadius.horizontal(
                left: direction ? const Radius.circular(18) : Radius.zero,
                right: direction ? Radius.zero : const Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withAlpha(60),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: direction
                      ? const Offset(-4, 0)
                      : const Offset(4, 0),
                ),
              ],
            ),
            margin: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
            child: Align(
              alignment: direction
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Padding(
                padding: direction
                    ? const EdgeInsets.only(right: 8.0)
                    : const EdgeInsets.only(left: 8.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Shadow
                    Positioned(
                      left: direction
                          ? -2
                          : 2, // Increased offset for larger shadow
                      top: 2,
                      child: Icon(
                        direction
                            ? Icons.arrow_forward_ios
                            : Icons.arrow_back_ios_new,
                        color: Colors.black.withAlpha(120),
                        size: 20, // Increased shadow icon size
                      ),
                    ),
                    // Main Icon
                    Icon(
                      direction
                          ? Icons.arrow_forward_ios
                          : Icons.arrow_back_ios_new,
                      color: colorScheme.primary.withAlpha(255),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }



  void _onHighlightTrigger() {

    if (_lastTriggerTime != null &&
        DateTime.now().difference(_lastTriggerTime!) <
            const Duration(milliseconds: _repeatedTriggerDelay)) {
      return; // Ignore repeated triggers within the delay
    }

    _lastTriggerTime = DateTime.now();
    
    setState(() {
      _isCancelled = false;
      _visible = true;
    });
    _cancellationToken.cancel();
    _cancellationToken = CancellationToken();
    toggleVisibilityWithDelay();
  }

  void _onCancelationTrigger() {
    setState(() {
      _isCancelled = true;
      _visible = false;
    });
    _cancellationToken.cancel();
  }

  void toggleVisibilityWithDelay() async {
    try {
      await Future.delayed(
        Duration(milliseconds: widget.appearTime),
      ).asCancellable(_cancellationToken);
    } on CancelledException {
      return;
    }
    setState(() {
      _visible = false;
    });
  }

  @override
  void dispose() {
    _cancellationToken.cancel();
    widget.highlightTrigger.removeListener(_onHighlightTrigger);
    widget.cancelationTrigger.removeListener(_onCancelationTrigger);
    super.dispose();
  }
}
