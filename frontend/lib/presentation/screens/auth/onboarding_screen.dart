import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/services/launch_preferences.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/presentation/screens/auth/login_screen.dart';
import 'package:hugeicons/hugeicons.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingPageData> _pages = [
    _OnboardingPageData(
      icon: HugeIcons.strokeRoundedAiMail,
      accentLabel: 'Gmail connected',
      metricOne: '12 primary',
      metricTwo: '5 priority',
      title: 'Connect your inbox',
      description:
          'Let TT Mail Assistant classify, prioritize, and draft replies before email noise reaches you.',
    ),
    _OnboardingPageData(
      icon: HugeIcons.strokeRoundedAiLock,
      accentLabel: 'Review protected',
      metricOne: 'Urgent held',
      metricTwo: 'Draft checked',
      title: 'Keep control',
      description:
          'Urgent or uncertain replies wait for your review, while safe routine emails move quietly.',
    ),
    _OnboardingPageData(
      icon: HugeIcons.strokeRoundedAiChat01,
      accentLabel: 'Replies ready',
      metricOne: '3 drafts',
      metricTwo: '1 tap approve',
      title: 'Answer faster',
      description:
          'Approve, edit, or ignore AI drafts from one calm mobile workspace built for daily triage.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    await LaunchPreferences.markOnboardingSeen();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  void _next() {
    if (_currentPage == _pages.length - 1) {
      _completeOnboarding();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isCompact = media.size.height < 720;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppPalette.mist, AppPalette.white, Color(0xFFDDE2D7)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
            child: Column(
              children: [
                _OnboardingHeader(onSkip: _completeOnboarding),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      return _OnboardingPage(
                        data: _pages[index],
                        isCompact: isCompact,
                      );
                    },
                  ),
                ),
                _PageIndicator(count: _pages.length, activeIndex: _currentPage),
                const SizedBox(height: 18),
                _PrimaryActionButton(
                  label:
                      _currentPage == _pages.length - 1
                          ? 'Open assistant'
                          : 'Get started',
                  onPressed: _next,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          'assets/logos/simple-logo-no-bg.png',
          width: 42,
          height: 42,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'TT Mail Assistant',
            style: TextStyle(
              color: AppPalette.ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(
            foregroundColor: AppPalette.pine,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          child: const Text('Skip'),
        ),
      ],
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data, required this.isCompact});

  final _OnboardingPageData data;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageHeight = constraints.maxHeight * (isCompact ? 0.42 : 0.56);
        final titleSize = isCompact ? 30.0 : 38.0;
        final bodySize = isCompact ? 15.0 : 17.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: imageHeight.clamp(170.0, 520.0),
              child: _HeroVisual(data: data),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Text(
                    data.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppPalette.ink,
                      height: 1.02,
                      fontWeight: FontWeight.w900,
                    ).copyWith(fontSize: titleSize),
                  ),
                  SizedBox(height: isCompact ? 8 : 14),
                  Text(
                    data.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppPalette.pine,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ).copyWith(fontSize: bodySize),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          width: isActive ? 28 : 9,
          height: 9,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isActive ? AppPalette.teal : AppPalette.lavender,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _HeroVisual extends StatelessWidget {
  const _HeroVisual({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 360,
        height: 300,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            const Positioned(top: 18, right: 24, child: _AccentSpark(size: 82)),
            const Positioned(
              bottom: 20,
              left: 18,
              child: _AccentSpark(size: 56),
            ),
            Container(
              width: 248,
              height: 248,
              decoration: BoxDecoration(
                color: AppPalette.white.withValues(alpha: 0.80),
                borderRadius: BorderRadius.circular(42),
                border: Border.all(
                  color: AppPalette.white.withValues(alpha: 0.90),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppPalette.pine.withValues(alpha: 0.16),
                    blurRadius: 34,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/logos/simple-logo-no-bg.png',
                          width: 44,
                          height: 44,
                          fit: BoxFit.contain,
                        ),
                        const Spacer(),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppPalette.ink,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: HugeIcon(
                            icon: data.icon,
                            color: AppPalette.lavender,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppPalette.pine,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.accentLabel,
                            style: const TextStyle(
                              color: AppPalette.mist,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const _SignalLine(widthFactor: 0.86),
                          const SizedBox(height: 8),
                          const _SignalLine(widthFactor: 0.62),
                        ],
                      ),
                    ),
                    const Row(
                      children: [
                        _StatusDot(color: AppPalette.teal),
                        SizedBox(width: 8),
                        _StatusDot(color: AppPalette.lavender),
                        SizedBox(width: 8),
                        _StatusDot(color: AppPalette.pine),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 2,
              child: _FloatingBadge(
                icon: HugeIcons.strokeRoundedAiMagic,
                label: data.metricOne,
                color: AppPalette.lavender,
              ),
            ),
            Positioned(
              left: 2,
              bottom: 18,
              child: _FloatingBadge(
                icon: HugeIcons.strokeRoundedCheckmarkBadge02,
                label: data.metricTwo,
                color: AppPalette.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingBadge extends StatelessWidget {
  const _FloatingBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final List<List<dynamic>> icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 144,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppPalette.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: AppPalette.ink.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: 18, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppPalette.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalLine extends StatelessWidget {
  const _SignalLine({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          color: AppPalette.mist.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 62,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.teal,
          foregroundColor: AppPalette.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ).copyWith(
          overlayColor: WidgetStateProperty.all(
            AppPalette.lavender.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label),
            const SizedBox(width: 10),
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight02,
              color: AppPalette.white,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentSpark extends StatelessWidget {
  const _AccentSpark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppPalette.lavender.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.accentLabel,
    required this.metricOne,
    required this.metricTwo,
    required this.title,
    required this.description,
  });

  final List<List<dynamic>> icon;
  final String accentLabel;
  final String metricOne;
  final String metricTwo;
  final String title;
  final String description;
}
