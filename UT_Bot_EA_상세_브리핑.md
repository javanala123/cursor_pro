# UT Bot EA Production - 상세 브리핑 및 작동 원리

## 📋 목차
1. [전체 개요](#전체-개요)
2. [핵심 작동 원리](#핵심-작동-원리)
3. [주요 함수 설명](#주요-함수-설명)
4. [실행 흐름도](#실행-흐름도)
5. [매매 로직 상세](#매매-로직-상세)

---

## 🎯 전체 개요

### EA의 목적
**UT Bot EA**는 ATR(Average True Range) 기반의 동적 트레일링 스탑을 사용하여 자동으로 매매 신호를 생성하고 거래를 실행하는 Expert Advisor입니다.

### 기본 전략
```
ATR 트레일링 스탑 = 현재 가격 ± (ATR × Key Value)

매수 신호: 가격이 트레일링 스탑을 상향 돌파
매도 신호: 가격이 트레일링 스탑을 하향 돌파
```

---

## 🔄 핵심 작동 원리

### 1. **초기화 단계 (OnInit)**

```mql5
OnInit()
├── 거래 파라미터 설정 (MagicNumber, Slippage 등)
├── ATR 인디케이터 핸들 생성 ★ 중요!
│   └── g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod)
├── 시각적 객체 생성
│   ├── 트레일링 스탑 라인
│   └── 정보 패널
└── 초기화 완료 메시지 출력
```

**핵심 포인트:**
- MQL5에서는 ATR 값을 직접 가져올 수 없고 **핸들**을 먼저 생성해야 함
- 핸들 = 인디케이터에 대한 참조 번호 (파일 핸들과 유사한 개념)

### 2. **실시간 처리 단계 (OnTick)**

매 틱(가격 변동)마다 실행되는 메인 로직:

```
OnTick() - 매 틱마다 실행
│
├── 1단계: 사전 체크
│   ├── 충분한 바 개수 확인 (ATRPeriod + 1개 이상)
│   ├── 스프레드 필터 체크 (현재 스프레드 ≤ MaxSpread?)
│   └── 시간 필터 체크 (거래 허용 시간?)
│
├── 2단계: 데이터 수집
│   ├── 현재 종가 가져오기
│   ├── 소스 가격 계산 (Heikin Ashi or 종가)
│   └── ATR 값 가져오기 ★ CopyBuffer() 사용!
│
├── 3단계: 계산
│   ├── ATR 트레일링 스탑 계산
│   └── 포지션 상태 업데이트 (LONG/SHORT/NEUTRAL)
│
├── 4단계: 신호 감지 (새 바에서만)
│   ├── 크로스오버 감지
│   ├── 매수/매도 신호 판단
│   └── 거래 실행
│
└── 5단계: 업데이트
    ├── 차트 객체 업데이트
    └── 이전 값 저장
```

### 3. **종료 단계 (OnDeinit)**

```mql5
OnDeinit()
├── ATR 핸들 해제 ★ 중요! (메모리 누수 방지)
├── 차트 객체 제거
└── 종료 메시지 출력
```

---

## 🔍 주요 함수 상세 설명

### **OnInit() - 초기화 함수**

**역할:** EA가 차트에 적용될 때 한 번만 실행

**주요 작업:**
1. **거래 설정 초기화**
   ```mql5
   trade.SetExpertMagicNumber(MagicNumber);  // 이 EA의 거래 식별
   trade.SetDeviationInPoints(Slippage);     // 슬리피지 허용 범위
   trade.SetTypeFilling(ORDER_FILLING_FOK);  // 주문 체결 방식 (전부 아니면 취소)
   ```

2. **ATR 핸들 생성** ⭐ 가장 중요!
   ```mql5
   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
   if(g_atr_handle == INVALID_HANDLE)
       return(INIT_FAILED);  // 실패 시 EA 작동 중지
   ```
   - `iATR()`는 값이 아닌 **핸들(참조 번호)**을 반환
   - 이후 `CopyBuffer()`로 실제 ATR 값을 가져옴

3. **시각적 객체 생성**
   - 트레일링 스탑 라인: 파란색 수평선
   - 정보 패널: 좌측 상단 상태 표시

**반환값:**
- `INIT_SUCCEEDED`: 초기화 성공 → EA 작동 시작
- `INIT_FAILED`: 초기화 실패 → EA 작동 중지

---

### **OnTick() - 메인 로직 함수**

**역할:** 매 틱(가격 변동)마다 실행되는 핵심 함수

#### 단계별 동작:

**1단계: 사전 조건 체크**
```mql5
// 충분한 바 개수?
if(Bars(_Symbol, PERIOD_CURRENT) < ATRPeriod + 1)
    return;  // ATR 계산에 필요한 최소 바 개수 미달

// 스프레드 필터
if(EnableSpreadFilter && !CheckSpread())
    return;  // 스프레드가 너무 크면 거래 중지

// 시간 필터
if(UseTimeFilter && !IsTimeToTrade())
    return;  // 거래 허용 시간이 아니면 중지
```

**2단계: ATR 값 가져오기** ⭐ MQL5 핵심!
```mql5
// MQL5 방식: 핸들 → CopyBuffer → 값
double atr_buffer[];
ArraySetAsSeries(atr_buffer, true);  // 배열을 역순으로 (최신 데이터가 [0])
if(CopyBuffer(g_atr_handle, 0, 0, 1, atr_buffer) < 0)
{
    Print("ATR 값 가져오기 실패");
    return;
}
double atr = atr_buffer[0];  // 최신 ATR 값
```

**왜 이렇게 복잡한가?**
- MQL4: `double atr = iATR(symbol, period, atr_period, 0);` ✅ 간단
- MQL5: 핸들 시스템 사용 → 성능 향상, 메모리 효율적

**3단계: 트레일링 스탑 계산**
```mql5
CalculateATRTrailingStop(src, atr);
```
- Pine Script의 로직을 정확히 구현
- 상세 알고리즘은 아래 참조

**4단계: 신호 감지 (새 바에서만)**
```mql5
datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
if(currentBarTime != g_lastBarTime)  // 새 바가 생성되었을 때만
{
    CheckTradingSignals(src);  // 매매 신호 체크
    g_lastBarTime = currentBarTime;
}
```

**왜 새 바에서만?**
- 같은 바 내에서 여러 번 신호 발생 방지
- 노이즈 트레이딩 감소

---

### **CalculateATRTrailingStop() - 트레일링 스탑 계산**

**역할:** ATR 기반 동적 트레일링 스탑 계산

**알고리즘:**
```
nLoss = KeyValue × ATR  (스탑까지의 거리)

상황별 계산:

1. 첫 계산:
   TrailingStop = 현재가 - nLoss

2. 가격 상승 중 (src > 이전 스탑 && prevSrc > 이전 스탑):
   TrailingStop = MAX(이전 스탑, 현재가 - nLoss)
   → 스탑을 올리기만 하고 내리지 않음 (트레일링)

3. 가격 하락 중 (src < 이전 스탑 && prevSrc < 이전 스탑):
   TrailingStop = MIN(이전 스탑, 현재가 + nLoss)
   → 스탑을 내리기만 하고 올리지 않음

4. 방향 전환 (상향 돌파):
   TrailingStop = 현재가 - nLoss

5. 방향 전환 (하향 돌파):
   TrailingStop = 현재가 + nLoss
```

**시각화 예시:**
```
가격이 상승 중:
   │
120 │     ●  ← 현재가
115 │   ●
110 │ ●
105 │ ------- ← 트레일링 스탑 (계속 올라감)
100 │ ------- ← 이전 스탑 (더 이상 안내려감)
   │

가격이 하락 중:
   │
120 │ ------- ← 이전 스탑 (더 이상 안올라감)
115 │ ------- ← 트레일링 스탑 (계속 내려감)
110 │     ●
105 │   ●  ← 현재가
100 │ ●
   │
```

---

### **CheckTradingSignals() - 매매 신호 감지**

**역할:** 크로스오버를 감지하여 매수/매도 신호 생성

**신호 생성 로직:**

```mql5
// 1. EMA(1) 계산 (Pine Script 호환)
double ema = src;  // EMA(1)은 src 자체와 동일

// 2. 크로스오버 감지
bool above = (ema > g_xATRTrailingStop) && 
             (g_prevSrc <= g_prevATRTrailingStop);
// → 이전에는 스탑 아래, 현재는 스탑 위 = 상향 돌파

bool below = (ema < g_xATRTrailingStop) && 
             (g_prevSrc >= g_prevATRTrailingStop);
// → 이전에는 스탑 위, 현재는 스탑 아래 = 하향 돌파

// 3. 최종 신호 판단
bool buy = (src > g_xATRTrailingStop) && above;
bool sell = (src < g_xATRTrailingStop) && below;
```

**시각화:**
```
매수 신호 발생:

트레일링 스탑 -------
                     ╱ ← 가격이 위로 돌파! (BUY)
가격          ●  ●
            ●

매도 신호 발생:

가격          ●
            ●  ●
                  ╲ ← 가격이 아래로 돌파! (SELL)
트레일링 스탑 -------
```

---

### **ExecuteBuyOrder() / ExecuteSellOrder() - 주문 실행**

**역할:** 실제 매수/매도 주문 실행

**실행 순서:**

```mql5
ExecuteBuyOrder()
│
├── 1. 다중 포지션 체크
│   ├── AllowMultiplePositions = false?
│   │   ├── 기존 매도 포지션 청산
│   │   └── 매수 포지션 이미 있으면 중단
│   └── AllowMultiplePositions = true?
│       └── 그냥 진행 (여러 포지션 허용)
│
├── 2. 로트 크기 계산
│   └── CalculateLotSize()
│       ├── RiskPercent ≤ 0? → LotSize 사용
│       └── RiskPercent > 0? → 리스크 기반 계산
│
├── 3. 스탑로스/테이크프로핏 계산
│   ├── SL = UseStopLoss? 트레일링 스탑 : 0
│   └── TP = UseTakeProfit? 2배 거리 : 0
│
└── 4. 주문 실행
    └── trade.Buy(lotSize, _Symbol, ask, sl, tp, "UT Bot Buy")
```

---

### **CalculateLotSize() - 로트 크기 계산**

**역할:** 리스크 관리에 따른 적절한 포지션 크기 계산

**계산 방식:**

```
리스크 금액 = 계좌 잔고 × (RiskPercent / 100)

로트 크기 = 리스크 금액 / (스탑로스 거리 × 틱 가치)

예시:
- 계좌 잔고: $10,000
- RiskPercent: 2% → 리스크 금액 = $200
- 스탑로스 거리: 50 pips
- 틱 가치: $1 per pip (for 0.1 lot)
→ 로트 크기 = 200 / (50 × 1) = 4 lots

하지만:
- 최소 로트 (0.01) ~ 최대 로트 범위 내로 제한
- 로트 스텝 단위로 반올림
```

---

## 🎨 시각적 표시 기능

### 1. **트레일링 스탑 라인**
```mql5
CreateTrailingStopLine()
├── 객체 생성: OBJ_HLINE (수평선)
├── 색상: TrailingStopColor (기본 파란색)
├── 스타일: STYLE_DASH (점선)
└── 업데이트: 매 틱마다 가격 갱신
```

### 2. **매매 신호 화살표**
```mql5
CreateSignalArrow("BUY", price)
├── 매수: 위쪽 화살표 (코드 233), 초록색
└── 매도: 아래쪽 화살표 (코드 234), 빨간색
```

### 3. **정보 패널**
차트 좌측 상단에 실시간 정보 표시:
```
Status:          ACTIVE        (초록: 정상, 노랑: 초기화 중)
Position:        LONG          (초록: 롱, 빨강: 숏, 회색: 중립)
Trailing Stop:   1.08450       (현재 스탑 가격)
ATR:            0.00025        (현재 ATR 값)
Spread:         1.5 pts        (초록: 정상, 빨강: 초과)
Time Filter:    ALLOWED        (초록: 허용, 빨강: 차단)
Open Positions: 1              (노랑: 있음, 회색: 없음)
```

---

## 🛡️ 리스크 관리 시스템

### 1. **스프레드 필터**
```mql5
CheckSpread()
├── 현재 스프레드 계산 = (Ask - Bid) / Point
├── 스프레드 > MaxSpread?
│   ├── Yes: 거래 중지, 1시간마다 경고
│   └── No: 거래 허용
```

### 2. **시간 필터**
```mql5
IsTimeToTrade()
├── 요일 체크 (월~금 각각 설정)
└── 시간 체크 (StartHour ~ EndHour)
    └── 예: 8시~22시만 거래 (런던~뉴욕 세션)
```

### 3. **포지션 관리**
```
AllowMultiplePositions = false (기본):
- 매수 신호 → 기존 매도 청산 후 매수
- 한 번에 하나의 포지션만 유지

AllowMultiplePositions = true:
- 신호 발생마다 새 포지션 추가
- 여러 포지션 동시 보유 가능
```

---

## 📈 실행 흐름도

```
EA 시작
│
├─> OnInit()
│   ├─> ATR 핸들 생성 ★
│   ├─> 차트 객체 생성
│   └─> 초기화 완료
│
├─> [매 틱마다 반복]
│   │
│   OnTick()
│   ├─> 사전 체크 (바 개수, 스프레드, 시간)
│   ├─> 데이터 수집 (가격, ATR)
│   ├─> 트레일링 스탑 계산
│   ├─> 포지션 상태 업데이트
│   ├─> [새 바에서만]
│   │   └─> 신호 체크 → 거래 실행
│   └─> 차트 업데이트
│
└─> OnDeinit()
    ├─> ATR 핸들 해제 ★
    ├─> 차트 객체 제거
    └─> 종료
```

---

## 💡 핵심 포인트 요약

### MQL5의 핵심 개념

**1. 핸들 시스템**
```mql5
// ❌ MQL4 방식 (작동 안함)
double atr = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod, 0);

// ✅ MQL5 방식
int handle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);  // 핸들 생성
double buffer[];
CopyBuffer(handle, 0, 0, 1, buffer);  // 값 복사
double atr = buffer[0];  // 사용
IndicatorRelease(handle);  // 종료 시 해제
```

**2. 새 바 감지**
```mql5
datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
if(currentBarTime != g_lastBarTime)
{
    // 새 바에서만 실행할 코드
    g_lastBarTime = currentBarTime;
}
```

**3. 배열 순서**
```mql5
ArraySetAsSeries(array, true);  // 최신 데이터가 [0]
// array[0] = 현재 바
// array[1] = 이전 바
// array[2] = 2개 전 바
```

---

## 🔧 주요 설정 추천값

### 변동성 낮은 시장 (EUR/USD 런던 세션)
```
KeyValue = 1.5
ATRPeriod = 15
RiskPercent = 2.0
MaxSpread = 20
StartHour = 8
EndHour = 17
```

### 변동성 높은 시장 (GBP/JPY)
```
KeyValue = 0.8
ATRPeriod = 7
RiskPercent = 1.5
MaxSpread = 40
UseTimeFilter = false
```

### 보수적 설정
```
KeyValue = 2.0
ATRPeriod = 20
RiskPercent = 1.0
MaxSpread = 15
AllowMultiplePositions = false
```

---

이 브리핑을 통해 UT Bot EA의 전체 작동 원리와 각 부분의 역할을 이해하실 수 있습니다. 실제 코드에도 상세한 주석이 추가되어 있어 함께 보시면 더욱 명확하게 이해하실 수 있습니다.

