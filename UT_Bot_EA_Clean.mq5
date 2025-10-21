//+------------------------------------------------------------------+
//|                                          UT_Bot_EA_Clean.mq5    |
//|                        Copyright 2024, MetaQuotes Software Corp.|
//|                                             https://www.mql5.com|
//+------------------------------------------------------------------+
//| UT Bot Expert Advisor - 깔끔한 버전                              |
//| 핵심 기능만 포함: 신호 생성, 연속 신호 방지, 청산/진입, 화살표   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "UT Bot Expert Advisor - Clean Version"

//--- 입력 파라미터
input group "=== UT Bot 설정 ==="
input double KeyValue = 1.0;           // 민감도 조절 값
input int ATRPeriod = 20;              // ATR 계산 기간
input double FixedLotSize = 0.01;      // 고정 로트 크기
input bool UseReversePosition = true;  // 반대 신호 시 청산 후 반대 진입

input group "=== 거래 설정 ==="
input int MagicNumber = 12345;         // 매직 넘버
input int Slippage = 10;               // 슬리피지
input double MaxSpread = 500;          // 최대 허용 스프레드

//--- 전역 변수
int g_atr_handle;                      // ATR 인디케이터 핸들
double g_xATRTrailingStop = 0.0;       // 현재 ATR 트레일링 스탑
double g_prevATRTrailingStop = 0.0;    // 이전 ATR 트레일링 스탑
double g_prevSrc = 0.0;                // 이전 소스 가격

//--- 연속 신호 방지
int g_lastSignalType = 0;              // 마지막 신호 타입 (1=매수, -1=매도, 0=없음)
datetime g_lastBarTime = 0;            // 마지막 바 시간

//--- 거래 객체
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- 거래 파라미터 설정
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(Slippage);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    //--- ATR 인디케이터 초기화
    g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
    if(g_atr_handle == INVALID_HANDLE)
    {
        Print("❌ ATR 인디케이터 초기화 실패");
        return INIT_FAILED;
    }
    
    //--- 전역 변수 초기화
    g_xATRTrailingStop = 0.0;
    g_prevATRTrailingStop = 0.0;
    g_prevSrc = 0.0;
    g_lastSignalType = 0;
    g_lastBarTime = 0;
    
    Print("✅ UT Bot EA 초기화 완료");
    Print("📊 KeyValue: ", KeyValue, " / ATR Period: ", ATRPeriod);
    Print("💰 로트 크기: ", FixedLotSize);
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- 인디케이터 핸들 해제
    if(g_atr_handle != INVALID_HANDLE)
        IndicatorRelease(g_atr_handle);
    
    Print("✅ UT Bot EA 종료");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- 새 바 확인
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(currentBarTime == g_lastBarTime)
        return;  // 같은 바이면 처리하지 않음
    
    g_lastBarTime = currentBarTime;
    
    //--- 현재 가격 가져오기
    double src = iClose(_Symbol, PERIOD_CURRENT, 0);
    if(src <= 0)
        return;
    
    //--- ATR 값 가져오기
    double atr[1];
    if(CopyBuffer(g_atr_handle, 0, 0, 1, atr) <= 0 || atr[0] <= 0)
        return;
    
    //--- ATR 트레일링 스탑 계산
    CalculateATRTrailingStop(src, atr[0]);
    
    //--- 거래 신호 확인
    CheckTradingSignals(src);
    
    //--- 이전 값 저장
    g_prevSrc = src;
    g_prevATRTrailingStop = g_xATRTrailingStop;
}

//+------------------------------------------------------------------+
//| ATR 트레일링 스탑 계산                                           |
//+------------------------------------------------------------------+
void CalculateATRTrailingStop(double src, double atr)
{
    //--- 이전 값이 없으면 초기화
    if(g_prevATRTrailingStop == 0.0)
    {
        g_xATRTrailingStop = src - (atr * KeyValue);
        return;
    }
    
    //--- nLoss 계산
    double nLoss = atr * KeyValue;
    
    //--- iff_1 계산
    double iff_1;
    if((src > g_prevATRTrailingStop) && (g_prevSrc > g_prevATRTrailingStop))
    {
        iff_1 = MathMax(g_prevATRTrailingStop, src - nLoss);
    }
    else
    {
        iff_1 = g_prevATRTrailingStop;
    }
    
    //--- iff_2 계산
    double iff_2;
    if((src < g_prevATRTrailingStop) && (g_prevSrc < g_prevATRTrailingStop))
    {
        iff_2 = MathMin(g_prevATRTrailingStop, src + nLoss);
    }
    else
    {
        iff_2 = iff_1;
    }
    
    //--- 최종 xATRTrailingStop 계산
    if((src > g_prevATRTrailingStop) && (g_prevSrc > g_prevATRTrailingStop))
    {
        g_xATRTrailingStop = MathMax(g_prevATRTrailingStop, src - nLoss);
    }
    else
    {
        g_xATRTrailingStop = iff_2;
    }
}

//+------------------------------------------------------------------+
//| 거래 신호 확인 및 처리                                           |
//+------------------------------------------------------------------+
void CheckTradingSignals(double src)
{
    //--- 이전 값이 없으면 신호 판단 불가
    if(g_prevATRTrailingStop == 0.0)
        return;
    
    //--- 현재 포지션 상태 확인
    bool hasBuy = HasPosition(POSITION_TYPE_BUY);
    bool hasSell = HasPosition(POSITION_TYPE_SELL);
    
    //--- 신호 생성
    bool buySignal = (src > g_prevATRTrailingStop) && (g_prevSrc <= g_prevATRTrailingStop);
    bool sellSignal = (src < g_prevATRTrailingStop) && (g_prevSrc >= g_prevATRTrailingStop);
    
    //--- 연속 신호 방지
    if(buySignal && g_lastSignalType == 1)
    {
        Print("⚠️ 중복 매수 신호 무시");
        return;
    }
    
    if(sellSignal && g_lastSignalType == -1)
    {
        Print("⚠️ 중복 매도 신호 무시");
        return;
    }
    
    //--- 매수 신호 처리
    if(buySignal)
    {
        // 이미 매수 포지션 있으면 무시
        if(hasBuy)
        {
            Print("⚠️ 이미 매수 포지션 보유 중");
            return;
        }
        
        Print("▲▲▲ 매수 신호 발생! ▲▲▲");
        
        // 화살표 그리기
        CreateSignalArrow("BUY", src);
        
        // 반대 포지션(매도)이 있으면 청산
        if(hasSell && UseReversePosition)
        {
            ClosePositions(POSITION_TYPE_SELL);
            Print("★ 매도 포지션 청산 완료 → 매수 진입 ★");
            Sleep(100);  // 청산 완료 대기
        }
        
        // 매수 진입
        ExecuteBuyOrder();
        g_lastSignalType = 1;  // 매수 신호 기록
    }
    
    //--- 매도 신호 처리
    if(sellSignal)
    {
        // 이미 매도 포지션 있으면 무시
        if(hasSell)
        {
            Print("⚠️ 이미 매도 포지션 보유 중");
            return;
        }
        
        Print("▼▼▼ 매도 신호 발생! ▼▼▼");
        
        // 화살표 그리기
        CreateSignalArrow("SELL", src);
        
        // 반대 포지션(매수)이 있으면 청산
        if(hasBuy && UseReversePosition)
        {
            ClosePositions(POSITION_TYPE_BUY);
            Print("★ 매수 포지션 청산 완료 → 매도 진입 ★");
            Sleep(100);  // 청산 완료 대기
        }
        
        // 매도 진입
        ExecuteSellOrder();
        g_lastSignalType = -1;  // 매도 신호 기록
    }
}

//+------------------------------------------------------------------+
//| 매수 주문 실행                                                   |
//+------------------------------------------------------------------+
void ExecuteBuyOrder()
{
    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double lot = FixedLotSize;
    
    if(trade.Buy(lot, _Symbol, price, 0, 0, "UT Bot Buy"))
    {
        Print("✅ 매수 주문 체결: ", lot, " 랏 @ ", price);
    }
    else
    {
        Print("❌ 매수 주문 실패: ", trade.ResultRetcode());
    }
}

//+------------------------------------------------------------------+
//| 매도 주문 실행                                                   |
//+------------------------------------------------------------------+
void ExecuteSellOrder()
{
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double lot = FixedLotSize;
    
    if(trade.Sell(lot, _Symbol, price, 0, 0, "UT Bot Sell"))
    {
        Print("✅ 매도 주문 체결: ", lot, " 랏 @ ", price);
    }
    else
    {
        Print("❌ 매도 주문 실패: ", trade.ResultRetcode());
    }
}

//+------------------------------------------------------------------+
//| 포지션 존재 여부 확인                                            |
//+------------------------------------------------------------------+
bool HasPosition(ENUM_POSITION_TYPE type)
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
            if(PositionGetInteger(POSITION_TYPE) == type)
                return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| 포지션 청산                                                      |
//+------------------------------------------------------------------+
void ClosePositions(ENUM_POSITION_TYPE type)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
            if(PositionGetInteger(POSITION_TYPE) == type)
            {
                ulong ticket = PositionGetInteger(POSITION_TICKET);
                if(trade.PositionClose(ticket))
                {
                    Print("✅ 포지션 청산 완료: ", ticket);
                }
                else
                {
                    Print("❌ 포지션 청산 실패: ", trade.ResultRetcode());
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 신호 화살표 그리기                                               |
//+------------------------------------------------------------------+
void CreateSignalArrow(string signal, double price)
{
    string arrowName = "UT_Bot_" + signal + "_" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
    
    // 화살표 위치 설정 (넉넉하게 이격)
    double arrowOffset = 50.0;  // 50포인트 이격
    double arrowPrice;
    int arrowCode;
    
    if(signal == "BUY")
    {
        arrowPrice = price - arrowOffset;
        arrowCode = 233;  // 위쪽 화살표
    }
    else  // SELL
    {
        arrowPrice = price + arrowOffset;
        arrowCode = 234;  // 아래쪽 화살표
    }
    
    // 화살표 객체 생성
    if(ObjectCreate(0, arrowName, OBJ_ARROW, 0, TimeCurrent(), arrowPrice))
    {
        ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, arrowCode);
        ObjectSetInteger(0, arrowName, OBJPROP_COLOR, signal == "BUY" ? clrLime : clrRed);
        ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);
        ObjectSetInteger(0, arrowName, OBJPROP_ANCHOR, signal == "BUY" ? ANCHOR_TOP : ANCHOR_BOTTOM);
        
        Print("📊 ", signal, " 신호 화살표 표시: ", arrowPrice);
    }
}
