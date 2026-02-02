import 'package:flutter/cupertino.dart'
    show CupertinoSliverRefreshControl, RefreshIndicatorMode;
import 'package:flutter/material.dart';
import 'package:sono/styles/app_theme.dart';

/// Custom refresh indicator
class SonoRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final double displacement;
  final double edgeOffset;

  const SonoRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.displacement = 40.0,
    this.edgeOffset = 0.0,
  });

  @override
  State<SonoRefreshIndicator> createState() => _SonoRefreshIndicatorState();
}

class _SonoRefreshIndicatorState extends State<SonoRefreshIndicator> {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      displacement: widget.displacement,
      edgeOffset: widget.edgeOffset,
      color: AppTheme.brandPink,
      backgroundColor: AppTheme.elevatedSurfaceDark,
      child: widget.child,
    );
  }
}

class SonoRefreshLogo extends StatefulWidget {
  final bool isRefreshing;
  final double size;
  final Color? color;

  const SonoRefreshLogo({
    super.key,
    this.isRefreshing = false,
    this.size = 40.0,
    this.color,
  });

  @override
  State<SonoRefreshLogo> createState() => _SonoRefreshLogoState();
}

class _SonoRefreshLogoState extends State<SonoRefreshLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.15,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);

    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: -0.15,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -0.15,
          end: 0.15,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.15,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
    ]).animate(_controller);

    if (widget.isRefreshing) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SonoRefreshLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRefreshing && !oldWidget.isRefreshing) {
      _controller.repeat();
    } else if (!widget.isRefreshing && oldWidget.isRefreshing) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isRefreshing ? _scaleAnimation.value : 1.0,
          child: Transform.rotate(
            angle: widget.isRefreshing ? _rotationAnimation.value : 0.0,
            child: child,
          ),
        );
      },
      child: Image.asset(
        'assets/images/logos/favicon-white.png',
        width: widget.size,
        height: widget.size,
        color: widget.color ?? AppTheme.backgroundLight,
        colorBlendMode: BlendMode.srcIn,
      ),
    );
  }
}

class SonoBouncingScrollPhysics extends BouncingScrollPhysics {
  const SonoBouncingScrollPhysics({super.parent});

  @override
  SonoBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SonoBouncingScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get dragStartDistanceMotionThreshold => 3.5;
}

class SonoSliverRefreshControl extends StatefulWidget {
  final Future<void> Function() onRefresh;

  const SonoSliverRefreshControl({super.key, required this.onRefresh});

  @override
  State<SonoSliverRefreshControl> createState() =>
      _SonoSliverRefreshControlState();
}

class _SonoSliverRefreshControlState extends State<SonoSliverRefreshControl>
    with SingleTickerProviderStateMixin {
  bool _isRefreshing = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateToSideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.2,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_animationController);
    _rotateToSideAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: -0.15,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -0.15,
          end: 0.15,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.15,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
    ]).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    _animationController.repeat();

    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        _animationController.stop();
        _animationController.reset();
        setState(() => _isRefreshing = false);
      }
    }
  }

  Widget _buildRefreshIndicator(
    BuildContext context,
    RefreshIndicatorMode refreshState,
    double pulledExtent,
    double refreshTriggerPullDistance,
    double refreshIndicatorExtent,
  ) {
    final double percentageComplete =
        (pulledExtent / refreshTriggerPullDistance).clamp(0.0, 1.0);

    if (refreshState == RefreshIndicatorMode.refresh && !_isRefreshing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleRefresh();
      });
    }

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.elevatedSurfaceDark,
            ),
          ),
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final scale =
                  _isRefreshing
                      ? _scaleAnimation.value
                      : 0.5 + (percentageComplete * 0.5);

              final rotation =
                  _isRefreshing ? _rotateToSideAnimation.value : 0.0;

              return Transform.rotate(
                angle: rotation,
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: percentageComplete,
                    child: child,
                  ),
                ),
              );
            },
            child: Image.asset(
              'assets/images/logos/favicon-white.png',
              width: 28,
              height: 28,
              color: AppTheme.backgroundLight,
              colorBlendMode: BlendMode.srcIn,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoSliverRefreshControl(
      onRefresh: _handleRefresh,
      builder: _buildRefreshIndicator,
    );
  }
}