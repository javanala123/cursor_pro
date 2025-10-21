# UT Bot EA Production - 사용 가이드

## 📌 빠른 시작

### 1단계: 파일 설치
```
1. MetaTrader 5 열기
2. 파일 → 데이터 폴더 열기
3. MQL5 → Experts 폴더로 이동
4. UT_Bot_EA_Production.mq5 파일 복사
5. MetaEditor에서 컴파일 (F7)
```

### 2단계: 차트에 적용
```
1. 원하는 통화쌍 차트 열기 (예: EURUSD)
2. 내비게이터 → Expert Advisors
3. UT_Bot_EA_Production을 차트에 드래그
4. 자동매매 활성화 확인 (상단 툴바의 AutoTrading 버튼)
```

### 3단계: 기본 설정 확인
```
입력 탭에서 다음 항목 확인:
- KeyValue: 1.0 (기본값)
- ATRPeriod: 10 (기본값)
- LotSize: 0.01 (데모 계좌에서는 작은 값으로 시작)
- RiskPercent: 2.0 (계좌의 2%만 리스크)
```

---

## 🎛️ 주요 설정 항목 설명

### UT Bot 핵심 설정

#### KeyValue (민감도)
```
역할: 트레일링 스탑의 거리 조절

0.5 = 매우 민감 (스탑이 가까움)
- 장점: 빠른 진입, 많은 신호
- 단점: 잦은 손절, 노이즈 트레이딩

1.0 = 균형 잡힌 설정 ★ 추천
- 장점: 적절한 진입 타이밍
- 단점: 보통

1.5-2.0 = 보수적 (스탑이 멀음)
- 장점: 적은 손절, 큰 트렌드만 포착
- 단점: 늦은 진입, 적은 신호

추천 시작값: 1.0
변동성 높은 시장: 0.8-1.0
변동성 낮은 시장: 1.2-1.5
```

#### ATRPeriod
```
역할: ATR 계산에 사용할 바의 개수

5-7 = 짧은 기간
- 최근 변동성에 빠르게 반응
- 단기 트레이딩에 적합

10-14 = 중간 기간 ★ 추천
- 균형 잡힌 반응 속도
- 대부분의 시장에 적합

15-20 = 긴 기간
- 안정적인 ATR 값
- 장기 트렌드에 적합

추천 시작값: 10
스캘핑: 5-7
데이 트레이딩: 10-14
스윙 트레이딩: 15-20
```

#### UseHeikinAshi
```
false = 일반 캔들 사용 ★ 기본값
- 실제 가격 반영
- 빠른 반응

true = Heikin Ashi 캔들 사용
- 노이즈 감소
- 부드러운 트렌드 파악
- 실제 가격과 차이 있음

추천: 
- 변동성 높은 시장: true
- 일반 시장: false
```

---

### 거래 설정

#### LotSize
```
고정 로트 크기 (RiskPercent = 0일 때 사용)

0.01 = 마이크로 로트 (1,000 units)
- 데모 계좌 테스트용
- 소액 계좌

0.1 = 미니 로트 (10,000 units)
- 일반적인 시작 크기
- 중간 계좌

1.0 = 표준 로트 (100,000 units)
- 대형 계좌

추천:
- 데모/테스트: 0.01
- 실계좌 시작: 0.01-0.1
```

#### AllowMultiplePositions
```
false = 한 번에 하나의 포지션만 ★ 추천
- 안전한 리스크 관리
- 명확한 포지션 추적
- 초보자에게 적합

true = 여러 포지션 동시 보유
- 공격적인 전략
- 복잡한 관리 필요
- 숙련자용

추천: false (처음 시작 시)
```

---

### 리스크 관리

#### RiskPercent
```
거래당 리스크 비율 (계좌 잔고의 %)

0 = 비활성화 (고정 LotSize 사용)

1% = 매우 보수적
- 느린 계좌 성장
- 안전함

2% = 권장 설정 ★
- 균형 잡힌 리스크/리워드
- 대부분의 전문가 추천

3-5% = 공격적
- 빠른 계좌 성장 또는 손실
- 높은 변동성

추천:
- 초보자: 1%
- 일반: 2%
- 숙련자: 2-3%
```

#### MaxSpread
```
최대 허용 스프레드 (포인트)

15-20 = EUR/USD 등 주요 통화쌍
30-40 = GBP/JPY 등 변동성 높은 쌍
50+ = 마이너 통화쌍

추천:
- 주요 통화쌍: 20-30
- 크로스 통화쌍: 30-50
- 금/은: 40-60
```

#### UseStopLoss / UseTakeProfit
```
UseStopLoss = true ★ 필수!
- 트레일링 스탑 가격에 손절 설정
- 리스크 제한

UseTakeProfit = false (권장)
- 트렌드를 최대한 추종
- true로 설정 시 R:R 1:2로 자동 익절

추천:
- UseStopLoss: 항상 true
- UseTakeProfit: false (트렌드 추종)
```

---

### 시간 필터

#### UseTimeFilter
```
false = 24시간 거래 ★ 기본값

true = 특정 시간대만 거래
- StartHour ~ EndHour 설정
- 요일별 거래 설정

언제 사용?
- 런던/뉴욕 세션만 거래
- 아시아 세션 회피 (낮은 변동성)
- 주요 경제 지표 발표 시간만

예시 설정:
런던+뉴욕 세션: 8:00 ~ 22:00
뉴욕 세션만: 14:00 ~ 23:00
```

---

## 📊 차트 표시 이해하기

### 트레일링 스탑 라인 (파란색)
```
위치: 가격 아래/위에 표시되는 수평선

의미:
- 가격 아래 = 상승 트렌드 중
- 가격 위 = 하락 트렌드 중

움직임:
- 상승장: 라인이 계속 올라감 (안내려감)
- 하락장: 라인이 계속 내려감 (안올라감)
```

### 매매 신호 화살표
```
초록 화살표 (위) = 매수 신호
- 가격이 스탑을 상향 돌파

빨간 화살표 (아래) = 매도 신호
- 가격이 스탑을 하향 돌파
```

### 정보 패널 (좌측 상단)
```
Status: ACTIVE / INITIALIZING
- ACTIVE (초록) = 정상 작동 중
- INITIALIZING (노랑) = 시작 중

Position: LONG / SHORT / NEUTRAL
- LONG (초록) = 매수 추세
- SHORT (빨강) = 매도 추세
- NEUTRAL (회색) = 중립

Trailing Stop: 현재 스탑 가격

ATR: 현재 변동성 지표

Spread: 현재 스프레드
- 초록 = 정상 범위
- 빨강 = MaxSpread 초과

Time Filter: ALLOWED / BLOCKED / DISABLED
- ALLOWED (초록) = 거래 허용 시간
- BLOCKED (빨강) = 거래 차단 시간
- DISABLED = 필터 비활성화

Open Positions: 열린 포지션 개수
```

---

## 🎯 통화쌍별 권장 설정

### EUR/USD (유로/달러)
```
KeyValue: 1.0
ATRPeriod: 10
MaxSpread: 20
RiskPercent: 2.0
TimeFilter: 
  StartHour: 8
  EndHour: 22
  (런던+뉴욕 세션)

특징: 안정적, 낮은 스프레드, 초보자에게 적합
```

### GBP/JPY (파운드/엔)
```
KeyValue: 0.8
ATRPeriod: 7
MaxSpread: 40
RiskPercent: 1.5
UseHeikinAshi: true

특징: 변동성 높음, 빠른 움직임, 경험자 추천
```

### XAU/USD (금/달러)
```
KeyValue: 1.2
ATRPeriod: 14
MaxSpread: 50
RiskPercent: 1.5
UseStopLoss: true

특징: 큰 변동성, 갭 발생, 보수적 설정 권장
```

### BTC/USD (비트코인)
```
KeyValue: 0.8
ATRPeriod: 10
MaxSpread: 100
RiskPercent: 1.0
AllowMultiplePositions: false

특징: 극도로 높은 변동성, 주의 필요
```

---

## 🔧 문제 해결

### EA가 거래하지 않는 경우

**1. AutoTrading 버튼 확인**
```
차트 상단의 AutoTrading 버튼이 초록색인지 확인
빨간색이면 클릭하여 활성화
```

**2. 전문가 탭 확인**
```
터미널 → 전문가 탭에서 오류 메시지 확인

일반적인 오류:
- "ATR 인디케이터 핸들 생성 실패"
  → EA 재시작 (차트에서 제거 후 다시 적용)

- "스프레드가 너무 높음"
  → MaxSpread 값 증가 또는 EnableSpreadFilter = false

- "거래 허용 시간이 아님"
  → UseTimeFilter = false 또는 시간 설정 확인
```

**3. 계좌 설정 확인**
```
도구 → 옵션 → Expert Advisors
- "자동매매 허용" 체크
- "DLL 가져오기 허용" 체크 (필요시)
```

### 너무 많은 신호가 발생하는 경우
```
해결책:
1. KeyValue 증가 (1.0 → 1.5)
2. ATRPeriod 증가 (10 → 15)
3. UseHeikinAshi = true
```

### 신호가 너무 적은 경우
```
해결책:
1. KeyValue 감소 (1.0 → 0.8)
2. ATRPeriod 감소 (10 → 7)
3. 다른 타임프레임 사용 (H1 → M15)
```

### 손절이 너무 잦은 경우
```
해결책:
1. KeyValue 증가 (더 넓은 스탑)
2. RiskPercent 감소 (더 작은 포지션)
3. 변동성 낮은 시간대에만 거래
```

---

## 📈 백테스팅 가이드

### 백테스트 수행 방법

**1. Strategy Tester 열기**
```
보기 → Strategy Tester (Ctrl + R)
```

**2. 설정**
```
Expert Advisor: UT_Bot_EA_Production
Symbol: EURUSD (또는 원하는 통화쌍)
Period: H1 (또는 원하는 타임프레임)
Dates: 최근 1년 (예: 2023.01.01 ~ 2024.01.01)
Deposit: 10000
Execution: Every tick (가장 정확)
Optimization: 비활성화 (처음에는)
```

**3. 입력 값 설정**
```
파라미터 탭에서 설정 조정
처음에는 기본값으로 시작
```

**4. 시작**
```
시작 버튼 클릭
결과 기다림 (수 분~수십 분 소요)
```

### 결과 분석

**좋은 결과 지표:**
```
✅ Total Net Profit: 양수 (수익)
✅ Profit Factor: > 1.5 (수익/손실 비율)
✅ Sharpe Ratio: > 1.0 (위험 대비 수익)
✅ Max Drawdown: < 20% (최대 손실)
✅ Win Rate: > 40% (승률)
```

**나쁜 결과 지표:**
```
❌ Total Net Profit: 음수 (손실)
❌ Profit Factor: < 1.0
❌ Max Drawdown: > 30%
❌ Recovery Factor: < 2.0
```

---

## ⚠️ 주의사항

### 필수 확인 사항

**1. 데모 계좌에서 먼저 테스트**
```
최소 2주 이상 데모 거래 후 실계좌 고려
다양한 시장 상황에서 테스트
```

**2. 적절한 자금 관리**
```
RiskPercent: 최대 2-3%
한 통화쌍에만 집중하지 말 것
전체 계좌의 10% 이상 리스크 노출 금지
```

**3. 시장 상황 모니터링**
```
주요 경제 지표 발표 시간 확인
큰 변동성 시기 주의
주말 갭에 주의
```

**4. EA 상태 정기 점검**
```
매일 1회 이상 차트 확인
전문가 탭 로그 확인
비정상 동작 시 즉시 중지
```

### 피해야 할 실수

**❌ 과도한 레버리지**
```
초보자: 최대 1:50
중급자: 최대 1:100
RiskPercent를 높이는 것보다 레버리지를 낮추는 것이 안전
```

**❌ 감정적 설정 변경**
```
손실 후 즉시 설정 변경 금지
최소 20-30거래 후 평가
체계적인 백테스트 기반 조정
```

**❌ 다중 EA 동시 사용**
```
같은 통화쌍에 여러 EA 사용 금지
신호 충돌 가능
```

**❌ 인터넷 연결 불안정**
```
VPS 사용 권장
안정적인 인터넷 필수
```

---

## 🚀 최적화 가이드

### 매개변수 최적화

**Strategy Tester에서:**
```
1. 최적화 활성화
2. 최적화할 파라미터 선택:
   - KeyValue: 0.5 ~ 2.0, Step 0.1
   - ATRPeriod: 5 ~ 20, Step 1
3. Optimization criterion: Balance + Profit Factor
4. 시작 (수 시간 소요)
```

**주의:**
```
⚠️ 과최적화(Overfitting) 위험
- 백테스트 기간 나누기 (In-sample / Out-sample)
- 여러 통화쌍에서 테스트
- Forward testing 필수
```

---

## 📞 지원 및 업데이트

### 로그 확인
```
터미널 → 전문가 탭
모든 거래 기록과 오류 메시지 확인
```

### 설정 백업
```
입력 탭 → 저장
.set 파일로 설정 저장
나중에 불러오기 가능
```

---

## 요약: 빠른 체크리스트

**EA 적용 전:**
```
☑ MetaTrader 5 업데이트 확인
☑ 데모 계좌 준비
☑ AutoTrading 활성화
☑ 인터넷 연결 안정적
```

**초기 설정:**
```
☑ KeyValue = 1.0
☑ ATRPeriod = 10
☑ LotSize = 0.01 (데모)
☑ RiskPercent = 2.0
☑ UseStopLoss = true
☑ AllowMultiplePositions = false
```

**일일 점검:**
```
☑ EA 작동 상태 확인
☑ 정보 패널 확인
☑ 열린 포지션 확인
☑ 전문가 탭 로그 확인
```

**주간 점검:**
```
☑ 수익/손실 분석
☑ 승률 확인
☑ 최대 손실(Drawdown) 확인
☑ 필요시 설정 조정
```

---

성공적인 자동매매를 기원합니다! 🎯

