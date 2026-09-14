
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class ProfileScreen extends StatelessWidget {
  final bool showNavigation;

  const ProfileScreen({
    super.key,
    this.showNavigation = true,
  });

  @override
  Widget build(BuildContext context) {
    final page = ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 38,
              backgroundColor: Color(0xFFEAE8FF),
              child: Text(
                'KJ',
                style: TextStyle(
                  color: AppTheme.purple,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KJun',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '경준 · 대한민국',
                    style: TextStyle(
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/edit-profile',
                );
              },
              child: const Text('프로필 수정'),
            ),
          ],
        ),
        const _SectionTitle('나의 플레이 스타일'),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.line),
          ),
          child: const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill('편하게'),
              _Pill('협동 선호'),
              _Pill('마이크 사용'),
            ],
          ),
        ),
        const _SectionTitle('게임별 요약'),
        const _GameSummary(
          game: 'VALORANT',
          rank: 'Gold 2',
          count: '최근 플레이 8회',
        ),
        const _GameSummary(
          game: 'FC ONLINE',
          rank: '월드클래스 3',
          count: '최근 플레이 8회',
        ),
        const _SectionTitle('최근 매칭 활동'),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.line),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.schedule,
                color: AppTheme.purple,
              ),
              SizedBox(width: 10),
              Text(
                '주말 저녁',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.line),
          ),
          leading: const Icon(
            Icons.settings_outlined,
            color: AppTheme.purple,
          ),
          title: const Text(
            '설정',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.pushNamed(context, '/settings');
          },
        ),
      ],
    );

    if (showNavigation) {
      return MainNavShell(initialIndex: 4);
    }

    return page;
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 22, 0, 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;

  const _Pill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.purple.withAlpha(23),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.purple,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GameSummary extends StatelessWidget {
  final String game;
  final String rank;
  final String count;

  const _GameSummary({
    required this.game,
    required this.rank,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.purple.withAlpha(23),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.sports_esports,
              color: AppTheme.purple,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            rank,
            style: const TextStyle(
              color: AppTheme.purple,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
