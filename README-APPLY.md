# PyGa feature update v3

이번 패치 포함 내용

- 로그인 이메일은 가입 당시 저장된 대소문자와 정확히 일치해야 로그인됨
- 회원가입 이메일/닉네임 중복은 계속 대소문자 무시로 차단
- 파티 참가: `OO님이 파티에 참가했습니다.` 시스템 메시지 기록
- 파티 나가기: `OO님이 파티에서 나갔습니다.` 시스템 메시지 기록
- 추방: `OO님이 파티에서 퇴장되었습니다.` 시스템 메시지 기록
- 관리자 채팅 검열에서도 SYSTEM 메시지 확인 가능
- 신고 처리 시 신고자에게 처리 결과 알림 발송
- 신고 대상이 정지되면 운영 정책 조치 알림 저장
- 처리 완료 신고는 관리자 목록에서 5분 뒤 자동 숨김 (DB 기록은 유지)
- 회원 관리에서 정지 해제 버튼을 눈에 보이게 추가
- 정지/정지 해제 시 회원에게 알림 저장
- 공지 개별 기록 삭제 기능
- 공지 전체 기록 삭제 기능
- 점검 중 공지는 점검 종료 전 삭제 불가

## 적용

PyGa 루트에서 ZIP을 `-DestinationPath . -Force`로 덮어씁니다.

```powershell
cd C:\Users\jang1\OneDrive\Desktop\PyGa
Expand-Archive "$env:USERPROFILE\Downloads\PyGa-feature-update-v3.zip" -DestinationPath . -Force
```

## 확인

```powershell
cd C:\Users\jang1\OneDrive\Desktop\PyGa\backend
npm run build
npm run db:setup
```

그 다음 루트에서:

```powershell
cd C:\Users\jang1\OneDrive\Desktop\PyGa
git add .
git diff --cached --check
git commit -m "feat: add moderation notifications and party activity logs"
git push origin main
```

Render Auto-Deploy 완료 후 Chrome에서 확인:

```powershell
cd C:\Users\jang1\OneDrive\Desktop\PyGa\frontend
flutter run -d chrome --dart-define=API_BASE_URL=https://pyga-backend.onrender.com
```
