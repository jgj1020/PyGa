
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import 'match_result_screen.dart';

class FindScreen extends StatefulWidget {
  final bool showNavigation;

  const FindScreen({
    super.key,
    this.showNavigation = true,
  });

  @override
  State<FindScreen> createState() => _FindScreenState();
}

class _FindScreenState extends State<FindScreen> {
  String game = 'VALORANT';
  String mode = '경쟁전';
  String style = '빡겜';
  String mic = '가능';
  double count = 2;

  void runMatch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchResultScreen(game: game),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const Text(
          '같이 할 사람 찾기',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '원하는 조건을 설정하면 잘 맞는 플레이어를 찾아드려요.',
          style: TextStyle(color: AppTheme.muted),
        ),
        const _Label('게임 선택'),
        DropdownButtonFormField<String>(
          initialValue: game,
          items: const [
            'VALORANT',
            'League of Legends',
            '배틀그라운드',
            'FC Online',
          ].map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(e),
            ),
          ).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => game = value);
            }
          },
        ),
        const _Label('모드'),
        _ChoiceRow(
          values: const ['경쟁전', '일반전', '칼바람 나락'],
          selected: mode,
          onChanged: (value) => setState(() => mode = value),
        ),
        const _Label('플레이 스타일'),
        _ChoiceRow(
          values: const ['빡겜', '편하게', '상관없음'],
          selected: style,
          onChanged: (value) => setState(() => style = value),
        ),
        const _Label('마이크 사용'),
        _ChoiceRow(
          values: const ['가능', '불가능'],
          selected: mic,
          onChanged: (value) => setState(() => mic = value),
        ),
        const _Label('필요 인원'),
        Container(
          padding: const EdgeInsets.fromLTRB(15, 7, 15, 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            children: [
              const Text(
                '같이 할 사람',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Expanded(
                child: Slider(
                  value: count,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: AppTheme.purple,
                  onChanged: (value) {
                    setState(() => count = value);
                  },
                ),
              ),
              Text(
                '${count.round()}명',
                style: const TextStyle(
                  color: AppTheme.purple,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 54,
          child: FilledButton(
            onPressed: runMatch,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.purple,
            ),
            child: const Text(
              '매칭 찾기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );

    if (widget.showNavigation) {
      return MainNavShell(initialIndex: 1);
    }
    return page;
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 9),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  final List<String> values;
  final String selected;
  final ValueChanged<String> onChanged;

  const _ChoiceRow({
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map(
        (value) {
          final active = value == selected;
          return GestureDetector(
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.purple.withAlpha(25)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active
                      ? AppTheme.purple
                      : AppTheme.line,
                ),
              ),
              child: Text(
                value,
                style: TextStyle(
                  color: active
                      ? AppTheme.purple
                      : AppTheme.dark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ).toList(),
    );
  }
}
