import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:staffpro/core/theme/app_colors.dart';
import 'package:staffpro/core/validators/validators.dart';
import 'package:staffpro/core/widgets/brand_logo.dart';
import 'package:staffpro/core/widgets/ui_kit.dart';
import 'package:staffpro/state/app_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      final app = context.read<StaffProController>();
      if (app.currentUser == null) {
        context.go('/login');
      } else {
        context.go(homeFor(app.currentUser!.role));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecorativeBackground(
        child: Center(child: BrandLogo(size: 96)),
      ),
    );
  }
}

String homeFor(dynamic role) {
  final name = role.toString().split('.').last;
  switch (name) {
    case 'superAdmin':
      return '/sa';
    case 'businessAdmin':
      return '/ba';
    case 'manager':
      return '/mg';
    default:
      return '/emp';
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _remember = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    context.read<StaffProController>().rememberedEmail().then((v) {
      if (v != null && mounted) _email.text = v;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final app = context.read<StaffProController>();
      await app.login(_email.text, _password.text, remember: _remember);
      if (!mounted) return;
      context.go(homeFor(app.currentUser!.role));
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecorativeBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  const BrandLogo(size: 78)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: -0.08, end: 0),
                  const SizedBox(height: 28),
                  const Text('Login', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.navy)),
                  const SizedBox(height: 4),
                  const Text('Access your account', style: TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 22),
                  AppTextField(
                    label: 'Email',
                    controller: _email,
                    hint: 'Enter your email',
                    prefix: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Password',
                    controller: _password,
                    hint: 'Enter your password',
                    prefix: Icons.lock_outline_rounded,
                    obscure: _obscure,
                    textInputAction: TextInputAction.done,
                    validator: (v) => Validators.password(v),
                    suffix: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.placeholder),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(value: _remember, onChanged: (v) => setState(() => _remember = v ?? true)),
                      ),
                      const SizedBox(width: 8),
                      const Text('Remember me', style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        child: const Text('Forgot password?'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AppButton(label: 'Login', loading: _loading, onPressed: _loading ? null : _submit),
                  const SizedBox(height: 22),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.wash,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.verified_user_outlined, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Are you a Super Admin?', style: TextStyle(fontWeight: FontWeight.w800)),
                                  SizedBox(height: 2),
                                  Text(
                                    'Create your Super Admin account using the secret registration code.',
                                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: 'Super Admin Signup',
                          outlined: true,
                          icon: Icons.arrow_forward_rounded,
                          onPressed: () => context.push('/signup'),
                        ),
                      ],
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0),
            ),
          ),
        ),
      ),
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<StaffProController>().signupSuperAdmin(
            fullName: _name.text,
            email: _email.text,
            password: _password.text,
            confirm: _confirm.text,
            secretCode: _code.text,
          );
      if (!mounted) return;
      showToast(context, 'Super Admin account created. Please login.');
      context.go('/login');
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecorativeBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary),
                    ),
                  ),
                  const BrandLogo(size: 64),
                  const SizedBox(height: 18),
                  const Text('Create Super Admin', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter your details and the secret code to create a super admin account.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 20),
                  AppTextField(label: 'Full Name', controller: _name, hint: 'Enter your full name', prefix: Icons.person_outline, validator: (v) => Validators.requiredField(v, field: 'Full name')),
                  const SizedBox(height: 14),
                  AppTextField(label: 'Email Address', controller: _email, hint: 'Enter your email address', prefix: Icons.mail_outline, keyboardType: TextInputType.emailAddress, validator: Validators.email),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Password',
                    controller: _password,
                    hint: 'Enter your password',
                    prefix: Icons.lock_outline,
                    obscure: _obscure1,
                    validator: (v) => Validators.password(v),
                    suffix: IconButton(onPressed: () => setState(() => _obscure1 = !_obscure1), icon: Icon(_obscure1 ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.placeholder)),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Confirm Password',
                    controller: _confirm,
                    hint: 'Confirm your password',
                    prefix: Icons.lock_outline,
                    obscure: _obscure2,
                    validator: (v) => Validators.confirmPassword(v, _password.text),
                    suffix: IconButton(onPressed: () => setState(() => _obscure2 = !_obscure2), icon: Icon(_obscure2 ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.placeholder)),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Secret Registration Code',
                    controller: _code,
                    hint: 'Enter secret code',
                    prefix: Icons.verified_user_outlined,
                    validator: Validators.secretCode,
                    suffix: IconButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => const AlertDialog(
                            title: Text('Secret code'),
                            content: Text('Ask the platform owner for the Super Admin registration code. It can be rotated later from Settings.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.info_outline, color: AppColors.placeholder),
                    ),
                  ),
                  const SizedBox(height: 22),
                  AppButton(label: 'Create Account', loading: _loading, onPressed: _loading ? null : _submit),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account? ', style: TextStyle(color: AppColors.muted)),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: const Text('Login', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _message = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final err = Validators.email(_email.text);
    if (err != null) {
      showToast(context, err, error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<StaffProController>().submitPasswordRequest(email: _email.text, message: _message.text);
      if (!mounted) return;
      showToast(context, 'Request sent to the authorized manager or admin.');
      context.pop();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.vpn_key_outlined, size: 56, color: AppColors.primary),
          const SizedBox(height: 12),
          const Text('Password recovery', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Your request will be sent to the assigned Manager or Business Admin. You will be notified once it is reset.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          AppTextField(label: 'Email', controller: _email, hint: 'Enter your email', prefix: Icons.mail_outline, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 14),
          AppTextField(label: 'Message (optional)', controller: _message, hint: 'Add a message', prefix: Icons.chat_bubble_outline, maxLines: 4),
          const SizedBox(height: 22),
          AppButton(label: 'Send Request', loading: _loading, onPressed: _loading ? null : _submit),
        ],
      ),
    );
  }
}
