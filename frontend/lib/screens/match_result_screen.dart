
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MatchResultScreen extends StatelessWidget {
  final String game;

  const MatchResultScreen({
    super.key,
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    final players = const [
      ('PlayerA', 'Gold 2', 94, ['빡겜', '마이크 가능', '경쟁전 선호']),
      ('PlayerB', 'Platinum 3', 87, ['마이크 가능', '경쟁전 선호']),
      ('초보환영러', 'Gold 1', 78, ['듣기만 가능', '일반전 선호']),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '잘 맞는 플레이어',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
        children: [
          Text(
            '$game 기준 추천 결과',
            style: const TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 15),
          ...players.map(
            (player) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MatchCard(
                name: player.$1,
                rank: player.$2,
                compatibility: player.$3,
                tags: player.$4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final String name;
  final String rank;
  final int compatibility;
  final List<String> tags;

  const _MatchCard({
    required this.name,
    required this.rank,
    required this.compatibility,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFEDEAFF),
            child: Text(
              name.substring(0, 1),
              style: const TextStyle(
                color: AppTheme.purple,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rank,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: tags.map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F3F7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Text(
                '$compatibility%',
                style: const TextStyle(
                  color: AppTheme.purple,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                '궁합',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 11,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('프로필'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
