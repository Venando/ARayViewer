
import 'package:flutter/material.dart';
import 'package:cancellation_token/cancellation_token.dart';

class FilesIndexerText extends StatefulWidget {
  
  final int? currentIndex;
  final int totalFiles;
  
  const FilesIndexerText({
    super.key,
    required this.currentIndex,
    required this.totalFiles,
  });

  @override
  State<FilesIndexerText> createState() => _FilesIndexerTextState();
}

class _FilesIndexerTextState extends State<FilesIndexerText> {
  
  static const int _fadeOutDelay = 1000; // milliseconds
  static const int _fadeOutDuration = 400;
  bool _visible = false;
  int _currentIndex = -1;
  CancellationToken _cancellationToken = CancellationToken();

  @override
  void initState() {
    super.initState();
    _visible = false;
  }

  @override
  void didUpdateWidget(covariant FilesIndexerText oldWidget) {
    super.didUpdateWidget(widget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _onCurrentIndexChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          duration: _visible ? Duration.zero : const Duration(milliseconds: _fadeOutDuration),
          opacity: _visible ? 1.0 : 0.0,
          curve: Easing.standardDecelerate,
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 12.0,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(175),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Text(
              widget.totalFiles > 0
                  ? '${widget.currentIndex != null ? widget.currentIndex! + 1 : 0} / ${widget.totalFiles}'
                  : 'No images found',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.bold
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onCurrentIndexChanged() {
    if (widget.currentIndex != null && widget.currentIndex! >= 0) {
      if (_currentIndex != widget.currentIndex) {
        _visible = true;
        _currentIndex = widget.currentIndex!;
        _cancellationToken.cancel();
        _cancellationToken = CancellationToken();
        toggleVisibilityWithDelay();
      }
    }
  }

  void toggleVisibilityWithDelay() async {
    try {
      await Future.delayed(const Duration(milliseconds: _fadeOutDelay)).asCancellable(_cancellationToken);
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
    super.dispose();
  }
}
