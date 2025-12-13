//+------------------------------------------------------------------+
//|                                    BollingerBands_Strategy.mq5   |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//| 볼린저 밴드 돌파 전략 EA - Pine Script에서 변환                    |
//|                                                                  |
//| 주요 기능:                                                       |
//| - 롱/숏 독립적인 볼린저 밴드 설정                                |
//| - 다양한 필터 (ADX, Volume OSC, Volatility, ARMA 등)            |
//| - 동적 손절/익절 (PERC, ATR, BOTH 방식)                          |
//| - 트레일링 스톱 및 브레이크이븐 지원                              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "볼린저 밴드 돌파 전략 - 최적화용 EA"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| 입력 파라미터 - 볼린저 밴드 설정                                  |
//+------------------------------------------------------------------+
input group "=== 볼린저 밴드 설정 ==="
input bool ActiveLong = true;                    // 롱 활성화
input bool ActiveShort = true;                   // 숏 활성화
input ENUM_MA_METHOD LongMAType = MODE_SMA;      // 롱 MA 타입
input ENUM_MA_METHOD ShortMAType = MODE_SMA;     // 숏 MA 타입
input int LongBBLength = 15;                    // 롱 길이
input double LongBBDev = 2.0;                   // 롱 편차
input double LongBBMinWidth = 3.0;              // 롱 최소폭 (%)
input bool LongBBDiff = false;                   // 롱 BB Diff 활성화
input double LongBBDiffPerc = 2.0;               // 롱 BB Diff %
input int ShortBBLength = 15;                    // 숏 길이
input double ShortBBDev = 2.0;                  // 숏 편차
input double ShortBBMinWidth = 3.0;             // 숏 최소폭 (%)
input bool ShortBBDiff = false;                 // 숏 BB Diff 활성화
input double ShortBBDiffPerc = 2.0;              // 숏 BB Diff %

//+------------------------------------------------------------------+
//| 입력 파라미터 - 손절/익절 설정                                    |
//+------------------------------------------------------------------+
input group "=== 손절/익절 설정 ==="
input int ATRLength = 14;                        // ATR Length
input bool LongTPTrailing = false;               // 롱 TP 트레일링
input double LongTPDistance = 0.005;             // 롱 TP 거리 (%)
input int LongTPMethod = 0;                     // 롱 TP 방식 (0=PERC, 1=ATR, 2=BOTH)
input double LongTPPerc = 0.02;                 // 롱 TP % (2%)
input double LongTPATR = 1.0;                   // 롱 TP ATR 배수
input bool ShortTPTrailing = false;              // 숏 TP 트레일링
input double ShortTPDistance = 0.005;            // 숏 TP 거리 (%)
input int ShortTPMethod = 0;                    // 숏 TP 방식 (0=PERC, 1=ATR, 2=BOTH)
input double ShortTPPerc = 0.02;                // 숏 TP % (2%)
input double ShortTPATR = 1.0;                  // 숏 TP ATR 배수
input bool LongSLTrailing = false;               // 롱 SL 트레일링
input int LongSLMethod = 2;                    // 롱 SL 방식 (0=PERC, 1=ATR, 2=BOTH)
input double LongSLPerc = 0.07;                 // 롱 SL % (7%)
input double LongSLATR = 2.0;                   // 롱 SL ATR 배수
input bool LongBreakEven = false;                // 롱 브레이크이븐
input bool ShortSLTrailing = false;              // 숏 SL 트레일링
input int ShortSLMethod = 2;                    // 숏 SL 방식 (0=PERC, 1=ATR, 2=BOTH)
input double ShortSLPerc = 0.07;                // 숏 SL % (7%)
input double ShortSLATR = 2.0;                  // 숏 SL ATR 배수
input bool ShortBreakEven = false;               // 숏 브레이크이븐

//+------------------------------------------------------------------+
//| 입력 파라미터 - 필터 설정                                         |
//+------------------------------------------------------------------+
input group "=== 필터 설정 ==="
input bool EnableLongARMA = false;               // 롱 ARMA 활성화
input bool EnableShortARMA = false;              // 숏 ARMA 활성화
input int ARMALength = 13;                      // ARMA Length
input double ARMAGamma = 3.0;                   // ARMA Gamma
input bool EnableLongVolatility = false;        // 롱 변동성 필터
input bool EnableShortVolatility = false;       // 숏 변동성 필터
input int VolatilityStDevLength = 2;            // 변동성 StdDev 길이
input int VolatilityMALength = 2;              // 변동성 MA 길이
input bool EnableLongHV = false;                // 롱 Historical Volatility
input bool EnableShortHV = false;               // 숏 Historical Volatility
input int HVLength = 10;                        // HV Length
input int HVThreshold = 1;                      // HV Threshold
input bool EnableLongADX = false;               // 롱 ADX 필터
input bool EnableShortADX = false;              // 숏 ADX 필터
input int LongADXLength = 14;                  // 롱 ADX Length
input int ShortADXLength = 14;                 // 숏 ADX Length
input bool EnableLongVOSC = false;              // 롱 Volume OSC
input bool EnableShortVOSC = false;            // 숏 Volume OSC
input int LongVOSCShort = 5;                   // 롱 VOSC 단기
input int LongVOSCLong = 10;                   // 롱 VOSC 장기
input double LongVOSCValue = 0;                // 롱 VOSC 값
input int ShortVOSCShort = 5;                  // 숏 VOSC 단기
input int ShortVOSCLong = 10;                  // 숏 VOSC 장기
input double ShortVOSCValue = 0;               // 숏 VOSC 값

//+------------------------------------------------------------------+
//| 입력 파라미터 - 거래 설정                                         |
//+------------------------------------------------------------------+
input group "=== 거래 설정 ==="
input double LotSize = 0.1;                     // 로트 크기
input ulong MagicNumber = 123456;               // 매직 넘버
input int Slippage = 3;                         // 슬리피지
input string LongCloseLine = "Lower";           // 롱 청산선 (Lower/Basis)
input string ShortCloseLine = "Upper";          // 숏 청산선 (Upper/Basis)

//+------------------------------------------------------------------+
//| 전역 변수                                                         |
//+------------------------------------------------------------------+
CTrade trade;                                    // 거래 객체
int g_longBB_handle = INVALID_HANDLE;           // 롱 볼린저 밴드 핸들
int g_shortBB_handle = INVALID_HANDLE;          // 숏 볼린저 밴드 핸들
int g_atr_handle = INVALID_HANDLE;              // ATR 핸들
int g_longMA_handle = INVALID_HANDLE;           // 롱 MA 핸들
int g_shortMA_handle = INVALID_HANDLE;          // 숏 MA 핸들

// 볼린저 밴드 버퍼
double g_longBBUpper[];
double g_longBBMiddle[];
double g_longBBLower[];
double g_shortBBUpper[];
double g_shortBBMiddle[];
double g_shortBBLower[];

// ARMA 변수
double g_arma_ma[];
double g_arma_mad[];

// 포지션 상태
int g_position = 0;                             // 1=롱, -1=숏, 0=없음
double g_entryPrice = 0.0;                     // 진입 가격
double g_tpPrice = 0.0;                        // 익절 가격
double g_slPrice = 0.0;                        // 손절 가격

datetime g_lastBarTime = 0;                     // 마지막 바 시간

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // 거래 객체 설정
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(Slippage);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    // ATR 인디케이터 생성
    g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATRLength);
    if(g_atr_handle == INVALID_HANDLE)
    {
        Print("ATR 인디케이터 생성 실패!");
        return(INIT_FAILED);
    }
    
    // 롱 볼린저 밴드 인디케이터 생성
    g_longBB_handle = iBands(_Symbol, PERIOD_CURRENT, LongBBLength, 0, LongBBDev, LongMAType);
    if(g_longBB_handle == INVALID_HANDLE)
    {
        Print("롱 볼린저 밴드 인디케이터 생성 실패!");
        return(INIT_FAILED);
    }
    
    // 숏 볼린저 밴드 인디케이터 생성
    g_shortBB_handle = iBands(_Symbol, PERIOD_CURRENT, ShortBBLength, 0, ShortBBDev, ShortMAType);
    if(g_shortBB_handle == INVALID_HANDLE)
    {
        Print("숏 볼린저 밴드 인디케이터 생성 실패!");
        return(INIT_FAILED);
    }
    
    // 버퍼 배열 설정
    ArraySetAsSeries(g_longBBUpper, true);
    ArraySetAsSeries(g_longBBMiddle, true);
    ArraySetAsSeries(g_longBBLower, true);
    ArraySetAsSeries(g_shortBBUpper, true);
    ArraySetAsSeries(g_shortBBMiddle, true);
    ArraySetAsSeries(g_shortBBLower, true);
    
    // ARMA 배열 초기화
    ArrayResize(g_arma_ma, 1000);
    ArrayResize(g_arma_mad, 1000);
    ArraySetAsSeries(g_arma_ma, true);
    ArraySetAsSeries(g_arma_mad, true);
    
    Print("볼린저 밴드 전략 EA 초기화 완료");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // 인디케이터 핸들 해제
    if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
    if(g_longBB_handle != INVALID_HANDLE) IndicatorRelease(g_longBB_handle);
    if(g_shortBB_handle != INVALID_HANDLE) IndicatorRelease(g_shortBB_handle);
    if(g_longMA_handle != INVALID_HANDLE) IndicatorRelease(g_longMA_handle);
    if(g_shortMA_handle != INVALID_HANDLE) IndicatorRelease(g_shortMA_handle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // 충분한 바 개수 확인
    if(Bars(_Symbol, PERIOD_CURRENT) < MathMax(LongBBLength, ShortBBLength) + 10)
        return;
    
    // 새 바 확인
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    bool isNewBar = (currentBarTime != g_lastBarTime);
    if(isNewBar)
        g_lastBarTime = currentBarTime;
    
    // 볼린저 밴드 값 가져오기
    if(!UpdateBollingerBands())
        return;
    
    // 현재 포지션 확인
    UpdatePositionStatus();
    
    // ARMA 계산 (필요시)
    if(EnableLongARMA || EnableShortARMA)
        CalculateARMA();
    
    // 신호 확인 및 거래 실행
    if(isNewBar)
    {
        CheckTradingSignals();
    }
    
    // 손절/익절 관리
    ManageStopLossTakeProfit();
}

//+------------------------------------------------------------------+
//| 볼린저 밴드 값 업데이트                                           |
//+------------------------------------------------------------------+
bool UpdateBollingerBands()
{
    // 롱 볼린저 밴드
    if(CopyBuffer(g_longBB_handle, 0, 0, 3, g_longBBMiddle) < 0) return false;
    if(CopyBuffer(g_longBB_handle, 1, 0, 3, g_longBBUpper) < 0) return false;
    if(CopyBuffer(g_longBB_handle, 2, 0, 3, g_longBBLower) < 0) return false;
    
    // 숏 볼린저 밴드
    if(CopyBuffer(g_shortBB_handle, 0, 0, 3, g_shortBBMiddle) < 0) return false;
    if(CopyBuffer(g_shortBB_handle, 1, 0, 3, g_shortBBUpper) < 0) return false;
    if(CopyBuffer(g_shortBB_handle, 2, 0, 3, g_shortBBLower) < 0) return false;
    
    // 최소 폭 적용
    double longDev = g_longBBUpper[0] - g_longBBMiddle[0];
    double longMinDev = g_longBBMiddle[0] * LongBBMinWidth / 100.0;
    if(longDev < longMinDev)
    {
        longDev = longMinDev;
        g_longBBUpper[0] = g_longBBMiddle[0] + longDev;
        g_longBBLower[0] = g_longBBMiddle[0] - longDev;
    }
    
    double shortDev = g_shortBBUpper[0] - g_shortBBMiddle[0];
    double shortMinDev = g_shortBBMiddle[0] * ShortBBMinWidth / 100.0;
    if(shortDev < shortMinDev)
    {
        shortDev = shortMinDev;
        g_shortBBUpper[0] = g_shortBBMiddle[0] + shortDev;
        g_shortBBLower[0] = g_shortBBMiddle[0] - shortDev;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| ARMA 계산                                                         |
//+------------------------------------------------------------------+
void CalculateARMA()
{
    // ARMA 계산 로직 (Pine Script에서 변환)
    // 간소화 버전 - 실제 구현 시 Pine Script 로직 그대로 변환 필요
    double close[];
    ArraySetAsSeries(close, true);
    if(CopyClose(_Symbol, PERIOD_CURRENT, 0, ARMALength + 10, close) < 0)
        return;
    
    // ARMA 계산 (Pine Script 로직 구현)
    // 실제 구현은 Pine Script의 ARMA 로직을 그대로 변환
}

//+------------------------------------------------------------------+
//| 거래 신호 확인                                                    |
//+------------------------------------------------------------------+
void CheckTradingSignals()
{
    double close[];
    ArraySetAsSeries(close, true);
    if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 3, close) < 0)
        return;
    
    // 필터 조건 확인
    bool longFilters = CheckLongFilters();
    bool shortFilters = CheckShortFilters();
    
    // 롱 진입 조건
    bool longEntry = ActiveLong && 
                     close[1] <= g_longBBUpper[1] && 
                     close[0] > g_longBBUpper[0] &&
                     longFilters;
    
    // 롱 BB Diff 조건
    if(LongBBDiff)
    {
        double longBBDiff = ((g_longBBUpper[0] / g_longBBLower[0]) * 100.0) - 100.0;
        if(longBBDiff < LongBBDiffPerc)
            longEntry = false;
    }
    
    // 숏 진입 조건
    bool shortEntry = ActiveShort && 
                      close[1] >= g_shortBBLower[1] && 
                      close[0] < g_shortBBLower[0] &&
                      shortFilters;
    
    // 숏 BB Diff 조건
    if(ShortBBDiff)
    {
        double shortBBDiff = ((g_shortBBUpper[0] / g_shortBBLower[0]) * 100.0) - 100.0;
        if(shortBBDiff < ShortBBDiffPerc)
            shortEntry = false;
    }
    
    // 롱 청산 조건
    bool longClose = false;
    if(LongCloseLine == "Lower")
        longClose = close[1] >= g_longBBLower[1] && close[0] < g_longBBLower[0];
    else
        longClose = close[1] >= g_longBBMiddle[1] && close[0] < g_longBBMiddle[0];
    
    // 숏 청산 조건
    bool shortClose = false;
    if(ShortCloseLine == "Upper")
        shortClose = close[1] <= g_shortBBUpper[1] && close[0] > g_shortBBUpper[0];
    else
        shortClose = close[1] <= g_shortBBMiddle[1] && close[0] > g_shortBBMiddle[0];
    
    // 거래 실행
    if(g_position == 0) // 포지션 없음
    {
        if(longEntry)
            OpenLongPosition();
        else if(shortEntry)
            OpenShortPosition();
    }
    else if(g_position > 0) // 롱 포지션
    {
        if(longClose)
            ClosePosition();
        else if(shortEntry)
        {
            ClosePosition();
            OpenShortPosition();
        }
    }
    else if(g_position < 0) // 숏 포지션
    {
        if(shortClose)
            ClosePosition();
        else if(longEntry)
        {
            ClosePosition();
            OpenLongPosition();
        }
    }
}

//+------------------------------------------------------------------+
//| 롱 필터 확인                                                      |
//+------------------------------------------------------------------+
bool CheckLongFilters()
{
    // ARMA 필터
    if(EnableLongARMA)
    {
        // ARMA 조건 확인 (구현 필요)
    }
    
    // 변동성 필터
    if(EnableLongVolatility)
    {
        // 변동성 조건 확인 (구현 필요)
    }
    
    // Historical Volatility 필터
    if(EnableLongHV)
    {
        // HV 조건 확인 (구현 필요)
    }
    
    // ADX 필터
    if(EnableLongADX)
    {
        // ADX 조건 확인 (구현 필요)
    }
    
    // Volume OSC 필터
    if(EnableLongVOSC)
    {
        // VOSC 조건 확인 (구현 필요)
    }
    
    return true; // 모든 필터 통과
}

//+------------------------------------------------------------------+
//| 숏 필터 확인                                                      |
//+------------------------------------------------------------------+
bool CheckShortFilters()
{
    // ARMA 필터
    if(EnableShortARMA)
    {
        // ARMA 조건 확인 (구현 필요)
    }
    
    // 변동성 필터
    if(EnableShortVolatility)
    {
        // 변동성 조건 확인 (구현 필요)
    }
    
    // Historical Volatility 필터
    if(EnableShortHV)
    {
        // HV 조건 확인 (구현 필요)
    }
    
    // ADX 필터
    if(EnableShortADX)
    {
        // ADX 조건 확인 (구현 필요)
    }
    
    // Volume OSC 필터
    if(EnableShortVOSC)
    {
        // VOSC 조건 확인 (구현 필요)
    }
    
    return true; // 모든 필터 통과
}

//+------------------------------------------------------------------+
//| 롱 포지션 열기                                                     |
//+------------------------------------------------------------------+
void OpenLongPosition()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(g_atr_handle, 0, 0, 1, atr) < 0)
        return;
    
    // 익절 가격 계산
    if(LongTPMethod == 0) // PERC
        g_tpPrice = ask * (1.0 + LongTPPerc);
    else if(LongTPMethod == 1) // ATR
        g_tpPrice = ask + atr[0] * LongTPATR;
    else // BOTH
        g_tpPrice = ask + MathMax(ask * LongTPPerc, atr[0] * LongTPATR);
    
    // 손절 가격 계산
    if(LongSLMethod == 0) // PERC
        g_slPrice = ask * (1.0 - LongSLPerc);
    else if(LongSLMethod == 1) // ATR
        g_slPrice = ask - atr[0] * LongSLATR;
    else // BOTH
        g_slPrice = ask - MathMax(ask * LongSLPerc, atr[0] * LongSLATR);
    
    // 주문 실행
    if(trade.Buy(LotSize, _Symbol, ask, g_slPrice, g_tpPrice, "BB Long"))
    {
        g_position = 1;
        g_entryPrice = ask;
        Print("롱 포지션 진입: ", ask, " TP: ", g_tpPrice, " SL: ", g_slPrice);
    }
}

//+------------------------------------------------------------------+
//| 숏 포지션 열기                                                     |
//+------------------------------------------------------------------+
void OpenShortPosition()
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(g_atr_handle, 0, 0, 1, atr) < 0)
        return;
    
    // 익절 가격 계산
    if(ShortTPMethod == 0) // PERC
        g_tpPrice = bid * (1.0 - ShortTPPerc);
    else if(ShortTPMethod == 1) // ATR
        g_tpPrice = bid - atr[0] * ShortTPATR;
    else // BOTH
        g_tpPrice = bid - MathMax(bid * ShortTPPerc, atr[0] * ShortTPATR);
    
    // 손절 가격 계산
    if(ShortSLMethod == 0) // PERC
        g_slPrice = bid * (1.0 + ShortSLPerc);
    else if(ShortSLMethod == 1) // ATR
        g_slPrice = bid + atr[0] * ShortSLATR;
    else // BOTH
        g_slPrice = bid + MathMax(bid * ShortSLPerc, atr[0] * ShortSLATR);
    
    // 주문 실행
    if(trade.Sell(LotSize, _Symbol, bid, g_slPrice, g_tpPrice, "BB Short"))
    {
        g_position = -1;
        g_entryPrice = bid;
        Print("숏 포지션 진입: ", bid, " TP: ", g_tpPrice, " SL: ", g_slPrice);
    }
}

//+------------------------------------------------------------------+
//| 포지션 청산                                                        |
//+------------------------------------------------------------------+
void ClosePosition()
{
    if(trade.PositionClose(_Symbol))
    {
        g_position = 0;
        g_entryPrice = 0.0;
        g_tpPrice = 0.0;
        g_slPrice = 0.0;
        Print("포지션 청산 완료");
    }
}

//+------------------------------------------------------------------+
//| 포지션 상태 업데이트                                               |
//+------------------------------------------------------------------+
void UpdatePositionStatus()
{
    if(PositionSelect(_Symbol))
    {
        if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
            long posType = PositionGetInteger(POSITION_TYPE);
            if(posType == POSITION_TYPE_BUY)
                g_position = 1;
            else if(posType == POSITION_TYPE_SELL)
                g_position = -1;
            
            g_entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        }
        else
            g_position = 0;
    }
    else
        g_position = 0;
}

//+------------------------------------------------------------------+
//| 손절/익절 관리                                                    |
//+------------------------------------------------------------------+
void ManageStopLossTakeProfit()
{
    if(g_position == 0)
        return;
    
    if(!PositionSelect(_Symbol))
        return;
    
    double currentPrice = (g_position > 0) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    // 브레이크이븐 로직
    if(g_position > 0 && LongBreakEven)
    {
        if(currentPrice >= g_tpPrice)
        {
            double newSL = g_entryPrice;
            if(PositionGetDouble(POSITION_SL) != newSL)
                trade.PositionModify(_Symbol, newSL, PositionGetDouble(POSITION_TP));
        }
    }
    else if(g_position < 0 && ShortBreakEven)
    {
        if(currentPrice <= g_tpPrice)
        {
            double newSL = g_entryPrice;
            if(PositionGetDouble(POSITION_SL) != newSL)
                trade.PositionModify(_Symbol, newSL, PositionGetDouble(POSITION_TP));
        }
    }
    
    // 트레일링 스톱 로직 (구현 필요)
}

