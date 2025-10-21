# UT Bot EA Production Version 사용 가이드

## 📋 개요
UT_Bot_EA_Production.mq5는 실전 거래를 위한 완전한 기능을 갖춘 Expert Advisor입니다. 모든 버그가 수정되었으며, 시각적 표시, 시간 필터링, 스프레드 필터링, 다중 포지션 지원 등의 고급 기능이 포함되어 있습니다.

## ✨ 주요 기능

### 1. 🎨 시각적 표시 기능
- **트레일링 스탑 라인**: 차트에 실시간 트레일링 스탑 라인 표시
- **매매 신호 화살표**: Buy/Sell 신호를 차트에 화살표로 표시
- **정보 패널**: 차트 좌측 상단에 실시간 상태 정보 표시
  - 시스템 상태 (ACTIVE/INITIALIZING)
  - 현재 포지션 (LONG/SHORT/NEUTRAL)
  - 트레일링 스탑 가격
  - 현재 ATR 값
  - 현재 스프레드
  - 시간 필터 상태
  - 오픈 포지션 수

### 2. ⏰ 시간 필터링
- **거래 시간 제한**: 특정 시간대에만 거래 가능
- **요일별 설정**: 월~금 각각 거래 허용 여부 설정
- **유연한 시간 범위**: 시작/종료 시간 자유 설정
- **자동 감지**: 거래 불가 시간대에 신호 무시

### 3. 📊 스프레드 필터링
- **최대 스프레드 제한**: 설정한 스프레드 이상일 때 거래 중지
- **실시간 모니터링**: 스프레드를 실시간으로 체크
- **알림 기능**: 스프레드 초과 시 로그에 경고 표시
- **자동 보호**: 불리한 조건에서 거래 방지

### 4. 🔄 다중 포지션 지원
- **동시 포지션**: 여러 개의 포지션 동시 보유 가능
- **단일 포지션 모드**: 한 번에 하나의 포지션만 허용
- **자동 관리**: 반대 방향 신호 시 기존 포지션 자동 청산

## ⚙️ 설정 가이드

### UT Bot 핵심 설정
```
Key Value = 1.0          // 민감도 (0.5-2.0 권장)
ATR Period = 10          // ATR 계산 기간 (5-20 권장)
Use Heikin Ashi = false  // Heikin Ashi 캔들 사용 여부
```

**추천 설정:**
- 변동성 낮은 시장: Key Value = 1.5-2.0
- 변동성 높은 시장: Key Value = 0.5-1.0
- 단기 거래: ATR Period = 5-10
- 장기 거래: ATR Period = 15-20

### 거래 설정
```
Lot Size = 0.1                    // 로트 크기
Magic Number = 123456             // 매직 넘버 (고유 식별자)
Slippage = 3                      // 슬리피지 (포인트)
Allow Multiple Positions = false  // 다중 포지션 허용
```

**추천 설정:**
- 초보자: Allow Multiple Positions = false
- 경험자: Allow Multiple Positions = true (리스크 관리 필수)

### 리스크 관리
```
Use Stop Loss = true         // 스탑로스 사용
Use Take Profit = false      // 테이크프로핏 사용
Risk Percent = 2.0          // 거래당 리스크 비율 (%)
Max Spread = 30             // 최대 허용 스프레드 (포인트)
Enable Spread Filter = true // 스프레드 필터 활성화
```

**추천 설정:**
- 보수적: Risk Percent = 1.0%, Max Spread = 20
- 중립적: Risk Percent = 2.0%, Max Spread = 30
- 공격적: Risk Percent = 3.0%, Max Spread = 50

### 시간 필터 설정
```
Use Time Filter = false    // 시간 필터 사용
Start Hour = 0            // 거래 시작 시간
End Hour = 23             // 거래 종료 시간
Trade Monday = true       // 월요일 거래
Trade Tuesday = true      // 화요일 거래
Trade Wednesday = true    // 수요일 거래
Trade Thursday = true     // 목요일 거래
Trade Friday = true       // 금요일 거래
```

**추천 설정:**
- EUR/USD: Start Hour = 8, End Hour = 22 (런던~뉴욕 세션)
- USD/JPY: Start Hour = 0, End Hour = 9 (도쿄 세션)
- 금요일 거래 제한: Trade Friday = false (주말 갭 리스크 회피)

### 시각적 표시 설정
```
Show Trailing Stop = true           // 트레일링 스탑 라인 표시
Trailing Stop Color = clrBlue       // 트레일링 스탑 색상
Trailing Stop Width = 2             // 트레일링 스탑 선 두께
Show Signals = true                 // 매매 신호 표시
Buy Signal Color = clrLime          // 매수 신호 색상
Sell Signal Color = clrRed          // 매도 신호 색상
Signal Arrow Code = 233             // 신호 화살표 코드
Show Info Panel = true              // 정보 패널 표시
Info Panel X = 20                   // 정보 패널 X 위치
Info Panel Y = 30                   // 정보 패널 Y 위치
Info Panel Color = clrWhite         // 정보 패널 색상
Info Panel Font Size = 10           // 정보 패널 폰트 크기
```

## 📝 설치 및 사용 방법

### 1. 설치
1. MetaTrader 5를 실행합니다.
2. 파일 → 데이터 폴더 열기 → MQL5 → Experts 폴더에 `UT_Bot_EA_Production.mq5` 파일을 복사합니다.
3. MetaEditor에서 파일을 열고 컴파일합니다 (F7 키).
4. MetaTrader 5를 재시작하거나 네비게이터를 새로고침합니다.

### 2. 차트에 적용
1. 원하는 차트를 엽니다.
2. 네비게이터 창에서 Expert Advisors → UT_Bot_EA_Production을 차트로 드래그합니다.
3. 설정 창에서 원하는 매개변수를 조정합니다.
4. "자동매매 허용" 체크박스를 활성화합니다.
5. OK 버튼을 클릭합니다.

### 3. 자동매매 활성화
1. 툴바에서 "자동매매" 버튼을 클릭합니다 (초록색으로 변경되어야 함).
2. 차트 우상단에 웃는 얼굴 아이콘이 표시되면 정상 작동 중입니다.

## 📊 차트 표시 요소 설명

### 트레일링 스탑 라인 (파란색 점선)
- 현재 ATR 트레일링 스탑 위치를 실시간으로 표시
- 가격이 이 라인을 돌파하면 매매 신호 발생

### 매매 신호 화살표
- **위쪽 화살표 (초록색)**: 매수 신호
- **아래쪽 화살표 (빨간색)**: 매도 신호
- 화살표가 나타난 바에서 신호가 발생했음을 의미

### 정보 패널 (차트 좌측 상단)
```
Status:           ACTIVE          // 시스템 상태
Position:         LONG            // 현재 포지션 방향
Trailing Stop:    1.08450         // 트레일링 스탑 가격
ATR:             0.00025          // 현재 ATR 값
Spread:          1.5 pts          // 현재 스프레드
Time Filter:     ALLOWED          // 시간 필터 상태
Open Positions:  1                // 오픈 포지션 수
```

## 🎯 실전 거래 전략

### 1. 보수적 전략
```
Key Value = 1.5
ATR Period = 15
Risk Percent = 1.0
Max Spread = 20
Allow Multiple Positions = false
Use Time Filter = true (유럽/미국 세션만)
```

### 2. 균형 전략 (권장)
```
Key Value = 1.0
ATR Period = 10
Risk Percent = 2.0
Max Spread = 30
Allow Multiple Positions = false
Use Time Filter = false
```

### 3. 공격적 전략
```
Key Value = 0.7
ATR Period = 7
Risk Percent = 3.0
Max Spread = 40
Allow Multiple Positions = true
Use Time Filter = false
```

## ⚠️ 주의사항

### 1. 백테스팅 필수
- 실전 거래 전에 충분한 백테스팅을 수행하세요.
- 다양한 시장 조건에서 테스트하세요.
- 최소 3개월 이상의 데이터로 테스트하세요.

### 2. 데모 계좌 테스트
- 실전 계좌 사용 전에 데모 계좌에서 최소 1개월 이상 테스트하세요.
- 실제 시장 조건에서의 성능을 확인하세요.

### 3. 리스크 관리
- Risk Percent를 계좌의 5% 이상으로 설정하지 마세요.
- 여러 통화쌍에 동시 적용 시 총 리스크를 관리하세요.
- 손실 한도를 설정하고 준수하세요.

### 4. 모니터링
- 정기적으로 EA의 성능을 모니터링하세요.
- 로그 파일을 확인하여 오류를 추적하세요.
- 중요한 경제 이벤트 전후에는 거래를 중단하는 것을 고려하세요.

### 5. VPS 사용 권장
- 24시간 안정적인 거래를 위해 VPS 사용을 권장합니다.
- 낮은 지연시간의 서버를 선택하세요.

## 🔧 문제 해결

### EA가 거래하지 않는 경우
1. 자동매매가 활성화되어 있는지 확인
2. 스프레드 필터를 확인 (현재 스프레드 > Max Spread?)
3. 시간 필터를 확인 (현재 시간이 거래 가능 시간인가?)
4. 계좌 잔고와 마진을 확인
5. 로그에서 오류 메시지 확인

### 신호가 표시되지 않는 경우
1. Show Signals = true로 설정되어 있는지 확인
2. 차트를 새로고침
3. EA를 다시 시작

### 정보 패널이 보이지 않는 경우
1. Show Info Panel = true로 설정되어 있는지 확인
2. Info Panel X, Y 위치를 조정
3. 차트 축소/확대를 시도

## 📈 성능 최적화 팁

1. **통화쌍 선택**: 유동성이 높은 메이저 통화쌍 사용 (EUR/USD, GBP/USD 등)
2. **시간대 선택**: 주요 거래 세션 시간대 활용
3. **스프레드 관리**: ECN 계좌 사용으로 스프레드 최소화
4. **설정 최적화**: 각 통화쌍에 맞게 Key Value와 ATR Period 조정
5. **정기 검토**: 매주/매월 성과를 검토하고 필요시 설정 조정

## 📞 지원 및 업데이트

이 EA는 Pine Script v4의 UT Bot Alerts를 기반으로 MQL5로 완전히 변환되었으며, 모든 버그가 수정되고 실전 거래를 위한 고급 기능이 추가되었습니다.

**버전**: 2.00 (Production Version)
**마지막 업데이트**: 2024

---

**면책 조항**: 이 소프트웨어는 교육 및 연구 목적으로 제공됩니다. 실제 거래에서 발생하는 손실에 대해서는 사용자가 전적으로 책임집니다. 충분한 테스트와 리스크 관리 없이 실전 계좌에서 사용하지 마십시오.
