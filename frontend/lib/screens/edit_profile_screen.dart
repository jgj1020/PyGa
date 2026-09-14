
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final nicknameController = TextEditingController(text: 'KJun');
  String style = '편하게';
  String mic = '사용';
  String playTime = '주말 저녁';

  @override
  void dispose() {
    nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '프로필 수정',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: [
          const Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Color(0xFFEAE8FF),
              child: Text(
                'KJ',
                style: TextStyle(
                  color: AppTheme.purple,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            '닉네임',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: nicknameController,
          ),
          const _Label('플레이 스타일'),
          _ChoiceRow(
            values: const ['빡겜', '편하게', '상관없음'],
            selected: style,
            onChanged: (value) {
              setState(() {
                style = value;
              });
            },
          ),
          const _Label('마이크'),
          _ChoiceRow(
            values: const ['사용', '미사용'],
            selected: mic,
            onChanged: (value) {
              setState(() {
                mic = value;
              });
            },
          ),
          const _Label('주로 플레이하는 시간'),
          _ChoiceRow(
            values: const ['평일 저녁', '주말 저녁', '새벽'],
            selected: playTime,
            onChanged: (value) {
              setState(() {
                playTime = value;
              });
            },
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.purple,
              ),
              child: const Text(
                '저장하기',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
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
        style: const TextStyle(fontWeight: FontWeight.w800),
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
          final isSelected = value == selected;

          return GestureDetector(
            onTap: () => onChanged(value),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.purple.withAlpha(25)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.purple
                      : AppTheme.line,
                ),
              ),
              child: Text(
                value,
                style: TextStyle(
                  color: isSelected
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
