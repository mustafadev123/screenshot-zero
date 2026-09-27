import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../shared/widgets/page_frame.dart';
import 'onboarding_visuals.dart';
import '../import_preview/import_provider.dart';
import '../zero_stack/inbox_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  void _exploreDemo() {
    ref.read(importProvider.notifier).clear();
    ref.read(inboxProvider.notifier).reset();
    context.go('/home');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(_page + 1);
    } else {
      _controller.nextPage(
        duration: motionDuration(context),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    label: 'Screenshot Zero',
    showBack: false,
    trailing: TextButton(
      onPressed: () => context.go('/home'),
      child: const Text('Skip intro'),
    ),
    footer: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            3,
            (index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
              child: Semantics(
                label: 'Page ${index + 1} of 3',
                selected: index == _page,
                child: Container(
                  width: index == _page ? 24 : 6,
                  height: 4,
                  decoration: BoxDecoration(
                    color: index == _page ? AppColors.signal : AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
        PrimaryButton(
          label: _page == 2 ? 'Start with screenshots' : 'Next',
          onPressed: _page == 2 ? () => context.go('/home') : _next,
        ),
        if (_page == 2)
          TextButton(
            onPressed: _exploreDemo,
            child: const Text('Explore demo'),
          ),
      ],
    ),
    child: PageView(
      controller: _controller,
      onPageChanged: (page) => setState(() => _page = page),
      children: const [
        _IntroPage(
          number: '01 / THE PILE',
          headline: 'Your screenshots are unfinished intentions.',
          copy:
              'Turn the things you save for later into things you actually do.',
          visual: OnboardingStack(),
        ),
        _IntroPage(
          number: '02 / THE POSSIBILITY',
          headline: 'From saved.\nTo done.',
          copy: 'A plan, a place, a little nudge. Give every screenshot somewhere to go.',
          visual: TransformationVisual(),
        ),
        _IntroPage(
          number: '03 / A FRESH START',
          headline: 'Clear the pile.',
          copy: 'One screenshot. One small decision. A little more room for what’s next.',
          visual: OnboardingStack(cleared: true),
        ),
      ],
    ),
  );
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({
    required this.number,
    required this.headline,
    required this.copy,
    required this.visual,
  });
  final String number;
  final String headline;
  final String copy;
  final Widget visual;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          MetaLabel(number),
          const SizedBox(height: 18),
          Text(headline, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 16),
          Text(copy, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          SizedBox(
            height: (constraints.maxHeight * .49).clamp(220.0, 340.0),
            child: visual,
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}
