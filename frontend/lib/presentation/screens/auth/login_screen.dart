import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/domain/usecases/auth_usecase.dart';
import 'package:tt_mail_assistant/presentation/screens/inbox/inbox_screen.dart';
import 'package:tt_mail_assistant/presentation/viewmodels/auth_view_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AuthViewModel(getIt<AuthUseCase>());
    _viewModel.addListener(_onAuthChanged);
    _viewModel.prepareSignIn();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onAuthChanged);
    _viewModel.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _signIn() async {
    final user = await _viewModel.signIn();
    if (!mounted || user == null) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const InboxScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _viewModel.status == AuthStatus.loading;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppPalette.ink, AppPalette.pine, AppPalette.teal],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BrandMark(),
                const Spacer(),
                const _LoginHero(),
                const SizedBox(height: 34),
                _GoogleButton(isLoading: isLoading, onPressed: _signIn),
                if (_viewModel.errorMessage != null) ...[
                  const SizedBox(height: 14),
                  _ErrorBanner(message: _viewModel.errorMessage!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppPalette.mist,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Image.asset('assets/logos/simple-logo-no-bg.png'),
        ),
        const SizedBox(width: 12),
        const Text(
          'TT Mail Assistant',
          style: TextStyle(
            color: AppPalette.mist,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        const Text(
          'Sign in to your intelligent inbox',
          style: TextStyle(
            color: AppPalette.mist,
            fontSize: 42,
            fontWeight: FontWeight.w900,
            height: 1.02,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Connect Gmail to classify messages, prepare safe drafts, and keep every action under your control.',
          style: TextStyle(
            color: AppPalette.mist.withValues(alpha: 0.78),
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.mist,
          disabledBackgroundColor: AppPalette.mist.withValues(alpha: 0.64),
          foregroundColor: AppPalette.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon:
            isLoading
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
                : const HugeIcon(
                  icon: HugeIcons.strokeRoundedGoogle,
                  color: AppPalette.ink,
                  size: 22,
                ),
        label: Text(
          isLoading ? 'Connecting...' : 'Continue with Google',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.lavender.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.lavender.withValues(alpha: 0.34)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppPalette.mist,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
