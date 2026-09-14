
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '설정',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: [
          const _SectionLabel('계정'),
          _SettingTile(
            icon: Icons.person_outline,
            title: '프로필 수정',
            onTap: () {
              Navigator.pushNamed(
                context,
                '/edit-profile',
              );
            },
          ),
          _SettingTile(
            icon: Icons.lock_outline,
            title: '비밀번호 변경',
            onTap: () {},
          ),
          const _SectionLabel('앱'),
          _SettingTile(
            icon: Icons.notifications_none,
            title: '알림 설정',
            trailing: Switch(
              value: true,
              onChanged: (_) {},
              activeColor: AppTheme.purple,
            ),
            onTap: () {},
          ),
          _SettingTile(
            icon: Icons.dark_mode_outlined,
            title: '다크 모드',
            trailing: Switch(
              value: false,
              onChanged: (_) {},
              activeColor: AppTheme.purple,
            ),
            onTap: () {},
          ),
          const _SectionLabel('기타'),
          _SettingTile(
            icon: Icons.help_outline,
            title: '도움말',
            onTap: () {},
          ),
          _SettingTile(
            icon: Icons.logout,
            title: '로그아웃',
            color: Colors.redAccent,
            onTap: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 12,
        bottom: 9,
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.muted,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final Color? color;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.line),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icon,
          color: color ?? AppTheme.purple,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: color ?? AppTheme.dark,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: trailing ??
            const Icon(
              Icons.chevron_right,
              color: AppTheme.muted,
            ),
      ),
    );
  }
}
