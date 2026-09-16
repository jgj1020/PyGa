# PyGa 전체 교체 코드

이 ZIP은 조각 코드가 아니라 **그대로 덮어쓰는 전체 파일**입니다.

적용 기능
- 이미 가입된 이메일 재가입 차단
- 이메일 대소문자/앞뒤 공백을 무시하고 중복 차단
- 이미 사용 중인 닉네임 회원가입 차단
- 닉네임 대소문자/앞뒤 공백을 무시하고 중복 차단
- 프로필에서 다른 사람이 쓰는 닉네임으로 변경 차단
- 일반 파티원 `파티 나가기` 추가
- 방장은 나가기 대신 기존 `파티 삭제` 사용

포함된 전체 파일
- backend/src/auth/auth.service.ts
- backend/src/users/users.service.ts
- backend/src/community/community.service.ts
- backend/src/community/realtime.ts
- backend/schema.sql
- frontend/lib/services/api.dart
- frontend/lib/pyga_app.dart

## 적용
ZIP 내부의 `backend`, `frontend` 폴더를 PyGa 프로젝트 루트에 그대로 덮어씁니다.

PowerShell:

```powershell
cd C:\Users\jang1\OneDrive\Desktop\PyGa
Expand-Archive "C:\Users\jang1\Downloads\PyGa-duplicate-check-full-code.zip" -DestinationPath . -Force

cd .\backend
npm run build
npm run db:setup

cd ..\frontend
flutter analyze
```

그 다음 테스트 후 커밋:

```powershell
cd C:\Users\jang1\OneDrive\Desktop\PyGa
git add .
git diff --cached --check
git commit -m "feat: prevent duplicate accounts and add party leave"
git push origin main
```

주의: schema.sql은 기존 데이터에 이미 중복 이메일/닉네임이 있더라도 배포 자체가 실패하지 않도록 작성했습니다. 기존 중복 계정은 자동 삭제하지 않습니다. 앞으로 새 중복 가입/변경을 막습니다.
