//+------------------------------------------------------------------+
//|                                          UT_Bot_EA_Simple.mq5   |
//|                        Copyright 2024, MetaQuotes Software Corp.|
//|                                             https://www.mql5.com|
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "2.00"
#property description "UT Bot EA - 간결한 버전 (핵심 로직만)"

#include <Trade\Trade.mqh>

//--- 입력 파라미터 (원본 Pine Script 기본값과 동일)
input double KeyValue = 1.0;           // 민감도 (ATR 배수)
input int ATRPeriod = 10;              // ATR 기간
input double LotSize = 0.01;           // 로트 크기
input bool AutoTrade = false;          // 자동매매 사용
input long MagicNumber = 12345;        // 매직 넘버

//--- 화살표 설정
input int ArrowDistance = 20;          // 화살표 거리 (포인트)
input color BuyArrowColor = clrLime;   // 매수 화살표 색깔
input color SellArrowColor = clrRed;   // 매도 화살표 색깔

//--- 전역 변수
int atr_handle;
double prevATRStop = 0;
datetime lastBarTime = 0;
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // 지표 초기화
    atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
    if(atr_handle == INVALID_HANDLE)
    {
        Print("❌ ATR 지표 초기화 실패");
        return INIT_FAILED;
    }
    
    trade.SetExpertMagicNumber(MagicNumber);
    
    Print("✅ UT Bot 시작 - KeyValue:", KeyValue, " ATRPeriod:", ATRPeriod);
    
    // 초기화 시 모든 과거 봉 계산
    CalculateHistoricalSignals();
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // 지표 핸들 해제
    if(atr_handle != INVALID_HANDLE)
        IndicatorRelease(atr_handle);
    
    // EA 제거 시 화살표 삭제
    ObjectsDeleteAll(0, "UTB_");
    
    Print("🔄 UT Bot 종료");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // 새 봉 확인
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(currentBarTime == lastBarTime)
        return;
    
    lastBarTime = currentBarTime;
    
    // 현재 봉 신호 계산
    CheckCurrentBarSignal();
}

//+------------------------------------------------------------------+
//| 모든 과거 봉의 신호 계산 및 화살표 표시                          |
//+------------------------------------------------------------------+
void CalculateHistoricalSignals()
{
    int totalBars = iBars(_Symbol, PERIOD_CURRENT);
    int visibleBars = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
    int barsToCalculate = MathMin(totalBars, visibleBars + 100);
    
    Print("📊 과거 신호 계산 시작 - 총 ", barsToCalculate, "개 봉");
    
    // ATR 데이터 가져오기
    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(atr_handle, 0, 0, barsToCalculate, atr) <= 0)
    {
        Print("❌ ATR 데이터 복사 실패");
        return;
    }
    
    // 가격 데이터 가져오기
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(_Symbol, PERIOD_CURRENT, 0, barsToCalculate, rates) <= 0)
    {
        Print("❌ 가격 데이터 복사 실패");
        return;
    }
    
    // 과거부터 현재까지 순차 계산
    double prevStop = 0.0;
    double prevEMA = 0.0;
    int signalCount = 0;
    
    for(int i = barsToCalculate - 1; i >= 0; i--)
    {
        double close = rates[i].close;
        double prevClose = (i < barsToCalculate - 1) ? rates[i + 1].close : close;
        double nLoss = atr[i] * KeyValue;
        
        // ATR Trailing Stop 계산 (Pine Script 로직)
        double currentStop = CalculateATRStop(close, prevClose, prevStop, nLoss, i == barsToCalculate - 1);
        
        // EMA(1) = close (수학적으로 동일)
        double ema = close;
        
        // 첫 봉이 아닐 때만 신호 감지 (Pine Script에서 첫 봉은 ema[1], xATRTrailingStop[1]이 na이므로 신호 없음)
        if(i < barsToCalculate - 1)
        {
            // Crossover 감지
            bool above = (ema > currentStop) && (prevEMA <= prevStop);
            bool below = (currentStop > ema) && (prevStop <= prevEMA);
            
            // 신호 조건
            bool buySignal = (close > currentStop) && above;
            bool sellSignal = (close < currentStop) && below;
            
            // 화살표 그리기
            if(buySignal)
            {
                DrawArrow("BUY", rates[i].time, close);
                signalCount++;
            }
            else if(sellSignal)
            {
                DrawArrow("SELL", rates[i].time, close);
                signalCount++;
            }
        }
        
        // 다음 봉을 위해 저장
        prevStop = currentStop;
        prevEMA = ema;
    }
    
    prevATRStop = prevStop;  // 실시간 계산을 위해 저장
    
    Print("✅ 과거 신호 계산 완료 - 총 ", signalCount, "개 신호");
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| 현재 봉의 신호 확인 (실시간)                                     |
//+------------------------------------------------------------------+
void CheckCurrentBarSignal()
{
    // ATR 데이터
    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(atr_handle, 0, 0, 3, atr) <= 0)
        return;
    
    // 가격 데이터
    double close = iClose(_Symbol, PERIOD_CURRENT, 1);  // 완성된 봉
    double prevClose = iClose(_Symbol, PERIOD_CURRENT, 2);
    double nLoss = atr[1] * KeyValue;
    
    // ATR Trailing Stop 계산
    double currentStop = CalculateATRStop(close, prevClose, prevATRStop, nLoss, false);
    
    // EMA(1) = close
    double ema = close;
    double prevEMA = prevClose;
    
    // Crossover 감지
    bool above = (ema > currentStop) && (prevEMA <= prevATRStop);
    bool below = (currentStop > ema) && (prevATRStop <= prevEMA);
    
    // 신호 조건
    bool buySignal = (close > currentStop) && above;
    bool sellSignal = (close < currentStop) && below;
    
    // 화살표 그리기
    datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 1);
    
    if(buySignal)
    {
        DrawArrow("BUY", barTime, close);
        Print("🟢 매수 신호 발생 - 가격:", close);
        
        // 자동매매
        if(AutoTrade)
            trade.Buy(LotSize, _Symbol);
    }
    else if(sellSignal)
    {
        DrawArrow("SELL", barTime, close);
        Print("🔴 매도 신호 발생 - 가격:", close);
        
        // 자동매매
        if(AutoTrade)
            trade.Sell(LotSize, _Symbol);
    }
    
    // 다음 봉을 위해 저장
    prevATRStop = currentStop;
}

//+------------------------------------------------------------------+
//| ATR Trailing Stop 계산 (Pine Script 로직)                       |
//+------------------------------------------------------------------+
double CalculateATRStop(double price, double prevPrice, double prevStop, double nLoss, bool isFirstBar)
{
    // 1단계: 기본 후보
    double iff_1 = (price > prevStop) ? (price - nLoss) : (price + nLoss);
    
    // 2단계: 하락 추세 보정
    double iff_2 = iff_1;
    if(!isFirstBar && price < prevStop && prevPrice < prevStop)
        iff_2 = MathMin(prevStop, price + nLoss);
    
    // 3단계: 상승 추세 보정
    double result;
    if(!isFirstBar && price > prevStop && prevPrice > prevStop)
        result = MathMax(prevStop, price - nLoss);
    else
        result = iff_2;
    
    return result;
}

//+------------------------------------------------------------------+
//| 화살표 그리기 (단일 함수로 통합)                                 |
//+------------------------------------------------------------------+
void DrawArrow(string signal, datetime time, double price)
{
    // 고유한 객체 이름
    string name = "UTB_" + IntegerToString((long)time) + "_" + signal;
    
    // 이미 존재하면 생략
    if(ObjectFind(0, name) >= 0)
        return;
    
    // 화살표 위치 및 속성
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double arrowPrice;
    int arrowCode;
    color arrowColor;
    
    if(signal == "BUY")
    {
        arrowPrice = price - (ArrowDistance * point);  // 봉 아래
        arrowCode = 233;  // 위쪽 화살표
        arrowColor = BuyArrowColor;
    }
    else  // SELL
    {
        arrowPrice = price + (ArrowDistance * point);  // 봉 위
        arrowCode = 234;  // 아래쪽 화살표
        arrowColor = SellArrowColor;
    }
    
    // 화살표 생성
    if(ObjectCreate(0, name, OBJ_ARROW, 0, time, arrowPrice))
    {
        ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
        ObjectSetInteger(0, name, OBJPROP_COLOR, arrowColor);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
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
    // 시간 프레임 변경 시 재계산
    if(id == CHARTEVENT_CHART_CHANGE)
    {
        static int lastPeriod = 0;
        int currentPeriod = (int)Period();
        
        if(lastPeriod != 0 && lastPeriod != currentPeriod)
        {
            ObjectsDeleteAll(0, "UTB_");  // 기존 화살표 삭제
            prevATRStop = 0;  // 초기화
            CalculateHistoricalSignals();  // 재계산
            Print("🔄 시간 프레임 변경 - 신호 재계산 완료");
        }
        
        lastPeriod = currentPeriod;
    }
}
//+------------------------------------------------------------------+

