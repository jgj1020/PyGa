# PyGa 실행 안내

## 이번 수정 내용

- PDF 원안의 검정 배경, 보라색 버튼, 민트색 포인트를 로그인/홈/찾기/파티/채팅/프로필에 적용했습니다.
- 회원가입과 로그인이 실제 NestJS API를 호출합니다. 비밀번호는 최소 8자입니다.
- 공개 모집 팀을 만들고 다른 계정이 참가할 수 있습니다. 만든 사람도 팀원에 포함됩니다.
- 채팅 목록에는 내가 가입한 팀만 나옵니다. 서버가 기록 조회/방 입장/메시지 전송마다 팀 가입 여부를 검사합니다.
- 메시지를 DB에 저장한 뒤 실시간으로 전달합니다. 전송 확인이 늦으면 같은 메시지 ID로 재시도하여 중복 저장을 막습니다.
- 다시 로그인해도 팀과 대화 기록은 남습니다. 최근 50개와 '이전 대화 더 보기'를 제공합니다.
- 프로필에서 닉네임과 사진을 변경할 수 있습니다. 사진은 DB에 작은 JPEG로 저장되고 같은 팀 채팅에서 표시됩니다.

이번 버전은 두 계정으로 직접 테스트할 수 있는 개발용 구현입니다. 인터넷 공개 배포는 하지 않았습니다.
원안의 가짜 플레이어 추천 점수/티어/활동 통계는 실제 데이터가 없어 새 화면에 표시하지 않습니다.

## 1. 기존 프로젝트에 적용

1. 실행 중인 Flutter와 NestJS 터미널에서 Ctrl+C를 눌러 종료합니다.
2. 현재 PyGa 폴더를 복사해 백업합니다. PostgreSQL 데이터는 별도이므로 중요한 회원 데이터가 있다면 pgAdmin에서 DB도 백업하세요.
3. 이 ZIP을 별도 폴더에 압축 해제합니다.
4. 안의 `backend`, `frontend` 폴더를 기존 `C:\Users\jang1\OneDrive\Desktop\PyGa` 안에 복사하고 같은 이름의 파일을 덮어씁니다.
   **기존 backend/frontend 폴더 전체를 삭제하지 마세요.** ZIP에는 플랫폼 폴더(android, web 등)가 없으며 기존 폴더와 합쳐서 사용합니다.
5. 이 안내 파일도 PyGa 폴더에 두세요.

기존 `frontend/lib/screens` 디자인 파일은 보존했습니다. 새 실행 진입점은 `lib/main.dart` → `lib/pyga_app.dart`입니다.
기존 화면은 더 이상 실행 경로에 연결되지 않습니다. 기존 데모 코드를 실시간 API 화면과 혼용하지 마세요.

## 2. 백엔드 실행 (PowerShell 창 1)

PostgreSQL이 실행 중이고 `pyga` DB가 존재해야 합니다. 기존 pgAdmin에서 보던 DB를 그대로 사용합니다.
아래 명령어는 **PowerShell**에 입력합니다. SQL을 PowerShell에 붙여넣을 필요는 없습니다.

```powershell
cd C:\Users\jang1\OneDrive\Desktop\PyGa\backend
npm ci

$dbSecure = Read-Host "PostgreSQL postgres 계정 비밀번호" -AsSecureString
$env:DB_PASSWORD = [System.Net.NetworkCredential]::new('', $dbSecure).Password
$env:DB_HOST = 'localhost'
$env:DB_PORT = '5432'
$env:DB_USER = 'postgres'
$env:DB_NAME = 'pyga'
$env:JWT_SECRET = node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"

npm run db:setup
npm start
```

- `db:setup`이 성공한 다음에만 `npm start`로 진행하세요. 기존 users 테이블/회원은 삭제하지 않습니다.
- DB에 `avatar` 컬럼과 `teams`, `team_members`, `messages` 테이블을 추가합니다. SQL은 `backend/schema.sql`입니다.
- TypeORM 자동 스키마 동기화는 꺼두었습니다. 테이블 삭제/초기화 명령은 없습니다.
- 비밀번호를 코드 파일에 다시 적지 마세요. 명령 결과나 화면 캡처에도 비밀번호/토큰을 노출하지 마세요.
- 서버는 기본적으로 이 PC의 `127.0.0.1:3000`에서만 열립니다.
- 창을 닫으면 환경변수가 사라집니다. 다시 시작할 때 위 설정을 다시 실행하세요.
- JWT 키를 새로 만들면 기존 로그인 토큰은 무효가 됩니다. 다시 로그인하면 됩니다. 회원/대화 기록은 그대로입니다.
- 기존 계정 비밀번호가 8자 미만이면 로그인할 수 없습니다. 이번 테스트에는 8자 이상 새 계정을 사용하세요.
- bcrypt 입력 제한 때문에 비밀번호는 UTF-8 기준 최대 72바이트입니다.

## 3. Flutter 실행 (새 PowerShell 창 2)

```powershell
cd C:\Users\jang1\OneDrive\Desktop\PyGa\frontend
flutter pub get
flutter analyze lib\main.dart lib\pyga_app.dart lib\services\api.dart
flutter test test\widget_test.dart
flutter run -d web-server --web-hostname=localhost --web-port=5173 --dart-define=API_BASE_URL=http://localhost:3000
```

오류가 나면 그 단계에서 멈추고 첫 오류 문구를 보내주세요. 이 환경에는 Flutter SDK가 없어 analyze/test/화면 실행은 미검증입니다.
실행되면 브라우저에서 <http://localhost:5173>을 엽니다. 두 터미널은 계속 켜두세요.
브라우저 새로고침 시 로그인 정보는 지워지므로 다시 로그인합니다. DB 기록은 지워지지 않습니다.

## 4. 두 계정 실시간 테스트

1. 일반 Chrome 창에서 계정 A로 회원가입하고 로그인합니다.
2. 시크릿 창에서 같은 <http://localhost:5173>을 열고 계정 B로 회원가입/로그인합니다.
3. A: '파티' 탭 → 소개와 인원을 입력 → '모집 시작'. 생성자는 자동으로 참가합니다.
4. B: '홈' 탭 → 우측 새로고침 → A가 만든 팀에 '참가하고 채팅하기'.
5. A: '채팅' 탭 → 같은 팀의 '채팅 열기'. 두 창 모두 '실시간 연결됨'인지 확인합니다.
6. A와 B가 번갈아 메시지를 보내면 상대 창에 즉시 나타나야 합니다.
7. B 창을 새로고침하고 다시 로그인 → 채팅 → 같은 팀. 이전 기록이 남아 있어야 합니다.
8. 프로필에서 사진을 선택해 저장하고 다시 채팅방에 들어가 메시지를 보냅니다. 상대방 화면에 사진이 나와야 합니다.
9. 가능하면 계정 C도 만들어 팀에 참가하지 않은 상태에서 '채팅' 목록에 그 팀이 없는지 확인하세요.

사진은 PNG/JPEG/WebP, 전송 데이터 기준 2MB 이하입니다. 큰 사진은 작은 파일로 바꿔보세요.
기존 대화의 사진/닉네임은 대화를 다시 불러오면 갱신됩니다. 실시간 프로필 변경 알림은 이번 범위에 없습니다.

## 검증한 범위

`backend`에서 `npm run test:chat`로 재실행 가능합니다. 사용자 PostgreSQL을 건드리지 않는 격리된 PGlite(PostgreSQL WASM) 테스트입니다.
실제 NestJS HTTP/Socket.IO 서버, JWT, bcrypt, SQL을 사용하되 TypeORM 연결/Repository는 테스트 어댑터를 사용합니다.

- TypeScript 빌드 성공
- 익명 HTTP/잘못된 토큰 차단
- 서버의 비밀번호 8자 제한, 실제 회원가입/로그인
- 비팀원의 기록 조회/방 구독/메시지 전송 차단
- 팀 참가 중복 방지와 정원 검사
- 두 독립 계정 실시간 송수신과 재접속
- 재전송 중복 저장 방지, 외부 계정에 메시지가 가지 않음
- 50개 단위 이전 기록 조회
- 프로필 사진 저장/잘못된 이미지 거절
- 토큰 만료 시 연결 종료
- 서비스 인스턴스를 새로 만들어도 DB 기록 조회

미검증: 실제 Windows/Flutter 렌더링, 실제 PostgreSQL 17 연결, 모바일 플랫폼 권한 및 외부 네트워크.

## 다른 PC/휴대폰 또는 인터넷 서비스

이번 기본 설정은 같은 PC의 두 브라우저 창 테스트용입니다. 다른 기기에서 localhost를 입력하면 그 기기 자신을 가리키므로 연결되지 않습니다.
외부 사용에는 서버 배포, HTTPS/WSS, 고정 JWT 비밀키 관리, 허용 프런트 주소 설정, 백업과 접근 통제가 별도로 필요합니다.
공유기 포트를 무작정 열거나 PostgreSQL 포트(5432)를 인터넷에 공개하지 마세요.
공개 서비스 전에는 로그인/가입 속도 제한, 신고/차단, 회원 탈퇴/보관 정책, 모니터링을 추가해야 합니다.
현재는 단일 서버 전제이며 다중 서버 실시간 전달/푸시 알림/읽음 표시/메시지 수정·삭제/팀 탈퇴는 포함하지 않았습니다.

프로필 사진의 모바일 사용에는 플랫폼 설정이 필요할 수 있습니다. iOS에서는 Info.plist의 사진 접근 설명을 확인하세요.
참고: [Socket.IO 서버 문서](https://socket.io/docs/v4/server-api/), [Dart Socket.IO 클라이언트](https://pub.dev/packages/socket_io_client), [Flutter 이미지 선택](https://pub.dev/packages/image_picker).

## 비밀키 관련

원본 ZIP의 소스에 DB 비밀번호와 JWT 비밀키가 직접 들어 있었습니다. 이번 수정본에는 그 값을 넣지 않았습니다.
원본이 GitHub 등에 올라갔다면 비밀번호/키를 교체하세요. 현재 코드에서 지워도 과거 커밋의 값은 남을 수 있습니다.
