import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:uuid/uuid.dart';
import 'services/api.dart';

const bg = Color(0xFF0B0B0F);
const panel = Color(0xFF14141F);
const purple = Color(0xFF9B49DF);
const mint = Color(0xFF00DFCE);
const muted = Color(0xFF9295A6);
const games = ['VALORANT', 'League of Legends', '배틀그라운드', 'FC Online'];
const modes = ['경쟁전', '일반전', '칼바람 나락', '자유 플레이'];

void notice(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
}

class PyGaApp extends StatelessWidget {
  const PyGaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PyGa', debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true, brightness: Brightness.dark, scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(primary: purple, secondary: mint, surface: panel),
      appBarTheme: const AppBarTheme(backgroundColor: bg, foregroundColor: Colors.white, centerTitle: false),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: panel,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF242433))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: purple)),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        backgroundColor: purple, foregroundColor: Colors.white, minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)))),
    ),
    home: const AuthPage(),
  );
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override State<AuthPage> createState() => _AuthPageState();
}
class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController(), password = TextEditingController();
  final nickname = TextEditingController(), confirm = TextEditingController();
  final form = GlobalKey<FormState>();
  bool register = false, busy = false, obscure = true;
  @override void dispose() { email.dispose(); password.dispose(); nickname.dispose(); confirm.dispose(); super.dispose(); }
  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      if (register) {
        await Api.request('POST', '/auth/register', {'nickname': nickname.text.trim(), 'email': email.text.trim(), 'password': password.text});
        if (!mounted) return;
        notice(context, '가입 완료! 로그인해주세요.');
        setState(() { register = false; password.clear(); confirm.clear(); });
      } else {
        await Api.login(email.text, password.text);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainPage()));
      }
    } catch (e) { if (mounted) notice(context, e); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: Form(key: form, child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.sports_esports_rounded, size: 64, color: mint),
        const SizedBox(height: 18),
        const Text('PyGa', textAlign: TextAlign.center, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
        const Text('함께할 팀원, 함께할 플레이', textAlign: TextAlign.center, style: TextStyle(color: muted)),
        const SizedBox(height: 36),
        Text(register ? '회원가입' : '다시 만나서 반가워요', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        if (register) ...[
          TextFormField(controller: nickname, decoration: const InputDecoration(labelText: '닉네임 (2~30자)'),
            validator: (v) => (v?.trim().length ?? 0) < 2 || v!.trim().length > 30 ? '닉네임은 2~30자로 입력해주세요.' : null),
          const SizedBox(height: 16),
        ],
        TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: '이메일'),
          validator: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v?.trim() ?? '') ? null : '이메일을 확인해주세요.'),
        const SizedBox(height: 16),
        TextFormField(controller: password, obscureText: obscure,
          decoration: InputDecoration(labelText: '비밀번호 (최소 8자)', suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => obscure = !obscure))),
          validator: (v) => (v?.length ?? 0) < 8 ? '비밀번호는 최소 8자입니다.' : null),
        if (register) ...[
          const SizedBox(height: 16),
          TextFormField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: '비밀번호 확인'),
            validator: (v) => v == password.text ? null : '비밀번호가 일치하지 않습니다.'),
        ],
        const SizedBox(height: 24),
        FilledButton(onPressed: busy ? null : submit, child: Text(busy ? '처리 중…' : register ? '가입하기' : '로그인')),
        TextButton(onPressed: busy ? null : () => setState(() { register = !register; form.currentState?.reset(); }),
          child: Text(register ? '이미 계정이 있나요? 로그인' : '처음이신가요? 회원가입', style: const TextStyle(color: mint))),
      ],
    ))),
  ))));
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override State<MainPage> createState() => _MainPageState();
}
class _MainPageState extends State<MainPage> {
  int tab = 0;
  @override Widget build(BuildContext context) {
    final pages = [
      const TeamsPage(), const TeamsPage(search: true),
      CreateTeamPage(onCreated: () => setState(() => tab = 3)),
      const TeamsPage(mine: true), const ProfilePage(),
    ];
    return Scaffold(
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 650),
        child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]))),
      bottomNavigationBar: NavigationBar(
        backgroundColor: panel, indicatorColor: mint.withAlpha(24), selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: mint), label: '홈'),
          NavigationDestination(icon: Icon(Icons.search), selectedIcon: Icon(Icons.search, color: mint), label: '찾기'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle, color: mint), label: '파티'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble, color: mint), label: '채팅'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: mint), label: '프로필'),
        ],
      ),
    );
  }
}

class TeamsPage extends StatefulWidget {
  final bool mine, search;
  const TeamsPage({super.key, this.mine = false, this.search = false});
  @override State<TeamsPage> createState() => _TeamsPageState();
}
class _TeamsPageState extends State<TeamsPage> {
  List<dynamic> teams = [];
  String? selected, error;
  bool loading = true;
  int? joining;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final result = await Api.request('GET', '/community/teams?mine=${widget.mine}');
      if (mounted) setState(() { teams = result as List; error = null; loading = false; });
    } catch (e) { if (mounted) setState(() { error = e.toString(); loading = false; }); }
  }
  Future<void> enter(Map<String, dynamic> team) async {
    if (joining != null) return;
    setState(() => joining = team['id'] as int);
    try {
      if (team['joined'] != true) await Api.request('POST', '/community/teams/${team['id']}/join', {});
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(team: team)));
      if (mounted) await load();
    } catch (e) { if (mounted) notice(context, e); }
    finally { if (mounted) setState(() => joining = null); }
  }
  @override Widget build(BuildContext context) {
    final visible = teams.where((t) => selected == null || t['game'] == selected).toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.mine ? '내 팀 채팅' : widget.search ? '같이 할 사람 찾기' : '안녕하세요, ${Api.user['nickname']}님 👋',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh, color: mint))]),
      body: RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(), children: [
          if (!widget.mine) ...[
            const Text('🎮 어떤 게임을 할까요?', style: TextStyle(color: muted, fontSize: 17)),
            const SizedBox(height: 20),
            GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.2, mainAxisSpacing: 10, crossAxisSpacing: 10,
              children: games.map((g) => InkWell(onTap: () => setState(() => selected = selected == g ? null : g),
                borderRadius: BorderRadius.circular(18),
                child: Container(decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: selected == g ? purple : const Color(0xFF242433), width: 2)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.sports_esports_outlined, color: selected == g ? purple : mint),
                    const SizedBox(height: 6), Text(g, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ])))).toList()),
            const SizedBox(height: 26),
            const Text('🔥 지금 같이 할 사람', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
          ] else const Text('가입한 팀의 대화만 표시됩니다.', style: TextStyle(color: muted)),
          const SizedBox(height: 18),
          if (loading) const Center(child: CircularProgressIndicator()),
          if (error != null) Text(error!, style: const TextStyle(color: Colors.orangeAccent)),
          if (!loading && error == null && visible.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 50), child: Text(
              widget.mine ? '아직 가입한 팀이 없어요.\n홈에서 참가하거나 파티 탭에서 만들어보세요.' : '아직 모집 중인 팀이 없어요.\n파티 탭에서 첫 팀을 만들어보세요.',
              textAlign: TextAlign.center, style: const TextStyle(color: muted, height: 1.7))),
          ...visible.map((raw) {
            final t = Map<String, dynamic>.from(raw);
            final full = (t['memberCount'] as int) >= (t['capacity'] as int);
            return Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF242433))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(spacing: 8, runSpacing: 8, children: [tag(t['game'], purple), tag(t['mode'], mint),
                  tag("${t['memberCount']}/${t['capacity']}명", mint)]),
                const SizedBox(height: 16),
                Text(t['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text("${t['ownerName']} · ${t['style']} · ${t['mic'] == true ? '마이크 사용' : '마이크 미사용'}",
                  style: const TextStyle(color: muted)),
                const SizedBox(height: 18),
                FilledButton(onPressed: joining != null || (full && t['joined'] != true) ? null : () => enter(t),
                  child: Text(joining == t['id'] ? '연결 중…' : t['joined'] == true ? '채팅 열기' : full ? '모집 완료' : '참가하고 채팅하기')),
              ]));
          }),
        ])),
    );
  }
}
Widget tag(String text, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  decoration: BoxDecoration(color: color.withAlpha(22), borderRadius: BorderRadius.circular(8)),
  child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)));

class CreateTeamPage extends StatefulWidget {
  final VoidCallback onCreated;
  const CreateTeamPage({super.key, required this.onCreated});
  @override State<CreateTeamPage> createState() => _CreateTeamPageState();
}
class _CreateTeamPageState extends State<CreateTeamPage> {
  String game = games.first, mode = modes.first, style = '편하게';
  bool mic = true, busy = false;
  int capacity = 5;
  final title = TextEditingController();
  @override void dispose() { title.dispose(); super.dispose(); }
  Future<void> create() async {
    if (title.text.trim().isEmpty) { notice(context, '파티 소개를 입력해주세요.'); return; }
    setState(() => busy = true);
    try {
      await Api.request('POST', '/community/teams', {'game': game, 'mode': mode, 'style': style,
        'mic': mic, 'capacity': capacity, 'title': title.text.trim()});
      if (!mounted) return;
      notice(context, '파티가 만들어졌어요. 다른 계정에서 홈을 새로고침하고 참가해보세요.');
      widget.onCreated();
    } catch (e) { if (mounted) notice(context, e); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('파티 만들기')),
    body: ListView(padding: const EdgeInsets.all(22), children: [
      const Text('게임', style: TextStyle(color: muted)), const SizedBox(height: 10),
      DropdownButtonFormField<String>(initialValue: game, items: games.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
        onChanged: (v) => setState(() => game = v!)),
      const SizedBox(height: 20), const Text('모드', style: TextStyle(color: muted)), const SizedBox(height: 10),
      DropdownButtonFormField<String>(initialValue: mode, items: modes.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
        onChanged: (v) => setState(() => mode = v!)),
      const SizedBox(height: 20), const Text('총 인원 (본인 포함)', style: TextStyle(color: muted)),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(onPressed: capacity > 2 ? () => setState(() => capacity--) : null, icon: const Icon(Icons.remove_circle_outline)),
        Text('$capacity 명', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        IconButton(onPressed: capacity < 20 ? () => setState(() => capacity++) : null, icon: const Icon(Icons.add_circle_outline, color: mint)),
      ]),
      const SizedBox(height: 16), const Text('플레이 스타일', style: TextStyle(color: muted)), const SizedBox(height: 10),
      Wrap(spacing: 8, children: ['빡겜', '편하게', '상관없음'].map((s) => ChoiceChip(label: Text(s), selected: style == s,
        onSelected: (_) => setState(() => style = s), selectedColor: mint.withAlpha(45))).toList()),
      const SizedBox(height: 16),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('마이크 사용'), value: mic, onChanged: (v) => setState(() => mic = v)),
      const SizedBox(height: 16),
      TextField(controller: title, maxLength: 80, maxLines: 3, decoration: const InputDecoration(labelText: '파티 소개 메모', hintText: '같이 즐겁게 해요!')),
      const SizedBox(height: 20),
      const Text('공개 모집 팀입니다. 다른 회원이 홈에서 참가할 수 있어요.', style: TextStyle(color: muted)),
      const SizedBox(height: 14),
      FilledButton(onPressed: busy ? null : create, child: Text(busy ? '만드는 중…' : '모집 시작')),
    ]));
}

class Avatar extends StatelessWidget {
  final dynamic photo;
  final double radius;
  const Avatar(this.photo, {super.key, this.radius = 20});
  @override Widget build(BuildContext context) {
    ImageProvider? image;
    try { if (photo is String && (photo as String).startsWith('data:image/')) image = MemoryImage(base64Decode((photo as String).split(',')[1])); }
    catch (_) { image = null; }
    return CircleAvatar(radius: radius, backgroundColor: const Color(0xFF252537), backgroundImage: image,
      child: image == null ? Icon(Icons.person, color: mint, size: radius) : null);
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override State<ProfilePage> createState() => _ProfilePageState();
}
class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController nickname;
  bool busy = false;
  @override void initState() { super.initState(); nickname = TextEditingController(text: Api.user['nickname'] as String? ?? ''); }
  @override void dispose() { nickname.dispose(); super.dispose(); }
  Future<void> save({bool photo = false, bool remove = false}) async {
    if (busy) return;
    if (nickname.text.trim().length < 2 || nickname.text.trim().length > 30) { notice(context, '닉네임은 2~30자로 입력해주세요.'); return; }
    setState(() => busy = true);
    try {
      final body = <String, dynamic>{'nickname': nickname.text.trim()};
      if (remove) body['avatar'] = null;
      if (photo) {
        final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        if (bytes.length > 2 * 1024 * 1024) throw Exception('2MB 이하 사진을 선택해주세요.');
        final mime = bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50 ? 'png' :
          bytes.length > 3 && bytes[0] == 0xff && bytes[1] == 0xd8 ? 'jpeg' :
          bytes.length > 12 && ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP' ? 'webp' : null;
        if (mime == null) throw Exception('PNG, JPEG, WebP 사진을 선택해주세요.');
        body['avatar'] = 'data:image/$mime;base64,${base64Encode(bytes)}';
      }
      final user = await Api.request('PATCH', '/community/me', body);
      Api.user = Map<String, dynamic>.from(user);
      if (mounted) { setState(() {}); notice(context, '프로필을 저장했어요.'); }
    } catch (e) { if (mounted) notice(context, e); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('내 프로필')),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      const SizedBox(height: 20),
      Center(child: Container(padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: mint, width: 2)),
        child: Avatar(Api.user['avatar'], radius: 48))),
      const SizedBox(height: 16),
      Text(Api.user['nickname'] ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(Api.user['email'] ?? '', textAlign: TextAlign.center, style: const TextStyle(color: muted)),
      const SizedBox(height: 20),
      OutlinedButton.icon(onPressed: busy ? null : () => save(photo: true), icon: const Icon(Icons.add_a_photo_outlined, color: mint), label: const Text('프로필 사진 선택')),
      if (Api.user['avatar'] != null) TextButton(onPressed: busy ? null : () => save(remove: true), child: const Text('사진 제거')),
      const SizedBox(height: 24),
      TextField(controller: nickname, maxLength: 30, decoration: const InputDecoration(labelText: '닉네임')),
      const SizedBox(height: 16),
      FilledButton(onPressed: busy ? null : save, child: Text(busy ? '저장 중…' : '프로필 저장')),
      const SizedBox(height: 24),
      const Text('사진과 닉네임은 같은 팀 채팅에서 표시돼요.\n이메일은 내 프로필에만 표시됩니다.', style: TextStyle(color: muted, height: 1.7)),
      const SizedBox(height: 24),
      OutlinedButton(onPressed: () {
        Api.logout();
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthPage()), (_) => false);
      }, child: const Text('로그아웃')),
    ]),
  );
}

class ChatPage extends StatefulWidget {
  final Map<String, dynamic> team;
  const ChatPage({super.key, required this.team});
  @override State<ChatPage> createState() => _ChatPageState();
}
class _ChatPageState extends State<ChatPage> {
  late final io.Socket socket;
  final draft = TextEditingController(), scroll = ScrollController();
  List<Map<String, dynamic>> messages = [];
  Map<String, dynamic>? pending;
  String status = '연결 중…';
  bool ready = false, sending = false, loading = true, more = true, olderBusy = false;
  int generation = 0;
  int get teamId => widget.team['id'] as int;
  @override void initState() {
    super.initState();
    socket = io.io(Api.base, io.OptionBuilder().setTransports(['websocket']).disableAutoConnect()
      .enableForceNew().setAuth({'token': Api.token}).build());
    socket.onConnect((_) => connectRoom());
    socket.onDisconnect((_) {
      generation++;
      if (mounted) setState(() { ready = false; status = '연결 끊김 · 재연결 중'; });
    });
    socket.onConnectError((_) { if (mounted) setState(() { loading = false; status = '연결 실패 · 서버 확인 또는 다시 로그인'; }); });
    socket.on('message:new', (dynamic raw) {
      if (!mounted || raw is! Map || raw['teamId'] != teamId) return;
      addMessages([Map<String, dynamic>.from(raw)]);
      bottom();
    });
    socket.connect();
  }
  Future<dynamic> ack(String event, dynamic data) {
    final c = Completer<dynamic>();
    socket.emitWithAck(event, data, ack: (dynamic response) {
      if (c.isCompleted) return;
      if (response is Map && response['ok'] == true) { c.complete(response['data']); }
      else { c.completeError(Exception(response is Map ? response['error'] ?? '요청 실패' : '응답 오류')); }
    });
    return c.future.timeout(const Duration(seconds: 10), onTimeout: () => throw Exception('전송 확인이 늦습니다. 재시도해주세요.'));
  }
  Future<void> connectRoom() async {
    final current = ++generation;
    if (mounted) setState(() { loading = true; ready = false; status = '대화 불러오는 중…'; messages = []; });
    try {
      await ack('team:join', {'teamId': teamId});
      final rows = await Api.request('GET', '/community/teams/$teamId/messages');
      if (!mounted || current != generation) return;
      addMessages((rows as List).map((r) => Map<String, dynamic>.from(r)).toList());
      setState(() { ready = true; loading = false; more = rows.length == 50; status = '실시간 연결됨 · 팀원 전용'; });
      bottom();
    } catch (e) { if (mounted && current == generation) setState(() { loading = false; status = e.toString().replaceFirst('Exception: ', ''); }); }
  }
  void addMessages(List<Map<String, dynamic>> rows) {
    if (!mounted) return;
    final map = <int, Map<String, dynamic>>{for (final m in messages) m['id'] as int: m};
    for (final m in rows) { map[m['id'] as int] = m; }
    setState(() { messages = map.values.toList()..sort((a,b) => (a['id'] as int).compareTo(b['id'] as int)); });
  }
  void bottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
  });
  Future<void> older() async {
    if (olderBusy || messages.isEmpty) return;
    final current = generation;
    setState(() => olderBusy = true);
    try {
      final rows = await Api.request('GET', '/community/teams/$teamId/messages?before=${messages.first['id']}');
      if (!mounted || current != generation) return;
      addMessages((rows as List).map((r) => Map<String, dynamic>.from(r)).toList());
      setState(() => more = rows.length == 50);
    } catch (e) { if (mounted) notice(context, e); }
    finally { if (mounted) setState(() => olderBusy = false); }
  }
  Future<void> send() async {
    if (!ready || sending) return;
    if (pending == null) {
      if (draft.text.trim().isEmpty) return;
      pending = {'teamId': teamId, 'clientId': const Uuid().v4(), 'body': draft.text.trim()};
    }
    setState(() => sending = true);
    try {
      final sent = Map<String, dynamic>.from(await ack('message:send', pending));
      if (!mounted) return;
      addMessages([sent]);
      setState(() { pending = null; draft.clear(); });
      bottom();
    } catch (e) { if (mounted) notice(context, e); }
    finally { if (mounted) setState(() => sending = false); }
  }
  @override void dispose() { generation++; socket.dispose(); draft.dispose(); scroll.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.team['title'], overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Text(status, style: TextStyle(fontSize: 11, color: ready ? mint : muted)),
    ]), actions: [IconButton(onPressed: socket.connected ? connectRoom : () => socket.connect(), icon: const Icon(Icons.refresh))]),
    body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 650),
      child: Column(children: [
        if (loading) const LinearProgressIndicator(color: mint),
        Expanded(child: ListView.builder(controller: scroll, padding: const EdgeInsets.all(18),
          itemCount: messages.length + 1, itemBuilder: (context, index) {
            if (index == 0) return more && messages.isNotEmpty
              ? TextButton(onPressed: olderBusy ? null : older, child: Text(olderBusy ? '불러오는 중…' : '이전 대화 더 보기'))
              : Padding(padding: const EdgeInsets.all(12), child: Text(messages.isEmpty && !loading ? '팀원에게 첫 인사를 보내보세요 👋' : '팀 대화의 시작', textAlign: TextAlign.center, style: const TextStyle(color: muted)));
            final m = messages[index - 1], mine = m['senderId'] == Api.user['id'];
            final time = DateTime.tryParse(m['createdAt'] ?? '')?.toLocal();
            final stamp = time == null ? '' : '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
            return Padding(padding: const EdgeInsets.only(bottom: 18), child: Row(
              crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!mine) ...[Avatar(m['avatar']), const SizedBox(width: 10)],
                Flexible(child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                  if (!mine) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(m['nickname'], style: const TextStyle(color: muted, fontSize: 12))),
                  Container(constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .68),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                    decoration: BoxDecoration(color: mine ? purple : panel, borderRadius: BorderRadius.circular(17)),
                    child: SelectableText(m['body'], style: const TextStyle(fontSize: 15, height: 1.4))),
                  const SizedBox(height: 4), Text(stamp, style: const TextStyle(color: muted, fontSize: 10)),
                ])),
              ],
            ));
          })),
        if (pending != null && !sending) Padding(padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(children: [const Expanded(child: Text('전송 확인 필요 · 같은 메시지로 재시도', style: TextStyle(color: Colors.orangeAccent, fontSize: 12))),
            TextButton(onPressed: ready ? send : null, child: const Text('재시도'))])),
        Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 14), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: TextField(controller: draft, readOnly: pending != null, minLines: 1, maxLines: 4, maxLength: 2000,
            decoration: const InputDecoration(hintText: '메시지를 입력하세요…', counterText: ''))),
          const SizedBox(width: 10),
          IconButton.filled(onPressed: ready && !sending ? send : null,
            style: IconButton.styleFrom(backgroundColor: mint, foregroundColor: bg, minimumSize: const Size(48, 48)),
            icon: Icon(sending ? Icons.hourglass_top : Icons.send_rounded)),
        ])),
      ]),
    ))),
  );
}
