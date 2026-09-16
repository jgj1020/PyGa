# PyGa 음성 상태바 Tooltip 오류 핫픽스

Chrome/Web에서 `No Overlay widget found` / `RawTooltip widgets require an Overlay widget ancestor` 오류가 뜨는 문제를 수정합니다.

원인: `MaterialApp.builder`의 전역 음성 상태바는 Navigator의 Overlay 바깥에 있는데, 상태바의 `IconButton.tooltip`이 Flutter `Tooltip`을 만들면서 Overlay를 찾지 못했습니다.

수정: 전역 음성 상태바의 마이크/헤드셋/종료 버튼에서 tooltip만 제거했습니다. 버튼 기능과 통화 기능은 그대로입니다.

프로젝트 루트에서 이 ZIP을 덮어쓴 후 실행:

```powershell
cd C:\Users\jang1\OneDrive\Desktop\PyGa\frontend
flutter run -d chrome --dart-define=API_BASE_URL=https://pyga-backend.onrender.com
```
