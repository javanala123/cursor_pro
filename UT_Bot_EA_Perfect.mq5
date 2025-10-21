//+------------------------------------------------------------------+
//|                                          UT_Bot_EA_Perfect.mq5   |
//|                        Copyright 2024, MetaQuotes Software Corp.|
//|                                             https://www.mql5.com|
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "4.00"
#property description "UT Bot EA - 완벽 버전 (Pine Script 완전 일치)"

#include <Trade\Trade.mqh>

//--- 입력 파라미터
input double KeyValue = 1.0;           // Key Value (민감도)
input int ATRPeriod = 10;              // ATR Period
input double LotSize = 0.01;           // 로트 크기
input bool AutoTrade = false;          // 자동매매 사용
input long MagicNumber = 12345;        // 매직 넘버
// 가격 소스 선택: 0=Close, 1=HeikinAshi Close, 2=Typical(H+L+C)/3, 3=Median(H+L)/2
input int PriceSource = 0;             // TV와 데이터 소스 차이를 보정하기 위한 옵션

//--- 화살표 설정
input int ArrowDistance = 100;         // 화살표 거리 (포인트) - 봉과 떨어진 거리
input color BuyArrowColor = clrLime;   // 매수 화살표 색깔 (밝은 초록)
input color SellArrowColor = clrRed;   // 매도 화살표 색깔 (빨강)
input int BuyArrowCode = 233;          // 매수 화살표 코드 (위쪽 화살표)
input int SellArrowCode = 234;         // 매도 화살표 코드 (아래쪽 화살표)
input int ArrowWidth = 3;              // 화살표 두께

//--- 전역 변수
int atr_handle;
datetime lastBarTime = 0;
CTrade trade;

// ATR Trailing Stop 히스토리 저장 (연속성 유지)
struct StopHistory
{
    datetime time;
    double stop;
};
StopHistory stopHistory[];
int historySize = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // ATR 지표만 초기화 (EMA는 사용하지 않음 - EMA(1) ≈ close)
    atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
    
    if(atr_handle == INVALID_HANDLE)
    {
        Print("❌ ATR 지표 초기화 실패");
        return INIT_FAILED;
    }
    
    trade.SetExpertMagicNumber(MagicNumber);
    
    Print("✅ UT Bot 시작 - KeyValue:", KeyValue, " ATRPeriod:", ATRPeriod);
    
    // 설정 변경 시 즉시 반영: 기존 화살표 제거 후 재계산
    ObjectsDeleteAll(0, "UTB_");
    ChartRedraw(0);
    
    // 히스토리 배열 초기화
    ArrayResize(stopHistory, 1000);
    historySize = 0;
    
    // 초기화 시 모든 과거 봉 계산
    CalculateAllSignals();
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(atr_handle != INVALID_HANDLE)
        IndicatorRelease(atr_handle);
    
    ObjectsDeleteAll(0, "UTB_");
    
    Print("🔄 UT Bot 종료");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(currentBarTime == lastBarTime)
        return;
    
    lastBarTime = currentBarTime;
    
    // 새 봉 시작 시 이전 봉(완성된 봉) 신호 확인
    CheckNewBarSignal();
}

//+------------------------------------------------------------------+
//| 모든 과거 봉의 신호 계산                                         |
//+------------------------------------------------------------------+
void CalculateAllSignals()
{
    int totalBars = iBars(_Symbol, PERIOD_CURRENT);
    int visibleBars = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
    int barsToCalculate = MathMin(totalBars - 1, visibleBars + 100);
    
    if(barsToCalculate < 2)
    {
        Print("❌ 계산할 봉이 부족합니다");
        return;
    }
    
    Print("📊 과거 신호 계산 시작 - 총 ", barsToCalculate, "개 봉");
    
    // 데이터 가져오기 (완성된 봉만, EMA는 사용 안 함!)
    double atr[];
    double open[];
    double high[];
    double low[];
    double close[];
    datetime time[];
    
    if(CopyBuffer(atr_handle, 0, 1, barsToCalculate, atr) <= 0)
    {
        Print("❌ ATR 데이터 복사 실패");
        return;
    }
    if(CopyOpen(_Symbol, PERIOD_CURRENT, 1, barsToCalculate, open) <= 0)
    {
        Print("❌ Open 데이터 복사 실패");
        return;
    }
    if(CopyHigh(_Symbol, PERIOD_CURRENT, 1, barsToCalculate, high) <= 0)
    {
        Print("❌ High 데이터 복사 실패");
        return;
    }
    if(CopyLow(_Symbol, PERIOD_CURRENT, 1, barsToCalculate, low) <= 0)
    {
        Print("❌ Low 데이터 복사 실패");
        return;
    }
    if(CopyClose(_Symbol, PERIOD_CURRENT, 1, barsToCalculate, close) <= 0)
    {
        Print("❌ 가격 데이터 복사 실패");
        return;
    }
    if(CopyTime(_Symbol, PERIOD_CURRENT, 1, barsToCalculate, time) <= 0)
    {
        Print("❌ 시간 데이터 복사 실패");
        return;
    }
    
    // 배열을 과거부터 현재 순서로
    ArraySetAsSeries(atr, false);
    ArraySetAsSeries(open, false);
    ArraySetAsSeries(high, false);
    ArraySetAsSeries(low, false);
    ArraySetAsSeries(close, false);
    ArraySetAsSeries(time, false);
    
    // 히스토리 초기화
    historySize = 0;
    
    // 과거부터 현재까지 순차 계산
    double prevStop = 0.0;
    int signalCount = 0;
    
    for(int i = 0; i < barsToCalculate; i++)
    {
        double nLoss = atr[i] * KeyValue;
        double src;
        if(PriceSource == 1)
            src = (open[i] + high[i] + low[i] + close[i]) / 4.0;                 // Heikin Ashi Close
        else if(PriceSource == 2)
            src = (high[i] + low[i] + close[i]) / 3.0;                           // Typical Price
        else if(PriceSource == 3)
            src = (high[i] + low[i]) / 2.0;                                      // Median Price
        else
            src = close[i];                                                       // Close
        double src_prev;
        if(i > 0)
        {
            if(PriceSource == 1)
                src_prev = (open[i-1] + high[i-1] + low[i-1] + close[i-1]) / 4.0;
            else if(PriceSource == 2)
                src_prev = (high[i-1] + low[i-1] + close[i-1]) / 3.0;
            else if(PriceSource == 3)
                src_prev = (high[i-1] + low[i-1]) / 2.0;
            else
                src_prev = close[i-1];
        }
        else src_prev = src;
        
        // ATR Trailing Stop 계산 (Pine Script 로직 완전 일치)
        double currentStop = 0.0;
        {
            // 1단계: iff_1
            double iff_1 = (src > prevStop) ? (src - nLoss) : (src + nLoss);
            
            // 2단계: iff_2
            double iff_2 = iff_1;
            if(i > 0 && src < prevStop && src_prev < prevStop)
                iff_2 = MathMin(prevStop, src + nLoss);
            
            // 3단계: 최종
            if(i > 0 && src > prevStop && src_prev > prevStop)
                currentStop = MathMax(prevStop, src - nLoss);
            else
                currentStop = iff_2;
        }
        
        // 히스토리에 저장 (연속성 유지)
        if(historySize < ArraySize(stopHistory))
        {
            stopHistory[historySize].time = time[i];
            stopHistory[historySize].stop = currentStop;
            historySize++;
        }
        
        // 신호 감지 (첫 봉 제외)
        // Pine Script: ema = ta.ema(src, 1) ≈ close이므로 src(close) 직접 사용!
        if(i > 0)
        {
            // Crossover 감지 (close 사용, EMA(1) ≈ close)
            bool above = (src > currentStop) && (src_prev <= prevStop);
            bool below = (currentStop > src) && (prevStop <= src_prev);
            
            // 신호 조건 (src = close 사용)
            bool buySignal = (src > currentStop) && above;
            bool sellSignal = (src < currentStop) && below;
            
            // 화살표 그리기 (close 가격 기준으로 위치 결정)
            if(buySignal)
            {
                DrawArrow("BUY", time[i], close[i]);
                signalCount++;
            }
            else if(sellSignal)
            {
                DrawArrow("SELL", time[i], close[i]);
                signalCount++;
            }
        }
        
        prevStop = currentStop;
    }
    
    Print("✅ 과거 신호 계산 완료 - 총 ", signalCount, "개 신호");
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| 새 봉 시작 시 신호 확인 (히스토리 사용)                          |
//+------------------------------------------------------------------+
void CheckNewBarSignal()
{
    // 완성된 봉(1봉 전) 데이터 (EMA는 사용 안 함!)
    double atr[];
    double open[];
    double high[];
    double low[];
    double close[];
    
    if(CopyBuffer(atr_handle, 0, 1, 2, atr) <= 0)
        return;
    if(CopyOpen(_Symbol, PERIOD_CURRENT, 1, 2, open) <= 0)
        return;
    if(CopyHigh(_Symbol, PERIOD_CURRENT, 1, 2, high) <= 0)
        return;
    if(CopyLow(_Symbol, PERIOD_CURRENT, 1, 2, low) <= 0)
        return;
    if(CopyClose(_Symbol, PERIOD_CURRENT, 1, 2, close) <= 0)
        return;
    
    ArraySetAsSeries(atr, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    // 현재 완성된 봉 (PriceSource 옵션 반영)
    double src;
    if(PriceSource == 1)
        src = (open[0] + high[0] + low[0] + close[0]) / 4.0;               // HA Close
    else if(PriceSource == 2)
        src = (high[0] + low[0] + close[0]) / 3.0;                         // Typical
    else if(PriceSource == 3)
        src = (high[0] + low[0]) / 2.0;                                    // Median
    else
        src = close[0];                                                    // Close

    double src_prev;
    if(PriceSource == 1)
        src_prev = (open[1] + high[1] + low[1] + close[1]) / 4.0;
    else if(PriceSource == 2)
        src_prev = (high[1] + low[1] + close[1]) / 3.0;
    else if(PriceSource == 3)
        src_prev = (high[1] + low[1]) / 2.0;
    else
        src_prev = close[1];
    double nLoss = atr[0] * KeyValue;
    
    // 히스토리에서 이전 Stop 가져오기
    datetime prevBarTime = iTime(_Symbol, PERIOD_CURRENT, 2);
    double prevStop = 0.0;
    
    // 히스토리 검색
    for(int i = historySize - 1; i >= 0; i--)
    {
        if(stopHistory[i].time == prevBarTime)
        {
            prevStop = stopHistory[i].stop;
            break;
        }
    }
    
    // 히스토리에 없으면 재계산 (안전장치)
    if(prevStop == 0.0 && historySize > 0)
    {
        prevStop = stopHistory[historySize - 1].stop;
    }
    
    // 현재 ATR Trailing Stop 계산
    double currentStop = 0.0;
    {
        double iff_1 = (src > prevStop) ? (src - nLoss) : (src + nLoss);
        double iff_2 = iff_1;
        
        if(src < prevStop && src_prev < prevStop)
            iff_2 = MathMin(prevStop, src + nLoss);
        
        if(src > prevStop && src_prev > prevStop)
            currentStop = MathMax(prevStop, src - nLoss);
        else
            currentStop = iff_2;
    }
    
    // 히스토리에 추가
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 1);
    if(historySize < ArraySize(stopHistory))
    {
        stopHistory[historySize].time = currentBarTime;
        stopHistory[historySize].stop = currentStop;
        historySize++;
    }
    
    // Crossover 감지 (close 사용, EMA(1) ≈ close)
    bool above = (src > currentStop) && (src_prev <= prevStop);
    bool below = (currentStop > src) && (prevStop <= src_prev);
    
    // 신호 조건 (src = close 사용)
    bool buySignal = (src > currentStop) && above;
    bool sellSignal = (src < currentStop) && below;
    
    // 화살표 그리기 (close 가격 기준으로 위치 결정)
    if(buySignal)
    {
        DrawArrow("BUY", currentBarTime, close[0]);
        Print("🟢 매수 신호 - Close:", src, " Stop:", currentStop, " PrevStop:", prevStop);
        
        if(AutoTrade)
            trade.Buy(LotSize, _Symbol);
    }
    else if(sellSignal)
    {
        DrawArrow("SELL", currentBarTime, close[0]);
        Print("🔴 매도 신호 - Close:", src, " Stop:", currentStop, " PrevStop:", prevStop);
        
        if(AutoTrade)
            trade.Sell(LotSize, _Symbol);
    }
}

//+------------------------------------------------------------------+
//| 화살표 그리기 (더 명확하게)                                      |
//+------------------------------------------------------------------+
void DrawArrow(string signal, datetime time, double price)
{
    string name = "UTB_" + IntegerToString((long)time) + "_" + signal;
    
    if(ObjectFind(0, name) >= 0)
        return;
    
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double arrowPrice;
    int arrowCode;
    color arrowColor;
    
    // 정확히 동일한 봉 인덱스 찾기 (시간 정확 일치)
    int barIndex = iBarShift(_Symbol, PERIOD_CURRENT, time, true);
    if(barIndex < 0)
        return;  // 해당 시간의 봉이 없으면 생성하지 않음

    if(signal == "BUY")
    {
        // 매수: 봉의 Low 아래에 표시
        double low = iLow(_Symbol, PERIOD_CURRENT, barIndex);
        arrowPrice = low - (ArrowDistance * point);
        arrowCode = BuyArrowCode;
        arrowColor = BuyArrowColor;
    }
    else  // SELL
    {
        // 매도: 봉의 High 위에 표시
        double high = iHigh(_Symbol, PERIOD_CURRENT, barIndex);
        arrowPrice = high + (ArrowDistance * point);
        arrowCode = SellArrowCode;
        arrowColor = SellArrowColor;
    }
    
    if(ObjectCreate(0, name, OBJ_ARROW, 0, time, arrowPrice))
    {
        ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
        ObjectSetInteger(0, name, OBJPROP_COLOR, arrowColor);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, ArrowWidth);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_BACK, false);  // 앞에 표시
    }
}

//+------------------------------------------------------------------+
//| 차트 이벤트 핸들러                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    // 시간 프레임 변경
    if(id == CHARTEVENT_CHART_CHANGE)
    {
        static int lastPeriod = 0;
        int currentPeriod = (int)Period();
        
        if(lastPeriod != 0 && lastPeriod != currentPeriod)
        {
            ObjectsDeleteAll(0, "UTB_");
            historySize = 0;
            CalculateAllSignals();
            Print("🔄 시간 프레임 변경 - 신호 재계산 완료");
        }
        
        lastPeriod = currentPeriod;
    }
    
    // EA 설정 변경 감지 (Properties 창에서 변경 후 OK 누를 때)
    if(id == CHARTEVENT_OBJECT_CHANGE || id == CHARTEVENT_CHART_CHANGE)
    {
        static int lastArrowDistance = 0;
        static color lastBuyColor = 0;
        static color lastSellColor = 0;
        static bool lastUseHA = false;
        static double lastKey = 0.0;
        static int lastAtr = 0;
        
        // 첫 실행 시 초기화
        if(lastArrowDistance == 0)
        {
            lastArrowDistance = ArrowDistance;
            lastBuyColor = BuyArrowColor;
            lastSellColor = SellArrowColor;
            lastUseHA = UseHeikinAshi;
            lastKey = KeyValue;
            lastAtr = ATRPeriod;
            return;
        }
        
        // 설정 변경 감지
        if(lastArrowDistance != ArrowDistance || 
           lastBuyColor != BuyArrowColor || 
           lastSellColor != SellArrowColor ||
           lastUseHA != UseHeikinAshi ||
           lastKey != KeyValue ||
           lastAtr != ATRPeriod)
        {
            Print("🎨 화살표 설정 변경 감지 - 화살표 재생성");
            
            // 모든 화살표 삭제
            ObjectsDeleteAll(0, "UTB_");
            
            // 설정 업데이트
            lastArrowDistance = ArrowDistance;
            lastBuyColor = BuyArrowColor;
            lastSellColor = SellArrowColor;
            lastUseHA = UseHeikinAshi;
            lastKey = KeyValue;
            lastAtr = ATRPeriod;
            
            // 화살표 재생성
            CalculateAllSignals();
        }
    }
}
//+------------------------------------------------------------------+

