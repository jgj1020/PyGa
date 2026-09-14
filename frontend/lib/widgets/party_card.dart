
import 'package:flutter/material.dart';
import '../screens/party_detail_screen.dart';
import '../theme/app_theme.dart';

class PartyCard extends StatelessWidget {
  final String game;
  final String mode;
  final String title;
  final String user;
  final String rank;
  final int current;
  final int max;

  const PartyCard({
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
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PartyDetailScreen(
              game: game,
              mode: mode,
              title: title,
              user: user,
              rank: rank,
              current: current,
              max: max,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.purple.withAlpha(23),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    game,
                    style: const TextStyle(
                      color: AppTheme.purple,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  mode,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                Text(
                  '$current/$max',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFFEDEEF3),
                  child: Text(
                    user.substring(0, 1),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$user · $rank',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PartyDetailScreen(
                          game: game,
                          mode: mode,
                          title: title,
                          user: user,
                          rank: rank,
                          current: current,
                          max: max,
                        ),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.purple,
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('참가하기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
