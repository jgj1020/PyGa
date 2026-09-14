
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav.dart';

class PartyScreen extends StatefulWidget {
  final bool showNavigation;

  const PartyScreen({
    super.key,
    this.showNavigation = true,
  });

  @override
  State<PartyScreen> createState() => _PartyScreenState();
}

class _PartyScreenState extends State<PartyScreen> {
  final memoController = TextEditingController();

  @override
  void dispose() {
    memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = ListView(
      padding: const EdgeInsets.only(bottom: 30),
      children: [
        const AppHeader(
          title: '파티 만들기',
          subtitle: '원하는 조건으로 파티원을 모집하세요.',
        ),
        const _SettingBox(label: '게임', value: 'VALORANT'),
        const _SettingBox(label: '모드', value: '경쟁전'),
        const _SettingBox(label: '필요 인원', value: '2명'),
        const _SettingBox(label: '플레이 스타일', value: '빡겜'),
        const _SettingBox(label: '마이크 사용', value: '사용'),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Text(
            '파티 소개 메모',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: memoController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '같이 즐겁게 해요!',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
          child: SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('파티 모집을 시작했습니다!'),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.purple,
              ),
              child: const Text(
                '모집 시작',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ],
    );

    if (widget.showNavigation) {
      return MainNavShell(initialIndex: 2);
    }

    return page;
  }
}

class _SettingBox extends StatelessWidget {
  final String label;
  final String value;

  const _SettingBox({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 7, 20, 7),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.line),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.purple,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              color: AppTheme.muted,
            ),
          ],
        ),
      ),
    );
  }
}
