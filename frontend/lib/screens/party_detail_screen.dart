
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class PartyDetailScreen extends StatelessWidget {
  final String game;
  final String mode;
  final String title;
  final String user;
  final String rank;
  final int current;
  final int max;

  const PartyDetailScreen({
    super.key,
    required this.game,
    required this.mode,
    required this.title,
    required this.user,
    required this.rank,
    required this.current,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '파티 상세',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF7568EF),
                  Color(0xFF5B4AD5),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$mode · $current/$max명',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '파티장',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _MemberTile(
            name: user,
            rank: rank,
            owner: true,
          ),
          const SizedBox(height: 18),
          const Text(
            '파티원',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const _MemberTile(
            name: 'PlayerA',
            rank: 'Gold 2',
          ),
          const _MemberTile(
            name: 'PlayerB',
            rank: 'Silver 3',
          ),
          const SizedBox(height: 25),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: current >= max
                  ? null
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('파티에 참가했습니다!'),
                        ),
                      );
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.purple,
              ),
              child: Text(
                current >= max ? '파티가 가득 찼어요' : '파티 참가하기',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChatScreen(
                    showNavigation: false,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('파티 채팅 열기'),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final String name;
  final String rank;
  final bool owner;

  const _MemberTile({
    required this.name,
    required this.rank,
    this.owner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFEDEAFF),
            child: Icon(
              Icons.person,
              color: AppTheme.purple,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              '$name · $rank',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (owner)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: AppTheme.purple.withAlpha(23),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '파티장',
                style: TextStyle(
                  color: AppTheme.purple,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
