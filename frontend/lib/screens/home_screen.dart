
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/section_title.dart';
import '../widgets/party_card.dart';
import '../widgets/bottom_nav.dart';

class HomeScreen extends StatelessWidget {
  final bool showNavigation;

  const HomeScreen({
    super.key,
    this.showNavigation = true,
  });

  @override
  Widget build(BuildContext context) {
    final page = ListView(
      padding: const EdgeInsets.only(bottom: 25),
      children: [
        AppHeader(
          title: '안녕하세요, 경준님 👋',
          subtitle: '오늘 같이 게임할 사람을 찾아볼까요?',
          onSettings: () {
            Navigator.pushNamed(context, '/settings');
          },
        ),
        const SectionTitle('🎮 어떤 게임을 할까요?'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _GameButton(game: 'VALORANT', color: const Color(0xFFFFE9EE)),
              _GameButton(game: 'League of Legends', color: const Color(0xFFE8F1FF)),
              _GameButton(game: '배틀그라운드', color: const Color(0xFFFFF2DF)),
              _GameButton(game: 'FC Online', color: const Color(0xFFE9FAEF)),
            ],
          ),
        ),
        SectionTitle(
          '🔥 지금 같이 할 사람',
          action: '전체보기',
          onAction: () {
            Navigator.pushNamed(context, '/find');
          },
        ),
        const PartyCard(
          game: 'VALORANT',
          mode: '경쟁전',
          title: '매너 빡겜하실 실버/골드 구합니다!',
          user: '경준',
          rank: 'GOLD',
          current: 2,
          max: 5,
        ),
        const PartyCard(
          game: 'League of Legends',
          mode: '칼바람 나락',
          title: '편하게 웃으면서 한 판 하실 분 들어오세요~',
          user: '페이커지망생',
          rank: 'PLATINUM',
          current: 3,
          max: 5,
        ),
        const SectionTitle('⚡ 바로 시작하기'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/find');
              },
              icon: const Icon(Icons.search),
              label: const Text(
                '같이 할 사람 찾기',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.purple,
              ),
            ),
          ),
        ),
      ],
    );

    if (showNavigation) {
      return MainNavShell(initialIndex: 0);
    }

    return page;
  }
}

class _GameButton extends StatelessWidget {
  final String game;
  final Color color;

  const _GameButton({
    required this.game,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        game,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
