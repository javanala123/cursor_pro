# UT Bot Alerts Indicator - 오류 수정 가이드

## 🔧 수정된 오류들

Context7을 통해 MQL5의 최신 문법을 확인하여 다음 오류들을 수정했습니다:

### 1. ❌ `OnCalculate function not found in custom indicator`

**문제**: 인디케이터에 필수적인 `OnCalculate` 함수가 없었습니다.

**해결**:
```mql5
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    // 인디케이터 계산 로직
    return(rates_total);
}
```

### 2. ❌ `no indicator plot defined for indicator`

**문제**: 인디케이터 플롯이 정의되지 않았습니다.

**해결**:
```mql5
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   3

//--- Plot 1: Trailing Stop Line
#property indicator_label1  "Trailing Stop"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_style1  STYLE_DASH
#property indicator_width1  2

//--- Plot 2: Buy Signal
#property indicator_label2  "Buy Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrLime
#property indicator_width2  3

//--- Plot 3: Sell Signal
#property indicator_label3  "Sell Signal"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrRed
#property indicator_width3  3
```

### 3. ❌ `wrong parameters count for iATR`

**문제**: MQL5에서 `iATR()` 함수는 핸들을 반환하며, 직접 값을 반환하지 않습니다.

**잘못된 사용**:
```mql5
// ❌ 잘못됨 - MQL4 스타일
double atr = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod, 0);
```

**올바른 사용**:
```mql5
// ✅ MQL5 올바른 방법
// 1. OnInit()에서 핸들 생성
int atr_handle;

int OnInit()
{
    atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
    
    if(atr_handle == INVALID_HANDLE)
    {
        Print("Failed to create ATR indicator handle");
        return(INIT_FAILED);
    }
    return(INIT_SUCCEEDED);
}

// 2. OnCalculate()에서 CopyBuffer()로 값 가져오기
int OnCalculate(...)
{
    double ATRBuffer[];
    ArraySetAsSeries(ATRBuffer, true);
    
    if(CopyBuffer(atr_handle, 0, 0, rates_total, ATRBuffer) < 0)
    {
        Print("Failed to copy ATR buffer");
        return(0);
    }
    
    // 이제 ATRBuffer[i]로 ATR 값 사용 가능
    double atr_value = ATRBuffer[i];
}

// 3. OnDeinit()에서 핸들 해제
void OnDeinit(const int reason)
{
    if(atr_handle != INVALID_HANDLE)
        IndicatorRelease(atr_handle);
}
```

## 🎯 MQL5 인디케이터 핵심 개념

### 1. 인디케이터 핸들 시스템

MQL5에서는 MQL4와 달리 **핸들 기반 시스템**을 사용합니다:

```mql5
// 기술적 지표 함수들은 핸들을 반환
int iATR(symbol, period, ma_period)
int iMA(symbol, period, ma_period, ma_shift, ma_method, applied_price)
int iRSI(symbol, period, ma_period, applied_price)

// 값을 가져오려면 CopyBuffer() 사용
int CopyBuffer(indicator_handle, buffer_num, start_pos, count, buffer[])
```

### 2. 필수 함수들

```mql5
// 초기화
int OnInit()
{
    // 버퍼 매핑
    SetIndexBuffer(index, array[], type);
    
    // 인디케이터 핸들 생성
    handle = iATR(...);
    
    return(INIT_SUCCEEDED);
}

// 계산
int OnCalculate(const int rates_total, ...)
{
    // 메인 계산 로직
    return(rates_total);
}

// 종료
void OnDeinit(const int reason)
{
    // 핸들 해제
    IndicatorRelease(handle);
}
```

### 3. 버퍼 타입

```mql5
INDICATOR_DATA         // 플롯되는 데이터
INDICATOR_CALCULATIONS // 중간 계산용 (플롯 안됨)
INDICATOR_COLOR_INDEX  // 색상 인덱스
```

## 📋 수정된 파일 구조

```
UT_Bot_Alerts_Indicator.mq5
├── Property 선언
│   ├── indicator_chart_window
│   ├── indicator_buffers (5개)
│   └── indicator_plots (3개)
│
├── Input 매개변수
│   ├── KeyValue
│   ├── ATRPeriod
│   └── UseHeikinAshi
│
├── Indicator 버퍼
│   ├── TrailingStopBuffer (플롯)
│   ├── BuySignalBuffer (플롯)
│   ├── SellSignalBuffer (플롯)
│   ├── ATRBuffer (계산용)
│   └── PosBuffer (계산용)
│
├── OnInit()
│   ├── 버퍼 매핑
│   ├── 화살표 코드 설정
│   └── ATR 핸들 생성
│
├── OnDeinit()
│   └── ATR 핸들 해제
│
├── OnCalculate()
│   ├── ATR 값 복사
│   ├── 배열 시리즈 설정
│   ├── 메인 계산 루프
│   │   ├── 소스 가격 계산
│   │   ├── 트레일링 스탑 계산
│   │   ├── 포지션 상태 계산
│   │   └── 매매 신호 계산
│   └── rates_total 반환
│
└── CalculateHeikinAshiClose()
    └── Heikin Ashi 종가 계산
```

## ✨ 주요 특징

1. **3개의 플롯**:
   - 트레일링 스탑 라인 (파란색 점선)
   - 매수 신호 화살표 (초록색, 코드 233)
   - 매도 신호 화살표 (빨간색, 코드 234)

2. **2개의 계산 버퍼**:
   - ATR 값 저장
   - 포지션 상태 저장

3. **Heikin Ashi 지원**:
   - UseHeikinAshi = true로 설정 시 Heikin Ashi 캔들 사용

4. **효율적인 계산**:
   - prev_calculated를 사용하여 새로운 바만 계산
   - ArraySetAsSeries()로 배열 역순 정렬

## 🚀 사용 방법

### 1. 설치
```
1. MetaTrader 5 실행
2. 파일 → 데이터 폴더 열기
3. MQL5 → Indicators 폴더에 UT_Bot_Alerts_Indicator.mq5 복사
4. MetaEditor에서 컴파일 (F7)
```

### 2. 차트에 적용
```
1. 차트 열기
2. 네비게이터 → Indicators → Custom → UT Bot Alerts
3. 드래그하여 차트에 적용
4. 매개변수 설정:
   - Key Value: 1.0 (민감도)
   - ATR Period: 10 (ATR 계산 기간)
   - Use Heikin Ashi: false
```

### 3. 표시 요소
```
- 파란색 점선: ATR 트레일링 스탑
- 위쪽 화살표 (초록): 매수 신호
- 아래쪽 화살표 (빨강): 매도 신호
```

## 📊 차이점: Expert Advisor vs Indicator

| 특징 | Expert Advisor | Indicator |
|------|---------------|-----------|
| **파일 위치** | MQL5/Experts/ | MQL5/Indicators/ |
| **주요 함수** | OnTick() | OnCalculate() |
| **거래 실행** | ✅ 가능 | ❌ 불가능 |
| **차트 표시** | 제한적 | ✅ 전문적 |
| **용도** | 자동매매 | 분석 및 신호 표시 |
| **플롯** | 선택적 | 필수 |

## ⚠️ 주의사항

1. **인디케이터는 거래를 실행하지 않습니다**
   - 신호만 표시합니다
   - 자동매매를 원하면 Expert Advisor를 사용하세요

2. **핸들 관리**
   - OnInit()에서 생성
   - OnDeinit()에서 반드시 해제

3. **배열 방향**
   - MQL5는 기본적으로 left-to-right
   - ArraySetAsSeries(true)로 right-to-left 변경 가능

이제 컴파일 오류 없이 정상적으로 작동하는 UT Bot Alerts 인디케이터를 사용하실 수 있습니다!
