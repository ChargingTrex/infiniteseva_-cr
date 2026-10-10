import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../theme.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final user = app.user;
    final route = ModalRoute.of(context)?.settings.name;
    final isHome = route == '/' || route == null;
    final isLogin = route == '/login';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false),
                child: Image.asset(
                  'assets/images/InfiniteSeva-Logo.png',
                  height: 44,
                  errorBuilder: (_, __, ___) => Text('Infinite Seva', style: display(20)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _HeaderButton(
                      label: app.isTamil ? '🇬🇧 EN' : '🇮🇳 த',
                      onTap: app.toggleLanguage,
                    ),
                    if (user?.isAdmin == true)
                      _HeaderButton(
                        icon: Icons.settings_outlined,
                        filled: true,
                        tooltip: app.t('header.admin'),
                        onTap: () => Navigator.of(context).pushNamed('/admin/ads'),
                      ),
                    if (!isHome)
                      _HeaderButton(
                        icon: Icons.home_outlined,
                        tooltip: app.t('header.home'),
                        onTap: () => Navigator.of(context)
                            .pushNamedAndRemoveUntil('/', (r) => false),
                      ),
                    if (user != null)
                      _HeaderButton(
                        label: app.t('header.logout'),
                        onTap: () async {
                          final nav = Navigator.of(context);
                          await app.clearUser();
                          nav.pushNamedAndRemoveUntil('/login', (r) => false);
                        },
                      )
                    else if (!isLogin)
                      _HeaderButton(
                        label: app.t('header.login'),
                        onTap: () => Navigator.of(context).pushNamed('/login'),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, C.gold.withOpacity(0.6), Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool filled;
  final String? tooltip;

  const _HeaderButton({
    this.label,
    this.icon,
    required this.onTap,
    this.filled = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : C.maroon;
    final child = Material(
      color: filled ? C.maroon : Colors.white.withOpacity(0.6),
      shape: StadiumBorder(side: BorderSide(color: filled ? C.maroon : C.gold, width: 1.5)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: label != null ? 14 : 9, vertical: label != null ? 7 : 7),
          child: label != null
              ? Text(label!, style: body(12, color: fg, weight: FontWeight.w600))
              : Icon(icon, size: 18, color: fg),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: child) : child;
  }
}
