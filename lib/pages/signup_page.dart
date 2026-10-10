import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  bool _show = false;
  bool _submitting = false;
  String _error = '';

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final app = AppState.instance;
    setState(() => _error = '');

    if (_name.text.trim().isEmpty) {
      setState(() => _error = app.t('signup.namePlaceholder'));
      return;
    }
    if (onlyDigits(_mobile.text).length != 10) {
      setState(() => _error = app.t('login.validMobile'));
      return;
    }

    setState(() => _submitting = true);
    try {
      final mobile = normalizeMobile(_mobile.text);
      final exists = await Api.instance.userExists(mobile);
      if (exists) {
        setState(() {
          _error = 'ALREADY_EXISTS';
          _submitting = false;
        });
        return;
      }

      final json = await Api.instance.login(_name.text.trim(), mobile, _password.text);
      await app.saveUser(AppUser.fromJson(json));
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/participate', (r) => r.settings.name == '/');
    } on ApiException catch (e) {
      setState(() => _error = e.message.isNotEmpty ? e.message : app.t('signup.failed'));
    } catch (_) {
      setState(() => _error = app.t('signup.failed'));
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                        Text(t('signup.title'), style: body(16, weight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('1. ${t('signup.step1')}',
                            style: body(13.5, color: C.neutral700, height: 1.5)),
                        Text('2. ${t('login.step2')} ${t('login.step2Bold')} ${t('login.step2End')}',
                            style: body(13.5, color: C.neutral700, height: 1.5)),
                        Text('3. ${t('login.step3')} 98765 43210 → ${t('login.step3Pwd')} 43210.',
                            style: body(13.5, color: C.neutral500, height: 1.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(t('signup.name'),
                      style: body(14, color: C.neutral700, weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _name,
                    enabled: !_submitting,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    style: body(16, color: Colors.black87),
                    decoration: inputDeco(hint: t('signup.namePlaceholder')),
                  ),
                  const SizedBox(height: 16),

                  Text(t('login.mobile'),
                      style: body(14, color: C.neutral700, weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _mobile,
                    enabled: !_submitting,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
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

                  Text(t('signup.passwordLabel'),
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
                            TextSpan(text: last5, style: body(12, weight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  if (_error == 'ALREADY_EXISTS')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        border: Border.all(color: const Color(0xFFFDA4AF)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('⚠️ ${t('signup.already')}',
                              style: body(14, color: const Color(0xFF881337), weight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(t('signup.alreadyMsg'),
                              style: body(12, color: const Color(0xFF9F1239), height: 1.5)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pushReplacementNamed('/login'),
                            child: Text('${t('signup.goLogin')} →',
                                style: body(12, weight: FontWeight.w700)
                                    .copyWith(decoration: TextDecoration.underline)),
                          ),
                        ],
                      ),
                    )
                  else if (_error.isNotEmpty)
                    ErrorBox(_error),
                  const SizedBox(height: 12),

                  PrimaryButton(
                    label: _submitting ? t('signup.submitting') : t('signup.submit'),
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
                        Text('${t('signup.haveAccount')} ',
                            style: body(12.5, color: C.neutral500)),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pushReplacementNamed('/login'),
                          child: Text(t('signup.login'), style: body(12.5, weight: FontWeight.w700)),
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
