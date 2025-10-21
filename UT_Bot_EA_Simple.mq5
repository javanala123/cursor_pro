//+------------------------------------------------------------------+
//|                                          UT_Bot_EA_Simple.mq5   |
//|                        Copyright 2024, MetaQuotes Software Corp.|
//|                                             https://www.mql5.com|
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "UT Bot EA - 완전 수정된 버전 (시간프레임별 분리, 모든 봉 신호 표시, 부분익절/스탑로스)"

#include <Trade\Trade.mqh>

//--- 입력 파라미터 (원본 Pine Script 기본값과 동일하게 설정)
input double KeyValue = 1.0;           // 민감도 (ATR 배수) - 원본 Pine Script 기본값: 1
input int ATRPeriod = 10;              // ATR 기간 - 원본 Pine Script 기본값: 10
input int MAPeriod = 1;                // MA 기간 (EMA 기간) - 원본 Pine Script: ema(src, 1)
input double LotSize = 0.01;           // 로트 크기
input bool ReversePosition = true;     // 반대 신호 시 청산 후 진입
input long MagicNumber = 12345;        // 매직 넘버
input bool UniqueMagicPerChart = true; // 차트별 고유 매직넘버

//--- 화살표 설정
input int ArrowDistance = 20;          // 화살표 거리 (포인트)
input color BuyArrowColor = clrLime;   // 매수 화살표 색깔
input color SellArrowColor = clrRed;   // 매도 화살표 색깔
input int BuyArrowCode = 233;          // 매수 화살표 코드
input int SellArrowCode = 234;         // 매도 화살표 코드

//--- 부분익절/스탑로스 설정
input bool UsePartialTakeProfit = true;    // 부분익절 사용
input double PartialTakeProfitUSD = 50.0;  // 부분익절 금액 (달러)
input double PartialTakeProfitPercent = 50.0; // 부분익절 비율 (%)
input bool UseStopLoss = true;             // 스탑로스 사용
input double StopLossUSD = 100.0;          // 스탑로스 금액 (달러)

//--- 리셋 기능
input bool EnableManualReset = true;       // 수동 리셋 기능 사용
input string ResetHotkey = "R";            // 리셋 단축키 (R키)

//--- 전역 변수
int atr_handle;
int ma_handle;
double prevStop = 0;
double prevPrice = 0;
double prevMa = 0;
int lastSignal = 0;  // 1=매수, -1=매도, 0=없음
datetime lastBar = 0;
int g_lastPeriod = 0;               // 마지막 감지한 차트 주기
int g_lastVisibleBars = 0;          // 마지막 감지한 화면 봉 개수 (차트 확대/축소 감지용)
long g_magic = 0;                   // 이 EA가 사용하는 실제 매직넘버
string g_timeframePrefix = "";      // 시간프레임별 접두사
bool g_firstRun = true;             // 첫 실행 여부

//--- 설정 변경 감지용 변수들
int g_prevArrowDistance = 0;
color g_prevBuyArrowColor = 0;
color g_prevSellArrowColor = 0;
int g_prevBuyArrowCode = 0;
int g_prevSellArrowCode = 0;

CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // 매직넘버 설정 (차트별 고유화)
    long magic = MagicNumber;
    if(UniqueMagicPerChart)
    {
        magic += (long)Period();
    }
    trade.SetExpertMagicNumber(magic);
    g_magic = magic;
    
    // 시간프레임별 접두사 설정
    g_timeframePrefix = "UTB_" + IntegerToString((int)Period()) + "_";
    
    // 지표 핸들 초기화
    atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
    ma_handle = iMA(_Symbol, PERIOD_CURRENT, MAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    
    if(atr_handle == INVALID_HANDLE || ma_handle == INVALID_HANDLE)
    {
        Print("❌ 지표 핸들 생성 실패");
            return INIT_FAILED;
    }
    
    // 설정값 초기화 (변경 감지용)
    g_prevArrowDistance = ArrowDistance;
    g_prevBuyArrowColor = BuyArrowColor;
    g_prevSellArrowColor = SellArrowColor;
    g_prevBuyArrowCode = BuyArrowCode;
    g_prevSellArrowCode = SellArrowCode;
    
    Print("✅ UT Bot 시작 - KeyValue:", KeyValue, " ATRPeriod:", ATRPeriod, " MAPeriod:", MAPeriod, " Magic:", magic);
    Print("🎯 화살표 설정 - 거리:", ArrowDistance, "포인트, 매수색:", BuyArrowColor, " 매도색:", SellArrowColor);
    Print("💰 부분익절/스탑로스 - 부분익절:", PartialTakeProfitUSD, "달러, 스탑로스:", StopLossUSD, "달러");
    if(EnableManualReset) Print("🔄 수동 리셋 기능 활성화 - R키로 화살표 리셋 가능");
    g_lastPeriod = (int)Period();
    g_lastVisibleBars = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
    
    // EA 시작 시 즉시 모든 봉에 신호 표시
    Print("🚀 EA 초기화 완료 - 화면에 보이는 모든 봉 신호 계산 시작");
    CalculateAllBarsSignals();
    g_firstRun = false;
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // 설정 변경 감지 및 기존 화살표 즉시 업데이트
    if(IsSettingsChanged())
    {
        Print("🔄 화살표 설정 변경 감지 - 모든 기존 화살표 즉시 업데이트");
        UpdateAllArrows();
        UpdateSettingsCache();
    }
    
    // 새 바 확인
    datetime bar = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(bar == lastBar) return;
    lastBar = bar;
    
    // 차트 주기 변경 감지 시 이전 주기의 화살표 정리
    int curPeriod = (int)Period();
    if(curPeriod != g_lastPeriod)
    {
        CleanupOldArrows();
        g_timeframePrefix = "UTB_" + IntegerToString(curPeriod) + "_";
        g_lastPeriod = curPeriod;
        Print("🔄 차트 주기 변경 감지 - 이전 화살표 정리 완료, 새 접두사:", g_timeframePrefix);
    }

    // 첫 실행 시 모든 봉에 신호 표시 (OnInit에서 이미 실행됨)
    if(g_firstRun)
    {
        Print("🔄 OnTick에서 첫 실행 감지 - 모든 봉 신호 재계산");
        CalculateAllBarsSignals();
        g_firstRun = false;
    }

    // 우리 EA 포지션 확인
    bool hasOurPosition = false;
    int total = PositionsTotal();
    for(int i = 0; i < total; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionSelectByTicket(ticket))
        {
            string pos_symbol = PositionGetString(POSITION_SYMBOL);
            long pos_magic = PositionGetInteger(POSITION_MAGIC);
            if(pos_symbol == _Symbol && pos_magic == g_magic)
            {
                hasOurPosition = true;
                break;
            }
        }
    }
    
    if(!hasOurPosition && lastSignal != 0)
    {
        Print("ℹ️ 우리 EA 포지션 없음 감지 - 내부 상태 리셋");
        lastSignal = 0;
    }
    
    // 가격 데이터 복사 (CopyRates 사용)
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 2, rates) <= 0) return;
    
    // ATR, 이동평균 가져오기
    double atr[1], ma[1];
    if(CopyBuffer(atr_handle, 0, 0, 1, atr) <= 0) return;
    if(CopyBuffer(ma_handle, 0, 0, 1, ma) <= 0) return;
    
    // 현재 봉과 이전 봉 가격
    double price = rates[0].close;      // 현재 봉 종가
    double prevBarPrice = rates[1].close; // 이전 봉 종가
    
    // Pine Script 로직에 따른 ATR 스탑 계산
    double nLoss = atr[0] * KeyValue;
    double currentATRStop = 0.0;
    
    if(prevStop == 0.0) {
        // 초기값 설정
        currentATRStop = price + nLoss;
    } else {
        // Pine Script 로직 적용
        double iff_1 = (price > prevStop) ? (price - nLoss) : (price + nLoss);
        double iff_2 = iff_1;
        
        if(price < prevStop && prevBarPrice < prevStop)
            iff_2 = MathMin(prevStop, price + nLoss);
            
        if(price > prevStop && prevBarPrice > prevStop)
            currentATRStop = MathMax(prevStop, price - nLoss);
        else
            currentATRStop = iff_2;
    }
    
    // 교차 조건 (Pine Script의 ta.crossover 동치)
    bool above = (ma[0] > currentATRStop) && (prevMa <= prevStop);
    bool below = (currentATRStop > ma[0]) && (prevStop <= prevMa);
    
    // Pine Script의 신호 조건
    bool buySignal = (price > currentATRStop) && above;
    bool sellSignal = (price < currentATRStop) && below;
    
    // 연속 신호 방지
    if((buySignal && lastSignal == 1) || (sellSignal && lastSignal == -1))
        return;
    
    // 매수 신호 처리
    if(buySignal)
    {
        Print("▲ 매수 신호 - Price:", price, " > ATR Stop:", currentATRStop, " | EMA:", ma[0], " 교차");
        DrawArrow("BUY", price);
        
        // 반대 포지션 청산
        if(ReversePosition) CloseOwnPositions();
        
        // 매수 주문 실행
        PrintFormat("🚀 자동매매 매수 시도 - Symbol:%s Lot:%.2f Magic:%d", _Symbol, LotSize, g_magic);
        if(trade.Buy(LotSize, _Symbol)) {
            PrintFormat("✅ 자동매매 매수 성공 - Symbol:%s Lot:%.2f Magic:%d", _Symbol, LotSize, g_magic);
            lastSignal = 1;
        } else {
            PrintFormat("❌ 자동매매 매수 실패 - Symbol:%s ret:%d %s, lastError:%d", 
                       _Symbol, trade.ResultRetcode(), trade.ResultRetcodeDescription(), GetLastError());
        }
    }
    
    // 매도 신호 처리
    if(sellSignal)
    {
        Print("▼ 매도 신호 - Price:", price, " < ATR Stop:", currentATRStop, " | ATR 교차 EMA:", ma[0]);
        DrawArrow("SELL", price);
        
        // 반대 포지션 청산
        if(ReversePosition) CloseOwnPositions();
        
        // 매도 주문 실행
        PrintFormat("🚀 자동매매 매도 시도 - Symbol:%s Lot:%.2f Magic:%d", _Symbol, LotSize, g_magic);
        if(trade.Sell(LotSize, _Symbol)) {
            PrintFormat("✅ 자동매매 매도 성공 - Symbol:%s Lot:%.2f Magic:%d", _Symbol, LotSize, g_magic);
            lastSignal = -1;
        } else {
            PrintFormat("❌ 자동매매 매도 실패 - Symbol:%s ret:%d %s, lastError:%d", 
                       _Symbol, trade.ResultRetcode(), trade.ResultRetcodeDescription(), GetLastError());
        }
    }
    
    // 부분익절/스탑로스 체크
    CheckPartialTakeProfitAndStopLoss();
    
    // 이전 값 저장
    prevStop = currentATRStop;
    prevPrice = price;
    prevMa = ma[0];
}

//+------------------------------------------------------------------+
//| 설정 변경 감지 함수                                              |
//+------------------------------------------------------------------+
bool IsSettingsChanged()
{
    return (g_prevArrowDistance != ArrowDistance ||
            g_prevBuyArrowColor != BuyArrowColor ||
            g_prevSellArrowColor != SellArrowColor ||
            g_prevBuyArrowCode != BuyArrowCode ||
            g_prevSellArrowCode != SellArrowCode);
}

//+------------------------------------------------------------------+
//| 설정 캐시 업데이트 함수                                          |
//+------------------------------------------------------------------+
void UpdateSettingsCache()
{
    g_prevArrowDistance = ArrowDistance;
    g_prevBuyArrowColor = BuyArrowColor;
    g_prevSellArrowColor = SellArrowColor;
    g_prevBuyArrowCode = BuyArrowCode;
    g_prevSellArrowCode = SellArrowCode;
}

//+------------------------------------------------------------------+
//| 모든 기존 화살표 업데이트 함수                                    |
//+------------------------------------------------------------------+
void UpdateAllArrows()
{
    int total = ObjectsTotal(0, -1, -1);
    int updated = 0;
    
    for(int i = 0; i < total; i++)
    {
        string name = ObjectName(0, i, -1, -1);
        if(StringFind(name, g_timeframePrefix, 0) == 0)
        {
            // 화살표 타입 확인
            if(ObjectGetInteger(0, name, OBJPROP_TYPE) == OBJ_ARROW)
            {
                // 신호 타입 확인 (BUY/SELL)
                bool isBuy = (StringFind(name, "_BUY", 0) > 0);
                
                // 새로운 속성 적용
                if(isBuy)
                {
                    ObjectSetInteger(0, name, OBJPROP_COLOR, BuyArrowColor);
                    ObjectSetInteger(0, name, OBJPROP_ARROWCODE, BuyArrowCode);
                }
                else
                {
                    ObjectSetInteger(0, name, OBJPROP_COLOR, SellArrowColor);
                    ObjectSetInteger(0, name, OBJPROP_ARROWCODE, SellArrowCode);
                }
                
                // 화살표 위치 재계산
                double currentPrice = ObjectGetDouble(0, name, OBJPROP_PRICE);
                double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                double newPrice;
                
                if(isBuy)
                {
                    newPrice = currentPrice + (g_prevArrowDistance * point) - (ArrowDistance * point);
                }
                else
                {
                    newPrice = currentPrice - (g_prevArrowDistance * point) + (ArrowDistance * point);
                }
                
                ObjectSetDouble(0, name, OBJPROP_PRICE, newPrice);
                updated++;
            }
        }
    }
    
    Print("🎯 기존 화살표 업데이트 완료 - 업데이트된 화살표 수:", updated);
    ChartRedraw(0); // 차트 즉시 새로고침
}

//+------------------------------------------------------------------+
//| 수동 화살표 리셋 함수                                            |
//+------------------------------------------------------------------+
void ManualResetArrows()
{
    if(!EnableManualReset) return;
    
    Print("🔄 수동 화살표 리셋 시작");
    
    // 모든 UT Bot 화살표 삭제
    int total = ObjectsTotal(0, -1, -1);
    int deleted = 0;
    
    for(int i = total - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i, -1, -1);
        if(StringFind(name, "UTB_", 0) == 0) // 모든 UT Bot 화살표 삭제
        {
            ObjectDelete(0, name);
            deleted++;
        }
    }
    
    // 첫 실행 플래그 리셋 (다시 모든 봉 신호 계산)
    g_firstRun = true;
    
    Print("✅ 수동 화살표 리셋 완료 - 삭제된 화살표 수:", deleted);
    Print("🔄 다음 틱에서 모든 봉 신호 다시 계산됩니다");
}

//+------------------------------------------------------------------+
//| 모든 봉에 신호 계산 및 화살표 표시 (과거 봉 포함)                 |
//+------------------------------------------------------------------+
void CalculateAllBarsSignals()
{
    int totalBars = iBars(_Symbol, PERIOD_CURRENT);
    int visibleBars = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
    
    // 화면에 보이는 모든 봉 계산 (충분한 여유분 포함)
    int startBar = MathMax(0, totalBars - visibleBars - 50); // 화면 봉 + 여유분 50개
    int endBar = totalBars - 1; // 마지막 완성된 봉까지
    
    Print("========================================");
    Print("📊 화면에 보이는 모든 봉 신호 계산 시작");
    Print("📊 총 봉:", totalBars, " 화면 봉:", visibleBars);
    Print("📊 계산 범위:", startBar, "~", endBar, " (총 ", endBar - startBar + 1, "개 봉)");
    Print("🔍 지표 핸들 상태 - ATR:", atr_handle, " MA:", ma_handle);
    Print("========================================");
    
    // ATR과 MA 데이터 가져오기
    double atr[], ma[];
    int atrCopied = CopyBuffer(atr_handle, 0, 0, totalBars, atr);
    int maCopied = CopyBuffer(ma_handle, 0, 0, totalBars, ma);
    //--- 가격 데이터 복사용 배열 (close 값)
    MqlRates rates[];
    int ratesCopied = CopyRates(_Symbol, PERIOD_CURRENT, 0, totalBars, rates);

    Print("📈 데이터 복사 결과 - ATR:", atrCopied, " MA:", maCopied);
    if(ratesCopied <= 0) { Print("❌ Rates 데이터 복사 실패 - 에러:", GetLastError()); return; }

    if(atrCopied <= 0) {
        Print("❌ ATR 데이터 복사 실패 - 에러:", GetLastError());
        return;
    }
    if(maCopied <= 0) {
        Print("❌ MA 데이터 복사 실패 - 에러:", GetLastError());
        return;
    }
    
    // Pine Script 로직에 따라 순차적으로 계산 (과거부터 현재까지)
    int signalCount = 0;
    double prevATRStop = 0; // 이전 ATR 스탑 값 (Pine Script의 xATRTrailingStop[1])
    
    for(int i = startBar; i <= endBar; i++) // 화면에 보이는 모든 봉 계산
    {
        // 가격은 복사한 rates 배열 사용 (close) - 올바른 인덱싱
        double price = rates[i].close;
        double atrValue = atr[i];
        double maValue = ma[i];
        
        // 이전 봉 데이터 (Pine Script의 [1] 인덱스)
        double prevBarPrice = (i > 0) ? rates[i-1].close : price;
        double prevBarMa = (i > 0) ? ma[i-1] : maValue;
        
        // UT Bot(TradingView) 트레일링 스탑 계산식과 동일한 방식으로 계산
        // - 단순 +/- nLoss가 아니라, 이전 스탑과 이전 가격의 위치 관계에 따라 단계적으로 결정
        // - 실시간 계산에 사용하는 CalculateStop과 동일한 규칙을 과거 봉에도 적용
        // Pine Script의 정확한 ATR Trailing Stop 계산 로직
        // nz(xATRTrailingStop[1], 0): 이전 값이 없으면 0 사용
        double currentATRStop = 0.0;
        {
            double nLoss = atrValue * KeyValue;
            double prevStopLocal = prevATRStop;  // 첫 봉에서는 0.0
            
            // 첫 봉 처리: Pine Script에서 src[1]은 na이므로 비교 시 false 반환
            // MQL5에서는 i == 0일 때 이전 봉이 없으므로 특별 처리
            bool hasPrevBar = (i > 0);

            // 1단계: 기본 후보
            // iff_1 = src > nz(xATRTrailingStop[1], 0) ? src - nLoss : src + nLoss
            double iff_1 = (price > prevStopLocal) ? (price - nLoss) : (price + nLoss);
            
            // 2단계: 하락 추세 보정
            // iff_2 = src < nz(xATRTrailingStop[1], 0) and src[1] < nz(xATRTrailingStop[1], 0) ? math.min(nz(xATRTrailingStop[1]), src + nLoss) : iff_1
            double iff_2 = iff_1;
            if(hasPrevBar && price < prevStopLocal && prevBarPrice < prevStopLocal)
                iff_2 = MathMin(prevStopLocal, price + nLoss);
            
            // 3단계: 상승 추세 보정
            // xATRTrailingStop := src > nz(xATRTrailingStop[1], 0) and src[1] > nz(xATRTrailingStop[1], 0) ? math.max(nz(xATRTrailingStop[1]), src - nLoss) : iff_2
            if(hasPrevBar && price > prevStopLocal && prevBarPrice > prevStopLocal)
                currentATRStop = MathMax(prevStopLocal, price - nLoss);
            else
                currentATRStop = iff_2;
        }
        
        // 교차 조건 (Pine Script의 ta.crossover 동치)
        bool above = (maValue > currentATRStop) && (prevBarMa <= prevATRStop);
        bool below = (currentATRStop > maValue) && (prevATRStop <= prevBarMa);
        
        // Pine Script의 신호 조건
        // buy = src > xATRTrailingStop and above
        // sell = src < xATRTrailingStop and below
        bool buySignal = (price > currentATRStop) && above;
        bool sellSignal = (price < currentATRStop) && below;
        
        // 화살표 표시
        if(buySignal || sellSignal)
        {
            // 중복 방지: 동일 바에 이미 동일 신호 객체가 있으면 건너뜀
            string sig = buySignal ? "BUY" : "SELL";
            datetime t = iTime(_Symbol, PERIOD_CURRENT, totalBars - 1 - i);
            string checkName = g_timeframePrefix + IntegerToString((int)t) + "_" + sig;
            if(ObjectFind(0, checkName) == -1)
            {
                if(buySignal)
                {
                    PrintFormat("🟢 BUY 신호 - Bar:%d Price:%.5f ATRStop:%.5f MA:%.5f", i, price, currentATRStop, maValue);
                    DrawArrowForBar("BUY", price, i);
                }
                else
                {
                    PrintFormat("🔴 SELL 신호 - Bar:%d Price:%.5f ATRStop:%.5f MA:%.5f", i, price, currentATRStop, maValue);
                    DrawArrowForBar("SELL", price, i);
                }
                signalCount++;
            }
        }
        
        // 모든 봉에 대해 상세 로그 (문제 파악용)
        if(totalBars - 1 - i < startBar + 20) {
            PrintFormat("🔍 봉 %d: Price=%.5f, ATR=%.5f, MA=%.5f", totalBars - 1 - i, price, atrValue, maValue);
            PrintFormat("   ATRStop=%.5f, PrevATRStop=%.5f, PrevMA=%.5f", currentATRStop, prevATRStop, prevBarMa);
            PrintFormat("   Above=%d (MA>Stop:%d && PrevMA<=PrevStop:%d)", above, maValue > currentATRStop, prevBarMa <= prevATRStop);
            PrintFormat("   Below=%d (Stop>MA:%d && PrevStop<=PrevMA:%d)", below, currentATRStop > maValue, prevATRStop <= prevBarMa);
            PrintFormat("   Buy=%d (Price>Stop:%d && Above:%d)", buySignal, price > currentATRStop, above);
            PrintFormat("   Sell=%d (Price<Stop:%d && Below:%d)", sellSignal, price < currentATRStop, below);
            Print("---");
        }
        
        // 다음 봉을 위해 현재 값을 이전 값으로 저장
        prevATRStop = currentATRStop;
    }
    
    Print("📊 신호 계산 완료 - 총 신호 수:", signalCount);
    
    Print("✅ 모든 봉 신호 계산 완료");
    ChartRedraw(0); // 차트 즉시 새로고침
}



//+------------------------------------------------------------------+
//| 특정 봉에 화살표 그리기                                          |
//+------------------------------------------------------------------+
void DrawArrowForBar(string signal, double price, int barIndex)
{
    // rates 배열에서 해당 봉의 시간 가져오기
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_CURRENT, 0, barIndex + 1, rates) <= 0) return;
    
    datetime bar_time = rates[barIndex].time;
    
    // 고유한 객체 이름 생성 (시간프레임별 접두사 + 시간 + 신호)
    string name = g_timeframePrefix + IntegerToString((int)bar_time) + "_" + signal;
    
    // 화살표 위치 계산
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double arrowPrice;
    int code;
    color clr;
    
    if(signal == "BUY")
    {
        arrowPrice = price - (ArrowDistance * point);
        code = BuyArrowCode;
        clr = BuyArrowColor;
    }
    else
    {
        arrowPrice = price + (ArrowDistance * point);
        code = SellArrowCode;
        clr = SellArrowColor;
    }

    // 화살표 생성
    PrintFormat("🎯 화살표 생성 시도 - %s Bar:%d Price:%.5f ArrowPrice:%.5f", signal, barIndex, price, arrowPrice);
    
    if(ObjectCreate(0, name, OBJ_ARROW, 0, bar_time, arrowPrice))
    {
        ObjectSetInteger(0, name, OBJPROP_ARROWCODE, code);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
        ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS); // 모든 시간프레임에 표시
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
        PrintFormat("✅ 화살표 생성 성공 - %s", name);
    }
    else
    {
        PrintFormat("❌ 화살표 생성 실패 - %s 에러:%d", name, GetLastError());
    }
}

//+------------------------------------------------------------------+
//| ATR 스탑 계산                                                    |
//+------------------------------------------------------------------+
double CalculateStop(double price, double atr)
{
    double nLoss = atr * KeyValue;
    
    // 1단계: 기본 스탑 라인 계산
    double iff_1 = (price > prevStop) ? (price - nLoss) : (price + nLoss);
    
    // 2단계: 하락 추세에서 스탑 라인 조정
    double iff_2;
    if(price < prevStop && prevPrice < prevStop)
        iff_2 = MathMin(prevStop, price + nLoss);
    else
        iff_2 = iff_1;
    
    // 3단계: 상승 추세에서 스탑 라인 조정
    double result;
    if(price > prevStop && prevPrice > prevStop)
        result = MathMax(prevStop, price - nLoss);
    else
        result = iff_2;
    
    return result;
}

//+------------------------------------------------------------------+
//| 신호 확인 및 거래                                                |
//+------------------------------------------------------------------+
void CheckSignal(double price, double stop, double ma)
{
    // 초기화 로직
    if(prevStop == 0) {
        double atr[1];
        if(CopyBuffer(atr_handle, 0, 0, 1, atr) <= 0) return;
        double nLoss = atr[0] * KeyValue;
        prevStop = price + nLoss;
        return;
    }
    if(prevMa == 0) return;
    
    // UT Bot 신호 로직
    bool above = (ma > stop) && (prevMa <= prevStop);  // EMA가 ATR 스탑 위로 교차
    bool below = (stop > ma) && (prevStop <= prevMa);  // ATR 스탑이 EMA 위로 교차
    
    bool buySignal = (price > stop) && above;   // 가격 > ATR 스탑 AND EMA 교차
    bool sellSignal = (price < stop) && below;  // 가격 < ATR 스탑 AND ATR 교차
    
    // 연속 신호 방지
    if((buySignal && lastSignal == 1) || (sellSignal && lastSignal == -1))
        return;
    
    // 매수 신호 처리
    if(buySignal)
    {
        Print("▲ 매수 신호 - Price:", price, " > ATR Stop:", stop, " | EMA:", ma, " 교차");
        DrawArrow("BUY", price);
        
        // 반대 포지션 청산
        if(ReversePosition) CloseOwnPositions();
        
        // 매수 주문 실행
        PrintFormat("🚀 자동매매 매수 시도 - Symbol:%s Lot:%.2f Magic:%d", _Symbol, LotSize, g_magic);
        if(trade.Buy(LotSize, _Symbol)) {
            PrintFormat("✅ 자동매매 매수 성공 - Symbol:%s Lot:%.2f Magic:%d", _Symbol, LotSize, g_magic);
            lastSignal = 1;
        } else {
            PrintFormat("❌ 자동매매 매수 실패 - Symbol:%s ret:%d %s, lastError:%d", 
                       _Symbol, trade.ResultRetcode(), trade.ResultRetcodeDescription(), GetLastError());
        }
    }
    
    // 매도 신호 처리
    if(sellSignal)
    {
            Print("▼ 매도 신호 - Price:", price, " < ATR Stop:", stop, " | ATR 교차 EMA:", ma);
            DrawArrow("SELL", price);
            
            // 반대 포지션 청산
        if(ReversePosition) CloseOwnPositions();
        
        // 매도 주문 실행
        PrintFormat("🚀 자동매매 매도 시도 - Symbol:%s Lot:%.2f Magic:%d", _Symbol, LotSize, g_magic);
        if(trade.Sell(LotSize, _Symbol)) {
            PrintFormat("✅ 자동매매 매도 성공 - Symbol:%s Lot:%.2f Magic:%d", _Symbol, LotSize, g_magic);
                lastSignal = -1;
        } else {
            PrintFormat("❌ 자동매매 매도 실패 - Symbol:%s ret:%d %s, lastError:%d", 
                       _Symbol, trade.ResultRetcode(), trade.ResultRetcodeDescription(), GetLastError());
        }
    }
}

//+------------------------------------------------------------------+
//| 부분익절 및 스탑로스 체크                                        |
//+------------------------------------------------------------------+
void CheckPartialTakeProfitAndStopLoss()
{
    int total = PositionsTotal();
    for(int i = 0; i < total; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionSelectByTicket(ticket))
        {
            string pos_symbol = PositionGetString(POSITION_SYMBOL);
            long pos_magic = PositionGetInteger(POSITION_MAGIC);
            double pos_volume = PositionGetDouble(POSITION_VOLUME);
            double pos_profit = PositionGetDouble(POSITION_PROFIT);
            double pos_price_open = PositionGetDouble(POSITION_PRICE_OPEN);
            double pos_price_current = PositionGetDouble(POSITION_PRICE_CURRENT);
            ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            // 우리 EA 포지션만 처리
            if(pos_symbol == _Symbol && pos_magic == g_magic)
            {
                // 부분익절 체크
                if(UsePartialTakeProfit && pos_profit >= PartialTakeProfitUSD)
                {
                    double partialVolume = pos_volume * (PartialTakeProfitPercent / 100.0);
                    if(partialVolume > 0.01) // 최소 로트 크기 확인
                    {
                        PrintFormat("💰 부분익절 실행 - Ticket:%I64u Profit:%.2f USD Volume:%.2f -> %.2f", 
                                   ticket, pos_profit, pos_volume, pos_volume - partialVolume);
                        
                        if(trade.PositionClosePartial(ticket, partialVolume))
                        {
                            PrintFormat("✅ 부분익절 성공 - Ticket:%I64u", ticket);
                        }
                        else
                        {
                            PrintFormat("❌ 부분익절 실패 - Ticket:%I64u ret:%d", ticket, trade.ResultRetcode());
                        }
                    }
                }
                
                // 스탑로스 체크
                if(UseStopLoss && pos_profit <= -StopLossUSD)
                {
                    PrintFormat("🛑 스탑로스 실행 - Ticket:%I64u Loss:%.2f USD", ticket, pos_profit);
                    
                    if(trade.PositionClose(ticket))
                    {
                        PrintFormat("✅ 스탑로스 성공 - Ticket:%I64u", ticket);
                    }
                    else
                    {
                        PrintFormat("❌ 스탑로스 실패 - Ticket:%I64u ret:%d", ticket, trade.ResultRetcode());
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 우리 EA 포지션만 청산 (수동 거래와 명확히 구분)                    |
//+------------------------------------------------------------------+
void CloseOwnPositions()
{
    int total = PositionsTotal();
    Print("🔍 포지션 검사 시작 - 총 포지션 수:", total, " 우리 매직넘버:", g_magic);
    
    for(int i = total - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionSelectByTicket(ticket))
        {
            string pos_symbol = PositionGetString(POSITION_SYMBOL);
            long pos_magic = PositionGetInteger(POSITION_MAGIC);
            ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double pos_volume = PositionGetDouble(POSITION_VOLUME);
            
            // 현재 심볼이고 우리 매직넘버인 포지션만 청산
            if(pos_symbol == _Symbol && pos_magic == g_magic)
            {
                PrintFormat("✅ 자동거래 포지션 청산 - Ticket:%I64u Symbol:%s Magic:%d Type:%s Volume:%.2f", 
                           ticket, pos_symbol, pos_magic, EnumToString(pos_type), pos_volume);
                
                if(!trade.PositionClose(ticket))
                {
                    PrintFormat("❌ 청산 실패 - ticket:%I64u ret:%d %s", ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
                }
            }
            else
            {
                // 수동 거래 또는 다른 EA 포지션은 건드리지 않음
                PrintFormat("ℹ️ 수동/다른EA 포지션 보호 - Ticket:%I64u Symbol:%s Magic:%d (우리:%d)", 
                           ticket, pos_symbol, pos_magic, g_magic);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 이전 주기 화살표 정리 함수 (시간프레임별 완전 분리)                |
//+------------------------------------------------------------------+
void CleanupOldArrows()
{
    int total = ObjectsTotal(0, -1, -1);
    int deleted = 0;
    for(int i = total - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i, -1, -1);
        if(StringFind(name, "UTB_", 0) == 0) // 모든 UT Bot 화살표 삭제
        {
            ObjectDelete(0, name);
            deleted++;
        }
    }
    Print("🧹 이전 화살표 정리 완료 - 삭제된 객체 수:", deleted);
}

//+------------------------------------------------------------------+
//| 화살표 그리기 (시간프레임별 분리)                                 |
//+------------------------------------------------------------------+
void DrawArrow(string signal, double price)
{
    // rates 배열에서 현재 봉의 시간 가져오기
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, rates) <= 0) return;
    
    datetime current_time = rates[0].time; // 현재 바 시간
    string name = g_timeframePrefix + IntegerToString((int)current_time) + "_" + signal;
    
    // 화살표 위치 계산
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double arrowPrice;
    int code;
    color clr;
    
    if(signal == "BUY")
    {
        arrowPrice = price - (ArrowDistance * point);
        code = BuyArrowCode;
        clr = BuyArrowColor;
    }
    else
    {
        arrowPrice = price + (ArrowDistance * point);
        code = SellArrowCode;
        clr = SellArrowColor;
    }

    // 화살표 생성
    if(ObjectCreate(0, name, OBJ_ARROW, 0, current_time, arrowPrice))
    {
        ObjectSetInteger(0, name, OBJPROP_ARROWCODE, code);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
        ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS); // 모든 시간프레임에 표시
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
        
        PrintFormat("🎯 화살표 생성 성공 - %s 신호, 가격:%.5f, 거리:%d포인트", signal, arrowPrice, ArrowDistance);
    }
    else
    {
        PrintFormat("❌ 화살표 생성 실패 - %s 신호, 에러:%d", signal, GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("🔄 EA 종료 감지 - 모든 화살표 정리 시작");
    
    // 모든 UT Bot 화살표 삭제
    int total = ObjectsTotal(0, -1, -1);
    int deleted = 0;
    
    for(int i = total - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i, -1, -1);
        if(StringFind(name, "UTB_", 0) == 0) // 모든 UT Bot 화살표 삭제
        {
            ObjectDelete(0, name);
            deleted++;
        }
    }
    
    Print("✅ EA 종료 완료 - 삭제된 화살표 수:", deleted);
    
    // 종료 이유에 따른 메시지
    string reasonText = "";
    switch(reason)
    {
        case REASON_PROGRAM: reasonText = "프로그램 종료"; break;
        case REASON_REMOVE: reasonText = "차트에서 제거"; break;
        case REASON_RECOMPILE: reasonText = "재컴파일"; break;
        case REASON_CHARTCHANGE: reasonText = "차트 변경"; break;
        case REASON_CHARTCLOSE: reasonText = "차트 닫기"; break;
        case REASON_PARAMETERS: reasonText = "파라미터 변경"; break;
        case REASON_ACCOUNT: reasonText = "계정 변경"; break;
        case REASON_TEMPLATE: reasonText = "템플릿 적용"; break;
        case REASON_INITFAILED: reasonText = "초기화 실패"; break;
        case REASON_CLOSE: reasonText = "터미널 종료"; break;
        default: reasonText = "기타 이유"; break;
    }
    
    Print("📋 종료 이유:", reasonText, " (코드:", reason, ")");
}

//+------------------------------------------------------------------+
//| 차트 이벤트 핸들러                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    // 차트 변경 이벤트 감지 (시간 프레임 변경, 차트 확대/축소)
    if(id == CHARTEVENT_CHART_CHANGE)
    {
        int curPeriod = (int)Period();
        int curVisibleBars = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
        
        // 시간 프레임 변경 감지
        if(curPeriod != g_lastPeriod)
        {
            CleanupOldArrows();
            g_timeframePrefix = "UTB_" + IntegerToString(curPeriod) + "_";
            g_lastPeriod = curPeriod;
            g_lastVisibleBars = curVisibleBars;
            g_firstRun = true; // 새 시간프레임에서 모든 봉 신호 다시 계산
            Print("🔄 시간 프레임 변경 감지 - Period:", curPeriod, " VisibleBars:", curVisibleBars);
        }
        // 차트 확대/축소 감지 (화면에 보이는 봉 개수 변경)
        else if(curVisibleBars != g_lastVisibleBars)
        {
            g_lastVisibleBars = curVisibleBars;
            g_firstRun = true; // 차트 확대/축소 시 재계산
            Print("🔍 차트 확대/축소 감지 - VisibleBars:", curVisibleBars);
        }
    }
    
    // 키보드 이벤트 감지 (Ctrl+R 리셋)
    if(id == CHARTEVENT_KEYDOWN && EnableManualReset)
    {
        // Ctrl+R (R키 코드 82)
        if(lparam == 82) // R키
        {
            Print("⌨️ R키 감지 - 화살표 리셋 실행");
            ManualResetArrows();
        }
    }
}