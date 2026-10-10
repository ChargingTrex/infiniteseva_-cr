import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  bool _show = false;
  bool _submitting = false;
  String _error = '';

  @override
  void dispose() {
    _mobile.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final app = AppState.instance;
    setState(() => _error = '');

    final digits = onlyDigits(_mobile.text);
    if (digits.length != 10) {
      setState(() => _error = app.t('login.validMobile'));
      return;
    }

    setState(() => _submitting = true);
    try {
      final mobile = normalizeMobile(_mobile.text);
      final exists = await Api.instance.userExists(mobile);
      if (!exists) {
        setState(() {
          _error = 'NOT_REGISTERED';
          _submitting = false;
        });
        return;
      }

      final json = await Api.instance.verifyPassword(mobile, _password.text);
      final user = AppUser.fromJson(json);
      await app.saveUser(user);
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(user.isAdmin ? '/admin/ads' : '/participate', (r) => r.settings.name == '/');
    } on ApiException catch (e) {
      setState(() => _error = e.message.isNotEmpty ? e.message : app.t('login.failed'));
    } catch (_) {
      setState(() => _error = app.t('login.failed'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final t = app.t;
    final digits = onlyDigits(_mobile.text);
    final last5 = digits.length >= 5 ? digits.substring(digits.length - 5) : '';

    return PageShell(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: GoldCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: C.gold.withOpacity(0.08),
                      border: Border.all(color: C.gold.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t('login.howToLogin'),
                            style: body(16, weight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('1. ${t('login.step1')}',
                            style: body(13.5, color: C.neutral700, height: 1.5)),
                        Text.rich(
                          TextSpan(
                            style: body(13.5, color: C.neutral700, height: 1.5),
                            children: [
                              TextSpan(text: '2. ${t('login.step2')} '),
                              TextSpan(
                                  text: t('login.step2Bold'),
                                  style: body(13.5, color: C.neutral700, weight: FontWeight.w800)),
                              TextSpan(text: ' ${t('login.step2End')}'),
                            ],
                          ),
                        ),
                        Text('3. ${t('login.step3')} 98765 43210 → ${t('login.step3Pwd')} 43210.',
                            style: body(13.5, color: C.neutral500, height: 1.5)),
                        const SizedBox(height: 10),
                        Text(t('login.firstTime'),
                            style: body(12, color: C.neutral500)
                                .copyWith(fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Mobile
                  Text(t('login.mobile'),
                      style: body(14, color: C.neutral700, weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _mobile,
                    enabled: !_submitting,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    style: body(16, color: Colors.black87),
                    onChanged: (v) {
                      final d = onlyDigits(v, 10);
                      if (d != v) {
                        _mobile.value = TextEditingValue(
                          text: d,
                          selection: TextSelection.collapsed(offset: d.length),
                        );
                      }
                      setState(() {});
                    },
                    decoration: inputDeco(hint: '98765 43210').copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 16),

                  // Password
                  Text(t('login.password'),
                      style: body(14, color: C.neutral700, weight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _password,
                    enabled: !_submitting,
                    obscureText: !_show,
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    style: body(16, color: Colors.black87),
                    onChanged: (v) {
                      final d = onlyDigits(v, 5);
                      if (d != v) {
                        _password.value = TextEditingValue(
                          text: d,
                          selection: TextSelection.collapsed(offset: d.length),
                        );
                      }
                    },
                    onSubmitted: (_) => _submit(),
                    decoration: inputDeco(
                      hint: '•••••',
                      suffix: TextButton(
                        onPressed: _submitting ? null : () => setState(() => _show = !_show),
                        child: Text(_show ? t('login.hide') : t('login.show'),
                            style: body(13, color: C.neutral500, weight: FontWeight.w600)),
                      ),
                    ).copyWith(counterText: ''),
                  ),
                  if (last5.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text.rich(
                        TextSpan(
                          style: body(12, color: C.neutral500),
                          children: [
                            TextSpan(text: '${t('login.hint')} '),
                            TextSpan(
                                text: last5,
                                style: body(12, weight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  if (_error == 'NOT_REGISTERED')
                    _NoticeBox(
                      title: '⚠️ ${t('login.notRegistered')}',
                      message: t('login.notRegisteredMsg'),
                      linkLabel: '${t('login.createAccount')} →',
                      onLink: () => Navigator.of(context).pushReplacementNamed('/signup'),
                      bg: const Color(0xFFFFFBEB),
                      border: const Color(0xFFFCD34D),
                      titleColor: const Color(0xFF78350F),
                      textColor: const Color(0xFF92400E),
                    )
                  else if (_error.isNotEmpty)
                    ErrorBox(_error),
                  const SizedBox(height: 12),

                  PrimaryButton(
                    label: _submitting ? t('login.submitting') : t('login.submit'),
                    busy: _submitting,
                    onPressed: _submit,
                  ),

                  const SizedBox(height: 20),
                  const Divider(height: 1, color: C.neutral200),
                  const SizedBox(height: 14),
                  Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('${t('login.newHere')} ',
                            style: body(12.5, color: C.neutral500)),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pushReplacementNamed('/signup'),
                          child: Text(t('login.createAccount'),
                              style: body(12.5, weight: FontWeight.w700)),
                        ),
                      ],
                    ),
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

class _NoticeBox extends StatelessWidget {
  final String title;
  final String message;
  final String linkLabel;
  final VoidCallback onLink;
  final Color bg, border, titleColor, textColor;

  const _NoticeBox({
    required this.title,
    required this.message,
    required this.linkLabel,
    required this.onLink,
    required this.bg,
    required this.border,
    required this.titleColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: body(14, color: titleColor, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(message, style: body(12, color: textColor, height: 1.5)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onLink,
            child: Text(linkLabel,
                style: body(12, weight: FontWeight.w700)
                    .copyWith(decoration: TextDecoration.underline)),
          ),
        ],
      ),
    );
  }
}
