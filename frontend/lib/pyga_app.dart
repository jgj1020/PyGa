import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
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

const games = ['League of Legends', 'VALORANT', '배틀그라운드', 'FC Online'];
const pcGames = <String>[
  'League of Legends',
  'VALORANT',
  '배틀그라운드',
  'FC Online',
  '오버워치 2',
  '메이플스토리',
  '로스트아크',
  '서든어택',
  '던전앤파이터',
  '마인크래프트',
  'TFT',
  '스타크래프트 2',
  '이터널 리턴',
  '레인보우 식스 시즈',
  '카운터 스트라이크 2',
];
const mobileGames = <String>[
  '브롤스타즈',
  '배틀그라운드 모바일',
  '리그 오브 레전드: 와일드 리프트',
  'TFT 모바일',
  '원신',
  '붕괴: 스타레일',
  '로블록스',
  '쿠키런: 킹덤',
  '클래시 로얄',
  '포켓몬 GO',
  '카트라이더 러쉬플러스',
  '모바일 레전드',
];
const allGames = <String>[...pcGames, ...mobileGames];
const modes = ['경쟁전', '일반전', '칼바람 나락', '자유 플레이'];


class GameCoverStore {
  static final ValueNotifier<Map<String, String>> covers = ValueNotifier(<String, String>{});
  static bool _loading = false;
  static bool _loaded = false;

  static Future<void> ensureLoaded({bool force = false}) async {
    if (_loading || (_loaded && !force)) return;
    _loading = true;
    try {
      final result = await Api.request('GET', '/games/covers');
      final rows = result is Map ? result['covers'] : null;
      if (rows is List) {
        final next = <String, String>{};
        for (final row in rows) {
          if (row is! Map) continue;
          final game = '${row['game'] ?? ''}'.trim();
          final url = '${row['coverUrl'] ?? ''}'.trim();
          if (game.isNotEmpty && url.startsWith('https://')) next[game] = url;
        }
        covers.value = next;
      }
    } catch (_) {
      // API 키가 아직 없거나 외부 API가 잠시 실패하면 저작권 부담이 적은 기본 게임 아이콘을 사용합니다.
    } finally {
      _loaded = true;
      _loading = false;
    }
  }
}

final GlobalKey<NavigatorState> pygaNavigatorKey = GlobalKey<NavigatorState>();

class MaintenanceState {
  final bool known;
  final bool active;
  final String title;
  final String message;

  const MaintenanceState({
    this.known = true,
    required this.active,
    this.title = 'PyGa 점검 중',
    this.message = '서비스 안정화를 위한 점검이 진행 중입니다.',
  });
}

class MaintenanceStore {
  static final ValueNotifier<MaintenanceState> state =
      ValueNotifier(const MaintenanceState(known: false, active: false));
  static Timer? _timer;
  static bool _checking = false;

  static void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 3), (_) => check());
    unawaited(check());
  }

  static Future<void> check() async {
    if (_checking) return;
    _checking = true;
    try {
      final raw = await Api.request('GET', '/maintenance/status')
          .timeout(const Duration(seconds: 12));
      if (raw is Map) {
        final active = raw['active'] == true;
        state.value = MaintenanceState(
          known: true,
          active: active,
          title: '${raw['title'] ?? 'PyGa 점검 중'}',
          message: '${raw['message'] ?? '서비스 안정화를 위한 점검이 진행 중입니다.'}',
        );
      } else if (!state.value.known) {
        // 예상하지 못한 응답이어도 시작 화면에서 무한 대기하지 않습니다.
        state.value = const MaintenanceState(known: true, active: false);
      }
    } catch (_) {
      // Render가 깨어나는 중이거나 이전 백엔드가 아직 배포된 경우에도
      // 시작 화면에서 무한 대기하지 않고 앱을 열어 둡니다.
      // 주기적인 check()가 계속 실행되어 서버가 준비되면 점검 상태가 즉시 반영됩니다.
      if (!state.value.known) {
        state.value = const MaintenanceState(known: true, active: false);
      }
    } finally {
      _checking = false;
    }
  }
}

class MaintenanceGate extends StatefulWidget {
  final Widget child;
  const MaintenanceGate({super.key, required this.child});

  @override
  State<MaintenanceGate> createState() => _MaintenanceGateState();
}

class _MaintenanceGateState extends State<MaintenanceGate> {
  bool adminLoginBypass = false;

  @override
  void initState() {
    super.initState();
    MaintenanceStore.start();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MaintenanceState>(
      valueListenable: MaintenanceStore.state,
      builder: (context, status, _) {
        final isAdmin = Api.user['isAdmin'] == true;
        if (isAdmin || adminLoginBypass) return widget.child;
        if (!status.known) {
          return const Material(
            color: bg,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BrandMark(size: 92),
                  SizedBox(height: 22),
                  CircularProgressIndicator(color: mint),
                  SizedBox(height: 14),
                  Text('서버 상태 확인 중…', style: TextStyle(color: muted)),
                ],
              ),
            ),
          );
        }
        if (!status.active) return widget.child;

        return Material(
          color: bg,
          child: Stack(
            children: [
              const Positioned.fill(child: _AmbientBackground(intensity: .75)),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: GlowCard(
                        borderColor: danger.withAlpha(140),
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const BrandMark(size: 96),
                            const SizedBox(height: 22),
                            Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                color: danger.withAlpha(24),
                                shape: BoxShape.circle,
                                border: Border.all(color: danger.withAlpha(110)),
                              ),
                              child: const Icon(Icons.build_circle_rounded, color: danger, size: 34),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              status.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              status.message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFD3D7E2), height: 1.55),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              '관리자가 점검 종료를 알리면 자동으로 다시 이용할 수 있습니다.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: muted, fontSize: 12.5),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: MaintenanceStore.check,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('점검 상태 다시 확인'),
                            ),
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: () async {
                                setState(() => adminLoginBypass = true);
                                await Future<void>.delayed(Duration.zero);
                                await pygaNavigatorKey.currentState?.push(
                                  MaterialPageRoute(builder: (_) => const AdminLoginPage()),
                                );
                                if (mounted) {
                                  setState(() => adminLoginBypass = false);
                                }
                              },
                              icon: const Icon(Icons.admin_panel_settings_outlined, size: 17),
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
      },
    );
  }
}

class _GameArtwork extends StatelessWidget {
  final String game;
  final BoxFit fit;
  final Alignment alignment;
  final FilterQuality filterQuality;

  const _GameArtwork({
    super.key,
    required this.game,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.high,
  });

  Widget _fallback() {
    final accent = gameAccent(game);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withAlpha(115), panelSoft, bg],
        ),
      ),
      child: Center(
        child: Icon(
          gamePlatform(game) == '모바일'
              ? Icons.phone_android_rounded
              : Icons.sports_esports_rounded,
          size: 62,
          color: Colors.white.withAlpha(185),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, String>>(
      valueListenable: GameCoverStore.covers,
      builder: (context, covers, _) {
        final url = covers[game];
        if (url == null || url.isEmpty) return _fallback();
        return Image.network(
          url,
          fit: fit,
          alignment: alignment,
          filterQuality: filterQuality,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _fallback(),
        );
      },
    );
  }
}

String gamePlatform(String game) => mobileGames.contains(game) ? '모바일' : 'PC';

List<String> gameModes(String game) {
  switch (game) {
    case 'League of Legends':
      return const ['솔로랭크', '자유랭크', '일반전', '칼바람 나락'];
    case 'VALORANT':
      return const ['경쟁전', '일반전', '신속플레이', '데스매치'];
    case '배틀그라운드':
    case '배틀그라운드 모바일':
      return const ['솔로', '듀오', '스쿼드', '일반전'];
    case 'FC Online':
      return const ['1vs1', '2vs2', '친선', '클럽'];
    case '오버워치 2':
      return const ['경쟁전', '빠른 대전', '아케이드', '사용자 지정'];
    case '메이플스토리':
    case '로스트아크':
    case '던전앤파이터':
      return const ['보스/레이드', '사냥', '퀘스트', '자유 플레이'];
    case '브롤스타즈':
      return const ['트로피', '경쟁전', '이벤트', '자유 플레이'];
    case 'TFT':
    case 'TFT 모바일':
      return const ['랭크', '일반', '더블 업', '자유 플레이'];
    default:
      return const ['랭크/경쟁', '일반', '협동', '자유 플레이'];
  }
}

String tierHint(String game) {
  switch (game) {
    case 'League of Legends':
    case 'TFT':
    case 'TFT 모바일':
      return '예) Gold 2 / Emerald 4 / Master';
    case 'VALORANT':
      return '예) Gold 3 / Diamond 1 / Immortal';
    case '오버워치 2':
      return '예) Platinum 2 / Master 5';
    case '배틀그라운드':
    case '배틀그라운드 모바일':
      return '예) Gold / Diamond / Master';
    case '브롤스타즈':
      return '예) Diamond / Mythic / Masters';
    case 'FC Online':
      return '예) 월드클래스 / 챌린저 / 슈퍼챔피언스';
    default:
      return '티어/랭크가 없다면 비워도 됩니다.';
  }
}

String gameDisplayName(String game) {
  switch (game) {
    case 'League of Legends':
      return '리그 오브 레전드';
    case 'VALORANT':
      return '발로란트';
    case '배틀그라운드':
      return '배틀그라운드';
    case 'FC Online':
      return 'FC 온라인';
    default:
      return game;
  }
}

String gameTagline(String game) {
  switch (game) {
    case 'League of Legends':
      return '랭크부터 칼바람까지, 바로 같이 할 팀을 찾아보세요.';
    case 'VALORANT':
      return '듀오부터 5인큐까지, 호흡 맞는 요원을 모집해보세요.';
    case '배틀그라운드':
      return '치킨을 향해 출발. 듀오와 스쿼드를 빠르게 모아보세요.';
    case 'FC Online':
      return '친선부터 팀플레이까지, 같이 뛸 플레이어를 만나보세요.';
    default:
      return '지금 함께 플레이할 파티를 찾아보세요.';
  }
}

Color gameAccent(String game) {
  switch (game) {
    case 'League of Legends':
      return const Color(0xFF2ED7D0);
    case 'VALORANT':
      return const Color(0xFFFF5A73);
    case '배틀그라운드':
      return const Color(0xFFFFC246);
    case 'FC Online':
      return const Color(0xFFE4B856);
    default:
      return purple;
  }
}

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
      navigatorKey: pygaNavigatorKey,
      title: 'PyGa',
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MaintenanceGate(
        child: child ?? const SizedBox.shrink(),
      ),
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
  void initState() {
    super.initState();
    unawaited(Api.warmup());
    unawaited(GameCoverStore.ensureLoaded());
  }

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

    final normalizedEmail = email.text.trim();
    final normalizedNickname = nickname.text.trim();

    setState(() => busy = true);

    try {
      if (register) {
        await Api.register(
          normalizedNickname,
          normalizedEmail,
          password.text,
        );

        unawaited(MaintenanceStore.check());
        unawaited(GameCoverStore.ensureLoaded(force: true));

        if (!mounted) return;

        successNotice(
          context,
          '회원가입 완료',
          '계정이 만들어졌어요. 바로 PyGa를 시작합니다!',
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainPage()),
          (_) => false,
        );
      } else {
        await Api.login(
          normalizedEmail,
          password.text,
        );

        unawaited(MaintenanceStore.check());
        unawaited(GameCoverStore.ensureLoaded(force: true));

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
                                register ? '새 계정 만들기' : '함께할 파티원을 찾아볼까요?',
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
      await MaintenanceStore.check();
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
    refreshTimer = Timer.periodic(const Duration(seconds: 6), (_) => load(silent: true));
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
          completer.completeError(Exception(response is Map ? response['error'] ?? '요청 실패' : '응답 오류'));
        }
      },
    );
    return completer.future.timeout(const Duration(seconds: 8), onTimeout: () => throw Exception('관리자 서버 응답이 늦습니다.'));
  }

  Future<void> load({bool silent = false}) async {
    if (!silent && mounted) setState(() => loading = true);
    try {
      final result = Map<String, dynamic>.from(await Api.request('GET', '/admin/dashboard'));
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
      (data?[key] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];

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

  Future<void> createAnnouncement() async {
    final title = TextEditingController();
    final message = TextEditingController();
    String kind = 'notice';
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          backgroundColor: panelSoft,
          title: const Text('전체 공지 보내기'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: '공지 종류'),
                  items: const [
                    DropdownMenuItem(value: 'notice', child: Text('일반 공지')),
                    DropdownMenuItem(value: 'maintenance_soon', child: Text('점검 예정')),
                    DropdownMenuItem(value: 'maintenance', child: Text('점검 중')),
                    DropdownMenuItem(value: 'maintenance_done', child: Text('점검 종료')),
                  ],
                  onChanged: (v) => setLocal(() => kind = v ?? 'notice'),
                ),
                const SizedBox(height: 12),
                TextField(controller: title, maxLength: 80, decoration: const InputDecoration(labelText: '제목', counterText: '')),
                const SizedBox(height: 12),
                TextField(
                  controller: message,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 1000,
                  decoration: const InputDecoration(labelText: '내용', hintText: '예) 서버 안정화 작업으로 22:00부터 점검을 시작합니다.', counterText: ''),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            FilledButton(
              onPressed: () {
                if (title.text.trim().length < 2 || message.text.trim().length < 2) return;
                Navigator.pop(context, {'kind': kind, 'title': title.text.trim(), 'message': message.text.trim()});
              },
              child: const Text('전체 전송'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    message.dispose();
    if (result == null) return;
    try {
      await Api.request('POST', '/admin/announcements', result);
      if (!mounted) return;
      successNotice(context, '공지 전송 완료', '접속 중인 사용자에게 운영 알림이 표시됩니다.');
      await load(silent: true);
    } catch (e) {
      if (mounted) notice(context, e);
    }
  }

  Future<void> closeAnnouncement(Map<String, dynamic> item) async {
    try {
      await Api.request('PATCH', '/admin/announcements/${item['id']}/close');
      if (!mounted) return;
      successNotice(context, '공지 종료', '해당 공지를 더 이상 사용자에게 표시하지 않습니다.');
      await load(silent: true);
    } catch (e) {
      if (mounted) notice(context, e);
    }
  }

  Future<void> deleteAnnouncement(Map<String, dynamic> item) async {
    final ok = await askConfirm(
      context,
      title: '공지 기록을 삭제할까요?',
      message: '「${item['title']}」 공지 기록을 완전히 삭제합니다.',
      action: '삭제',
      destructive: true,
    );
    if (!ok) return;
    try {
      await Api.request('DELETE', '/admin/announcements/${item['id']}');
      if (!mounted) return;
      successNotice(context, '공지 삭제 완료', '공지 기록을 삭제했습니다.');
      await load(silent: true);
    } catch (e) {
      if (mounted) notice(context, e);
    }
  }

  Future<void> clearAnnouncementHistory() async {
    final count = rows('announcements').length;
    final ok = await askConfirm(
      context,
      title: '공지 기록 전체 삭제',
      message: '저장된 공지 기록 $count건을 모두 삭제합니다. 이 작업은 되돌릴 수 없습니다.',
      action: '전체 삭제',
      destructive: true,
    );
    if (!ok) return;
    try {
      final result = await Api.request('DELETE', '/admin/announcements');
      if (!mounted) return;
      successNotice(context, '전체 삭제 완료', '${result['deletedCount'] ?? count}건의 공지 기록을 삭제했습니다.');
      await load(silent: true);
    } catch (e) {
      if (mounted) notice(context, e);
    }
  }

  Future<Map<String, String>?> suspensionDialog({String titleText = '이용 정지 설정', bool allowNone = true}) async {
    String duration = allowNone ? 'none' : '1d';
    final note = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          backgroundColor: panelSoft,
          title: Text(titleText),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: duration,
                  decoration: const InputDecoration(labelText: '처분'),
                  items: [
                    if (allowNone) const DropdownMenuItem(value: 'none', child: Text('신고 처리만 완료 · 정지 없음')),
                    const DropdownMenuItem(value: '1m', child: Text('1분 정지 (테스트용)')),
                    const DropdownMenuItem(value: '1d', child: Text('1일 정지')),
                    const DropdownMenuItem(value: '7d', child: Text('7일 정지')),
                    const DropdownMenuItem(value: '30d', child: Text('30일 정지')),
                    const DropdownMenuItem(value: '365d', child: Text('1년 정지')),
                    const DropdownMenuItem(value: 'permanent', child: Text('영구 정지')),
                  ],
                  onChanged: (v) => setLocal(() => duration = v ?? duration),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: '관리자 메모 / 정지 사유', counterText: ''),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            FilledButton(
              onPressed: () => Navigator.pop(context, {'duration': duration, 'adminNote': note.text.trim()}),
              child: const Text('처리'),
            ),
          ],
        ),
      ),
    );
    note.dispose();
    return result;
  }

  Future<void> resolveReport(Map<String, dynamic> report) async {
    final result = await suspensionDialog(titleText: '${report['reportedName']} 신고 처리');
    if (result == null) return;
    try {
      await Api.request('PATCH', '/admin/reports/${report['id']}/resolve', result);
      if (!mounted) return;
      successNotice(context, '신고 처리 완료', result['duration'] == 'none' ? '신고를 처리 완료로 변경했습니다.' : '신고 처리와 이용 정지를 적용했습니다.');
      await load(silent: true);
    } catch (e) {
      if (mounted) notice(context, e);
    }
  }

  Future<void> suspendUser(Map<String, dynamic> user) async {
    final result = await suspensionDialog(titleText: '${user['nickname']} 이용 정지', allowNone: false);
    if (result == null) return;
    try {
      await Api.request('POST', '/admin/users/${user['id']}/suspend', {
        'duration': result['duration'],
        'reason': result['adminNote']!.isEmpty ? '운영 정책 위반' : result['adminNote'],
      });
      if (!mounted) return;
      successNotice(context, '정지 적용 완료', '${user['nickname']} 계정에 이용 정지를 적용했습니다.');
      await load(silent: true);
    } catch (e) {
      if (mounted) notice(context, e);
    }
  }

  Future<void> unsuspendUser(Map<String, dynamic> user) async {
    try {
      await Api.request('POST', '/admin/users/${user['id']}/unsuspend');
      if (!mounted) return;
      successNotice(context, '정지 해제 완료', '${user['nickname']} 계정의 이용 정지를 해제했습니다.');
      await load(silent: true);
    } catch (e) {
      if (mounted) notice(context, e);
    }
  }

  void logout() {
    Api.logout();
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthPage()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final users = rows('users');
    final teams = rows('teams');
    final messages = rows('messages');
    final reports = rows('reports');
    final announcements = rows('announcements');
    final sectionTitles = ['실시간 현황', '채팅 검열', '파티 관리', '회원 관리', '신고 관리', '공지/점검'];
    final icons = [
      Icons.dashboard_rounded,
      Icons.shield_rounded,
      Icons.groups_2_rounded,
      Icons.people_alt_rounded,
      Icons.flag_rounded,
      Icons.campaign_rounded,
    ];

    Widget content;
    switch (section) {
      case 1:
        content = _adminMessages(messages);
        break;
      case 2:
        content = _adminTeams(teams);
        break;
      case 3:
        content = _adminUsers(users);
        break;
      case 4:
        content = _adminReports(reports);
        break;
      case 5:
        content = _adminAnnouncements(announcements);
        break;
      default:
        content = _adminOverview(users, teams, messages, reports);
    }

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
            child: Row(children: [
              Icon(Icons.circle, size: 8, color: live ? mint : danger),
              const SizedBox(width: 6),
              Text(live ? 'LIVE' : '연결 중', style: TextStyle(color: live ? mint : danger, fontSize: 10, fontWeight: FontWeight.w900)),
            ]),
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
                    GlowCard(
                      borderColor: purple.withAlpha(85),
                      child: const Row(children: [
                        BrandMark(size: 52, showName: false),
                        SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('운영 관제 센터', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                          SizedBox(height: 4),
                          Text('공지 · 신고 · 회원 정지 · 파티 · 채팅을 한 곳에서 관리합니다.', style: TextStyle(color: muted, height: 1.4)),
                        ])),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(sectionTitles.length, (index) {
                          final selected = section == index;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              avatar: Icon(icons[index], size: 17, color: selected ? bg : muted),
                              label: Text(sectionTitles[index]),
                              selected: selected,
                              onSelected: (_) => setState(() => section = index),
                              selectedColor: mint,
                              backgroundColor: panel,
                              labelStyle: TextStyle(color: selected ? bg : Colors.white, fontWeight: FontWeight.w800),
                              side: BorderSide(color: selected ? mint : line),
                            ),
                          );
                        }),
                      ),
                    ),
                    if (loading) ...[const SizedBox(height: 12), const LinearProgressIndicator(color: mint)],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      GlowCard(borderColor: danger.withAlpha(90), child: Text(error!, style: const TextStyle(color: danger))),
                    ],
                    const SizedBox(height: 18),
                    AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: KeyedSubtree(key: ValueKey(section), child: content)),
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
    List<Map<String, dynamic>> reports,
  ) {
    final pendingReports = reports.where((r) => r['status'] == 'pending').length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: columns == 4 ? 1.25 : 1.35,
          children: [
            _StatCard(icon: Icons.people_alt_rounded, label: '전체 회원', value: '${data?['userCount'] ?? users.length}', color: mint),
            _StatCard(icon: Icons.groups_2_rounded, label: '운영 파티', value: '${data?['teamCount'] ?? teams.length}', color: purpleSoft),
            _StatCard(icon: Icons.forum_rounded, label: '전체 메시지', value: '${data?['messageCount'] ?? 0}', color: warning),
            _StatCard(icon: Icons.flag_rounded, label: '미처리 신고', value: '$pendingReports', color: danger),
          ],
        );
      }),
      const SizedBox(height: 22),
      const Text('최근 채팅', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      ...messages.take(5).map((m) => _AdminMessageCard(message: m, onDelete: () => deleteMessage(m))),
    ]);
  }

  Widget _adminMessages(List<Map<String, dynamic>> messages) => Column(
        children: messages.isEmpty
            ? [const GlowCard(child: Text('표시할 채팅이 없습니다.', style: TextStyle(color: muted)))]
            : messages.map((m) => _AdminMessageCard(message: m, onDelete: () => deleteMessage(m))).toList(),
      );

  Widget _adminTeams(List<Map<String, dynamic>> teams) => Column(
        children: teams.isEmpty
            ? [const GlowCard(child: Text('현재 운영 중인 파티가 없습니다.', style: TextStyle(color: muted)))]
            : teams.map((t) => _AdminTeamCard(team: t, onDelete: () => deleteTeam(t))).toList(),
      );

  Widget _adminUsers(List<Map<String, dynamic>> users) => Column(
        children: users.isEmpty
            ? [const GlowCard(child: Text('회원이 없습니다.', style: TextStyle(color: muted)))]
            : users
                .map((u) => _AdminUserCard(
                      user: u,
                      onDelete: u['isAdmin'] == true ? null : () => deleteUser(u),
                      onSuspend: u['isAdmin'] == true ? null : () => suspendUser(u),
                      onUnsuspend: u['isAdmin'] == true ? null : () => unsuspendUser(u),
                    ))
                .toList(),
      );

  Widget _adminReports(List<Map<String, dynamic>> reports) {
    final pending = reports.where((r) => r['status'] == 'pending').toList();
    final done = reports.where((r) => r['status'] != 'pending').toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GlowCard(
        borderColor: danger.withAlpha(70),
        child: Row(children: [
          const Icon(Icons.flag_rounded, color: danger),
          const SizedBox(width: 10),
          Expanded(child: Text('미처리 신고 ${pending.length}건 · 신고 내용을 확인한 뒤 정지 기간을 선택할 수 있습니다.', style: const TextStyle(color: muted))),
        ]),
      ),
      const SizedBox(height: 12),
      if (pending.isEmpty) const GlowCard(child: Text('미처리 신고가 없습니다.', style: TextStyle(color: muted))),
      ...pending.map((r) => _AdminReportCard(report: r, onResolve: () => resolveReport(r))),
      if (done.isNotEmpty) ...[
        const SizedBox(height: 18),
        const Text('처리 완료', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text('처리 완료된 신고는 5분 후 이 목록에서 자동으로 숨겨집니다. 기록 자체는 서버에 보관됩니다.', style: TextStyle(color: muted, fontSize: 11)),
        const SizedBox(height: 8),
        ...done.take(50).map((r) => _AdminReportCard(report: r)),
      ],
    ]);
  }

  Widget _adminAnnouncements(List<Map<String, dynamic>> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: createAnnouncement,
                icon: const Icon(Icons.campaign_rounded),
                label: const Text('전체 공지 / 점검 알림 보내기'),
              ),
              OutlinedButton.icon(
                onPressed: items.isEmpty ? null : clearAnnouncementHistory,
                icon: const Icon(Icons.delete_sweep_rounded, color: danger),
                label: const Text('공지 기록 전체 삭제', style: TextStyle(color: danger)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const GlowCard(child: Text('공지 기록이 없습니다.', style: TextStyle(color: muted)))
          else
            ...items.map((a) => _AdminAnnouncementCard(
                  item: a,
                  onClose: a['active'] == true && a['kind'] != 'maintenance'
                      ? () => closeAnnouncement(a)
                      : null,
                  onDelete: a['kind'] == 'maintenance' && a['active'] == true
                      ? null
                      : () => deleteAnnouncement(a),
                )),
        ],
      );
}

class _AdminMessageCard extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback onDelete;
  const _AdminMessageCard({required this.message, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlowCard(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(message['kind'] == 'system' ? Icons.info_rounded : Icons.chat_bubble_rounded, color: message['kind'] == 'system' ? mint : purpleSoft),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, children: [
              Text('${message['nickname']}', style: const TextStyle(fontWeight: FontWeight.w900)),
              if (message['kind'] == 'system') const _MiniBadge(text: 'SYSTEM', color: mint),
              _MiniBadge(text: '${message['game']}', color: purpleSoft),
              _MiniBadge(text: '#${message['teamId']} ${message['teamTitle']}', color: mint),
            ]),
            const SizedBox(height: 8),
            SelectableText('${message['body']}', style: const TextStyle(height: 1.45)),
            const SizedBox(height: 5),
            Text('${message['email']}', style: const TextStyle(color: muted, fontSize: 10)),
          ])),
          IconButton(onPressed: onDelete, tooltip: '메시지 삭제', icon: const Icon(Icons.delete_outline_rounded, color: danger)),
        ]),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlowCard(
        padding: const EdgeInsets.all(15),
        child: Row(children: [
          Icon(team['isPrivate'] == true ? Icons.lock_rounded : Icons.public_rounded, color: team['isPrivate'] == true ? warning : mint),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${team['title']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Wrap(spacing: 6, runSpacing: 5, children: [
              _MiniBadge(text: '${team['game']}', color: purpleSoft),
              _MiniBadge(text: '${team['mode']}', color: mint),
              _MiniBadge(text: '${team['memberCount']}/${team['capacity']}명', color: warning),
            ]),
            const SizedBox(height: 5),
            Text('방장 ${team['ownerName']} · ${team['ownerEmail']}', style: const TextStyle(color: muted, fontSize: 11)),
          ])),
          IconButton(onPressed: onDelete, tooltip: '파티 강제 삭제', icon: const Icon(Icons.delete_forever_rounded, color: danger)),
        ]),
      ),
    );
  }
}

class _AdminUserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onDelete;
  final VoidCallback? onSuspend;
  final VoidCallback? onUnsuspend;
  const _AdminUserCard({required this.user, this.onDelete, this.onSuspend, this.onUnsuspend});

  bool get suspended {
    if (user['suspensionPermanent'] == true) return true;
    final until = DateTime.tryParse('${user['suspendedUntil'] ?? ''}');
    return until != null && until.isAfter(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlowCard(
        padding: const EdgeInsets.all(14),
        borderColor: suspended ? danger.withAlpha(85) : null,
        child: Row(children: [
          Avatar(user['avatar'], radius: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 7, runSpacing: 5, children: [
              Text('${user['nickname']}', style: const TextStyle(fontWeight: FontWeight.w900)),
              if (user['isAdmin'] == true) const _MiniBadge(text: 'ADMIN', color: mint),
              if (suspended) _MiniBadge(text: user['suspensionPermanent'] == true ? '영구 정지' : '이용 정지', color: danger),
            ]),
            const SizedBox(height: 4),
            Text('${user['email']}', style: const TextStyle(color: muted, fontSize: 11)),
            if (suspended && user['suspensionReason'] != null)
              Text('사유: ${user['suspensionReason']}', style: const TextStyle(color: danger, fontSize: 10)),
          ])),
          if (onSuspend != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (suspended && onUnsuspend != null)
                  TextButton.icon(
                    onPressed: onUnsuspend,
                    icon: const Icon(Icons.lock_open_rounded, color: mint, size: 18),
                    label: const Text('정지 해제', style: TextStyle(color: mint, fontWeight: FontWeight.w800)),
                  ),
                PopupMenuButton<String>(
                  color: panelSoft,
                  onSelected: (v) {
                    if (v == 'suspend') onSuspend?.call();
                    if (v == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => [
                    if (!suspended) const PopupMenuItem(value: 'suspend', child: Text('이용 정지')),
                    if (onDelete != null) const PopupMenuItem(value: 'delete', child: Text('회원 삭제', style: TextStyle(color: danger))),
                  ],
                ),
              ],
            ),
        ]),
      ),
    );
  }
}

class _AdminReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback? onResolve;
  const _AdminReportCard({required this.report, this.onResolve});

  @override
  Widget build(BuildContext context) {
    final pending = report['status'] == 'pending';
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GlowCard(
        borderColor: pending ? danger.withAlpha(75) : line,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(pending ? Icons.flag_rounded : Icons.task_alt_rounded, color: pending ? danger : mint),
            const SizedBox(width: 9),
            Expanded(child: Text('${report['reportedName']} 신고', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
            _MiniBadge(text: pending ? '처리 대기' : '처리 완료', color: pending ? danger : mint),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 7, runSpacing: 6, children: [
            _MiniBadge(text: '${report['category']}', color: warning),
            if (report['game'] != null) _MiniBadge(text: '${report['game']}', color: purpleSoft),
            if (report['teamTitle'] != null) _MiniBadge(text: '${report['teamTitle']}', color: mint),
          ]),
          const SizedBox(height: 9),
          SelectableText('${report['details']}', style: const TextStyle(height: 1.5)),
          const SizedBox(height: 7),
          Text('신고자 ${report['reporterName']} (${report['reporterEmail']})', style: const TextStyle(color: muted, fontSize: 11)),
          Text('대상 ${report['reportedName']} (${report['reportedEmail']})', style: const TextStyle(color: muted, fontSize: 11)),
          if (!pending && report['adminNote'] != null) ...[
            const SizedBox(height: 7),
            Text('관리자 메모: ${report['adminNote']}', style: const TextStyle(color: purpleSoft, fontSize: 11)),
          ],
          if (onResolve != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: onResolve, icon: const Icon(Icons.gavel_rounded), label: const Text('신고 처리 · 정지 기간 선택')),
          ],
        ]),
      ),
    );
  }
}

class _AdminAnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onClose;
  final VoidCallback? onDelete;
  const _AdminAnnouncementCard({required this.item, this.onClose, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final active = item['active'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlowCard(
        borderColor: active ? warning.withAlpha(65) : line,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.campaign_rounded, color: active ? warning : muted),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 7, children: [
              Text('${item['title']}', style: const TextStyle(fontWeight: FontWeight.w900)),
              _MiniBadge(text: '${item['kind']}', color: active ? warning : muted),
              _MiniBadge(text: active ? '표시 중' : '종료', color: active ? mint : muted),
            ]),
            const SizedBox(height: 7),
            Text('${item['message']}', style: const TextStyle(color: Color(0xFFD7DAE3), height: 1.45)),
          ])),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onClose != null) TextButton(onPressed: onClose, child: const Text('종료')),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  tooltip: '공지 기록 삭제',
                  icon: const Icon(Icons.delete_outline_rounded, color: danger),
                ),
            ],
          ),
        ]),
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

class ActiveAnnouncementBanner extends StatefulWidget {
  final bool compact;
  const ActiveAnnouncementBanner({super.key, this.compact = false});

  @override
  State<ActiveAnnouncementBanner> createState() => _ActiveAnnouncementBannerState();
}

class _ActiveAnnouncementBannerState extends State<ActiveAnnouncementBanner> {
  List<Map<String, dynamic>> announcements = [];
  Timer? timer;
  Timer? autoHideTimer;
  io.Socket? announcementSocket;
  final Set<int> hiddenIds = <int>{};

  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 15), (_) => load());
    if (Api.token != null) {
      announcementSocket = io.io(
        Api.base,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .enableForceNew()
            .setAuth({'token': Api.token})
            .build(),
      );
      announcementSocket!.on('announcement:update', (_) => load());
      announcementSocket!.connect();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    autoHideTimer?.cancel();
    announcementSocket?.dispose();
    super.dispose();
  }

  int? _idOf(Map<String, dynamic> item) => (item['id'] as num?)?.toInt();

  void _scheduleAutoHide() {
    autoHideTimer?.cancel();
    final visible = announcements.where((a) {
      final id = _idOf(a);
      return id == null || !hiddenIds.contains(id);
    }).toList();
    if (visible.isEmpty) return;

    final item = visible.first;
    final id = _idOf(item);
    if (id == null) return;

    final createdAt = DateTime.tryParse('${item['createdAt'] ?? ''}')?.toLocal();
    final elapsed = createdAt == null ? Duration.zero : DateTime.now().difference(createdAt);
    final remaining = const Duration(minutes: 2) - elapsed;

    if (remaining <= Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => hiddenIds.add(id));
        _scheduleAutoHide();
      });
      return;
    }

    autoHideTimer = Timer(remaining, () {
      if (!mounted) return;
      setState(() => hiddenIds.add(id));
      _scheduleAutoHide();
    });
  }

  Future<void> load() async {
    if (Api.token == null) return;
    try {
      final raw = await Api.request('GET', '/community/announcements');
      if (!mounted) return;
      setState(() {
        announcements = (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
      _scheduleAutoHide();
    } catch (_) {}
  }

  Color colorFor(String kind) {
    switch (kind) {
      case 'maintenance':
        return danger;
      case 'maintenance_soon':
        return warning;
      case 'maintenance_done':
        return mint;
      default:
        return purpleSoft;
    }
  }

  IconData iconFor(String kind) {
    switch (kind) {
      case 'maintenance':
        return Icons.build_circle_rounded;
      case 'maintenance_soon':
        return Icons.schedule_rounded;
      case 'maintenance_done':
        return Icons.check_circle_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = announcements.where((a) {
      final id = _idOf(a);
      return id == null || !hiddenIds.contains(id);
    }).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    final item = visible.first;
    final kind = '${item['kind'] ?? 'notice'}';
    final accent = colorFor(kind);
    final persistent = kind == 'maintenance' || kind == 'maintenance_soon';
    return Container(
      margin: EdgeInsets.fromLTRB(14, widget.compact ? 6 : 10, 14, 4),
      padding: EdgeInsets.symmetric(horizontal: 13, vertical: widget.compact ? 9 : 11),
      decoration: BoxDecoration(
        color: const Color(0xFF151821),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withAlpha(125)),
        boxShadow: [BoxShadow(color: accent.withAlpha(18), blurRadius: 18, offset: const Offset(0, 7))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconFor(kind), color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${item['title']}', style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 12)),
                const SizedBox(height: 3),
                Text('${item['message']}', style: const TextStyle(color: Color(0xFFE3E5EC), fontSize: 11.5, height: 1.35)),
              ],
            ),
          ),
          if (!persistent)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () {
                final id = _idOf(item);
                if (id == null) return;
                setState(() => hiddenIds.add(id));
                _scheduleAutoHide();
              },
              icon: const Icon(Icons.close_rounded, size: 17, color: muted),
            ),
        ],
      ),
    );
  }
}

class UserNotificationBanner extends StatefulWidget {
  final bool compact;
  const UserNotificationBanner({super.key, this.compact = false});

  @override
  State<UserNotificationBanner> createState() => _UserNotificationBannerState();
}

class _UserNotificationBannerState extends State<UserNotificationBanner> {
  List<Map<String, dynamic>> items = [];
  Timer? timer;
  io.Socket? socket;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 12), (_) => load());
    if (Api.token != null) {
      socket = io.io(
        Api.base,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .enableForceNew()
            .setAuth({'token': Api.token})
            .build(),
      );
      socket!.on('notification:update', (_) => load());
      socket!.connect();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    socket?.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (Api.token == null) return;
    try {
      final raw = await Api.request('GET', '/community/notifications');
      if (!mounted) return;
      setState(() {
        items = (raw as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((e) => e['readAt'] == null)
            .toList();
      });
    } catch (_) {}
  }

  Future<void> markRead(Map<String, dynamic> item) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await Api.request('PATCH', '/community/notifications/${item['id']}/read');
      if (!mounted) return;
      setState(() => items.removeWhere((e) => e['id'] == item['id']));
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Color colorFor(String kind) {
    switch (kind) {
      case 'moderation':
        return warning;
      case 'report':
        return mint;
      default:
        return purpleSoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final item = items.first;
    final accent = colorFor('${item['kind'] ?? 'system'}');
    final more = items.length - 1;

    return Container(
      margin: EdgeInsets.fromLTRB(14, widget.compact ? 4 : 8, 14, 4),
      padding: EdgeInsets.symmetric(horizontal: 13, vertical: widget.compact ? 9 : 11),
      decoration: BoxDecoration(
        color: const Color(0xFF121721),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withAlpha(120)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_active_rounded, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item['title']}',
                        style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ),
                    if (more > 0) _MiniBadge(text: '+$more', color: accent),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${item['message']}',
                  style: const TextStyle(color: Color(0xFFE3E5EC), fontSize: 11.5, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: busy ? null : () => markRead(item),
            child: Text(busy ? '처리 중…' : '확인'),
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
    final pages = <Widget>[
      TeamsPage(onCreate: () => setState(() => tab = 2)),
      TeamsPage(search: true, onCreate: () => setState(() => tab = 2)),
      CreateTeamPage(onCreated: () => setState(() => tab = 3)),
      const TeamsPage(mine: true),
      const ProfilePage(),
    ];

    final maxWidth = tab == 0
        ? 1180.0
        : tab == 1
            ? 1060.0
            : tab == 3
                ? 960.0
                : 760.0;

    return Scaffold(
      body: Stack(
        children: [
          const _AmbientBackground(intensity: 1.25),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -1.15),
                    radius: 1.1,
                    colors: [purple.withAlpha(22), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                children: [
                  const SafeArea(bottom: false, child: ActiveAnnouncementBanner()),
                  const UserNotificationBanner(),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 380),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
                        return FadeTransition(
                          opacity: curved,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(.035, .018), end: Offset.zero).animate(curved),
                            child: ScaleTransition(
                              scale: Tween<double>(begin: .992, end: 1).animate(curved),
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D0F15),
          border: Border(top: BorderSide(color: purple.withAlpha(45))),
          boxShadow: [BoxShadow(color: purple.withAlpha(16), blurRadius: 24, offset: const Offset(0, -8))],
        ),
        child: NavigationBar(
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
      ),
    );
  }
}

class TeamsPage extends StatefulWidget {
  final bool mine;
  final bool search;
  final VoidCallback? onCreate;

  const TeamsPage({
    super.key,
    this.mine = false,
    this.search = false,
    this.onCreate,
  });

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

  bool get isHome => !widget.mine && !widget.search;

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
            Text(
              '「${team['title']}」에 들어가려면 방장이 알려준 숫자 4자리 코드가 필요합니다.',
              style: const TextStyle(color: muted, height: 1.5),
            ),
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

  Map<String, int> get gameCounts {
    final result = <String, int>{for (final game in allGames) game: 0};
    for (final raw in teams) {
      final team = Map<String, dynamic>.from(raw as Map);
      final game = '${team['game']}';
      if (result.containsKey(game)) result[game] = (result[game] ?? 0) + 1;
    }
    return result;
  }

  void openSearchFilters() {
    String platformFilter = selected == null ? '전체' : gamePlatform(selected!);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final source = platformFilter == 'PC'
              ? pcGames
              : platformFilter == '모바일'
                  ? mobileGames
                  : allGames;
          return SafeArea(
            top: false,
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .78),
              decoration: const BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: line)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 14, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: purple.withAlpha(22),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: purple.withAlpha(70)),
                          ),
                          child: const Icon(Icons.grid_view_rounded, color: purpleSoft),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('게임 목록 · 필터', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                              SizedBox(height: 2),
                              Text('원하는 게임만 골라서 파티를 찾아보세요.', style: TextStyle(color: muted, fontSize: 11)),
                            ],
                          ),
                        ),
                        IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: ['전체', 'PC', '모바일'].map((value) {
                        final active = platformFilter == value;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: value == '모바일' ? 0 : 8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => setSheetState(() => platformFilter = value),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: active ? purple.withAlpha(30) : panelSoft,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: active ? purple.withAlpha(150) : line),
                                ),
                                child: Text(value, style: TextStyle(color: active ? Colors.white : muted, fontWeight: FontWeight.w800, fontSize: 12)),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 260,
                        mainAxisExtent: 68,
                        mainAxisSpacing: 9,
                        crossAxisSpacing: 9,
                      ),
                      itemCount: source.length,
                      itemBuilder: (context, index) {
                        final game = source[index];
                        final active = selected == game;
                        final accent = gameAccent(game);
                        final count = gameCounts[game] ?? 0;
                        return InkWell(
                          onTap: () {
                            setState(() => selected = game);
                            Navigator.pop(sheetContext);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: active ? accent.withAlpha(20) : panelSoft,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: active ? accent.withAlpha(165) : line),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Row(
                              children: [
                                SizedBox(width: 74, height: double.infinity, child: _GameArtwork(game: game)),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(gameDisplayName(game), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
                                        const SizedBox(height: 4),
                                        Text('${gamePlatform(game)} · $count LIVE', style: TextStyle(color: count > 0 ? mint : muted, fontSize: 9.5, fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                ),
                                if (active) Padding(padding: const EdgeInsets.only(right: 10), child: Icon(Icons.check_circle_rounded, color: accent, size: 20)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => selected = null);
                          Navigator.pop(sheetContext);
                        },
                        icon: const Icon(Icons.apps_rounded),
                        label: const Text('전체 파티 보기'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildPartyGrid() {
    final items = visible;
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 760;
        final threeColumns = constraints.maxWidth >= 1380;
        final cardWidth = threeColumns
            ? (constraints.maxWidth - 32) / 3
            : twoColumns
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: items.asMap().entries.map((entry) {
            return SizedBox(
              width: cardWidth,
              child: _Entrance(
                delay: math.min(entry.key * 45, 260).toInt(),
                child: TeamCard(
                  team: entry.value,
                  busy: joining == entry.value['id'],
                  onOpen: () => enter(entry.value),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.mine
        ? '내 채팅'
        : widget.search
            ? '파티 찾기'
            : 'PyGa';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        titleSpacing: 18,
        title: isHome
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BrandMark(size: 34, showName: false),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PyGa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, height: 1)),
                      SizedBox(height: 3),
                      Text('PLAY TOGETHER', style: TextStyle(color: mint, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
                    ],
                  ),
                ],
              )
            : Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (isHome)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: mint.withAlpha(14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: mint.withAlpha(55)),
              ),
              child: const Row(
                children: [
                  _LiveDot(),
                  SizedBox(width: 6),
                  Text('LIVE', style: TextStyle(color: mint, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ],
              ),
            ),
          IconButton(onPressed: load, tooltip: '새로고침', icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (isHome) ...[
              _HomeGameHero(
                nickname: '${Api.user['nickname'] ?? ''}',
                counts: gameCounts,
                selectedGame: selected,
                onSelectGame: (game) => setState(() => selected = game),
                onCreate: widget.onCreate,
              ),
              const SizedBox(height: 24),
              _GameRail(
                counts: gameCounts,
                selectedGame: selected,
                onSelect: (game) => setState(() => selected = selected == game ? null : game),
                onClear: () => setState(() => selected = null),
              ),
              const SizedBox(height: 30),
            ],
            if (widget.search) ...[
              TextField(
                controller: query,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '게임, 모드, 파티 소개, 방장 검색',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: Tooltip(
                    message: '게임 목록 · 필터',
                    child: IconButton(
                      onPressed: openSearchFilters,
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _GameRail(
                compact: true,
                counts: gameCounts,
                selectedGame: selected,
                onSelect: (game) => setState(() => selected = selected == game ? null : game),
                onClear: () => setState(() => selected = null),
              ),
              const SizedBox(height: 26),
            ],
            if (!widget.mine) ...[
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 26,
                    decoration: BoxDecoration(
                      color: selected == null ? purple : gameAccent(selected!),
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: [
                        BoxShadow(
                          color: (selected == null ? purple : gameAccent(selected!)).withAlpha(100),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected == null
                              ? (widget.search ? '모집 중인 파티' : '지금 뜨는 파티')
                              : '${gameDisplayName(selected!)} 파티',
                          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selected == null ? '실시간으로 모집 중인 파티를 확인하세요.' : gameTagline(selected!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: muted, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  if (selected != null)
                    TextButton.icon(
                      onPressed: () => setState(() => selected = null),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('전체'),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: panelSoft,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: line),
                    ),
                    child: Text('${visible.length} LIVE', style: const TextStyle(color: mint, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ] else ...[
              const GlowCard(
                padding: EdgeInsets.all(15),
                child: Row(
                  children: [
                    Icon(Icons.mark_chat_unread_rounded, color: mint),
                    SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        '가입한 파티와 읽지 않은 메시지를 여기서 확인할 수 있어요.',
                        style: TextStyle(color: muted, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: CircularProgressIndicator(color: mint),
                ),
              ),
            if (error != null)
              GlowCard(
                borderColor: danger.withAlpha(80),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: danger),
                    const SizedBox(width: 12),
                    Expanded(child: Text(error!, style: const TextStyle(color: danger))),
                  ],
                ),
              ),
            if (!loading && error == null && visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: purple.withAlpha(20),
                        shape: BoxShape.circle,
                        border: Border.all(color: purple.withAlpha(55)),
                      ),
                      child: Icon(widget.mine ? Icons.chat_bubble_outline_rounded : Icons.groups_2_outlined, size: 38, color: purpleSoft),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      widget.mine
                          ? '아직 참여한 파티가 없어요.\n홈에서 참가하거나 직접 파티를 만들어보세요.'
                          : '조건에 맞는 파티가 없어요.\n직접 새로운 파티를 만들어보세요.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: muted, height: 1.65),
                    ),
                    if (!widget.mine && widget.onCreate != null) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: widget.onCreate,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('첫 파티 만들기'),
                      ),
                    ],
                  ],
                ),
              ),
            if (!loading && error == null && visible.isNotEmpty) buildPartyGrid(),
          ],
        ),
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 950))..repeat(reverse: true);
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
      builder: (context, _) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: mint,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: mint.withAlpha(70 + (controller.value * 100).round()), blurRadius: 4 + controller.value * 7)],
        ),
      ),
    );
  }
}

class _HomeGameHero extends StatefulWidget {
  final String nickname;
  final Map<String, int> counts;
  final String? selectedGame;
  final ValueChanged<String> onSelectGame;
  final VoidCallback? onCreate;

  const _HomeGameHero({
    required this.nickname,
    required this.counts,
    required this.selectedGame,
    required this.onSelectGame,
    this.onCreate,
  });

  @override
  State<_HomeGameHero> createState() => _HomeGameHeroState();
}

class _HomeGameHeroState extends State<_HomeGameHero> with SingleTickerProviderStateMixin {
  int active = 0;
  Timer? timer;
  late final AnimationController motion;

  @override
  void initState() {
    super.initState();
    motion = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..repeat();
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => active = (active + 1) % games.length);
    });
  }

  @override
  void didUpdateWidget(covariant _HomeGameHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedGame != null && widget.selectedGame != oldWidget.selectedGame) {
      final index = games.indexOf(widget.selectedGame!);
      if (index >= 0) active = index;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    motion.dispose();
    super.dispose();
  }

  void choose(int index) {
    setState(() => active = index);
    widget.onSelectGame(games[index]);
  }

  @override
  Widget build(BuildContext context) {
    final game = games[active];
    final accent = gameAccent(game);
    final partyCount = widget.counts[game] ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final heroHeight = wide ? 350.0 : 330.0;
        return Container(
          height: heroHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(color: accent.withAlpha(42), blurRadius: 42, offset: const Offset(0, 20)),
              const BoxShadow(color: Colors.black45, blurRadius: 28, offset: Offset(0, 18)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 650),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _GameArtwork(
                    game: game,
                    key: ValueKey(game),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha(20),
                        Colors.black.withAlpha(70),
                        const Color(0xFF08090D).withAlpha(242),
                      ],
                      stops: const [0, .38, 1],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFF08090D).withAlpha(wide ? 205 : 170),
                        const Color(0xFF08090D).withAlpha(25),
                      ],
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: motion,
                  builder: (context, _) {
                    final x = -280 + (constraints.maxWidth + 520) * motion.value;
                    return Transform.translate(
                      offset: Offset(x, -30),
                      child: Transform.rotate(
                        angle: -.28,
                        child: Container(
                          width: 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withAlpha(10),
                                accent.withAlpha(28),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  left: wide ? 34 : 24,
                  right: wide ? 34 : 24,
                  top: wide ? 28 : 22,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(115),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: accent.withAlpha(150)),
                          boxShadow: [BoxShadow(color: accent.withAlpha(45), blurRadius: 14)],
                        ),
                        child: Row(
                          children: [
                            const _LiveDot(),
                            const SizedBox(width: 7),
                            Text('$partyCount PARTY LIVE', style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .7)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(color: Colors.black.withAlpha(110), borderRadius: BorderRadius.circular(99)),
                        child: Text('${active + 1} / ${games.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: wide ? 34 : 24,
                  right: wide ? (constraints.maxWidth * .35) : 24,
                  bottom: wide ? 36 : 74,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 360),
                    child: Column(
                      key: ValueKey('copy-$game'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.nickname.isEmpty ? '플레이어' : widget.nickname}님, 오늘은',
                          style: const TextStyle(color: Color(0xFFD5D9E5), fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          gameDisplayName(game),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: wide ? 35 : 27,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            shadows: const [Shadow(color: Colors.black87, blurRadius: 16)],
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          gameTagline(game),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFFD1D5E0), fontSize: 12, height: 1.45),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 9,
                          runSpacing: 9,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: game == 'League of Legends' || game == '배틀그라운드' || game == 'FC Online' ? bg : Colors.white,
                                minimumSize: const Size(0, 44),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              onPressed: () => widget.onSelectGame(game),
                              icon: const Icon(Icons.groups_2_rounded, size: 18),
                              label: const Text('이 게임 파티 보기'),
                            ),
                            if (widget.onCreate != null)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 44),
                                  backgroundColor: Colors.black.withAlpha(80),
                                  side: BorderSide(color: Colors.white.withAlpha(70)),
                                  padding: const EdgeInsets.symmetric(horizontal: 15),
                                ),
                                onPressed: widget.onCreate,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('파티 만들기'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (wide)
                  Positioned(
                    right: 28,
                    bottom: 30,
                    child: Row(
                      children: List.generate(games.length, (index) {
                        final selected = index == active;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: InkWell(
                            onTap: () => choose(index),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: selected ? 62 : 48,
                              height: selected ? 42 : 36,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: selected ? accent : Colors.white.withAlpha(55), width: selected ? 2 : 1),
                                boxShadow: selected ? [BoxShadow(color: accent.withAlpha(55), blurRadius: 12)] : null,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _GameArtwork(game: games[index]),
                                    if (!selected) Container(color: Colors.black.withAlpha(55)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                if (!wide)
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 20,
                    child: Row(
                      children: List.generate(games.length, (index) {
                        final selected = index == active;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: index == games.length - 1 ? 0 : 6),
                            child: InkWell(
                              onTap: () => choose(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                height: 5,
                                decoration: BoxDecoration(
                                  color: selected ? accent : Colors.white.withAlpha(55),
                                  borderRadius: BorderRadius.circular(99),
                                  boxShadow: selected ? [BoxShadow(color: accent.withAlpha(100), blurRadius: 8)] : null,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GameRail extends StatelessWidget {
  final Map<String, int> counts;
  final String? selectedGame;
  final ValueChanged<String> onSelect;
  final VoidCallback onClear;
  final bool compact;

  const _GameRail({
    required this.counts,
    required this.selectedGame,
    required this.onSelect,
    required this.onClear,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Text('게임 바로가기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                const Text('PICK YOUR GAME', style: TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const Spacer(),
                if (selectedGame != null)
                  TextButton(onPressed: onClear, child: const Text('전체 보기')),
              ],
            ),
          ),
        SizedBox(
          height: compact ? 106 : 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: games.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final game = games[index];
              return _GamePosterCard(
                game: game,
                count: counts[game] ?? 0,
                selected: selectedGame == game,
                compact: compact,
                onTap: () => onSelect(game),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GamePosterCard extends StatefulWidget {
  final String game;
  final int count;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _GamePosterCard({
    required this.game,
    required this.count,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  State<_GamePosterCard> createState() => _GamePosterCardState();
}

class _GamePosterCardState extends State<_GamePosterCard> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = gameAccent(widget.game);
    final width = widget.compact ? 165.0 : 215.0;
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: AnimatedScale(
        scale: hover ? 1.025 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: widget.selected ? accent : hover ? accent.withAlpha(130) : line, width: widget.selected ? 2 : 1),
              boxShadow: [
                BoxShadow(
                  color: widget.selected || hover ? accent.withAlpha(40) : Colors.black26,
                  blurRadius: widget.selected || hover ? 22 : 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedScale(
                    scale: hover ? 1.06 : 1,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    child: _GameArtwork(game: widget.game),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withAlpha(60), Colors.black.withAlpha(225)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black.withAlpha(125), borderRadius: BorderRadius.circular(99)),
                      child: Text('${widget.count} LIVE', style: TextStyle(color: accent, fontSize: 8.5, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 11,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gameDisplayName(widget.game),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: widget.compact ? 12 : 14, fontWeight: FontWeight.w900, shadows: const [Shadow(color: Colors.black, blurRadius: 8)]),
                        ),
                        if (!widget.compact) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(width: 5, height: 5, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                              const SizedBox(width: 5),
                              Text(widget.selected ? '선택됨' : '파티 찾기', style: TextStyle(color: widget.selected ? accent : const Color(0xFFD0D4DF), fontSize: 9.5, fontWeight: FontWeight.w800)),
                            ],
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
}

class TeamCard extends StatefulWidget {
  final Map<String, dynamic> team;
  final bool busy;
  final VoidCallback onOpen;

  const TeamCard({super.key, required this.team, required this.busy, required this.onOpen});

  @override
  State<TeamCard> createState() => _TeamCardState();
}

class _TeamCardState extends State<TeamCard> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final team = widget.team;
    final count = (team['memberCount'] as num?)?.toInt() ?? 0;
    final capacity = (team['capacity'] as num?)?.toInt() ?? 0;
    final full = count >= capacity;
    final joined = team['joined'] == true;
    final isOwner = team['isOwner'] == true;
    final unread = (team['unreadCount'] as num?)?.toInt() ?? 0;
    final isPrivate = team['isPrivate'] == true;
    final game = '${team['game']}';
    final accent = gameAccent(game);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        final cardRadius = compact ? 22.0 : 24.0;
        // Mobile party cards use a true 16:9 artwork area so game key art
        // is not crushed into a shallow banner after creating/joining a party.
        // Desktop keeps the compact launcher-style strip.
        final imageHeight = compact
            ? constraints.maxWidth * 9 / 16
            : 108.0;

        return MouseRegion(
          onEnter: compact ? null : (_) => setState(() => hover = true),
          onExit: compact ? null : (_) => setState(() => hover = false),
          child: AnimatedScale(
            scale: !compact && hover ? 1.012 : 1,
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(cardRadius),
                border: Border.all(
                  color: joined
                      ? purple.withAlpha(125)
                      : hover
                          ? accent.withAlpha(125)
                          : line,
                ),
                boxShadow: [
                  BoxShadow(
                    color: hover ? accent.withAlpha(28) : Colors.black26,
                    blurRadius: hover ? 30 : compact ? 18 : 18,
                    offset: Offset(0, hover ? 14 : compact ? 8 : 9),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(cardRadius - 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: imageHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AnimatedScale(
                            scale: !compact && hover ? 1.055 : 1,
                            duration: const Duration(milliseconds: 420),
                            curve: Curves.easeOutCubic,
                            child: _GameArtwork(
                              game: game,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withAlpha(6),
                                  Colors.black.withAlpha(compact ? 20 : 75),
                                  panel.withAlpha(compact ? 170 : 245),
                                ],
                                stops: compact
                                    ? const [0, .72, 1]
                                    : const [0, .50, 1],
                              ),
                            ),
                          ),
                          Positioned(
                            left: compact ? 13 : 14,
                            top: compact ? 12 : 13,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 9 : 9,
                                vertical: compact ? 5 : 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(135),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(color: accent.withAlpha(110)),
                              ),
                              child: Text(
                                gameDisplayName(game),
                                style: TextStyle(
                                  color: accent,
                                  fontSize: compact ? 10 : 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: compact ? 12 : 13,
                            top: compact ? 12 : 13,
                            child: Row(
                              children: [
                                if (isPrivate)
                                  Container(
                                    width: compact ? 31 : 30,
                                    height: compact ? 31 : 30,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha(145),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.lock_rounded,
                                      color: warning,
                                      size: compact ? 15 : 15,
                                    ),
                                  ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: compact ? 9 : 8,
                                    vertical: compact ? 5 : 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(145),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: mint,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        '$count/$capacity',
                                        style: TextStyle(
                                          fontSize: compact ? 10 : 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (unread > 0)
                            Positioned(
                              right: compact ? 12 : 13,
                              bottom: compact ? 10 : 12,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: compact ? 9 : 9,
                                  vertical: compact ? 5 : 5,
                                ),
                                decoration: BoxDecoration(
                                  color: danger,
                                  borderRadius: BorderRadius.circular(99),
                                  boxShadow: [
                                    BoxShadow(
                                      color: danger.withAlpha(80),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  compact ? '$unread 새 메시지' : '새 메시지 $unread',
                                  style: TextStyle(
                                    fontSize: compact ? 10 : 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 15 : 16,
                        compact ? 12 : 8,
                        compact ? 15 : 16,
                        compact ? 15 : 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${team['title']}',
                            maxLines: compact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 18 : 17,
                              fontWeight: FontWeight.w900,
                              height: compact ? 1.25 : 1.3,
                            ),
                          ),
                          SizedBox(height: compact ? 10 : 9),
                          Wrap(
                            spacing: compact ? 7 : 6,
                            runSpacing: compact ? 7 : 6,
                            children: [
                              _MiniBadge(text: '${team['mode']}', color: accent, compact: compact),
                              if (!compact) _MiniBadge(text: '${team['style']}', color: purpleSoft),
                              _MiniBadge(
                                text: team['mic'] == true ? 'MIC ON' : 'MIC OFF',
                                color: team['mic'] == true ? mint : muted,
                                compact: compact,
                              ),
                              _MiniBadge(
                                text: isPrivate ? '비공개' : '공개',
                                color: isPrivate ? warning : const Color(0xFF73A7FF),
                                compact: compact,
                              ),
                              if ((team['ownerTier']?.toString().trim().isNotEmpty ?? false) ||
                                  (team['ownerLevel']?.toString().trim().isNotEmpty ?? false))
                                _MiniBadge(
                                  text: [
                                    if (team['ownerTier']?.toString().trim().isNotEmpty ?? false) '${team['ownerTier']}',
                                    if (team['ownerLevel']?.toString().trim().isNotEmpty ?? false) 'Lv ${team['ownerLevel']}',
                                  ].join(' · '),
                                  color: warning,
                                  compact: compact,
                                ),
                              if (isOwner && isPrivate && team['accessCode'] != null)
                                _MiniBadge(
                                  text: 'CODE ${team['accessCode']}',
                                  color: warning,
                                  compact: compact,
                                ),
                            ],
                          ),
                          SizedBox(height: compact ? 13 : 14),
                          Row(
                            children: [
                              Avatar(team['ownerAvatar'], radius: compact ? 16 : 16),
                              SizedBox(width: compact ? 9 : 9),
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${team['ownerName']}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: compact ? 14 : null,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.workspace_premium_rounded,
                                      color: warning,
                                      size: compact ? 16 : 16,
                                    ),
                                    if (isOwner) ...[
                                      const SizedBox(width: 5),
                                      _MiniBadge(text: '내 파티', color: mint, compact: true),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.people_alt_rounded,
                                color: accent,
                                size: compact ? 17 : 17,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$count/$capacity',
                                style: TextStyle(
                                  color: muted,
                                  fontSize: compact ? 11.5 : 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: compact ? 13 : 12),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: joined ? purple : accent.withAlpha(215),
                              foregroundColor: game == 'League of Legends' ||
                                      game == '배틀그라운드' ||
                                      game == 'FC Online'
                                  ? bg
                                  : Colors.white,
                              minimumSize: Size(0, compact ? 48 : 44),
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 14 : 16,
                                vertical: compact ? 10 : 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(compact ? 14 : 14),
                              ),
                            ),
                            onPressed: widget.busy || (full && !joined) ? null : widget.onOpen,
                            icon: Icon(
                              joined
                                  ? Icons.chat_bubble_rounded
                                  : isPrivate
                                      ? Icons.lock_open_rounded
                                      : Icons.flash_on_rounded,
                              size: compact ? 18 : 18,
                            ),
                            label: Text(
                              widget.busy
                                  ? '연결 중…'
                                  : joined
                                      ? '채팅 바로가기'
                                      : full
                                          ? '모집 완료'
                                          : '지금 참가하기',
                              style: TextStyle(
                                fontSize: compact ? 14 : null,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
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
      },
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;
  final Color color;
  final bool compact;

  const _MiniBadge({required this.text, required this.color, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 8,
        vertical: compact ? 5 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(compact ? 9 : 9),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: compact ? 10.5 : 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PlatformSelectCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final int gameCount;
  final bool selected;
  final VoidCallback onTap;

  const _PlatformSelectCard({
    required this.label,
    required this.icon,
    required this.gameCount,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = label == 'PC 게임' ? mint : warning;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: [accent.withAlpha(34), purple.withAlpha(18)])
              : null,
          color: selected ? null : panelSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? accent.withAlpha(170) : line, width: selected ? 1.6 : 1),
          boxShadow: selected ? [BoxShadow(color: accent.withAlpha(28), blurRadius: 18, offset: const Offset(0, 7))] : null,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withAlpha(selected ? 36 : 18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: selected ? accent : muted, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: TextStyle(color: selected ? Colors.white : const Color(0xFFD5D8E2), fontSize: 12, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('$gameCount개 게임', style: const TextStyle(color: muted, fontSize: 9.5)),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: selected
                  ? Icon(Icons.check_circle_rounded, key: const ValueKey('on'), color: accent, size: 20)
                  : const Icon(Icons.chevron_right_rounded, key: ValueKey('off'), color: muted, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateGameTile extends StatefulWidget {
  final String game;
  final bool selected;
  final VoidCallback onTap;

  const _CreateGameTile({required this.game, required this.selected, required this.onTap});

  @override
  State<_CreateGameTile> createState() => _CreateGameTileState();
}

class _CreateGameTileState extends State<_CreateGameTile> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = gameAccent(widget.game);
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutBack,
        scale: hover ? 1.025 : 1,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(19),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: panelSoft,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: widget.selected ? accent : hover ? accent.withAlpha(130) : line,
                width: widget.selected ? 2 : 1,
              ),
              boxShadow: widget.selected || hover
                  ? [BoxShadow(color: accent.withAlpha(widget.selected ? 52 : 34), blurRadius: 22, offset: const Offset(0, 8))]
                  : [const BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedScale(
                    scale: hover ? 1.06 : 1,
                    duration: const Duration(milliseconds: 320),
                    child: _GameArtwork(game: widget.game),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withAlpha(8), Colors.black.withAlpha(70), Colors.black.withAlpha(230)],
                        stops: const [0, .45, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 9,
                    top: 9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(145),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: accent.withAlpha(100)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(gamePlatform(widget.game) == 'PC' ? Icons.computer_rounded : Icons.phone_android_rounded, color: accent, size: 11),
                          const SizedBox(width: 4),
                          Text(gamePlatform(widget.game), style: TextStyle(color: accent, fontSize: 8.5, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
                  if (widget.selected)
                    Positioned(
                      right: 9,
                      top: 9,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: [BoxShadow(color: accent.withAlpha(90), blurRadius: 12)],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 11, color: bg),
                            SizedBox(width: 3),
                            Text('선택됨', style: TextStyle(color: bg, fontSize: 8.5, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    left: 11,
                    right: 10,
                    bottom: 10,
                    child: Text(
                      gameDisplayName(widget.game),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black87, blurRadius: 5)]),
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
}

class CreateTeamPage extends StatefulWidget {
  final VoidCallback onCreated;

  const CreateTeamPage({super.key, required this.onCreated});

  @override
  State<CreateTeamPage> createState() => _CreateTeamPageState();
}

class _CreateTeamPageState extends State<CreateTeamPage> {
  String platform = 'PC';
  String game = pcGames.first;
  late String mode = gameModes(game).first;
  String style = '편하게';
  bool mic = true;
  bool isPrivate = false;
  bool busy = false;
  int capacity = 5;
  final title = TextEditingController();
  final accessCode = TextEditingController();
  final gameQuery = TextEditingController();

  List<String> get visibleGames {
    final source = platform == 'PC' ? pcGames : mobileGames;
    final q = gameQuery.text.trim().toLowerCase();
    if (q.isEmpty) return source;
    return source.where((g) => gameDisplayName(g).toLowerCase().contains(q) || g.toLowerCase().contains(q)).toList();
  }

  @override
  void dispose() {
    title.dispose();
    accessCode.dispose();
    gameQuery.dispose();
    super.dispose();
  }

  void selectGame(String value) {
    setState(() {
      game = value;
      mode = gameModes(value).first;
    });
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
            height: 158,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: gameAccent(game).withAlpha(120)),
              boxShadow: [BoxShadow(color: gameAccent(game).withAlpha(34), blurRadius: 26, offset: const Offset(0, 12))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _GameArtwork(game: game),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withAlpha(20), Colors.black.withAlpha(80), panel.withAlpha(245)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    top: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(125),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: warning.withAlpha(120)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.workspace_premium_rounded, color: warning, size: 15),
                          SizedBox(width: 6),
                          Text('HOST MODE', style: TextStyle(color: warning, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _MiniBadge(text: gamePlatform(game), color: gamePlatform(game) == 'PC' ? mint : warning),
                            const SizedBox(width: 7),
                            Expanded(child: Text(gameDisplayName(game), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('내가 방장이 되어 멤버 관리 · 임시/영구 추방 · 파티 삭제 권한을 가집니다.', style: TextStyle(color: Color(0xFFD2D6E0), height: 1.4, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _FormSection(
            title: '게임 선택',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _PlatformSelectCard(
                        label: 'PC 게임',
                        icon: Icons.computer_rounded,
                        gameCount: pcGames.length,
                        selected: platform == 'PC',
                        onTap: () {
                          setState(() {
                            platform = 'PC';
                            if (!pcGames.contains(game)) {
                              game = pcGames.first;
                              mode = gameModes(game).first;
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _PlatformSelectCard(
                        label: '모바일 게임',
                        icon: Icons.phone_android_rounded,
                        gameCount: mobileGames.length,
                        selected: platform == '모바일',
                        onTap: () {
                          setState(() {
                            platform = '모바일';
                            if (!mobileGames.contains(game)) {
                              game = mobileGames.first;
                              mode = gameModes(game).first;
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: gameQuery,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: '게임 검색',
                    hintText: '롤, 발로란트, 브롤스타즈…',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                if (visibleGames.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('검색 결과가 없습니다.', textAlign: TextAlign.center, style: TextStyle(color: muted)),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 210,
                      childAspectRatio: 1.82,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: visibleGames.length,
                    itemBuilder: (context, index) {
                      final item = visibleGames[index];
                      return _CreateGameTile(
                        game: item,
                        selected: game == item,
                        onTap: () => selectGame(item),
                      );
                    },
                  ),
                const SizedBox(height: 8),
                const Text(
                  '게임 정보 및 커버 이미지 제공: RAWG',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: muted, fontSize: 10.5),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey('mode-$game'),
                  initialValue: mode,
                  decoration: const InputDecoration(labelText: '모드'),
                  items: gameModes(game).map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
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
                    Expanded(child: Text('$capacity 명', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
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
                      .map((s) => ChoiceChip(
                            label: Text(s),
                            selected: style == s,
                            selectedColor: purple.withAlpha(55),
                            side: BorderSide(color: style == s ? purple : line),
                            onSelected: (_) => setState(() => style = s),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('마이크 사용', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('음성 대화를 원하는 파티인지 멤버들이 미리 알 수 있어요.', style: TextStyle(color: muted, fontSize: 11)),
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
                      if (v && accessCode.text.isEmpty) accessCode.text = (1000 + math.Random().nextInt(9000)).toString();
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
                                  decoration: const InputDecoration(labelText: '입장 코드', hintText: '1234', counterText: '', prefixIcon: Icon(Icons.password_rounded)),
                                ),
                              ),
                              const SizedBox(width: 9),
                              IconButton.filledTonal(
                                tooltip: '랜덤 코드 만들기',
                                onPressed: () => setState(() => accessCode.text = (1000 + math.Random().nextInt(9000)).toString()),
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
              decoration: const InputDecoration(hintText: '예) 즐겜 위주! 매너 좋으신 분 같이 해요 🙌', counterText: ''),
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
  bool gamesLoading = true;
  List<Map<String, dynamic>> gameProfiles = [];

  @override
  void initState() {
    super.initState();
    nickname = TextEditingController(text: Api.user['nickname'] as String? ?? '');
    loadGameProfiles();
  }

  @override
  void dispose() {
    nickname.dispose();
    super.dispose();
  }

  Future<void> loadGameProfiles() async {
    try {
      final rows = await Api.request('GET', '/community/me/games');
      if (!mounted) return;
      setState(() {
        gameProfiles = (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        gamesLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => gamesLoading = false);
        notice(context, e);
      }
    }
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

  Future<void> editGameProfile([Map<String, dynamic>? existing]) async {
    String selectedGame = existing?['game'] as String? ?? allGames.first;
    final tier = TextEditingController(text: existing?['tier']?.toString() ?? '');
    final level = TextEditingController(text: existing?['level']?.toString() ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          backgroundColor: panelSoft,
          title: Text(existing == null ? '게임 정보 추가' : '게임 정보 수정'),
          content: SizedBox(
            width: 470,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedGame,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '게임'),
                  items: allGames.map((g) => DropdownMenuItem(value: g, child: Text('${gameDisplayName(g)} · ${gamePlatform(g)}'))).toList(),
                  onChanged: existing == null ? (v) => setLocal(() => selectedGame = v ?? selectedGame) : null,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tier,
                  maxLength: 60,
                  decoration: InputDecoration(labelText: '티어 / 랭크', hintText: tierHint(selectedGame), counterText: ''),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: level,
                  maxLength: 60,
                  decoration: const InputDecoration(labelText: '레벨 / 전투력 / 트로피 등', hintText: '예) Lv. 245 / 35,000 트로피', counterText: ''),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            FilledButton(
              onPressed: () {
                if (tier.text.trim().isEmpty && level.text.trim().isEmpty) {
                  notice(context, '티어 또는 레벨 중 하나는 입력해주세요.');
                  return;
                }
                Navigator.pop(context, {
                  'game': selectedGame,
                  'tier': tier.text.trim(),
                  'level': level.text.trim(),
                });
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    tier.dispose();
    level.dispose();
    if (result == null) return;
    try {
      await Api.request('POST', '/community/me/games', result);
      if (!mounted) return;
      successNotice(context, '게임 정보 저장', '${gameDisplayName(result['game']!)} 정보를 저장했습니다.');
      await loadGameProfiles();
    } catch (e) {
      if (mounted) notice(context, e);
    }
  }

  Future<void> removeGameProfile(Map<String, dynamic> profile) async {
    final ok = await askConfirm(
      context,
      title: '게임 정보를 삭제할까요?',
      message: '${gameDisplayName('${profile['game']}')}의 티어/레벨 정보가 프로필에서 사라집니다.',
      action: '삭제',
      destructive: true,
    );
    if (!ok) return;
    try {
      final game = Uri.encodeQueryComponent('${profile['game']}');
      await Api.request('DELETE', '/community/me/games?game=$game');
      await loadGameProfiles();
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
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [purple, mint])),
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
            title: '게임 티어 · 레벨',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('파티원 목록과 플레이어 프로필에 표시됩니다.', style: TextStyle(color: muted, fontSize: 11)),
                const SizedBox(height: 12),
                if (gamesLoading)
                  const Center(child: CircularProgressIndicator(color: mint))
                else if (gameProfiles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('등록한 게임 정보가 없습니다. 자주 하는 게임부터 추가해보세요.', style: TextStyle(color: muted)),
                  )
                else
                  ...gameProfiles.map((profile) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: panelSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
                        child: Row(children: [
                          Icon(gamePlatform('${profile['game']}') == '모바일' ? Icons.phone_android_rounded : Icons.sports_esports_rounded, color: gameAccent('${profile['game']}')),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(gameDisplayName('${profile['game']}'), style: const TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 3),
                            Text(
                              [if (profile['tier'] != null && '${profile['tier']}'.isNotEmpty) '${profile['tier']}', if (profile['level'] != null && '${profile['level']}'.isNotEmpty) '${profile['level']}'].join(' · '),
                              style: const TextStyle(color: mint, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ])),
                          IconButton(onPressed: () => editGameProfile(profile), icon: const Icon(Icons.edit_outlined, size: 19)),
                          IconButton(onPressed: () => removeGameProfile(profile), icon: const Icon(Icons.delete_outline_rounded, color: danger, size: 19)),
                        ]),
                      )),
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: () => editGameProfile(), icon: const Icon(Icons.add_rounded, color: mint), label: const Text('게임 정보 추가')),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _FormSection(
            title: '프로필 편집',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(controller: nickname, maxLength: 30, decoration: const InputDecoration(labelText: '닉네임', counterText: '')),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => save(photo: true),
                  icon: const Icon(Icons.add_a_photo_outlined, color: mint),
                  label: const Text('프로필 사진 선택'),
                ),
                if (Api.user['avatar'] != null)
                  TextButton(onPressed: busy ? null : () => save(remove: true), child: const Text('사진 제거', style: TextStyle(color: danger))),
                const SizedBox(height: 8),
                FilledButton(onPressed: busy ? null : save, child: Text(busy ? '저장 중…' : '프로필 저장')),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlowCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('계정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('사진·닉네임·게임 티어는 파티 멤버와 채팅에 표시됩니다.', style: TextStyle(color: muted, height: 1.5, fontSize: 12)),
              const SizedBox(height: 16),
              OutlinedButton.icon(onPressed: logout, icon: const Icon(Icons.logout_rounded), label: const Text('로그아웃')),
            ]),
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
        final kind = raw['duration'] == 'permanent' ? '영구 추방' : '5분 임시 추방';
        exitChat('방장에 의해 파티에서 제외되었습니다. ($kind)');
      }
    });
    socket.on('moderation:update', (dynamic raw) {
      if (!mounted || raw is! Map || raw['type'] != 'suspended') return;
      closing = true;
      Api.logout();
      notice(context, '관리자에 의해 이용 정지가 적용되었습니다. 사유: ${raw['reason'] ?? '운영 정책 위반'}', warningNotice: true, title: '계정 이용 정지');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthPage()),
          (_) => false,
        );
      });
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
        more = rows.length == 40;
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
      setState(() => more = list.length == 40);
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

  Future<void> leaveParty() async {
    if (isOwner) {
      notice(
        context,
        '방장은 파티를 바로 나갈 수 없습니다. 파티 삭제를 이용해주세요.',
        warningNotice: true,
        title: '파티 나가기',
      );
      return;
    }

    final ok = await askConfirm(
      context,
      title: '파티에서 나갈까요?',
      message: '파티에서 나가면 멤버 목록과 채팅방에서 제외됩니다. 다시 이용하려면 파티에 다시 참가해야 합니다.',
      action: '나가기',
      destructive: true,
    );

    if (!ok) return;

    try {
      await ack('team:leave', {'teamId': teamId});
      if (!mounted) return;
      exitChat('파티에서 나갔습니다.');
    } catch (e) {
      if (mounted && !closing) notice(context, e);
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
          if (widget.team['mic'] == true)
            IconButton(
              tooltip: '음성 채팅',
              onPressed: ready
                  ? () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => VoiceRoomSheet(
                          teamId: teamId,
                          socket: socket,
                          ack: ack,
                        ),
                      )
                  : null,
              icon: const Icon(Icons.mic_rounded, color: mint),
            ),
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
              if (value == 'leave') leaveParty();
              if (value == 'delete') deleteParty();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded),
                    SizedBox(width: 10),
                    Text('새로고침'),
                  ],
                ),
              ),
              if (!isOwner)
                const PopupMenuItem(
                  value: 'leave',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, color: danger),
                      SizedBox(width: 10),
                      Text(
                        '파티 나가기',
                        style: TextStyle(
                          color: danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              if (isOwner)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever_rounded, color: danger),
                      SizedBox(width: 10),
                      Text(
                        '파티 삭제',
                        style: TextStyle(
                          color: danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
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
                const ActiveAnnouncementBanner(compact: true),
                const UserNotificationBanner(compact: true),
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
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          minLines: 1,
                          maxLines: 5,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                            hintText: '메시지를 입력하세요… (Enter 줄바꿈)',
                            counterText: '',
                            fillColor: panelSoft,
                          ),
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
    if (message['kind'] == 'system') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: panelSoft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: mint.withAlpha(55)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: mint),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${message['body']}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFC9CEDA), fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
                if (stamp.isNotEmpty) ...[
                  const SizedBox(width: 7),
                  Text(stamp, style: const TextStyle(color: muted, fontSize: 9)),
                ],
              ],
            ),
          ),
        ),
      );
    }

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


class VoiceRoomSheet extends StatefulWidget {
  final int teamId;
  final io.Socket socket;
  final Future<dynamic> Function(String event, dynamic data) ack;

  const VoiceRoomSheet({
    super.key,
    required this.teamId,
    required this.socket,
    required this.ack,
  });

  @override
  State<VoiceRoomSheet> createState() => _VoiceRoomSheetState();
}

class _VoiceRoomSheetState extends State<VoiceRoomSheet> {
  MediaStream? localStream;
  final Map<String, RTCPeerConnection> peers = {};
  final Map<String, MediaStream> remoteStreams = {};
  bool loading = true;
  bool mutedMic = false;
  bool leaving = false;
  String status = '마이크 연결 중…';

  int get participantCount => peers.length + 1;

  @override
  void initState() {
    super.initState();
    widget.socket.on('voice:peer_joined', _onPeerJoined);
    widget.socket.on('voice:peer_left', _onPeerLeft);
    widget.socket.on('voice:offer', _onOffer);
    widget.socket.on('voice:answer', _onAnswer);
    widget.socket.on('voice:ice', _onIce);
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      final raw = await widget.ack('voice:join', {'teamId': widget.teamId});
      final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final rows = data['peers'] is List ? data['peers'] as List : const [];
      for (final item in rows) {
        if (item is! Map) continue;
        final peerId = '${item['socketId'] ?? ''}';
        if (peerId.isNotEmpty) await _offerTo(peerId);
      }
      if (!mounted) return;
      setState(() {
        loading = false;
        status = '음성 채팅 연결됨';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        status = _cleanError(e);
      });
    }
  }

  String _cleanError(Object e) {
    final text = e.toString().replaceFirst('Exception: ', '');
    if (text.toLowerCase().contains('permission')) {
      return '마이크 권한이 필요합니다. 기기 설정에서 PyGa 마이크 권한을 허용해주세요.';
    }
    return text;
  }

  Future<RTCPeerConnection> _ensurePeer(String peerId) async {
    final existing = peers[peerId];
    if (existing != null) return existing;

    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    });
    final stream = localStream;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        await pc.addTrack(track, stream);
      }
    }
    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      widget.socket.emitWithAck(
        'voice:ice',
        {
          'teamId': widget.teamId,
          'target': peerId,
          'candidate': candidate.toMap(),
        },
        ack: (_) {},
      );
    };
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteStreams[peerId] = event.streams.first;
      }
      if (mounted) setState(() {});
    };
    pc.onConnectionState = (state) {
      if (!mounted) return;
      setState(() {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          status = '일부 음성 연결에 실패했습니다. 다시 입장해보세요.';
        }
      });
    };
    peers[peerId] = pc;
    if (mounted) setState(() {});
    return pc;
  }

  Future<void> _offerTo(String peerId) async {
    try {
      final pc = await _ensurePeer(peerId);
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      await widget.ack('voice:offer', {
        'teamId': widget.teamId,
        'target': peerId,
        'sdp': {'sdp': offer.sdp, 'type': offer.type},
      });
    } catch (_) {}
  }

  void _onPeerJoined(dynamic raw) {
    if (!mounted || raw is! Map || raw['teamId'] != widget.teamId) return;
    // 새로 들어온 사용자가 기존 사용자들에게 offer를 보냅니다.
    setState(() {});
  }

  void _onPeerLeft(dynamic raw) {
    if (raw is! Map || raw['teamId'] != widget.teamId) return;
    final peerId = '${raw['socketId'] ?? ''}';
    final pc = peers.remove(peerId);
    remoteStreams.remove(peerId);
    unawaited(pc?.close() ?? Future<void>.value());
    if (mounted) setState(() {});
  }

  void _onOffer(dynamic raw) {
    if (raw is! Map || raw['teamId'] != widget.teamId) return;
    unawaited(_answerOffer(Map<String, dynamic>.from(raw)));
  }

  Future<void> _answerOffer(Map<String, dynamic> raw) async {
    try {
      final from = '${raw['from'] ?? ''}';
      final sdp = raw['sdp'];
      if (from.isEmpty || sdp is! Map) return;
      final pc = await _ensurePeer(from);
      await pc.setRemoteDescription(RTCSessionDescription('${sdp['sdp'] ?? ''}', '${sdp['type'] ?? 'offer'}'));
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      await widget.ack('voice:answer', {
        'teamId': widget.teamId,
        'target': from,
        'sdp': {'sdp': answer.sdp, 'type': answer.type},
      });
    } catch (_) {}
  }

  void _onAnswer(dynamic raw) {
    if (raw is! Map || raw['teamId'] != widget.teamId) return;
    unawaited(_applyAnswer(Map<String, dynamic>.from(raw)));
  }

  Future<void> _applyAnswer(Map<String, dynamic> raw) async {
    try {
      final from = '${raw['from'] ?? ''}';
      final sdp = raw['sdp'];
      if (from.isEmpty || sdp is! Map) return;
      final pc = peers[from];
      if (pc == null) return;
      await pc.setRemoteDescription(RTCSessionDescription('${sdp['sdp'] ?? ''}', '${sdp['type'] ?? 'answer'}'));
    } catch (_) {}
  }

  void _onIce(dynamic raw) {
    if (raw is! Map || raw['teamId'] != widget.teamId) return;
    unawaited(_applyIce(Map<String, dynamic>.from(raw)));
  }

  Future<void> _applyIce(Map<String, dynamic> raw) async {
    try {
      final from = '${raw['from'] ?? ''}';
      final candidate = raw['candidate'];
      if (from.isEmpty || candidate is! Map) return;
      final pc = await _ensurePeer(from);
      final line = candidate['sdpMLineIndex'];
      await pc.addCandidate(RTCIceCandidate(
        candidate['candidate']?.toString(),
        candidate['sdpMid']?.toString(),
        line is num ? line.toInt() : int.tryParse('$line'),
      ));
    } catch (_) {}
  }

  void _toggleMute() {
    final stream = localStream;
    if (stream == null) return;
    final next = !mutedMic;
    for (final track in stream.getAudioTracks()) {
      track.enabled = !next;
    }
    setState(() => mutedMic = next);
  }

  Future<void> _leave({bool pop = true}) async {
    if (leaving) return;
    leaving = true;
    try {
      widget.socket.emitWithAck(
        'voice:leave',
        {'teamId': widget.teamId},
        ack: (_) {},
      );
      for (final pc in peers.values) {
        await pc.close();
      }
      peers.clear();
      remoteStreams.clear();
      final stream = localStream;
      if (stream != null) {
        for (final track in stream.getTracks()) {
          track.stop();
        }
        await stream.dispose();
      }
      localStream = null;
    } catch (_) {}
    if (pop && mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    widget.socket.off('voice:peer_joined', _onPeerJoined);
    widget.socket.off('voice:peer_left', _onPeerLeft);
    widget.socket.off('voice:offer', _onOffer);
    widget.socket.off('voice:answer', _onAnswer);
    widget.socket.off('voice:ice', _onIce);
    if (!leaving) unawaited(_leave(pop: false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewPaddingOf(context).bottom + 22),
        decoration: const BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: line)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 38, height: 4, decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(8))),
              const SizedBox(height: 20),
              const Icon(Icons.graphic_eq_rounded, color: mint, size: 38),
              const SizedBox(height: 10),
              const Text('파티 음성 채팅', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                loading ? '연결 준비 중…' : '$participantCount명 연결 · $status',
                textAlign: TextAlign.center,
                style: TextStyle(color: status == '음성 채팅 연결됨' ? mint : muted, fontSize: 12, height: 1.45),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: loading || localStream == null ? null : _toggleMute,
                      style: FilledButton.styleFrom(
                        backgroundColor: mutedMic ? panelSoft : mint,
                        foregroundColor: mutedMic ? Colors.white : bg,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      icon: Icon(mutedMic ? Icons.mic_off_rounded : Icons.mic_rounded),
                      label: Text(mutedMic ? '마이크 켜기' : '마이크 끄기'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _leave(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: danger,
                        side: const BorderSide(color: danger),
                        minimumSize: const Size.fromHeight(52),
                      ),
                      icon: const Icon(Icons.call_end_rounded),
                      label: const Text('나가기'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '베타 음성 기능 · 네트워크 환경에 따라 연결 품질이 달라질 수 있습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 10),
              ),
            ],
          ),
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

  Future<void> openProfile(Map<String, dynamic> member) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlayerProfileSheet(userId: member['id'] as int, teamId: widget.teamId),
    );
  }

  Future<String?> chooseKickType(Map<String, dynamic> member) {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: panelSoft,
        title: Text('${member['nickname']}님 추방'),
        content: const Text(
          '임시 추방은 5분 동안 다시 들어올 수 없고, 영구 추방은 이 파티에 다시 참가할 수 없습니다.',
          style: TextStyle(color: muted, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, '5m'),
            child: const Text('5분 임시 추방'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: danger),
            onPressed: () => Navigator.pop(context, 'permanent'),
            child: const Text('영구 추방'),
          ),
        ],
      ),
    );
  }

  Future<void> kick(Map<String, dynamic> member) async {
    final duration = await chooseKickType(member);
    if (duration == null) return;
    setState(() => kicking = member['id'] as int);
    try {
      await widget.ack('team:kick', {
        'teamId': widget.teamId,
        'memberId': member['id'],
        'duration': duration,
      });
      if (!mounted) return;
      successNotice(
        context,
        '파티원 추방 완료',
        duration == 'permanent'
            ? '${member['nickname']}님을 이 파티에서 영구 추방했습니다.'
            : '${member['nickname']}님을 5분 동안 임시 추방했습니다.',
      );
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
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .82),
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
              child: Row(children: [
                const Icon(Icons.groups_2_rounded, color: mint),
                const SizedBox(width: 10),
                Text('파티원 ${members.length}명', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const Spacer(),
                IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded)),
              ]),
            ),
            if (widget.owner)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 18),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: purple.withAlpha(20), borderRadius: BorderRadius.circular(14), border: Border.all(color: purple.withAlpha(60))),
                child: const Row(children: [
                  Icon(Icons.workspace_premium_rounded, color: warning, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('방장은 파티원을 5분 임시 추방하거나 영구 추방할 수 있습니다.', style: TextStyle(color: muted, fontSize: 11))),
                ]),
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
                        final detail = [
                          if (member['tier'] != null && '${member['tier']}'.isNotEmpty) '${member['tier']}',
                          if (member['level'] != null && '${member['level']}'.isNotEmpty) '${member['level']}',
                        ].join(' · ');
                        return InkWell(
                          onTap: () => openProfile(member),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                            child: Row(children: [
                              Avatar(member['avatar'], radius: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Flexible(child: Text('${member['nickname']}', style: const TextStyle(fontWeight: FontWeight.w800))),
                                    if (me) ...[const SizedBox(width: 6), const _MiniBadge(text: '나', color: mint)],
                                    if (owner) ...[const SizedBox(width: 6), const Icon(Icons.workspace_premium_rounded, color: warning, size: 17)],
                                  ]),
                                  const SizedBox(height: 4),
                                  Text(
                                    detail.isEmpty ? (owner ? '방장 · 프로필 보기' : '파티원 · 프로필 보기') : '$detail · 프로필 보기',
                                    style: TextStyle(color: detail.isEmpty ? muted : mint, fontSize: 11, fontWeight: detail.isEmpty ? FontWeight.normal : FontWeight.w700),
                                  ),
                                ]),
                              ),
                              if (widget.owner && !owner)
                                TextButton(
                                  onPressed: kicking == null ? () => kick(member) : null,
                                  child: Text(kicking == member['id'] ? '처리 중…' : '추방', style: const TextStyle(color: danger, fontWeight: FontWeight.w800)),
                                )
                              else
                                const Icon(Icons.chevron_right_rounded, color: muted),
                            ]),
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

class PlayerProfileSheet extends StatefulWidget {
  final int userId;
  final int teamId;
  const PlayerProfileSheet({super.key, required this.userId, required this.teamId});

  @override
  State<PlayerProfileSheet> createState() => _PlayerProfileSheetState();
}

class _PlayerProfileSheetState extends State<PlayerProfileSheet> {
  Map<String, dynamic>? profile;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final raw = await Api.request('GET', '/community/players/${widget.userId}');
      if (!mounted) return;
      setState(() {
        profile = Map<String, dynamic>.from(raw as Map);
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        notice(context, e);
      }
    }
  }

  Future<void> report() async {
    if (profile?['isMe'] == true) return;
    String category = '욕설/비속어';
    final details = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          backgroundColor: panelSoft,
          title: Text('${profile?['nickname'] ?? '플레이어'} 신고'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: '신고 유형'),
                  items: const [
                    DropdownMenuItem(value: '욕설/비속어', child: Text('욕설/비속어')),
                    DropdownMenuItem(value: '괴롭힘/비매너', child: Text('괴롭힘/비매너')),
                    DropdownMenuItem(value: '스팸/도배', child: Text('스팸/도배')),
                    DropdownMenuItem(value: '부적절한 닉네임', child: Text('부적절한 닉네임')),
                    DropdownMenuItem(value: '기타', child: Text('기타')),
                  ],
                  onChanged: (v) => setLocal(() => category = v ?? category),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: details,
                  minLines: 4,
                  maxLines: 7,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: '신고 내용',
                    hintText: '어떤 말을 했는지, 어떤 상황이었는지 적어주세요. 관리자만 확인합니다.',
                    counterText: '',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: danger),
              onPressed: () {
                if (details.text.trim().length < 2) {
                  notice(context, '신고 내용을 입력해주세요.');
                  return;
                }
                Navigator.pop(context, {'category': category, 'details': details.text.trim()});
              },
              child: const Text('관리자에게 신고'),
            ),
          ],
        ),
      ),
    );
    details.dispose();
    if (result == null) return;
    try {
      await Api.request('POST', '/community/reports', {
        'reportedUserId': widget.userId,
        'teamId': widget.teamId,
        ...result,
      });
      if (!mounted) return;
      successNotice(context, '신고 접수 완료', '관리자에게 신고 내용이 전달되었습니다. 처리 결과는 운영 기록에 남습니다.');
    } catch (e) {
      if (mounted) notice(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = (profile?['gameProfiles'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
      decoration: const BoxDecoration(
        color: Color(0xFF10121A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: line)),
      ),
      child: SafeArea(
        top: false,
        child: loading
            ? const Center(child: Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator(color: mint)))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(height: 22),
                  Center(child: Avatar(profile?['avatar'], radius: 44)),
                  const SizedBox(height: 12),
                  Text('${profile?['nickname'] ?? ''}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 18),
                  const Text('게임 티어 · 레벨', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 9),
                  if (profiles.isEmpty)
                    const GlowCard(child: Text('등록된 게임 정보가 없습니다.', style: TextStyle(color: muted)))
                  else
                    ...profiles.map((g) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: panelSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
                          child: Row(children: [
                            Icon(gamePlatform('${g['game']}') == '모바일' ? Icons.phone_android_rounded : Icons.sports_esports_rounded, color: gameAccent('${g['game']}')),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(gameDisplayName('${g['game']}'), style: const TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 3),
                              Text(
                                [if (g['tier'] != null && '${g['tier']}'.isNotEmpty) '${g['tier']}', if (g['level'] != null && '${g['level']}'.isNotEmpty) '${g['level']}'].join(' · '),
                                style: const TextStyle(color: mint, fontSize: 11),
                              ),
                            ])),
                          ]),
                        )),
                  if (profile?['isMe'] != true) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: report,
                      style: OutlinedButton.styleFrom(foregroundColor: danger, side: const BorderSide(color: danger)),
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('이 플레이어 신고하기'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

