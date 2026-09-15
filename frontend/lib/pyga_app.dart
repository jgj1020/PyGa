import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:uuid/uuid.dart';

import 'services/api.dart';

const bg = Color(0xFF08090D);
const panel = Color(0xFF12141C);
const panelSoft = Color(0xFF181B25);
const line = Color(0xFF262A36);
const purple = Color(0xFF8D5CFF);
const purpleSoft = Color(0xFFB8A0FF);
const mint = Color(0xFF32E6C4);
const muted = Color(0xFF8D93A5);
const danger = Color(0xFFFF667A);
const warning = Color(0xFFFFC765);

const games = ['VALORANT', 'League of Legends', '배틀그라운드', 'FC Online'];
const modes = ['경쟁전', '일반전', '칼바람 나락', '자유 플레이'];

void notice(
  BuildContext context,
  Object value, {
  bool success = false,
  bool warningNotice = false,
  String? title,
}) {
  final text = value.toString().replaceFirst('Exception: ', '').trim();
  final isError = value is Exception || value is Error;
  final isServerError = isError &&
      (text.contains('서버') || text.contains('백엔드') || text.contains('연결'));
  final accent = success
      ? mint
      : warningNotice
          ? warning
          : isError
              ? danger
              : purpleSoft;
  final icon = success
      ? Icons.check_circle_rounded
      : warningNotice
          ? Icons.warning_amber_rounded
          : isError
              ? Icons.error_outline_rounded
              : Icons.info_outline_rounded;
  final heading = title ??
      (success
          ? '완료'
          : warningNotice
              ? '주의'
              : isError
                  ? (isServerError ? '서버 연결 오류' : '확인 필요')
                  : '안내');

  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      padding: EdgeInsets.zero,
      duration: const Duration(seconds: 3),
      content: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFF171A23),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withAlpha(115)),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 7)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        heading,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (text.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          text,
                          style: const TextStyle(
                            color: Color(0xFFD6D9E2),
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void successNotice(BuildContext context, String title, String message) {
  notice(context, message, success: true, title: title);
}

Future<bool> askConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String action = '확인',
  bool destructive = false,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: panelSoft,
          title: Text(title),
          content: Text(message, style: const TextStyle(color: muted, height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(backgroundColor: danger)
                  : null,
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
}


class _AmbientBackground extends StatefulWidget {
  final double intensity;
  const _AmbientBackground({this.intensity = 1});

  @override
  State<_AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<_AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = controller.value * math.pi * 2;
          return Stack(
            children: [
              Positioned(
                left: -90 + math.sin(t) * 34,
                top: 70 + math.cos(t * .8) * 44,
                child: _GlowOrb(
                  size: 250,
                  color: purple.withAlpha((26 * widget.intensity).round()),
                ),
              ),
              Positioned(
                right: -110 + math.cos(t * .9) * 40,
                bottom: 90 + math.sin(t * .7) * 54,
                child: _GlowOrb(
                  size: 290,
                  color: mint.withAlpha((17 * widget.intensity).round()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withAlpha(0)],
        ),
      ),
    );
  }
}

class _Entrance extends StatelessWidget {
  final Widget child;
  final int delay;
  const _Entrance({required this.child, this.delay = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 430 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class PyGaApp extends StatelessWidget {
  const PyGaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PyGa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: purple,
          secondary: mint,
          surface: panel,
          error: danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 70,
          backgroundColor: const Color(0xFF0D0F15),
          indicatorColor: purple.withAlpha(35),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected) ? Colors.white : muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panel,
          hintStyle: const TextStyle(color: muted),
          labelStyle: const TextStyle(color: muted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: purple, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: purple,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: line),
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
        dividerColor: line,
      ),
      home: const AuthPage(),
    );
  }
}

class BrandMark extends StatelessWidget {
  final double size;
  final bool showName;

  const BrandMark({super.key, this.size = 60, this.showName = true});

  @override
  Widget build(BuildContext context) {
    final asset = showName
        ? 'assets/branding/pyga_logo.png'
        : 'assets/branding/pyga_mark.png';

    return Semantics(
      label: 'PyGa 로고',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(showName ? size * .18 : size * .28),
          boxShadow: [
            BoxShadow(
              color: purple.withAlpha(showName ? 34 : 58),
              blurRadius: showName ? 30 : 22,
              spreadRadius: showName ? 1 : 0,
            ),
          ],
        ),
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

class GlowCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  const GlowCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.borderColor,
  });

  @override
  State<GlowCard> createState() => _GlowCardState();
}

class _GlowCardState extends State<GlowCard> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: hover ? const Color(0xFF151823) : panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: hover ? (widget.borderColor ?? purple.withAlpha(90)) : (widget.borderColor ?? line),
        ),
        boxShadow: [
          BoxShadow(
            color: hover ? purple.withAlpha(20) : Colors.black26,
            blurRadius: hover ? 28 : 20,
            offset: Offset(0, hover ? 13 : 10),
          ),
        ],
      ),
      child: widget.child,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: AnimatedScale(
        scale: hover ? 1.008 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: widget.onTap == null
            ? box
            : InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(24),
                child: box,
              ),
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final nickname = TextEditingController();
  final confirm = TextEditingController();
  final form = GlobalKey<FormState>();

  bool register = false;
  bool busy = false;
  bool obscure = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    nickname.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      if (register) {
        await Api.request('POST', '/auth/register', {
          'nickname': nickname.text.trim(),
          'email': email.text.trim(),
          'password': password.text,
        });
        if (!mounted) return;
        successNotice(context, '회원가입 완료', '이제 로그인해서 PyGa를 시작할 수 있어요.');
        setState(() {
          register = false;
          password.clear();
          confirm.clear();
        });
      } else {
        await Api.login(email.text, password.text);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainPage()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -150,
            right: -130,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: purple.withAlpha(38),
              ),
            ),
          ),
          Positioned(
            bottom: -180,
            left: -140,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: mint.withAlpha(22),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 34),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Form(
                    key: form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: BrandMark(size: 138)),
                        const SizedBox(height: 18),
                        const Text(
                          '같이 할 사람을 찾는 가장 빠른 방법',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted, fontSize: 14),
                        ),
                        const SizedBox(height: 34),
                        GlowCard(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                register ? '새 계정 만들기' : '다시 만나서 반가워요 👋',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                register ? '몇 초면 가입이 끝나요.' : '오늘 같이 플레이할 팀을 찾아볼까요?',
                                style: const TextStyle(color: muted),
                              ),
                              const SizedBox(height: 22),
                              if (register) ...[
                                TextFormField(
                                  controller: nickname,
                                  decoration: const InputDecoration(
                                    labelText: '닉네임',
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                  validator: (v) {
                                    final length = v?.trim().length ?? 0;
                                    return length < 2 || length > 30 ? '닉네임은 2~30자로 입력해주세요.' : null;
                                  },
                                ),
                                const SizedBox(height: 14),
                              ],
                              TextFormField(
                                controller: email,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: '이메일',
                                  prefixIcon: Icon(Icons.alternate_email_rounded),
                                ),
                                validator: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v?.trim() ?? '')
                                    ? null
                                    : '이메일을 확인해주세요.',
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: password,
                                obscureText: obscure,
                                decoration: InputDecoration(
                                  labelText: '비밀번호',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() => obscure = !obscure),
                                    icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                  ),
                                ),
                                validator: (v) => (v?.length ?? 0) < 8 ? '비밀번호는 최소 8자입니다.' : null,
                              ),
                              if (register) ...[
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: confirm,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: '비밀번호 확인',
                                    prefixIcon: Icon(Icons.verified_user_outlined),
                                  ),
                                  validator: (v) => v == password.text ? null : '비밀번호가 일치하지 않습니다.',
                                ),
                              ],
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: busy ? null : submit,
                                child: Text(busy ? '처리 중…' : register ? '회원가입' : 'PyGa 시작하기'),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => setState(() {
                                          register = !register;
                                          form.currentState?.reset();
                                        }),
                                child: Text(
                                  register ? '이미 계정이 있어요 · 로그인' : '처음이신가요? 회원가입',
                                  style: const TextStyle(color: mint, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AdminLoginPage()),
                          ),
                          icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                          label: const Text('관리자 로그인'),
                          style: TextButton.styleFrom(foregroundColor: muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  bool obscure = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (email.text.trim().isEmpty || password.text.isEmpty || busy) return;
    setState(() => busy = true);
    try {
      await Api.adminLogin(email.text, password.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('관리자 전용')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: BrandMark(size: 118)),
                const SizedBox(height: 28),
                GlowCard(
                  borderColor: purple.withAlpha(100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield_rounded, color: purpleSoft),
                          SizedBox(width: 10),
                          Text('ADMIN CONSOLE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('관리자로 지정된 계정만 접근할 수 있습니다.', style: TextStyle(color: muted)),
                      const SizedBox(height: 22),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: '관리자 이메일'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: password,
                        obscureText: obscure,
                        decoration: InputDecoration(
                          labelText: '비밀번호',
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => obscure = !obscure),
                            icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                        ),
                        onSubmitted: (_) => login(),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: busy ? null : login,
                        icon: const Icon(Icons.login_rounded),
                        label: Text(busy ? '확인 중…' : '관리자 로그인'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  Map<String, dynamic>? data;
  String? error;
  bool loading = true;
  bool live = false;
  int section = 0;
  late final io.Socket socket;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    socket = io.io(
      Api.base,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .setAuth({'token': Api.token})
          .build(),
    );
    socket.onConnect((_) async {
      if (mounted) setState(() => live = true);
      try {
        await ack('admin:watch', {});
      } catch (_) {}
      load(silent: true);
    });
    socket.onDisconnect((_) {
      if (mounted) setState(() => live = false);
    });
    socket.onConnectError((_) {
      if (mounted) setState(() => live = false);
    });
    socket.on('admin:update', (_) => load(silent: true));
    socket.on('admin:message_new', (_) => load(silent: true));
    socket.connect();
    load();
    refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => load(silent: true),
    );
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    socket.dispose();
    super.dispose();
  }

  Future<dynamic> ack(String event, dynamic payload) {
    final completer = Completer<dynamic>();
    if (!socket.connected) {
      return Future.error(Exception('실시간 관리자 서버에 연결 중입니다. 잠시 후 다시 시도해주세요.'));
    }
    socket.emitWithAck(
      event,
      payload,
      ack: (dynamic response) {
        if (completer.isCompleted) return;
        if (response is Map && response['ok'] == true) {
          completer.complete(response['data']);
        } else {
          completer.completeError(
            Exception(response is Map ? response['error'] ?? '요청 실패' : '응답 오류'),
          );
        }
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => throw Exception('관리자 서버 응답이 늦습니다.'),
    );
  }

  Future<void> load({bool silent = false}) async {
    if (!silent && mounted) setState(() => loading = true);
    try {
      final result = Map<String, dynamic>.from(
        await Api.request('GET', '/admin/dashboard'),
      );
      if (mounted) {
        setState(() {
          data = result;
          error = null;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString().replaceFirst('Exception: ', '');
          loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> rows(String key) =>
      (data?[key] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ??
      [];

  Future<void> deleteMessage(Map<String, dynamic> message) async {
    final ok = await askConfirm(
      context,
      title: '이 메시지를 삭제할까요?',
      message: '${message['nickname']} · ${message['teamTitle']}\n\n${message['body']}',
      action: '메시지 삭제',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ack('admin:message_delete', {'messageId': message['id']});
      if (!mounted) return;
      successNotice(context, '메시지 삭제 완료', '채팅방에서도 즉시 제거되었습니다.');
      await load(silent: true);
    } catch (e) {
      if (mounted) notice(context, e);
    }
  }

  Future<void> deleteTeam(Map<String, dynamic> team) async {
    final ok = await askConfirm(
      context,
      title: '파티를 강제 삭제할까요?',
      message: '「${team['title']}」 파티와 채팅 기록이 모두 삭제됩니다.',
      action: '파티 삭제',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ack('admin:team_delete', {'teamId': team['id']});
      if (!mounted) return;
      successNotice(context, '파티 삭제 완료', '해당 파티를 운영 목록에서 제거했습니다.');
      await load(silent: true);
    } catch (e) {
      if (mounted) notice(context, e);
    }
  }

  Future<void> deleteUser(Map<String, dynamic> user) async {
    final ok = await askConfirm(
      context,
      title: '회원을 삭제할까요?',
      message: '${user['nickname']} (${user['email']}) 계정과 해당 회원이 만든 파티가 삭제됩니다.',
      action: '회원 삭제',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ack('admin:user_delete', {'userId': user['id']});
      if (!mounted) return;
      successNotice(context, '회원 삭제 완료', '회원과 관련된 운영 데이터를 정리했습니다.');
      await load(silent: true);
    } catch (e) {
      if (mounted) notice(context, e);
    }
  }

  void logout() {
    Api.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = rows('users');
    final teams = rows('teams');
    final messages = rows('messages');
    final sectionTitles = ['실시간 현황', '채팅 검열', '파티 관리', '회원 관리'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('PyGa Control', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: (live ? mint : danger).withAlpha(18),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: (live ? mint : danger).withAlpha(75)),
            ),
            child: Row(
              children: [
                Icon(Icons.circle, size: 8, color: live ? mint : danger),
                const SizedBox(width: 6),
                Text(
                  live ? 'LIVE' : '연결 중',
                  style: TextStyle(
                    color: live ? mint : danger,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton(onPressed: () => load(), icon: const Icon(Icons.refresh_rounded)),
          IconButton(onPressed: logout, icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      body: Stack(
        children: [
          const _AmbientBackground(intensity: .7),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: RefreshIndicator(
                onRefresh: () => load(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 40),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _Entrance(
                      child: GlowCard(
                        borderColor: purple.withAlpha(85),
                        child: Row(
                          children: [
                            const BrandMark(size: 52, showName: false),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('운영 관제 센터', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                                  SizedBox(height: 4),
                                  Text('회원 · 파티 · 채팅을 실시간으로 확인하고 관리합니다.', style: TextStyle(color: muted, height: 1.4)),
                                ],
                              ),
                            ),
                            if (live)
                              const _MiniBadge(text: '실시간 감시 ON', color: mint),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(sectionTitles.length, (index) {
                          final selected = section == index;
                          final icons = [Icons.dashboard_rounded, Icons.shield_rounded, Icons.groups_2_rounded, Icons.people_alt_rounded];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              avatar: Icon(icons[index], size: 17, color: selected ? bg : muted),
                              label: Text(sectionTitles[index]),
                              selected: selected,
                              onSelected: (_) => setState(() => section = index),
                              selectedColor: mint,
                              backgroundColor: panel,
                              labelStyle: TextStyle(
                                color: selected ? bg : Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                              side: BorderSide(color: selected ? mint : line),
                            ),
                          );
                        }),
                      ),
                    ),
                    if (loading) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(color: mint),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      GlowCard(
                        borderColor: danger.withAlpha(90),
                        child: Text(error!, style: const TextStyle(color: danger)),
                      ),
                    ],
                    const SizedBox(height: 18),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(.03, .03), end: Offset.zero).animate(animation),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(section),
                        child: section == 0
                            ? _adminOverview(users, teams, messages)
                            : section == 1
                                ? _adminMessages(messages)
                                : section == 2
                                    ? _adminTeams(teams)
                                    : _adminUsers(users),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminOverview(
    List<Map<String, dynamic>> users,
    List<Map<String, dynamic>> teams,
    List<Map<String, dynamic>> messages,
  ) {
    final latestMessages = messages.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 760 ? 4 : 2;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: columns == 4 ? 1.25 : 1.35,
              children: [
                _StatCard(icon: Icons.people_alt_rounded, label: '전체 회원', value: '${data?['userCount'] ?? 0}', color: mint),
                _StatCard(icon: Icons.groups_2_rounded, label: '운영 파티', value: '${data?['teamCount'] ?? 0}', color: purpleSoft),
                _StatCard(icon: Icons.forum_rounded, label: '전체 메시지', value: '${data?['messageCount'] ?? 0}', color: warning),
                _StatCard(icon: Icons.link_rounded, label: '파티 참여', value: '${data?['membershipCount'] ?? 0}', color: const Color(0xFF73A7FF)),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(child: Text('실시간 채팅 피드', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
            Text('${messages.length}개 표시', style: const TextStyle(color: muted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 10),
        if (latestMessages.isEmpty)
          const GlowCard(child: Text('아직 올라온 채팅이 없습니다.', style: TextStyle(color: muted)))
        else
          ...latestMessages.map((m) => _AdminMessageCard(message: m, onDelete: () => deleteMessage(m))),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(child: Text('최근 생성 파티', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
            Text('${teams.length}개 운영 중', style: const TextStyle(color: muted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 10),
        ...teams.take(4).map((t) => _AdminTeamCard(team: t, onDelete: () => deleteTeam(t))),
      ],
    );
  }

  Widget _adminMessages(List<Map<String, dynamic>> messages) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GlowCard(
          borderColor: Color(0x55FFC765),
          child: Row(
            children: [
              Icon(Icons.shield_rounded, color: warning),
              SizedBox(width: 12),
              Expanded(child: Text('새 채팅이 올라오면 자동 갱신됩니다. 문제가 있는 메시지는 즉시 삭제할 수 있습니다.', style: TextStyle(color: muted, height: 1.45))),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (messages.isEmpty)
          const GlowCard(child: Text('표시할 채팅이 없습니다.', style: TextStyle(color: muted)))
        else
          ...messages.map((m) => _AdminMessageCard(message: m, onDelete: () => deleteMessage(m))),
      ],
    );
  }

  Widget _adminTeams(List<Map<String, dynamic>> teams) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (teams.isEmpty)
          const GlowCard(child: Text('현재 운영 중인 파티가 없습니다.', style: TextStyle(color: muted)))
        else
          ...teams.map((t) => _AdminTeamCard(team: t, onDelete: () => deleteTeam(t))),
      ],
    );
  }

  Widget _adminUsers(List<Map<String, dynamic>> users) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (users.isEmpty)
          const GlowCard(child: Text('회원이 없습니다.', style: TextStyle(color: muted)))
        else
          ...users.map((u) => _AdminUserCard(
                user: u,
                onDelete: u['isAdmin'] == true ? null : () => deleteUser(u),
              )),
      ],
    );
  }
}

class _AdminMessageCard extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback onDelete;
  const _AdminMessageCard({required this.message, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final created = DateTime.tryParse('${message['createdAt']}')?.toLocal();
    final time = created == null
        ? ''
        : '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlowCard(
        padding: const EdgeInsets.all(14),
        borderColor: purple.withAlpha(45),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: purple.withAlpha(25), borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.chat_bubble_rounded, color: purpleSoft, size: 19),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      Text('${message['nickname']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                      _MiniBadge(text: '${message['game']}', color: purpleSoft),
                      _MiniBadge(text: '#${message['teamId']} ${message['teamTitle']}', color: mint),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText('${message['body']}', style: const TextStyle(height: 1.45)),
                  const SizedBox(height: 6),
                  Text('${message['email']} · $time', style: const TextStyle(color: muted, fontSize: 10)),
                ],
              ),
            ),
            IconButton(
              tooltip: '메시지 삭제',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, color: danger),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminTeamCard extends StatelessWidget {
  final Map<String, dynamic> team;
  final VoidCallback onDelete;
  const _AdminTeamCard({required this.team, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final private = team['isPrivate'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlowCard(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [purple.withAlpha(70), mint.withAlpha(25)]),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(private ? Icons.lock_rounded : Icons.public_rounded, color: private ? warning : mint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${team['title']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      _MiniBadge(text: '${team['game']}', color: purpleSoft),
                      _MiniBadge(text: '${team['mode']}', color: mint),
                      _MiniBadge(text: '${team['memberCount']}/${team['capacity']}명', color: warning),
                      _MiniBadge(text: '채팅 ${team['messageCount']}개', color: const Color(0xFF73A7FF)),
                      if (private) _MiniBadge(text: '비공개 · ${team['accessCode']}', color: danger),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('방장 ${team['ownerName']} · ${team['ownerEmail']}', style: const TextStyle(color: muted, fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              tooltip: '파티 강제 삭제',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_forever_rounded, color: danger),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminUserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onDelete;
  const _AdminUserCard({required this.user, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final created = DateTime.tryParse('${user['createdAt']}')?.toLocal();
    final dateText = created == null
        ? ''
        : '${created.year}.${created.month.toString().padLeft(2, '0')}.${created.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlowCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Avatar(user['avatar'], radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text('${user['nickname']}', style: const TextStyle(fontWeight: FontWeight.w900))),
                      if (user['isAdmin'] == true) ...[
                        const SizedBox(width: 7),
                        const _MiniBadge(text: 'ADMIN', color: mint),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${user['email']} · 가입 $dateText', style: const TextStyle(color: muted, fontSize: 11)),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: '회원 삭제',
                onPressed: onDelete,
                icon: const Icon(Icons.person_remove_alt_1_rounded, color: danger),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              Text(label, style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const TeamsPage(),
      const TeamsPage(search: true),
      CreateTeamPage(onCreated: () => setState(() => tab = 3)),
      const TeamsPage(mine: true),
      const ProfilePage(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          const _AmbientBackground(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(.04, .015),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: mint), label: '홈'),
          NavigationDestination(icon: Icon(Icons.search_rounded), selectedIcon: Icon(Icons.search_rounded, color: mint), label: '찾기'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline_rounded), selectedIcon: Icon(Icons.add_circle_rounded, color: mint), label: '파티'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline_rounded), selectedIcon: Icon(Icons.chat_bubble_rounded, color: mint), label: '채팅'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded, color: mint), label: '프로필'),
        ],
      ),
    );
  }
}

class TeamsPage extends StatefulWidget {
  final bool mine;
  final bool search;

  const TeamsPage({super.key, this.mine = false, this.search = false});

  @override
  State<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends State<TeamsPage> {
  final query = TextEditingController();
  List<dynamic> teams = [];
  String? selected;
  String? error;
  bool loading = true;
  int? joining;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final result = await Api.request('GET', '/community/teams?mine=${widget.mine}');
      if (mounted) {
        setState(() {
          teams = result as List;
          error = null;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString().replaceFirst('Exception: ', '');
          loading = false;
        });
      }
    }
  }

  Future<String?> askPrivateCode(Map<String, dynamic> team) async {
    final code = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: panelSoft,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: warning.withAlpha(24),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.lock_rounded, color: warning, size: 20),
            ),
            const SizedBox(width: 11),
            const Expanded(child: Text('비공개 파티')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('「${team['title']}」에 들어가려면 방장이 알려준 숫자 4자리 코드가 필요합니다.', style: const TextStyle(color: muted, height: 1.5)),
            const SizedBox(height: 16),
            TextField(
              controller: code,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 8),
              decoration: const InputDecoration(
                hintText: '1234',
                counterText: '',
                prefixIcon: Icon(Icons.password_rounded),
              ),
              onSubmitted: (value) {
                if (RegExp(r'^\d{4}$').hasMatch(value.trim())) {
                  Navigator.pop(context, value.trim());
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(
            onPressed: () {
              final value = code.text.trim();
              if (!RegExp(r'^\d{4}$').hasMatch(value)) {
                notice(context, '숫자 4자리 코드를 입력해주세요.');
                return;
              }
              Navigator.pop(context, value);
            },
            child: const Text('입장'),
          ),
        ],
      ),
    );
    code.dispose();
    return result;
  }

  Future<void> enter(Map<String, dynamic> team) async {
    if (joining != null) return;
    final joinedNow = team['joined'] != true;
    String? code;
    if (joinedNow && team['isPrivate'] == true) {
      code = await askPrivateCode(team);
      if (code == null) return;
    }

    setState(() => joining = team['id'] as int);
    try {
      if (joinedNow) {
        await Api.request('POST', '/community/teams/${team['id']}/join', {
          if (code != null) 'code': code,
        });
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(team: team, showJoinSuccess: joinedNow),
        ),
      );
      if (mounted) await load();
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => joining = null);
    }
  }

  List<Map<String, dynamic>> get visible {
    final keyword = query.text.trim().toLowerCase();
    return teams
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((team) {
          if (selected != null && team['game'] != selected) return false;
          if (keyword.isEmpty) return true;
          final haystack = '${team['title']} ${team['game']} ${team['mode']} ${team['ownerName']}'.toLowerCase();
          return haystack.contains(keyword);
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.mine
        ? '내 채팅'
        : widget.search
            ? '파티 찾기'
            : '홈';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (!widget.mine && !widget.search)
              _HomeHero(nickname: '${Api.user['nickname'] ?? ''}'),
            if (!widget.mine && !widget.search) const SizedBox(height: 22),
            if (widget.search) ...[
              TextField(
                controller: query,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: '게임, 모드, 파티 소개, 방장 검색',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (!widget.mine) ...[
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      text: '전체',
                      selected: selected == null,
                      onTap: () => setState(() => selected = null),
                    ),
                    ...games.map(
                      (game) => _FilterChip(
                        text: game,
                        selected: selected == game,
                        onTap: () => setState(() => selected = selected == game ? null : game),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    widget.search ? '모집 중인 파티' : '🔥 지금 같이 할 사람',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  Text('${visible.length}개', style: const TextStyle(color: muted, fontSize: 12)),
                ],
              ),
            ] else ...[
              const GlowCard(
                padding: EdgeInsets.all(15),
                child: Row(
                  children: [
                    Icon(Icons.mark_chat_unread_rounded, color: mint),
                    SizedBox(width: 11),
                    Expanded(child: Text('가입한 파티와 읽지 않은 메시지를 여기서 확인할 수 있어요.', style: TextStyle(color: muted, height: 1.4))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (loading) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator(color: mint))),
            if (error != null)
              GlowCard(
                borderColor: danger.withAlpha(80),
                child: Text(error!, style: const TextStyle(color: danger)),
              ),
            if (!loading && error == null && visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                child: Column(
                  children: [
                    Icon(widget.mine ? Icons.chat_bubble_outline_rounded : Icons.groups_2_outlined, size: 48, color: muted),
                    const SizedBox(height: 14),
                    Text(
                      widget.mine
                          ? '아직 참여한 파티가 없어요.\n홈에서 참가하거나 직접 파티를 만들어보세요.'
                          : '조건에 맞는 파티가 없어요.\n직접 새로운 파티를 만들어보세요.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: muted, height: 1.65),
                    ),
                  ],
                ),
              ),
            ...visible.asMap().entries.map(
              (entry) => _Entrance(
                delay: math.min(entry.key * 35, 220).toInt(),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TeamCard(
                    team: entry.value,
                    busy: joining == entry.value['id'],
                    onOpen: () => enter(entry.value),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHero extends StatefulWidget {
  final String nickname;

  const _HomeHero({required this.nickname});

  @override
  State<_HomeHero> createState() => _HomeHeroState();
}

class _HomeHeroState extends State<_HomeHero> with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final v = Curves.easeInOut.transform(controller.value);
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + v * .25, -1),
              end: Alignment(1, 1 - v * .25),
              colors: [
                purple.withAlpha(95 + (v * 28).round()),
                const Color(0xFF171B29),
                mint.withAlpha(28 + (v * 24).round()),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: purple.withAlpha(85 + (v * 35).round())),
            boxShadow: [
              BoxShadow(
                color: purple.withAlpha(18 + (v * 18).round()),
                blurRadius: 30 + v * 12,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: mint,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: mint.withAlpha(90), blurRadius: 8 + v * 8)],
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Text('READY TO PLAY?', style: TextStyle(color: mint, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${widget.nickname}님,\n오늘 누구랑 할까요?', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, height: 1.18)),
                    const SizedBox(height: 10),
                    const Text('원하는 게임과 분위기의 파티를 골라 바로 채팅해보세요.', style: TextStyle(color: Color(0xFFB7BDCA), height: 1.5, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Transform.translate(
                offset: Offset(0, -5 * v),
                child: Transform.rotate(
                  angle: (v - .5) * .05,
                  child: const BrandMark(size: 68, showName: false),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.text, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? purple.withAlpha(45) : panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? purple : line),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: selected ? Colors.white : muted,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class TeamCard extends StatelessWidget {
  final Map<String, dynamic> team;
  final bool busy;
  final VoidCallback onOpen;

  const TeamCard({super.key, required this.team, required this.busy, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final count = (team['memberCount'] as num?)?.toInt() ?? 0;
    final capacity = (team['capacity'] as num?)?.toInt() ?? 0;
    final full = count >= capacity;
    final joined = team['joined'] == true;
    final isOwner = team['isOwner'] == true;
    final unread = (team['unreadCount'] as num?)?.toInt() ?? 0;
    final isPrivate = team['isPrivate'] == true;

    return GlowCard(
      borderColor: joined ? purple.withAlpha(85) : line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: purple.withAlpha(30),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.sports_esports_rounded, color: purpleSoft),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${team['title']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, height: 1.3),
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                            padding: const EdgeInsets.symmetric(horizontal: 7),
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(color: danger, shape: BoxShape.circle),
                            child: Text('$unread', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniBadge(text: '${team['game']}', color: purpleSoft),
                        _MiniBadge(text: '${team['mode']}', color: mint),
                        _MiniBadge(text: '$count/$capacity', color: warning),
                        _MiniBadge(text: isPrivate ? '비공개' : '공개', color: isPrivate ? danger : const Color(0xFF73A7FF)),
                        if (isOwner && isPrivate && team['accessCode'] != null)
                          _MiniBadge(text: '코드 ${team['accessCode']}', color: warning),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Avatar(team['ownerAvatar'], radius: 16),
              const SizedBox(width: 9),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${team['ownerName']}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.workspace_premium_rounded, color: warning, size: 16),
                    if (isOwner) ...[
                      const SizedBox(width: 6),
                      const _MiniBadge(text: '내 파티', color: mint),
                    ],
                  ],
                ),
              ),
              Text(
                '${team['style']} · ${team['mic'] == true ? 'MIC ON' : 'MIC OFF'}',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy || (full && !joined) ? null : onOpen,
            icon: Icon(joined ? Icons.chat_bubble_rounded : isPrivate ? Icons.lock_open_rounded : Icons.login_rounded, size: 19),
            label: Text(
              busy
                  ? '연결 중…'
                  : joined
                      ? '채팅 열기'
                      : full
                          ? '모집 완료'
                          : '참가하고 채팅하기',
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _MiniBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}

class CreateTeamPage extends StatefulWidget {
  final VoidCallback onCreated;

  const CreateTeamPage({super.key, required this.onCreated});

  @override
  State<CreateTeamPage> createState() => _CreateTeamPageState();
}

class _CreateTeamPageState extends State<CreateTeamPage> {
  String game = games.first;
  String mode = modes.first;
  String style = '편하게';
  bool mic = true;
  bool isPrivate = false;
  bool busy = false;
  int capacity = 5;
  final title = TextEditingController();
  final accessCode = TextEditingController();

  @override
  void dispose() {
    title.dispose();
    accessCode.dispose();
    super.dispose();
  }

  Future<void> create() async {
    if (title.text.trim().isEmpty) {
      notice(context, '파티 소개를 입력해주세요.');
      return;
    }
    if (isPrivate && !RegExp(r'^\d{4}$').hasMatch(accessCode.text.trim())) {
      notice(context, '비공개 파티는 숫자 4자리 입장 코드를 설정해주세요.');
      return;
    }
    setState(() => busy = true);
    try {
      await Api.request('POST', '/community/teams', {
        'game': game,
        'mode': mode,
        'style': style,
        'mic': mic,
        'capacity': capacity,
        'title': title.text.trim(),
        'isPrivate': isPrivate,
        if (isPrivate) 'accessCode': accessCode.text.trim(),
      });
      if (!mounted) return;
      successNotice(context, '파티 생성 완료', '파티를 만들었어요. 이제 방장으로 관리할 수 있습니다.');
      title.clear();
      accessCode.clear();
      setState(() => isPrivate = false);
      widget.onCreated();
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('파티 만들기', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [purple.withAlpha(85), panel]),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: purple.withAlpha(80)),
            ),
            child: const Row(
              children: [
                Icon(Icons.workspace_premium_rounded, color: warning, size: 34),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('내가 방장이 됩니다', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      SizedBox(height: 5),
                      Text('파티원 확인, 추방, 파티 삭제 권한이 방장에게 주어집니다.', style: TextStyle(color: muted, height: 1.45, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _FormSection(
            title: '게임 & 모드',
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: game,
                  decoration: const InputDecoration(labelText: '게임'),
                  items: games.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setState(() => game = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  decoration: const InputDecoration(labelText: '모드'),
                  items: modes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setState(() => mode = v!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _FormSection(
            title: '파티 설정',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('총 인원 (나 포함)', style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 9),
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: capacity > 2 ? () => setState(() => capacity--) : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    Expanded(
                      child: Text('$capacity 명', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    ),
                    IconButton.filled(
                      onPressed: capacity < 20 ? () => setState(() => capacity++) : null,
                      style: IconButton.styleFrom(backgroundColor: mint, foregroundColor: bg),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text('플레이 스타일', style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  children: ['빡겜', '편하게', '상관없음']
                      .map(
                        (s) => ChoiceChip(
                          label: Text(s),
                          selected: style == s,
                          selectedColor: purple.withAlpha(55),
                          side: BorderSide(color: style == s ? purple : line),
                          onSelected: (_) => setState(() => style = s),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('마이크 사용', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('음성 채팅을 사용할 파티인지 표시해요.', style: TextStyle(color: muted, fontSize: 11)),
                  activeThumbColor: mint,
                  value: mic,
                  onChanged: (v) => setState(() => mic = v),
                ),
                const Divider(height: 24),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      Icon(isPrivate ? Icons.lock_rounded : Icons.public_rounded, color: isPrivate ? warning : mint, size: 20),
                      const SizedBox(width: 8),
                      Text(isPrivate ? '비공개 파티' : '공개 파티', style: const TextStyle(fontWeight: FontWeight.w900)),
                    ],
                  ),
                  subtitle: Text(
                    isPrivate ? '숫자 4자리 입장 코드를 아는 사람만 참가할 수 있어요.' : '누구나 파티 목록에서 바로 참가할 수 있어요.',
                    style: const TextStyle(color: muted, fontSize: 11, height: 1.4),
                  ),
                  activeThumbColor: warning,
                  value: isPrivate,
                  onChanged: (v) {
                    setState(() {
                      isPrivate = v;
                      if (v && accessCode.text.isEmpty) {
                        accessCode.text = (1000 + math.Random().nextInt(9000)).toString();
                      }
                    });
                  },
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: isPrivate
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: accessCode,
                                  keyboardType: TextInputType.number,
                                  maxLength: 4,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 7),
                                  decoration: const InputDecoration(
                                    labelText: '입장 코드',
                                    hintText: '1234',
                                    counterText: '',
                                    prefixIcon: Icon(Icons.password_rounded),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 9),
                              IconButton.filledTonal(
                                tooltip: '랜덤 코드 만들기',
                                onPressed: () => setState(() {
                                  accessCode.text = (1000 + math.Random().nextInt(9000)).toString();
                                }),
                                icon: const Icon(Icons.casino_rounded),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _FormSection(
            title: '파티 소개',
            child: TextField(
              controller: title,
              maxLength: 80,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '예) 즐겜 위주! 매너 좋으신 분 같이 해요 🙌',
                counterText: '',
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: busy ? null : create,
            icon: const Icon(Icons.rocket_launch_rounded),
            label: Text(busy ? '만드는 중…' : '파티 모집 시작'),
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _FormSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final dynamic photo;
  final double radius;

  const Avatar(this.photo, {super.key, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    try {
      if (photo is String && (photo as String).startsWith('data:image/')) {
        image = MemoryImage(base64Decode((photo as String).split(',')[1]));
      }
    } catch (_) {
      image = null;
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF252A38),
      backgroundImage: image,
      child: image == null ? Icon(Icons.person_rounded, color: mint, size: radius) : null,
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController nickname;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    nickname = TextEditingController(text: Api.user['nickname'] as String? ?? '');
  }

  @override
  void dispose() {
    nickname.dispose();
    super.dispose();
  }

  Future<void> save({bool photo = false, bool remove = false}) async {
    if (busy) return;
    if (nickname.text.trim().length < 2 || nickname.text.trim().length > 30) {
      notice(context, '닉네임은 2~30자로 입력해주세요.');
      return;
    }

    setState(() => busy = true);
    try {
      final body = <String, dynamic>{'nickname': nickname.text.trim()};
      if (remove) body['avatar'] = null;

      if (photo) {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 85,
        );
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        if (bytes.length > 2 * 1024 * 1024) throw Exception('2MB 이하 사진을 선택해주세요.');
        final mime = bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50
            ? 'png'
            : bytes.length > 3 && bytes[0] == 0xff && bytes[1] == 0xd8
                ? 'jpeg'
                : bytes.length > 12 && ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP'
                    ? 'webp'
                    : null;
        if (mime == null) throw Exception('PNG, JPEG, WebP 사진을 선택해주세요.');
        body['avatar'] = 'data:image/$mime;base64,${base64Encode(bytes)}';
      }

      final user = await Api.request('PATCH', '/community/me', body);
      Api.user = Map<String, dynamic>.from(user as Map);
      if (mounted) {
        setState(() {});
        successNotice(context, '프로필 저장 완료', '변경한 프로필이 정상적으로 저장되었습니다.');
      }
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void logout() {
    Api.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 프로필', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 34),
        children: [
          GlowCard(
            borderColor: purple.withAlpha(70),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [purple, mint]),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: panel, shape: BoxShape.circle),
                    child: Avatar(Api.user['avatar'], radius: 48),
                  ),
                ),
                const SizedBox(height: 15),
                Text('${Api.user['nickname'] ?? ''}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text('${Api.user['email'] ?? ''}', style: const TextStyle(color: muted)),
                if (Api.user['isAdmin'] == true) ...[
                  const SizedBox(height: 10),
                  const _MiniBadge(text: 'ADMIN', color: mint),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _FormSection(
            title: '프로필 편집',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nickname,
                  maxLength: 30,
                  decoration: const InputDecoration(labelText: '닉네임', counterText: ''),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => save(photo: true),
                  icon: const Icon(Icons.add_a_photo_outlined, color: mint),
                  label: const Text('프로필 사진 선택'),
                ),
                if (Api.user['avatar'] != null)
                  TextButton(
                    onPressed: busy ? null : () => save(remove: true),
                    child: const Text('사진 제거', style: TextStyle(color: danger)),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: busy ? null : save,
                  child: Text(busy ? '저장 중…' : '프로필 저장'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('계정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('사진과 닉네임은 파티 멤버와 채팅에 표시됩니다.', style: TextStyle(color: muted, height: 1.5, fontSize: 12)),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('로그아웃'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  final Map<String, dynamic> team;
  final bool showJoinSuccess;

  const ChatPage({
    super.key,
    required this.team,
    this.showJoinSuccess = false,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final io.Socket socket;
  final draft = TextEditingController();
  final scroll = ScrollController();

  List<Map<String, dynamic>> messages = [];
  List<Map<String, dynamic>> members = [];
  Map<String, dynamic>? pending;

  String status = '연결 중…';
  bool ready = false;
  bool sending = false;
  bool loading = true;
  bool more = true;
  bool olderBusy = false;
  bool closing = false;
  bool joinNoticeShown = false;
  int generation = 0;

  int get teamId => widget.team['id'] as int;
  bool get isOwner => widget.team['owner_id'] == Api.user['id'] || widget.team['ownerId'] == Api.user['id'] || widget.team['isOwner'] == true;

  @override
  void initState() {
    super.initState();
    socket = io.io(
      Api.base,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .setAuth({'token': Api.token})
          .build(),
    );

    socket.onConnect((_) => connectRoom());
    socket.onDisconnect((_) {
      generation++;
      if (mounted && !closing) {
        setState(() {
          ready = false;
          status = '연결 끊김 · 재연결 중';
        });
      }
    });
    socket.onConnectError((_) {
      if (mounted && !closing) {
        setState(() {
          loading = false;
          status = '연결 실패 · 서버 또는 로그인을 확인해주세요';
        });
      }
    });
    socket.on('message:new', (dynamic raw) {
      if (!mounted || raw is! Map || raw['teamId'] != teamId) return;
      final message = Map<String, dynamic>.from(raw);
      addMessages([message]);
      if (message['senderId'] != Api.user['id']) markRead(message['id'] as int);
      bottom();
    });
    socket.on('message:read', (dynamic raw) {
      if (!mounted || raw is! Map || raw['teamId'] != teamId) return;
      final update = Map<String, dynamic>.from(raw);
      setState(() {
        final index = members.indexWhere((m) => m['id'] == update['userId']);
        if (index >= 0) {
          members[index]['lastReadMessageId'] = update['messageId'];
        }
      });
    });
    socket.on('message:deleted', (dynamic raw) {
      if (!mounted || raw is! Map || raw['teamId'] != teamId) return;
      final messageId = (raw['messageId'] as num?)?.toInt();
      if (messageId == null) return;
      setState(() => messages.removeWhere((m) => m['id'] == messageId));
      notice(context, '관리자에 의해 메시지 1개가 삭제되었습니다.', warningNotice: true, title: '채팅 관리');
    });
    socket.on('account:deleted', (_) {
      if (!mounted || closing) return;
      closing = true;
      Api.logout();
      notice(context, '관리자에 의해 계정이 삭제되었습니다.', warningNotice: true, title: '계정 알림');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthPage()),
          (_) => false,
        );
      });
    });
    socket.on('team:members_changed', (dynamic raw) {
      if (raw is Map && raw['teamId'] == teamId) loadMembers();
    });
    socket.on('team:kicked', (dynamic raw) {
      if (raw is Map && raw['teamId'] == teamId) {
        exitChat('방장에 의해 파티에서 제외되었습니다.');
      }
    });
    socket.on('team:deleted', (dynamic raw) {
      if (raw is Map && raw['teamId'] == teamId) {
        exitChat(isOwner ? '파티를 삭제했습니다.' : '방장이 파티를 삭제했습니다.');
      }
    });

    socket.connect();
  }

  Future<dynamic> ack(String event, dynamic data) {
    final completer = Completer<dynamic>();
    socket.emitWithAck(
      event,
      data,
      ack: (dynamic response) {
        if (completer.isCompleted) return;
        if (response is Map && response['ok'] == true) {
          completer.complete(response['data']);
        } else {
          completer.completeError(
            Exception(response is Map ? response['error'] ?? '요청 실패' : '응답 오류'),
          );
        }
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('서버 응답이 늦습니다. 다시 시도해주세요.'),
    );
  }

  Future<void> connectRoom() async {
    final current = ++generation;
    if (mounted) {
      setState(() {
        loading = true;
        ready = false;
        status = '대화를 불러오는 중…';
        messages = [];
      });
    }

    try {
      await ack('team:join', {'teamId': teamId});
      final results = await Future.wait([
        Api.request('GET', '/community/teams/$teamId/messages'),
        Api.request('GET', '/community/teams/$teamId/members'),
      ]);
      if (!mounted || current != generation) return;

      final rows = (results[0] as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      final memberRows = (results[1] as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      messages = [];
      addMessages(rows);
      setState(() {
        members = memberRows;
        ready = true;
        loading = false;
        more = rows.length == 50;
        status = '실시간 연결됨 · ${members.length}명 참여 중';
      });
      if (messages.isNotEmpty) await markRead(messages.last['id'] as int);
      bottom();
      if (widget.showJoinSuccess && !joinNoticeShown) {
        joinNoticeShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            successNotice(
              context,
              '파티 참여 완료',
              '파티에 참여했습니다. 이제 멤버들과 채팅할 수 있어요.',
            );
          }
        });
      }
    } catch (e) {
      if (mounted && current == generation) {
        setState(() {
          loading = false;
          status = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> loadMembers() async {
    try {
      final rows = await Api.request('GET', '/community/teams/$teamId/members');
      if (!mounted) return;
      setState(() {
        members = (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
        status = '실시간 연결됨 · ${members.length}명 참여 중';
      });
    } catch (_) {}
  }

  void addMessages(List<Map<String, dynamic>> rows) {
    if (!mounted) return;
    final map = <int, Map<String, dynamic>>{
      for (final message in messages) message['id'] as int: message,
    };
    for (final message in rows) {
      map[message['id'] as int] = message;
    }
    setState(() {
      messages = map.values.toList()
        ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    });
  }

  Future<void> markRead(int messageId) async {
    if (!ready || messageId < 1) return;
    try {
      final raw = await ack('message:read', {'teamId': teamId, 'messageId': messageId});
      final update = Map<String, dynamic>.from(raw as Map);
      if (!mounted) return;
      setState(() {
        final index = members.indexWhere((m) => m['id'] == Api.user['id']);
        if (index >= 0) members[index]['lastReadMessageId'] = update['messageId'];
      });
    } catch (_) {}
  }

  int unreadFor(Map<String, dynamic> message) {
    if (members.length <= 1) return 0;
    final messageId = message['id'] as int;
    final senderId = message['senderId'] as int;
    return members.where((member) {
      if (member['id'] == senderId) return false;
      final lastRead = (member['lastReadMessageId'] as num?)?.toInt() ?? 0;
      return lastRead < messageId;
    }).length;
  }

  void bottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> older() async {
    if (olderBusy || messages.isEmpty) return;
    final current = generation;
    setState(() => olderBusy = true);
    try {
      final rows = await Api.request(
        'GET',
        '/community/teams/$teamId/messages?before=${messages.first['id']}',
      );
      if (!mounted || current != generation) return;
      final list = (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      addMessages(list);
      setState(() => more = list.length == 50);
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => olderBusy = false);
    }
  }

  Future<void> send() async {
    if (!ready || sending) return;
    if (pending == null) {
      if (draft.text.trim().isEmpty) return;
      pending = {
        'teamId': teamId,
        'clientId': const Uuid().v4(),
        'body': draft.text.trim(),
      };
    }

    setState(() => sending = true);
    try {
      final raw = await ack('message:send', pending);
      final sent = Map<String, dynamic>.from(raw as Map);
      if (!mounted) return;
      addMessages([sent]);
      setState(() {
        pending = null;
        draft.clear();
      });
      await markRead(sent['id'] as int);
      bottom();
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> deleteParty() async {
    if (!isOwner) return;
    final ok = await askConfirm(
      context,
      title: '파티를 삭제할까요?',
      message: '모든 파티원과 채팅 기록이 함께 삭제됩니다. 이 작업은 되돌릴 수 없습니다.',
      action: '파티 삭제',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ack('team:delete', {'teamId': teamId});
    } catch (e) {
      if (mounted && !closing) notice(context, e);
    }
  }

  void exitChat(String message) {
    if (!mounted || closing) return;
    closing = true;
    notice(context, message, warningNotice: true, title: '파티 알림');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  void dispose() {
    generation++;
    socket.dispose();
    draft.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 6,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    '${widget.team['title']}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ),
                if (isOwner) ...[
                  const SizedBox(width: 5),
                  const Icon(Icons.workspace_premium_rounded, size: 16, color: warning),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(status, style: TextStyle(fontSize: 10, color: ready ? mint : muted)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '파티원',
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => TeamMembersSheet(
                teamId: teamId,
                owner: isOwner,
                ack: ack,
              ),
            ),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.group_outlined),
                if (members.isNotEmpty)
                  Positioned(
                    top: -7,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: const BoxDecoration(color: purple, shape: BoxShape.circle),
                      child: Text('${members.length}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900)),
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: panelSoft,
            onSelected: (value) {
              if (value == 'refresh') connectRoom();
              if (value == 'delete') deleteParty();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'refresh', child: Row(children: [Icon(Icons.refresh_rounded), SizedBox(width: 10), Text('새로고침')])),
              if (isOwner)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [Icon(Icons.delete_forever_rounded, color: danger), SizedBox(width: 10), Text('파티 삭제', style: TextStyle(color: danger))]),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                if (loading) const LinearProgressIndicator(color: mint, minHeight: 2),
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: line),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, color: mint, size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isOwner ? '방장 권한 활성화 · 파티원 관리 및 삭제 가능' : '파티원 전용 채팅 · 읽음 상태가 실시간 반영됩니다',
                          style: const TextStyle(color: muted, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                    itemCount: messages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        if (more && messages.isNotEmpty) {
                          return Center(
                            child: TextButton(
                              onPressed: olderBusy ? null : older,
                              child: Text(olderBusy ? '불러오는 중…' : '이전 대화 더 보기'),
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            messages.isEmpty && !loading ? '첫 메시지를 보내 파티 대화를 시작해보세요 👋' : '파티 대화의 시작',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: muted, fontSize: 11),
                          ),
                        );
                      }

                      final message = messages[index - 1];
                      final mine = message['senderId'] == Api.user['id'];
                      final time = DateTime.tryParse('${message['createdAt']}')?.toLocal();
                      final stamp = time == null
                          ? ''
                          : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                      final unread = unreadFor(message);

                      return _MessageBubble(
                        message: message,
                        mine: mine,
                        stamp: stamp,
                        unread: unread,
                        showReceipt: members.length > 1,
                      );
                    },
                  ),
                ),
                if (pending != null && !sending)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        const Expanded(child: Text('전송 확인이 필요합니다.', style: TextStyle(color: warning, fontSize: 11))),
                        TextButton(onPressed: ready ? send : null, child: const Text('재시도')),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0D0F15),
                    border: Border(top: BorderSide(color: line)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: draft,
                          readOnly: pending != null,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                            hintText: '메시지를 입력하세요…',
                            counterText: '',
                            fillColor: panelSoft,
                          ),
                          onSubmitted: (_) => send(),
                        ),
                      ),
                      const SizedBox(width: 9),
                      IconButton.filled(
                        onPressed: ready && !sending ? send : null,
                        style: IconButton.styleFrom(
                          backgroundColor: mint,
                          foregroundColor: bg,
                          minimumSize: const Size(50, 50),
                        ),
                        icon: Icon(sending ? Icons.hourglass_top_rounded : Icons.arrow_upward_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool mine;
  final String stamp;
  final int unread;
  final bool showReceipt;

  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.stamp,
    required this.unread,
    required this.showReceipt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!mine) ...[
            Avatar(message['avatar'], radius: 18),
            const SizedBox(width: 9),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!mine)
                  Padding(
                    padding: const EdgeInsets.only(left: 3, bottom: 5),
                    child: Text('${message['nickname']}', style: const TextStyle(color: Color(0xFFB5BAC8), fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .68),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: mine ? const LinearGradient(colors: [purple, Color(0xFF6E4CE8)]) : null,
                    color: mine ? null : panelSoft,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(mine ? 18 : 5),
                      bottomRight: Radius.circular(mine ? 5 : 18),
                    ),
                    border: mine ? null : Border.all(color: line),
                  ),
                  child: SelectableText('${message['body']}', style: const TextStyle(fontSize: 14, height: 1.45)),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showReceipt) ...[
                      Text(
                        unread == 0 ? '읽음' : '$unread',
                        style: TextStyle(
                          color: unread == 0 ? mint : warning,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(stamp, style: const TextStyle(color: muted, fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TeamMembersSheet extends StatefulWidget {
  final int teamId;
  final bool owner;
  final Future<dynamic> Function(String event, dynamic data) ack;

  const TeamMembersSheet({super.key, required this.teamId, required this.owner, required this.ack});

  @override
  State<TeamMembersSheet> createState() => _TeamMembersSheetState();
}

class _TeamMembersSheetState extends State<TeamMembersSheet> {
  List<Map<String, dynamic>> members = [];
  bool loading = true;
  int? kicking;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final rows = await Api.request('GET', '/community/teams/${widget.teamId}/members');
      if (mounted) {
        setState(() {
          members = (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        notice(context, e);
      }
    }
  }

  Future<void> kick(Map<String, dynamic> member) async {
    final ok = await askConfirm(
      context,
      title: '${member['nickname']}님을 내보낼까요?',
      message: '추방된 파티원은 이 채팅방에 더 이상 접근할 수 없습니다.',
      action: '추방',
      destructive: true,
    );
    if (!ok) return;

    setState(() => kicking = member['id'] as int);
    try {
      await widget.ack('team:kick', {
        'teamId': widget.teamId,
        'memberId': member['id'],
      });
      if (!mounted) return;
      successNotice(context, '파티원 추방 완료', '${member['nickname']}님을 파티에서 내보냈습니다.');
      await load();
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => kicking = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .78),
      decoration: const BoxDecoration(
        color: Color(0xFF10121A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: line)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 42, height: 4, decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 12, 12),
              child: Row(
                children: [
                  const Icon(Icons.groups_2_rounded, color: mint),
                  const SizedBox(width: 10),
                  Text('파티원 ${members.length}명', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded)),
                ],
              ),
            ),
            if (widget.owner)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 18),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: purple.withAlpha(20),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: purple.withAlpha(60)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: warning, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text('방장 권한으로 다른 파티원을 추방할 수 있습니다.', style: TextStyle(color: muted, fontSize: 11))),
                  ],
                ),
              ),
            Flexible(
              child: loading
                  ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: mint)))
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(18),
                      itemCount: members.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final me = member['id'] == Api.user['id'];
                        final owner = member['isOwner'] == true;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Avatar(member['avatar'], radius: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(child: Text('${member['nickname']}', style: const TextStyle(fontWeight: FontWeight.w800))),
                                        if (me) ...[
                                          const SizedBox(width: 6),
                                          const _MiniBadge(text: '나', color: mint),
                                        ],
                                        if (owner) ...[
                                          const SizedBox(width: 6),
                                          const Icon(Icons.workspace_premium_rounded, color: warning, size: 17),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(owner ? '방장' : '파티원', style: const TextStyle(color: muted, fontSize: 11)),
                                  ],
                                ),
                              ),
                              if (widget.owner && !owner)
                                TextButton(
                                  onPressed: kicking == null ? () => kick(member) : null,
                                  child: Text(
                                    kicking == member['id'] ? '처리 중…' : '추방',
                                    style: const TextStyle(color: danger, fontWeight: FontWeight.w800),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
