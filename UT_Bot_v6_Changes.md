# UT Bot Pine Script v6 컨버전 변경사항

## 개요
Pine Script v4에서 v6로 컨버전하면서 적용된 주요 변경사항과 개선사항을 설명합니다.

## 🔄 주요 변경사항

### 1. 버전 및 기본 구조
```pinescript
// v4
//@version=4
study(title="UT Bot Alerts", overlay = true)

// v6
//@version=6
indicator(title="UT Bot Alerts v6", shorttitle="UT Bot v6", overlay=true, 
          max_boxes_count=500, max_lines_count=500, max_labels_count=500)
```

**개선사항:**
- `study()` → `indicator()` 변경
- `shorttitle` 추가로 차트에서 더 간결한 표시
- 성능 최적화를 위한 최대 객체 수 제한

### 2. 입력 매개변수 개선
```pinescript
// v4
a = input(1,     title = "Key Vaule. 'This changes the sensitivity'")
c = input(10,    title = "ATR Period")
h = input(false, title = "Signals from Heikin Ashi Candles")

// v6
a = input.float(1.0, title="Key Value. 'This changes the sensitivity'", 
                minval=0.1, maxval=10.0, step=0.1, 
                tooltip="Higher values make the strategy less sensitive to price movements")
c = input.int(10, title="ATR Period", minval=1, maxval=100, 
              tooltip="Period for Average True Range calculation")
h = input.bool(false, title="Signals from Heikin Ashi Candles", 
               tooltip="Use Heikin Ashi candles instead of regular candles")
```

**개선사항:**
- 타입별 입력 함수 사용 (`input.float()`, `input.int()`, `input.bool()`)
- 입력 값 범위 제한 (`minval`, `maxval`)
- 단계별 증가값 설정 (`step`)
- 도움말 툴팁 추가 (`tooltip`)
- 오타 수정 ("Vaule" → "Value")

### 3. 기술적 분석 함수 네임스페이스
```pinescript
// v4
xATR = atr(c)
ema = ema(src,1)
above = crossover(ema, xATRTrailingStop)
below = crossover(xATRTrailingStop, ema)

// v6
xATR = ta.atr(c)
ema = ta.ema(src, 1)
above = ta.crossover(ema, xATRTrailingStop)
below = ta.crossover(xATRTrailingStop, ema)
```

**개선사항:**
- 모든 기술적 분석 함수에 `ta.` 네임스페이스 적용
- 코드 가독성 향상
- 함수 충돌 방지

### 4. 데이터 요청 함수 개선
```pinescript
// v4
src = h ? security(heikinashi(syminfo.tickerid), timeframe.period, close, lookahead = false) : close

// v6
src = h ? request.security(ta.heikinashi(syminfo.tickerid), timeframe.period, close, 
                          lookahead=barmerge.lookahead_off) : close
```

**개선사항:**
- `security()` → `request.security()` 변경
- `heikinashi()` → `ta.heikinashi()` 변경
- `lookahead = false` → `lookahead=barmerge.lookahead_off` 변경
- 더 명확한 문법

### 5. 변수 선언 및 타입 개선
```pinescript
// v4
xATRTrailingStop = 0.0
pos = 0

// v6
var float xATRTrailingStop = na
var int pos = 0
```

**개선사항:**
- 명시적 타입 선언 (`float`, `int`)
- `var` 키워드로 상태 유지
- `na` 값으로 초기화

### 6. 조건문 개선
```pinescript
// v4
xATRTrailingStop := iff(src > nz(xATRTrailingStop[1], 0) and src[1] > nz(xATRTrailingStop[1], 0), 
                        max(nz(xATRTrailingStop[1]), src - nLoss),
                        iff(src < nz(xATRTrailingStop[1], 0) and src[1] < nz(xATRTrailingStop[1], 0), 
                            min(nz(xATRTrailingStop[1]), src + nLoss), 
                            iff(src > nz(xATRTrailingStop[1], 0), src - nLoss, src + nLoss)))

// v6
xATRTrailingStop := if na(xATRTrailingStop[1])
    src - nLoss
else
    if src > xATRTrailingStop[1] and src[1] > xATRTrailingStop[1]
        math.max(xATRTrailingStop[1], src - nLoss)
    else if src < xATRTrailingStop[1] and src[1] < xATRTrailingStop[1]
        math.min(xATRTrailingStop[1], src + nLoss)
    else if src > xATRTrailingStop[1]
        src - nLoss
    else
        src + nLoss
```

**개선사항:**
- `iff()` → `if-else` 구조로 변경
- `nz()` → `na()` 체크로 변경
- `max()` → `math.max()`, `min()` → `math.min()` 변경
- 더 읽기 쉬운 코드 구조

## 🆕 v6에서 추가된 새로운 기능

### 1. 향상된 시각화
- **그룹화된 입력**: 관련 설정들을 그룹으로 분류
- **색상 투명도**: `color.new()` 함수로 투명도 조절
- **툴팁**: 마우스 오버 시 상세 정보 표시
- **정보 테이블**: 차트 우상단에 실시간 상태 표시

### 2. 개선된 알림 시스템
```pinescript
// v6 알림 개선
alertcondition(buy, "UT Long Alert", "UT Bot: Long signal detected at {{close}}", alert.freq_once_per_bar)
alertcondition(sell, "UT Short Alert", "UT Bot: Short signal detected at {{close}}", alert.freq_once_per_bar)
```

**개선사항:**
- 더 상세한 알림 메시지
- 알림 빈도 제어
- 동적 값 삽입 (`{{close}}`)

### 3. 성능 최적화
- **최대 객체 수 제한**: 차트 성능 향상
- **효율적인 계산**: v6의 최적화된 함수 사용
- **메모리 관리**: `var` 키워드로 상태 유지

### 4. 사용자 경험 개선
- **배경 색상**: 포지션 상태에 따른 배경 색상
- **신호 크기 선택**: 사용자가 신호 크기 조절 가능
- **실시간 정보**: 현재 상태를 한눈에 확인 가능

## 🎯 사용법

### 1. 기본 설정
- **Key Value**: 0.5-2.0 범위에서 민감도 조절
- **ATR Period**: 5-20 범위에서 ATR 계산 기간 설정
- **Heikin Ashi**: 노이즈가 많은 시장에서 활성화

### 2. 표시 설정
- **Show Trailing Stop Line**: 트레일링 스탑 라인 표시
- **Show Buy/Sell Signals**: 매매 신호 화살표 표시
- **Signal Size**: 신호 크기 조절

### 3. 알림 설정
- **Enable Alerts**: 알림 활성화/비활성화
- **Alert Frequency**: 알림 빈도 설정

## 🔧 기술적 개선사항

### 1. 타입 안전성
- 명시적 타입 선언으로 오류 방지
- 컴파일 타임 오류 검출

### 2. 성능 최적화
- v6의 최적화된 함수 사용
- 메모리 사용량 최적화

### 3. 코드 가독성
- 더 명확한 함수명과 구조
- 주석과 툴팁으로 이해도 향상

## 📊 호환성

- **TradingView**: v6 지원하는 모든 계정
- **모바일**: 모바일 앱에서도 완전 지원
- **성능**: v4 대비 향상된 실행 속도

이 v6 컨버전은 원본 v4의 모든 기능을 유지하면서도 현대적인 Pine Script의 장점을 최대한 활용한 개선된 버전입니다.
