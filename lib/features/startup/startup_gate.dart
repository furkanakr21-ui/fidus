import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class StartupGate extends StatefulWidget {
  final bool isReady;
  final bool timeoutEnabled;
  final Widget child;
  final Duration minimumDisplayDuration;
  final Duration maximumWaitDuration;
  final Duration transitionDuration;

  const StartupGate({
    super.key,
    required this.isReady,
    required this.child,
    this.timeoutEnabled = true,
    this.minimumDisplayDuration = const Duration(milliseconds: 1300),
    this.maximumWaitDuration = const Duration(seconds: 8),
    this.transitionDuration = const Duration(milliseconds: 420),
  });

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  Timer? _minimumTimer;
  Timer? _maximumTimer;
  Timer? _removalTimer;
  bool _minimumElapsed = false;
  bool _timedOut = false;
  bool _visible = true;
  bool _removed = false;

  @override
  void initState() {
    super.initState();
    _minimumTimer = Timer(widget.minimumDisplayDuration, () {
      _minimumElapsed = true;
      _tryDismiss();
    });
    _startMaximumTimer();
  }

  @override
  void didUpdateWidget(covariant StartupGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.timeoutEnabled && widget.timeoutEnabled) {
      _startMaximumTimer();
    } else if (oldWidget.timeoutEnabled && !widget.timeoutEnabled) {
      _maximumTimer?.cancel();
      _maximumTimer = null;
    }
    if (!oldWidget.isReady && widget.isReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryDismiss());
    }
  }

  void _startMaximumTimer() {
    if (!widget.timeoutEnabled || _maximumTimer != null || _timedOut) return;
    _maximumTimer = Timer(widget.maximumWaitDuration, () {
      _timedOut = true;
      _tryDismiss();
    });
  }

  void _tryDismiss() {
    if (!mounted || !_visible) return;
    if (!_timedOut && !(widget.isReady && _minimumElapsed)) return;
    setState(() => _visible = false);
    _removalTimer = Timer(widget.transitionDuration, () {
      if (mounted) setState(() => _removed = true);
    });
  }

  @override
  void dispose() {
    _minimumTimer?.cancel();
    _maximumTimer?.cancel();
    _removalTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_removed)
          IgnorePointer(
            ignoring: !_visible,
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: widget.transitionDuration,
              curve: Curves.easeOutCubic,
              child: const StartupSplash(),
            ),
          ),
      ],
    );
  }
}

class StartupSplash extends StatefulWidget {
  const StartupSplash({super.key});

  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<StartupSplash>
    with TickerProviderStateMixin {
  late final AnimationController _signatureController;
  late final AnimationController _haloController;
  late final Animation<double> _lineScale;
  late final Animation<double> _contentOpacity;
  late final Animation<double> _haloScale;

  @override
  void initState() {
    super.initState();
    _signatureController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2250),
    )..repeat();
    _haloController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _lineScale = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0), weight: 12),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 46,
      ),
      TweenSequenceItem(tween: ConstantTween(1), weight: 24),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 18,
      ),
    ]).animate(_signatureController);
    _contentOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0), weight: 28),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 26),
      TweenSequenceItem(tween: ConstantTween(1), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 16),
    ]).animate(_signatureController);
    _haloScale = Tween(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _haloController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _haloController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('startup-splash-surface'),
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.08),
          radius: 0.82,
          colors: [Color(0xFF102D36), Color(0xFF071D26), Color(0xFF050E14)],
          stops: [0, 0.48, 1],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _signatureController,
              _haloController,
            ]),
            builder: (context, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 230,
                    height: 106,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(
                          scale: _haloScale.value,
                          child: Container(
                            width: 190,
                            height: 190,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [Color(0x1A00FFC1), Colors.transparent],
                              ),
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(0, -2 * _haloController.value),
                          child: const Text(
                            'fidus',
                            style: TextStyle(
                              color: Color(0xFFF4FBFA),
                              fontFamily: 'serif',
                              fontSize: 58,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -3,
                              height: 1,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    width: 158,
                    height: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.darkTextSecondary.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Align(
                        alignment: Alignment.center,
                        child: Transform.scale(
                          key: const Key('startup-signature-line'),
                          scaleX: _lineScale.value,
                          alignment: Alignment.center,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(99),
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.market,
                                  AppColors.primary,
                                  AppColors.market,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Opacity(
                    opacity: _contentOpacity.value,
                    child: const Text(
                      'Finansal görünümünüz hazırlanıyor',
                      style: TextStyle(
                        color: AppColors.darkTextSecondary,
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.75,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Opacity(
                    opacity: 0.35 + (_contentOpacity.value * 0.65),
                    child: Transform.scale(
                      scale: 0.8 + (_contentOpacity.value * 0.4),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
