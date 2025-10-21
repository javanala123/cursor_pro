//+------------------------------------------------------------------+
//|                                    Multi_Symbol_Strategy_EA.mq5 |
//|                                    Copyright 2024, AI Trading System |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, AI Trading System"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "다중 심볼 전략 EA - 커스텀 심볼 지원"

#include <Trade\Trade.mqh>

//--- 입력 파라미터
input double LotSize = 0.01;           // 기본 로트 크기
input int MagicNumber = 123456;        // 매직 넘버

// ★★★ 심볼별 설정 ★★★
input string Symbol1 = "BTCUSDM_Real";     // 심볼 1
input string Symbol2 = "ETHUSDM_Real";     // 심볼 2
input string Symbol3 = "EURUSD_Real";      // 심볼 3
input string Symbol4 = "GBPUSD_Real";      // 심볼 4

// ★★★ 전략 선택 ★★★
enum ENUM_STRATEGY {
    STRATEGY_MA_CROSS,      // 이동평균 교차
    STRATEGY_RSI,           // RSI 전략
    STRATEGY_BOLLINGER,     // 볼린저 밴드
    STRATEGY_UT_BOT,        // UT Bot 전략
    STRATEGY_COMBINED       // 복합 전략
};
input ENUM_STRATEGY Strategy = STRATEGY_MA_CROSS;

// ★★★ 이동평균 설정 ★★★
input int MA_Fast_Period = 10;         // 빠른 이동평균
input int MA_Slow_Period = 20;         // 느린 이동평균

// ★★★ RSI 설정 ★★★
input int RSI_Period = 14;             // RSI 기간
input double RSI_Overbought = 70.0;    // 과매수 레벨
input double RSI_Oversold = 30.0;      // 과매도 레벨

// ★★★ 볼린저 밴드 설정 ★★★
input int BB_Period = 20;              // 볼린저 밴드 기간
input double BB_Deviation = 2.0;       // 표준편차 배수

//--- 전역 변수
CTrade trade;
string symbols[];
int handles[][10];  // 각 심볼당 최대 10개 지표 핸들
double last_signals[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🚀 다중 심볼 전략 EA 초기화 시작");
    
    // 심볼 배열 초기화
    ArrayResize(symbols, 4);
    symbols[0] = Symbol1;
    symbols[1] = Symbol2;
    symbols[2] = Symbol3;
    symbols[3] = Symbol4;
    
    // 핸들 배열 초기화
    ArrayResize(handles, 4);
    ArrayResize(last_signals, 4);
    
    // 거래 설정
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    // 각 심볼별 초기화
    for(int i = 0; i < 4; i++)
    {
        if(symbols[i] != "")
        {
            if(!InitializeSymbol(i))
            {
                Print("❌ 심볼 초기화 실패: ", symbols[i]);
                return INIT_FAILED;
            }
        }
    }
    
    Print("✅ 다중 심볼 전략 EA 초기화 완료");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| 심볼별 초기화 함수                                               |
//+------------------------------------------------------------------+
bool InitializeSymbol(int symbol_index)
{
    string symbol = symbols[symbol_index];
    
    // 심볼 선택
    if(!SymbolSelect(symbol, true))
    {
        Print("❌ 심볼 선택 실패: ", symbol);
        return false;
    }
    
    // 심볼 정보 출력
    double contract_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    
    Print("📋 심볼 정보 [", symbol_index, "]: ", symbol);
    Print("   - 계약 크기: ", contract_size);
    Print("   - 최소 거래량: ", min_lot);
    Print("   - 최대 거래량: ", max_lot);
    
    // 지표 핸들 생성
    ArrayResize(handles[symbol_index], 10);
    ArrayInitialize(handles[symbol_index], INVALID_HANDLE);
    
    int handle_index = 0;
    
    // 전략별 지표 생성
    switch(Strategy)
    {
        case STRATEGY_MA_CROSS:
            handles[symbol_index][handle_index++] = iMA(symbol, PERIOD_CURRENT, MA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
            handles[symbol_index][handle_index++] = iMA(symbol, PERIOD_CURRENT, MA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
            break;
            
        case STRATEGY_RSI:
            handles[symbol_index][handle_index++] = iRSI(symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
            break;
            
        case STRATEGY_BOLLINGER:
            handles[symbol_index][handle_index++] = iBands(symbol, PERIOD_CURRENT, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
            break;
            
        case STRATEGY_UT_BOT:
            handles[symbol_index][handle_index++] = iCustom(symbol, PERIOD_CURRENT, "UT_Bot_Indicator");
            break;
            
        case STRATEGY_COMBINED:
            handles[symbol_index][handle_index++] = iMA(symbol, PERIOD_CURRENT, MA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
            handles[symbol_index][handle_index++] = iMA(symbol, PERIOD_CURRENT, MA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
            handles[symbol_index][handle_index++] = iRSI(symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
            break;
    }
    
    // 핸들 검증
    for(int i = 0; i < handle_index; i++)
    {
        if(handles[symbol_index][i] == INVALID_HANDLE)
        {
            Print("❌ 지표 핸들 생성 실패: ", symbol, " [", i, "]");
            return false;
        }
    }
    
    last_signals[symbol_index] = 0;
    return true;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // 모든 핸들 해제
    for(int i = 0; i < 4; i++)
    {
        for(int j = 0; j < ArraySize(handles[i]); j++)
        {
            if(handles[i][j] != INVALID_HANDLE)
                IndicatorRelease(handles[i][j]);
        }
    }
    
    Print("🔚 다중 심볼 전략 EA 종료");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // 각 심볼별 처리
    for(int i = 0; i < 4; i++)
    {
        if(symbols[i] != "")
        {
            ProcessSymbol(i);
        }
    }
}

//+------------------------------------------------------------------+
//| 심볼별 처리 함수                                                 |
//+------------------------------------------------------------------+
void ProcessSymbol(int symbol_index)
{
    string symbol = symbols[symbol_index];
    
    // 새로운 바 확인
    static datetime last_bar_times[4] = {0, 0, 0, 0};
    datetime current_bar_time = iTime(symbol, PERIOD_CURRENT, 0);
    
    if(current_bar_time == last_bar_times[symbol_index])
        return;
    
    last_bar_times[symbol_index] = current_bar_time;
    
    // 신호 분석
    double signal = AnalyzeSignal(symbol_index);
    
    if(signal != 0 && signal != last_signals[symbol_index])
    {
        Print("📊 신호 감지 [", symbol, "]: ", signal > 0 ? "매수" : "매도", " (", signal, ")");
        
        // 거래 실행
        ExecuteTrade(symbol_index, signal);
        last_signals[symbol_index] = signal;
    }
}

//+------------------------------------------------------------------+
//| 신호 분석 함수                                                   |
//+------------------------------------------------------------------+
double AnalyzeSignal(int symbol_index)
{
    string symbol = symbols[symbol_index];
    double signal = 0;
    
    switch(Strategy)
    {
        case STRATEGY_MA_CROSS:
            signal = AnalyzeMA_Cross(symbol_index);
            break;
            
        case STRATEGY_RSI:
            signal = AnalyzeRSI(symbol_index);
            break;
            
        case STRATEGY_BOLLINGER:
            signal = AnalyzeBollinger(symbol_index);
            break;
            
        case STRATEGY_UT_BOT:
            signal = AnalyzeUT_Bot(symbol_index);
            break;
            
        case STRATEGY_COMBINED:
            signal = AnalyzeCombined(symbol_index);
            break;
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| 이동평균 교차 분석                                               |
//+------------------------------------------------------------------+
double AnalyzeMA_Cross(int symbol_index)
{
    double ma_fast[2], ma_slow[2];
    
    if(CopyBuffer(handles[symbol_index][0], 0, 1, 2, ma_fast) <= 0 ||
       CopyBuffer(handles[symbol_index][1], 0, 1, 2, ma_slow) <= 0)
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
//| RSI 분석                                                         |
//+------------------------------------------------------------------+
double AnalyzeRSI(int symbol_index)
{
    double rsi[1];
    
    if(CopyBuffer(handles[symbol_index][0], 0, 1, 1, rsi) <= 0)
        return 0;
    
    // 과매도에서 반등 (매수 신호)
    if(rsi[0] < RSI_Oversold)
        return 1;
    
    // 과매수에서 하락 (매도 신호)
    if(rsi[0] > RSI_Overbought)
        return -1;
    
    return 0;
}

//+------------------------------------------------------------------+
//| 볼린저 밴드 분석                                                 |
//+------------------------------------------------------------------+
double AnalyzeBollinger(int symbol_index)
{
    string symbol = symbols[symbol_index];
    double bb_upper[1], bb_lower[1];
    double current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    if(CopyBuffer(handles[symbol_index][0], 1, 1, 1, bb_upper) <= 0 ||
       CopyBuffer(handles[symbol_index][0], 2, 1, 1, bb_lower) <= 0)
        return 0;
    
    // 하단 터치 후 반등 (매수 신호)
    if(current_price <= bb_lower[0])
        return 1;
    
    // 상단 터치 후 하락 (매도 신호)
    if(current_price >= bb_upper[0])
        return -1;
    
    return 0;
}

//+------------------------------------------------------------------+
//| UT Bot 분석                                                      |
//+------------------------------------------------------------------+
double AnalyzeUT_Bot(int symbol_index)
{
    double ut_signal[1];
    
    if(CopyBuffer(handles[symbol_index][0], 0, 1, 1, ut_signal) <= 0)
        return 0;
    
    return ut_signal[0];
}

//+------------------------------------------------------------------+
//| 복합 전략 분석                                                   |
//+------------------------------------------------------------------+
double AnalyzeCombined(int symbol_index)
{
    double ma_signal = AnalyzeMA_Cross(symbol_index);
    double rsi_signal = AnalyzeRSI(symbol_index);
    
    // MA와 RSI 신호가 일치할 때만 거래
    if(ma_signal > 0 && rsi_signal > 0)
        return 1;
    if(ma_signal < 0 && rsi_signal < 0)
        return -1;
    
    return 0;
}

//+------------------------------------------------------------------+
//| 거래 실행 함수                                                   |
//+------------------------------------------------------------------+
void ExecuteTrade(int symbol_index, double signal)
{
    string symbol = symbols[symbol_index];
    
    // 현재 포지션 확인
    bool has_buy = PositionSelect(symbol) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
    bool has_sell = PositionSelect(symbol) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL;
    
    // 매수 신호 처리
    if(signal > 0)
    {
        // 기존 매도 포지션 청산
        if(has_sell)
        {
            trade.PositionClose(symbol);
            Print("📉 매도 포지션 청산 [", symbol, "]");
        }
        
        // 매수 진입
        if(!has_buy)
        {
            double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
            double contract_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
            
            if(trade.Buy(LotSize, symbol, price, 0, 0, "Multi Strategy Buy"))
            {
                Print("📈 매수 진입 [", symbol, "]: ", LotSize, " 랏 @ ", price);
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
            trade.PositionClose(symbol);
            Print("📈 매수 포지션 청산 [", symbol, "]");
        }
        
        // 매도 진입
        if(!has_sell)
        {
            double price = SymbolInfoDouble(symbol, SYMBOL_BID);
            double contract_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
            
            if(trade.Sell(LotSize, symbol, price, 0, 0, "Multi Strategy Sell"))
            {
                Print("📉 매도 진입 [", symbol, "]: ", LotSize, " 랏 @ ", price);
                Print("   - 실제 거래량: ", LotSize * contract_size, " 단위");
            }
        }
    }
}
