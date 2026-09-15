# PyGa 업데이트 적용 안내

이번 압축은 기존 프로젝트에 **덮어쓰기용**입니다. 기존 `android`, `web`, `windows` 같은 Flutter 플랫폼 폴더는 들어 있지 않으므로 기존 `frontend` 폴더를 통째로 삭제하지 말고 파일을 합쳐서 덮어쓰세요.

## 이번 버전에 들어간 기능

- 전체 UI를 다크 게이밍 스타일로 다시 정리
- 로그인/회원가입 화면 리디자인
- 로고 자리 추가 (`BrandMark` 위젯). 지금은 게임패드 임시 아이콘이며 나중에 실제 로고로 교체 가능
- 관리자 전용 로그인 화면
- 관리자 대시보드: 전체 회원 수 / 파티 수 / 메시지 수 / 파티 참여 수 / 최근 가입 회원
- 파티 생성자는 자동으로 **방장(👑)**
- 채팅방에서 파티원 목록 확인
- 방장만 파티원 추방 가능
- 방장만 파티 삭제 가능
- 삭제된 파티는 메시지/멤버 데이터까지 함께 삭제
- 추방된 사용자는 실시간 채팅방에서 즉시 제외되고 다시 메시지를 보낼 수 없음
- 메시지 읽음 상태 추가: 아직 안 읽은 파티원 수를 숫자로 표시하고 모두 읽으면 `읽음`
- 내 채팅 목록에 읽지 않은 메시지 수 배지 표시
- 기존 프로필 사진/닉네임/실시간 채팅 기능 유지

## 1. 덮어쓰기

현재 프로젝트를 백업한 뒤, 이 압축 안의 `backend`, `frontend` 폴더를 기존 PyGa 폴더에 복사해 같은 파일을 덮어쓰세요.

예시 프로젝트 위치:

```powershell
C:\Users\jang1\OneDrive\Desktop\PyGa
```

## 2. DB 업데이트 + 관리자 설정

이번 버전에는 DB 컬럼이 추가됐으므로 **반드시 `npm run db:setup`을 다시 한 번 실행**해야 합니다. 기존 회원/파티/채팅 테이블을 삭제하지 않고 필요한 컬럼만 추가합니다.

관리자로 사용할 이메일을 `ADMIN_EMAIL`에 넣어주세요. 이미 그 이메일로 가입한 계정이 있다면 `db:setup` 실행 시 관리자 권한이 붙습니다. 아직 계정이 없다면 `ADMIN_EMAIL`을 설정한 상태로 서버를 실행하고 그 이메일로 회원가입하면 자동으로 관리자가 됩니다.

PowerShell:

```powershell
cd C:\Users\jang1\OneDrive\Desktop\PyGa\backend
npm ci

$dbSecure = Read-Host "PostgreSQL postgres 계정 비밀번호" -AsSecureString
$env:DB_PASSWORD = [System.Net.NetworkCredential]::new('', $dbSecure).Password
$env:DB_HOST = 'localhost'
$env:DB_PORT = '5432'
$env:DB_USER = 'postgres'
$env:DB_NAME = 'pyga'
$env:JWT_SECRET = '여기에_32자_이상_고정_비밀키'
$env:ADMIN_EMAIL = '관리자로쓸이메일@example.com'

npm run db:setup
npm start
```

> `JWT_SECRET`은 실행할 때마다 바꾸지 말고 개발 중에는 같은 값을 유지하는 편이 편합니다. GitHub에는 올리지 마세요.

이미 서버가 실행 중인 상태에서 관리자 계정을 새로 만들었다면 서버를 종료하고 같은 환경변수를 설정한 뒤 아래만 다시 실행하면 됩니다.

```powershell
npm run db:setup
npm start
```

## 3. Flutter 실행

새 PowerShell 창:

```powershell
cd C:\Users\jang1\OneDrive\Desktop\PyGa\frontend
flutter pub get
flutter analyze lib\main.dart lib\pyga_app.dart lib\services\api.dart
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
```

웹 서버 방식이면 기존처럼:

```powershell
flutter run -d web-server --web-hostname=localhost --web-port=5173 --dart-define=API_BASE_URL=http://localhost:3000
```

## 4. 꼭 테스트할 것

1. 일반 계정 A와 B를 각각 로그인합니다.
2. A가 파티를 만들면 A에게 👑 방장 표시가 뜨는지 확인합니다.
3. B가 파티에 참가합니다.
4. 채팅 우측 상단의 사람 아이콘을 눌러 A/B가 모두 보이는지 확인합니다.
5. A 화면에서 B 옆에 `추방` 버튼이 보이는지 확인합니다.
6. A → B로 메시지를 보내고, B가 채팅방을 열었을 때 A 화면의 숫자가 `읽음`으로 바뀌는지 확인합니다.
7. B가 채팅방을 닫은 상태에서 A가 메시지를 보내면 내 채팅 목록에 읽지 않은 메시지 배지가 뜨는지 확인합니다.
8. A가 B를 추방하면 B 채팅 화면이 닫히고 이후 접근이 막히는지 확인합니다.
9. A가 파티 삭제를 누르면 파티가 목록에서 사라지는지 확인합니다.
10. 로그인 화면 아래 `관리자 로그인` → 관리자 계정으로 로그인 → 회원 수가 보이는지 확인합니다.

## 5. 로고 교체 위치

현재 로고는 `frontend/lib/pyga_app.dart`의 `BrandMark` 클래스에 임시 게임패드 아이콘으로 되어 있습니다.

나중에 로고가 완성되면 예를 들어:

```dart
Image.asset('assets/branding/logo.png')
```

형태로 바꾸면 됩니다. 실제 로고 파일을 받으면 그때 앱 아이콘/스플래시까지 같이 맞추는 것이 좋습니다.

## 6. 구글 플레이 배포 전 아직 해야 할 것

지금 단계는 기능 완성도와 UI를 올리는 개발 버전입니다. 실제 Google Play에 올리기 전에는 최소한 아래 작업이 더 필요합니다.

- 백엔드 서버를 HTTPS/WSS 가능한 운영 서버에 배포
- 앱의 `API_BASE_URL`을 운영 서버 주소로 변경
- 회원 탈퇴 기능 및 개인정보 처리방침
- 신고/차단 기능 검토
- 로그인/회원가입 rate limit
- 운영 DB 백업
- Android 앱 아이콘/스플래시/패키지명/서명키 설정
- 실제 휴대폰에서 이미지 선택, 소켓 재연결, 네트워크 끊김 테스트

PostgreSQL `5432` 포트를 인터넷에 직접 공개하지 마세요.

## 검수 메모

이 작업 환경에는 Flutter SDK와 프로젝트 `node_modules`가 없어 실제 Flutter 렌더링 및 NestJS 전체 빌드는 실행하지 못했습니다. 대신 변경한 TypeScript 파일은 파서 단계에서 문법 오류가 없는지 확인했고, Dart 파일은 괄호/구조 검사를 진행했습니다. 로컬에서 위 `flutter analyze`와 `npm start`를 실행했을 때 나오는 **첫 오류가 있다면 그 문구만 그대로 보내주면 이어서 수정하면 됩니다.**
