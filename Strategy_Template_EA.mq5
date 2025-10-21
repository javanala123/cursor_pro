//+------------------------------------------------------------------+
//|                                        Strategy_Template_EA.mq5 |
//|                                    Copyright 2024, AI Trading System |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, AI Trading System"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "전략 템플릿 EA - 커스텀 심볼용"

#include <Trade\Trade.mqh>

//--- 입력 파라미터
input string CustomSymbol = "BTCUSDM_Real";  // 커스텀 심볼 이름
input double LotSize = 0.01;                 // 로트 크기
input int MagicNumber = 123456;              // 매직 넘버

// ★★★ 전략 파라미터 (사용자가 수정) ★★★
input int Strategy_Period1 = 10;             // 전략 파라미터 1
input int Strategy_Period2 = 20;             // 전략 파라미터 2
input double Strategy_Threshold = 0.5;       // 전략 임계값

//--- 전역 변수
CTrade trade;
int indicator_handles[5];  // 최대 5개 지표
double last_signal = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🚀 전략 템플릿 EA 초기화 시작");
    
    // 커스텀 심볼 확인
    if(!SymbolSelect(CustomSymbol, true))
    {
        Print("❌ 커스텀 심볼을 선택할 수 없습니다: ", CustomSymbol);
        return INIT_FAILED;
    }
    
    // 심볼 정보 출력
    PrintSymbolInfo();
    
    // 지표 핸들 생성 (여기에 전략에 맞는 지표 추가)
    if(!CreateIndicators())
    {
        Print("❌ 지표 생성 실패");
        return INIT_FAILED;
    }
    
    // 거래 설정
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    Print("✅ 전략 템플릿 EA 초기화 완료");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| 심볼 정보 출력 함수                                              |
//+------------------------------------------------------------------+
void PrintSymbolInfo()
{
    double contract_size = SymbolInfoDouble(CustomSymbol, SYMBOL_TRADE_CONTRACT_SIZE);
    double min_lot = SymbolInfoDouble(CustomSymbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(CustomSymbol, SYMBOL_VOLUME_MAX);
    double point = SymbolInfoDouble(CustomSymbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(CustomSymbol, SYMBOL_DIGITS);
    
    Print("📋 커스텀 심볼 정보:");
    Print("   - 심볼: ", CustomSymbol);
    Print("   - 계약 크기: ", contract_size);
    Print("   - 최소 거래량: ", min_lot);
    Print("   - 최대 거래량: ", max_lot);
    Print("   - 포인트: ", point);
    Print("   - 소수점: ", digits);
}

//+------------------------------------------------------------------+
//| 지표 생성 함수 (전략에 맞게 수정)                                |
//+------------------------------------------------------------------+
bool CreateIndicators()
{
    ArrayInitialize(indicator_handles, INVALID_HANDLE);
    
    // 예시: 이동평균 지표들
    indicator_handles[0] = iMA(CustomSymbol, PERIOD_CURRENT, Strategy_Period1, 0, MODE_EMA, PRICE_CLOSE);
    indicator_handles[1] = iMA(CustomSymbol, PERIOD_CURRENT, Strategy_Period2, 0, MODE_EMA, PRICE_CLOSE);
    indicator_handles[2] = iRSI(CustomSymbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
    
    // 핸들 검증
    for(int i = 0; i < 3; i++)
    {
        if(indicator_handles[i] == INVALID_HANDLE)
        {
            Print("❌ 지표 핸들 생성 실패 [", i, "]");
            return false;
        }
    }
    
    Print("✅ 지표 생성 완료");
    return true;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // 핸들 해제
    for(int i = 0; i < ArraySize(indicator_handles); i++)
    {
        if(indicator_handles[i] != INVALID_HANDLE)
            IndicatorRelease(indicator_handles[i]);
    }
    
    Print("🔚 전략 템플릿 EA 종료");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // 새로운 바 확인
    static datetime last_bar_time = 0;
    datetime current_bar_time = iTime(CustomSymbol, PERIOD_CURRENT, 0);
    
    if(current_bar_time == last_bar_time)
        return;
    
    last_bar_time = current_bar_time;
    
    // 신호 분석
    double signal = AnalyzeSignal();
    
    if(signal != 0 && signal != last_signal)
    {
        Print("📊 신호 감지: ", signal > 0 ? "매수" : "매도", " (", signal, ")");
        
        // 거래 실행
        ExecuteTrade(signal);
        last_signal = signal;
    }
}

//+------------------------------------------------------------------+
//| 신호 분석 함수 (전략 로직 구현)                                  |
//+------------------------------------------------------------------+
double AnalyzeSignal()
{
    // 여기에 전략 로직을 구현하세요
    // 예시: 이동평균 교차 전략
    
    double ma_fast[2], ma_slow[2];
    
    if(CopyBuffer(indicator_handles[0], 0, 1, 2, ma_fast) <= 0 ||
       CopyBuffer(indicator_handles[1], 0, 1, 2, ma_slow) <= 0)
        return 0;
    
    // 골든 크로스 (상승 신호)
    if(ma_fast[0] > ma_slow[0] && ma_fast[1] <= ma_slow[1])
        return 1;
    
    // 데드 크로스 (하락 신호)
    if(ma_fast[0] < ma_slow[0] && ma_fast[1] >= ma_slow[1])
        return -1;
    
    return 0;
}

//+------------------------------------------------------------------+
//| 거래 실행 함수                                                   |
//+------------------------------------------------------------------+
void ExecuteTrade(double signal)
{
    // 현재 포지션 확인
    bool has_buy = PositionSelect(CustomSymbol) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
    bool has_sell = PositionSelect(CustomSymbol) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL;
    
    // 매수 신호 처리
    if(signal > 0)
    {
        // 기존 매도 포지션 청산
        if(has_sell)
        {
            trade.PositionClose(CustomSymbol);
            Print("📉 매도 포지션 청산");
        }
        
        // 매수 진입
        if(!has_buy)
        {
            double price = SymbolInfoDouble(CustomSymbol, SYMBOL_ASK);
            double contract_size = SymbolInfoDouble(CustomSymbol, SYMBOL_TRADE_CONTRACT_SIZE);
            
            if(trade.Buy(LotSize, CustomSymbol, price, 0, 0, "Strategy Buy"))
            {
                Print("📈 매수 진입: ", LotSize, " 랏 @ ", price);
                Print("   - 실제 거래량: ", LotSize * contract_size, " 단위");
            }
        }
    }
    
    // 매도 신호 처리
    if(signal < 0)
    {
        // 기존 매수 포지션 청산
        if(has_buy)
        {
            trade.PositionClose(CustomSymbol);
            Print("📈 매수 포지션 청산");
        }
        
        // 매도 진입
        if(!has_sell)
        {
            double price = SymbolInfoDouble(CustomSymbol, SYMBOL_BID);
            double contract_size = SymbolInfoDouble(CustomSymbol, SYMBOL_TRADE_CONTRACT_SIZE);
            
            if(trade.Sell(LotSize, CustomSymbol, price, 0, 0, "Strategy Sell"))
            {
                Print("📉 매도 진입: ", LotSize, " 랏 @ ", price);
                Print("   - 실제 거래량: ", LotSize * contract_size, " 단위");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 거래 정보 출력 함수                                              |
//+------------------------------------------------------------------+
void PrintTradeInfo()
{
    if(PositionSelect(CustomSymbol))
    {
        double volume = PositionGetDouble(POSITION_VOLUME);
        double price_open = PositionGetDouble(POSITION_PRICE_OPEN);
        double profit = PositionGetDouble(POSITION_PROFIT);
        double swap = PositionGetDouble(POSITION_SWAP);
        double contract_size = SymbolInfoDouble(CustomSymbol, SYMBOL_TRADE_CONTRACT_SIZE);
        
        Print("📊 현재 포지션 정보:");
        Print("   - 거래량: ", volume, " 랏 (", volume * contract_size, " 단위)");
        Print("   - 진입가: $", price_open);
        Print("   - 현재 수익: $", profit);
        Print("   - 스왑: $", swap);
    }
}
