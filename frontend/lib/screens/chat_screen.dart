
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class ChatScreen extends StatefulWidget {
  final bool showNavigation;

  const ChatScreen({
    super.key,
    this.showNavigation = true,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatMessage {
  final String name;
  final String text;
  final bool mine;

  const _ChatMessage({
    required this.name,
    required this.text,
    required this.mine,
  });
}

class _ChatScreenState extends State<ChatScreen> {
  final controller = TextEditingController();

  final messages = <_ChatMessage>[
    const _ChatMessage(
      name: '경준',
      text: '안녕하세요!',
      mine: false,
    ),
    const _ChatMessage(
      name: 'PlayerA',
      text: 'ㅎㅇㅎㅇ',
      mine: false,
    ),
    const _ChatMessage(
      name: 'PlayerB',
      text: '몇 판 하실까요?',
      mine: false,
    ),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void send() {
    final text = controller.text.trim();

    if (text.isEmpty) return;

    setState(() {
      messages.add(
        _ChatMessage(
          name: '경준',
          text: text,
          mine: true,
        ),
      );
    });

    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final page = Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VALORANT PARTY',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '경준, PlayerA, PlayerB 참여 중',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];

                return _Bubble(
                  name: message.name,
                  text: message.text,
                  mine: message.mine,
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    onSubmitted: (_) => send(),
                    decoration: const InputDecoration(
                      hintText: '메시지를 입력하세요...',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: send,
                  child: const CircleAvatar(
                    backgroundColor: AppTheme.purple,
                    child: Icon(
                      Icons.send,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.showNavigation) {
      return MainNavShell(initialIndex: 3);
    }

    return page;
  }
}

class _Bubble extends StatelessWidget {
  final String name;
  final String text;
  final bool mine;

  const _Bubble({
    required this.name,
    required this.text,
    required this.mine,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * .78,
        ),
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          color: mine ? AppTheme.purple : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: mine ? AppTheme.purple : AppTheme.line,
          ),
        ),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: mine ? Colors.white70 : AppTheme.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: TextStyle(
                color: mine ? Colors.white : AppTheme.dark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
