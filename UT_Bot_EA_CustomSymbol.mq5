//+------------------------------------------------------------------+
//|                                    UT_Bot_EA_CustomSymbol.mq5 |
//|                                    Copyright 2024, AI Trading System |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, AI Trading System"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "UT Bot EA - 커스텀 심볼용 (정확한 계약 크기)"

#include <Trade\Trade.mqh>

//--- 입력 파라미터
input double KeyValue = 2.0;           // 민감도
input int ATRPeriod = 30;              // ATR 기간
input double LotSize = 0.01;           // 로트 크기 (실제: 0.01 BTC)
input bool ReversePosition = true;     // 반대 신호 시 청산 후 진입

// ★★★ 커스텀 심볼 설정 ★★★
input string CustomSymbolName = "BTCUSDM_Real";  // 커스텀 심볼 이름
input double ContractSize = 1.0;                 // 계약 크기 (1 랏 = 1 BTC)
input int Leverage = 200;                        // 레버리지
input double CommissionPerLot = 0.1;             // 랏당 수수료 (USD)

// ★★★ 매매 모드 선택 ★★★
enum ENUM_TRADE_MODE {
    TRADE_BUY_ONLY,      // 매수만
    TRADE_SELL_ONLY,     // 매도만
    TRADE_BOTH           // 매수+매도
};
input ENUM_TRADE_MODE TradeMode = TRADE_BOTH;

// ★★★ 지표 모드 선택 ★★★
enum ENUM_INDICATOR_MODE {
    MODE_UT_BOT_ONLY,    // 순수 UT Bot만
    MODE_UT_BOT_ADX,     // UT Bot + ADX 필터
    MODE_UT_BOT_RSI,     // UT Bot + RSI 필터
    MODE_UT_BOT_ENHANCED // UT Bot + ADX + RSI
};
input ENUM_INDICATOR_MODE IndicatorMode = MODE_UT_BOT_ONLY;

// ★★★ ADX 필터 설정 ★★★
input int ADXPeriod = 14;
input double ADXThreshold = 10.0;
input bool UseADXFilter = true;

// ★★★ RSI 필터 설정 ★★★
input int RSIPeriod = 14;
input double RSIOverbought = 70.0;
input double RSIOversold = 30.0;
input bool UseRSIFilter = true;

//--- 전역 변수
CTrade trade;
int ut_bot_handle;
int adx_handle;
int rsi_handle;
double last_signal = 0;
datetime last_trade_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🚀 UT Bot EA - 커스텀 심볼용 초기화 시작");
    
    // 커스텀 심볼 확인
    if(!SymbolSelect(CustomSymbolName, true))
    {
        Print("❌ 커스텀 심볼을 선택할 수 없습니다: ", CustomSymbolName);
        return INIT_FAILED;
    }
    
    // 심볼 정보 출력
    double contract_size = SymbolInfoDouble(CustomSymbolName, SYMBOL_TRADE_CONTRACT_SIZE);
    double min_lot = SymbolInfoDouble(CustomSymbolName, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(CustomSymbolName, SYMBOL_VOLUME_MAX);
    
    Print("📋 커스텀 심볼 정보:");
    Print("   - 심볼: ", CustomSymbolName);
    Print("   - 계약 크기: ", contract_size, " (목표: ", ContractSize, ")");
    Print("   - 최소 거래량: ", min_lot);
    Print("   - 최대 거래량: ", max_lot);
    Print("   - 레버리지: 1:", Leverage);
    
    // 계약 크기 검증
    if(MathAbs(contract_size - ContractSize) > 0.001)
    {
        Print("⚠️ 경고: 계약 크기가 설정과 다릅니다!");
        Print("   설정: ", ContractSize, " vs 실제: ", contract_size);
    }
    
    // 지표 핸들 생성
    ut_bot_handle = iCustom(CustomSymbolName, PERIOD_CURRENT, "UT_Bot_Indicator");
    if(ut_bot_handle == INVALID_HANDLE)
    {
        Print("❌ UT Bot 지표 핸들 생성 실패");
        return INIT_FAILED;
    }
    
    // ADX 핸들 (필요시)
    if(UseADXFilter && (IndicatorMode == MODE_UT_BOT_ADX || IndicatorMode == MODE_UT_BOT_ENHANCED))
    {
        adx_handle = iADX(CustomSymbolName, PERIOD_CURRENT, ADXPeriod);
        if(adx_handle == INVALID_HANDLE)
        {
            Print("❌ ADX 지표 핸들 생성 실패");
            return INIT_FAILED;
        }
    }
    
    // RSI 핸들 (필요시)
    if(UseRSIFilter && (IndicatorMode == MODE_UT_BOT_RSI || IndicatorMode == MODE_UT_BOT_ENHANCED))
    {
        rsi_handle = iRSI(CustomSymbolName, PERIOD_CURRENT, RSIPeriod, PRICE_CLOSE);
        if(rsi_handle == INVALID_HANDLE)
        {
            Print("❌ RSI 지표 핸들 생성 실패");
            return INIT_FAILED;
        }
    }
    
    // 거래 설정
    trade.SetExpertMagicNumber(123456);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    Print("✅ UT Bot EA 초기화 완료");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // 핸들 해제
    if(ut_bot_handle != INVALID_HANDLE)
        IndicatorRelease(ut_bot_handle);
    if(adx_handle != INVALID_HANDLE)
        IndicatorRelease(adx_handle);
    if(rsi_handle != INVALID_HANDLE)
        IndicatorRelease(rsi_handle);
    
    Print("🔚 UT Bot EA 종료");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // 새로운 바 확인
    static datetime last_bar_time = 0;
    datetime current_bar_time = iTime(CustomSymbolName, PERIOD_CURRENT, 0);
    
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
//| 신호 분석 함수                                                   |
//+------------------------------------------------------------------+
double AnalyzeSignal()
{
    // UT Bot 신호 가져오기
    double ut_signal[1];
    if(CopyBuffer(ut_bot_handle, 0, 1, 1, ut_signal) <= 0)
        return 0;
    
    double signal = ut_signal[0];
    
    // ADX 필터 적용
    if(UseADXFilter && (IndicatorMode == MODE_UT_BOT_ADX || IndicatorMode == MODE_UT_BOT_ENHANCED))
    {
        double adx_values[1];
        if(CopyBuffer(adx_handle, 0, 1, 1, adx_values) > 0)
        {
            if(adx_values[0] < ADXThreshold)
            {
                Print("🔍 ADX 필터: 추세 강도 부족 (", adx_values[0], " < ", ADXThreshold, ")");
                return 0;
            }
        }
    }
    
    // RSI 필터 적용
    if(UseRSIFilter && (IndicatorMode == MODE_UT_BOT_RSI || IndicatorMode == MODE_UT_BOT_ENHANCED))
    {
        double rsi_values[1];
        if(CopyBuffer(rsi_handle, 0, 1, 1, rsi_values) > 0)
        {
            if(signal > 0 && rsi_values[0] > RSIOverbought)
            {
                Print("🔍 RSI 필터: 과매수 구간 (", rsi_values[0], " > ", RSIOverbought, ")");
                return 0;
            }
            if(signal < 0 && rsi_values[0] < RSIOversold)
            {
                Print("🔍 RSI 필터: 과매도 구간 (", rsi_values[0], " < ", RSIOversold, ")");
                return 0;
            }
        }
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| 거래 실행 함수                                                   |
//+------------------------------------------------------------------+
void ExecuteTrade(double signal)
{
    // 현재 포지션 확인
    bool has_buy = PositionSelect(CustomSymbolName) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
    bool has_sell = PositionSelect(CustomSymbolName) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL;
    
    // 매수 신호 처리
    if(signal > 0)
    {
        if(TradeMode == TRADE_SELL_ONLY)
            return;
        
        // 기존 매도 포지션 청산
        if(has_sell)
        {
            trade.PositionClose(CustomSymbolName);
            Print("📉 매도 포지션 청산");
        }
        
        // 매수 진입
        if(!has_buy)
        {
            double price = SymbolInfoDouble(CustomSymbolName, SYMBOL_ASK);
            double margin_required = CalculateMarginRequired(LotSize, price);
            
            if(margin_required <= AccountInfoDouble(ACCOUNT_MARGIN_FREE))
            {
                if(trade.Buy(LotSize, CustomSymbolName, price, 0, 0, "UT Bot Buy"))
                {
                    Print("📈 매수 진입: ", LotSize, " 랏 @ ", price);
                    Print("   - 실제 거래량: ", LotSize * ContractSize, " BTC");
                    Print("   - 필요 증거금: $", margin_required);
                }
                else
                {
                    Print("❌ 매수 실패: ", trade.ResultRetcode());
                }
            }
            else
            {
                Print("⚠️ 증거금 부족: 필요 $", margin_required, ", 보유 $", AccountInfoDouble(ACCOUNT_MARGIN_FREE));
            }
        }
    }
    
    // 매도 신호 처리
    if(signal < 0)
    {
        if(TradeMode == TRADE_BUY_ONLY)
            return;
        
        // 기존 매수 포지션 청산
        if(has_buy)
        {
            trade.PositionClose(CustomSymbolName);
            Print("📈 매수 포지션 청산");
        }
        
        // 매도 진입
        if(!has_sell)
        {
            double price = SymbolInfoDouble(CustomSymbolName, SYMBOL_BID);
            double margin_required = CalculateMarginRequired(LotSize, price);
            
            if(margin_required <= AccountInfoDouble(ACCOUNT_MARGIN_FREE))
            {
                if(trade.Sell(LotSize, CustomSymbolName, price, 0, 0, "UT Bot Sell"))
                {
                    Print("📉 매도 진입: ", LotSize, " 랏 @ ", price);
                    Print("   - 실제 거래량: ", LotSize * ContractSize, " BTC");
                    Print("   - 필요 증거금: $", margin_required);
                }
                else
                {
                    Print("❌ 매도 실패: ", trade.ResultRetcode());
                }
            }
            else
            {
                Print("⚠️ 증거금 부족: 필요 $", margin_required, ", 보유 $", AccountInfoDouble(ACCOUNT_MARGIN_FREE));
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 증거금 계산 함수                                                 |
//+------------------------------------------------------------------+
double CalculateMarginRequired(double volume, double price)
{
    // 실제 거래 금액
    double actual_volume = volume * ContractSize;
    double trade_value = actual_volume * price;
    
    // 필요 증거금 (레버리지 적용)
    double margin_required = trade_value / Leverage;
    
    return margin_required;
}

//+------------------------------------------------------------------+
//| 거래 정보 출력 함수                                              |
//+------------------------------------------------------------------+
void PrintTradeInfo()
{
    if(PositionSelect(CustomSymbolName))
    {
        double volume = PositionGetDouble(POSITION_VOLUME);
        double price_open = PositionGetDouble(POSITION_PRICE_OPEN);
        double profit = PositionGetDouble(POSITION_PROFIT);
        double swap = PositionGetDouble(POSITION_SWAP);
        
        Print("📊 현재 포지션 정보:");
        Print("   - 거래량: ", volume, " 랏 (", volume * ContractSize, " BTC)");
        Print("   - 진입가: $", price_open);
        Print("   - 현재 수익: $", profit);
        Print("   - 스왑: $", swap);
    }
}
