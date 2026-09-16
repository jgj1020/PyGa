# PyGa Beta Feedback Update

이번 소스는 베타 피드백 반영본입니다.

## 반영 기능

- 방 만들기 게임 선택 개선
  - PC / 모바일 게임 분리
  - 게임 검색
  - 게임 목록 대폭 확대
  - 게임별 모드 목록
- 로그인/회원가입/채팅 체감 속도 개선
  - 로그인 시 불필요한 추가 프로필 요청 제거
  - 로그인 화면 진입 시 백엔드 warm-up
  - 회원가입 직후 토큰 발급 및 자동 로그인
  - 회원가입 중 이메일 확인과 bcrypt 해시를 병렬 처리
  - 소켓 연결 후 메시지마다 중복 DB 인증 조회하지 않도록 개선
  - 채팅 초기 로드 40개 + 이전 메시지 페이징
- 채팅 여러 줄 입력
  - Enter로 줄바꿈
  - 전송 버튼으로 메시지 전송
- 운영 공지 / 점검 알림
  - 관리자: 일반 공지 / 점검 예정 / 점검 중 / 점검 종료
  - 사용자: 상단 배너 실시간 표시 + 주기적 백업 조회
- 파티 추방
  - 5분 임시 추방
  - 영구 추방
- 플레이어 신고 / 이용 정지
  - 파티원 프로필에서 신고
  - 욕설/비속어 등 신고 사유와 상세 내용 입력
  - 관리자 신고함에서 처리 완료
  - 정지 없음 / 1분 / 1일 / 7일 / 30일 / 1년 / 영구 정지
  - 관리자 수동 정지/해제
- 게임별 프로필
  - 사용자별 게임 티어/랭크 + 레벨/전투력/트로피 입력
  - 파티 카드 / 파티원 목록 / 플레이어 프로필에서 표시
- 음성 채팅 베타
  - 마이크 사용 파티에서 채팅방 상단 마이크 버튼
  - 파티원끼리 P2P 음성 연결
  - 마이크 ON/OFF 및 나가기
  - Android 마이크 권한 추가
- Android 패키지 ID
  - `com.pyga.app`

## 적용 순서

### 1. 백엔드

Render에서 기존처럼 아래 Start Command를 사용하면 `schema.sql` 변경사항이 먼저 적용됩니다.

```text
npm run db:setup && node dist/main.js
```

Git에 올린 뒤 Render 배포 로그에서 `DB 준비 완료`와 서버 시작 로그를 확인하세요.

### 2. Flutter 의존성

`flutter_webrtc`가 추가되었으므로 frontend에서 한 번 실행하세요.

```powershell
cd C:\Users\jang1\OneDrive\Desktop\PyGa\frontend
flutter pub get
```

### 3. Android 베타 빌드

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://pyga-backend.onrender.com
```

Google Play용 AAB는 최종 서명 설정 후 아래 명령을 사용하세요.

```powershell
flutter build appbundle --release --dart-define=API_BASE_URL=https://pyga-backend.onrender.com
```

## 확인할 테스트

- 신규 가입 후 바로 메인 화면 이동
- 기존 계정 로그인
- PC/모바일 게임 검색 및 파티 생성
- 채팅 Enter 줄바꿈
- 5분 추방 후 즉시 재입장 차단, 5분 후 재입장
- 영구 추방 재입장 차단
- 신고 -> 관리자 신고함 -> 정지 기간 선택 -> 대상 계정 차단
- 관리자 공지/점검 배너가 사용자 화면에 표시/종료
- 게임 티어/레벨 저장 및 파티원 프로필 표시
- 두 기기에서 같은 마이크 ON 파티에 들어가 음성 연결

## 음성 채팅 참고

현재 음성 채팅은 베타 P2P 방식입니다. 네트워크 환경에 따라 일부 사용자끼리 직접 연결이 실패할 수 있으므로 정식 공개 전 실제 서로 다른 네트워크에서 충분히 테스트하세요.
