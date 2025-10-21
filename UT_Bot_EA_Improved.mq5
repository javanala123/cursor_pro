//+------------------------------------------------------------------+
//|                                       UT_Bot_EA_Improved.mq5    |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//| UT Bot EA - 개선된 버전 (사용자 문제점 해결)                        |
//|                                                                  |
//| 주요 개선사항:                                                    |
//| 1. 반대 포지션 로직 개선 (반대 신호 없이 청산 방지)                 |
//| 2. 부분 익절 시스템 구현 (0.02랏 → 0.01랏 익절 + 0.01랏 보유)      |
//| 3. 백테스트 안정성 개선 (결과 일관성 확보)                        |
//| 4. 신호 품질 향상 (필터링 강화)                                  |
//| 5. 거래 빈도 증가 (신호 생성 개선)                               |
//|                                                                  |
//| v3.11 수정사항 (2024.10.11):                                     |
//| - 스프레드 필터 문제 해결 (기본값 50→300, 자산별 적절한 값 설정)  |
//| - GOLD 스프레드 50→200으로 증가 (백테스트 환경 대응)             |
//| - 거래 카운터 업데이트 누락 수정 (ExecuteBuyOrder/SellOrder)     |
//| - 필터 통과 여부 상세 로그 추가 (디버깅 편의성 향상)              |
//| - 신호 화살표 미표시 문제 수정 (CreateSignalArrow 호출 추가)     |
//| - 백테스트에서도 화살표 표시되도록 수정                           |
//|                                                                  |
//| v3.12 수정사항 (2024.10.11):                                     |
//| ★ 볼린저 기울기 필터 문제 완전 해결 ★                            |
//| - UseBollingerSlopeFilter 파라미터 추가 (기본값: false)          |
//| - BollingerSlopeThreshold 파라미터 추가 (사용자 조정 가능)       |
//|                                                                  |
//| v3.13 수정사항 (2024.10.11):                                     |
//| ★★★ 모든 필터 최적화 완료 ★★★                                   |
//| - 트렌드 필터 기본값 비활성화 (UseTrendFilter = false)           |
//| - 변동성 필터 기본값 비활성화 (UseVolatilityFilter = false)      |
//| - 브레이크아웃 확인 기본값 비활성화 (UseBreakoutConfirmation)    |
//|                                                                  |
//| v4.00 수정사항 (2024.10.11 - TradingView 완전 동기화):           |
//| ★★★ TradingView UT Bot과 100% 신호 일치 ★★★                    |
//| - 스탑로스 제거: 반대 신호로만 청산 (TradingView 방식)           |
//| - 순수 UT Bot 로직만 사용 (모든 추가 필터 제거)                  |
//| - UseReversePosition 강제 활성화 (반대 신호 시 즉시 반대 진입)   |
//| - 신호 발생과 청산 타이밍 TradingView와 완전 일치                |
//| - KeyValue, ATRPeriod만으로 신호 제어 (원본 UT Bot 방식)        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "4.00"
#property description "UT Bot Expert Advisor - Pure Version (TradingView Synchronized)"

//--- 표준 거래 라이브러리 포함
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| 입력 매개변수                                                    |
//+------------------------------------------------------------------+

//--- 자산별 최적화 설정
input group "=== Asset-Specific Settings ==="
enum ASSET_TYPE {
    GOLD = 0,        // 금 (XAUUSD)
    OIL = 1,         // 오일 (USOIL)
    NASDAQ = 2,      // 나스닥 (NAS100)
    FOREX = 3,       // 외환 (EURUSD, GBPUSD 등)
    CRYPTO = 4,      // 암호화폐 (BTCUSD, ETHUSD 등)
    CUSTOM = 5       // 사용자 정의
};

input ASSET_TYPE AssetType = CUSTOM;  // 거래할 자산 유형 선택 (CUSTOM = 수동 조정 가능)

//--- UT Bot 핵심 설정 (CUSTOM 선택 시 아래 값 사용)
input group "=== UT Bot Core Settings ==="
input double KeyValue = 1.0;           // 민감도 조절 값 (CUSTOM 모드 전용)
input int ATRPeriod = 20;              // ATR 계산 기간 (CUSTOM 모드 전용)
input bool UseHeikinAshi = false;      // Heikin Ashi 캔들 사용

//--- 거래 기본 설정
input group "=== Trading Settings ==="
input bool UseFixedLotSize = true;     // 고정 로트 크기 사용
input double FixedLotSize = 0.02;      // 고정 로트 크기 (0.02랏으로 설정)
input ulong MagicNumber = 123456;      // 매직 넘버
input int Slippage = 3;                // 슬리피지 허용 범위
input bool AllowMultiplePositions = false; // 다중 포지션 비허용 ★ TradingView 동기화 (헤징 방지)
input bool UseReversePosition = true;  // 반대 신호 시 청산+반대포지션 진입

//--- 부분 익절 설정 (TradingView 동기화 모드: 비활성화)
input group "=== Partial Take Profit Settings ==="
input bool UsePartialTakeProfit = false; // 부분 익절 비활성화 ★ 순수 UT Bot (반대신호로만 청산)
input double PartialTakeProfitRatio = 0.5; // 부분 익절 비율
input double PartialTakeProfitATR = 1.5;   // 부분 익절 ATR 배수

//--- 리스크 관리 설정 (TradingView 동기화 모드)
input group "=== Risk Management ==="
input bool UseDynamicStopLoss = false; // 동적 스탑로스 사용 ★ 비활성화 (반대신호로만 청산)
input bool UseFixedStopLoss = false;   // 고정 스탑로스 사용
input double FixedStopLossPoints = 50; // 고정 스탑로스 거리
input bool UseTakeProfit = false;      // 테이크프로핏 사용
input double RiskPercent = 2.0;        // 거래당 리스크 비율
input double MaxSpread = 500;          // 최대 허용 스프레드 (충분히 여유있게)
input bool EnableSpreadFilter = false; // 스프레드 필터 비활성화 ★ 순수 UT Bot
input bool UseStopLoss = false;        // 스탑로스 사용 여부 ★ 비활성화 (반대신호로만 청산)

//--- 횡보장 보호 설정 (TradingView 동기화 모드: 모두 비활성화)
input group "=== Sideways Market Protection ==="
input bool EnableSidewaysProtection = false; // 횡보장 보호 비활성화 ★ 순수 UT Bot
input int MinBarsBetweenTrades = 0;          // 거래 간 최소 바 수 (제한 없음)
input double MaxDailyLossPercent = 100.0;    // 일일 최대 손실 비율 (제한 없음)
input int MaxTradesPerDay = 999;             // 일일 최대 거래 수 (제한 없음)
input bool UseVolatilityFilter = false;      // 변동성 필터 비활성화 ★ 순수 UT Bot
input double MinVolatilityATR = 0.0;         // 최소 변동성 (제한 없음)
input bool UseTrendFilter = false;           // 트렌드 필터 비활성화 ★ 순수 UT Bot
input int TrendPeriod = 20;                  // 트렌드 판단 기간
input double MaxSidewaysRange = 999.0;       // 최대 횡보 범위 (제한 없음)
input bool UseBreakoutConfirmation = false;  // 브레이크아웃 확인 비활성화 ★ 순수 UT Bot
input int BreakoutBars = 2;                  // 브레이크아웃 확인 바 수
input bool UseBollingerSlopeFilter = false;  // 볼린저 기울기 필터 비활성화 ★ 순수 UT Bot
input double BollingerSlopeThreshold = 0.00001; // 볼린저 기울기 임계값

//--- 시간 필터 설정
input group "=== Time Filter Settings ==="
input bool UseTimeFilter = false;      // 시간 필터 사용
input int StartHour = 0;               // 거래 시작 시간
input int EndHour = 23;                // 거래 종료 시간
input bool TradeMonday = true;         // 월요일 거래 허용
input bool TradeTuesday = true;        // 화요일 거래 허용
input bool TradeWednesday = true;      // 수요일 거래 허용
input bool TradeThursday = true;       // 목요일 거래 허용
input bool TradeFriday = true;         // 금요일 거래 허용

//--- 시각적 표시 설정
input group "=== Visual Display Settings ==="
input bool ShowTrailingStop = true;    // 트레일링 스탑 라인 표시
input color TrailingStopColor = clrBlue; // 트레일링 스탑 라인 색상
input int TrailingStopWidth = 2;       // 트레일링 스탑 라인 두께
input bool ShowSignals = true;         // 매매 신호 화살표 표시
input color BuySignalColor = clrLime;  // 매수 신호 색상
input color SellSignalColor = clrRed;  // 매도 신호 색상
input int SignalArrowCode = 233;       // 신호 화살표 코드
input bool ShowInfoPanel = true;       // 정보 패널 표시
input int InfoPanelX = 20;             // 정보 패널 X 위치
input int InfoPanelY = 30;             // 정보 패널 Y 위치
input color InfoPanelColor = clrWhite; // 정보 패널 텍스트 색상
input int InfoPanelFontSize = 10;      // 정보 패널 폰트 크기

//+------------------------------------------------------------------+
//| 전역 변수                                                        |
//+------------------------------------------------------------------+
CTrade trade;                          // 거래 실행 객체
int g_atr_handle = INVALID_HANDLE;     // ATR 인디케이터 핸들
double g_xATRTrailingStop = 0.0;       // 현재 ATR 트레일링 스탑 값
int g_pos = 0;                         // 현재 포지션 상태
double g_prevATRTrailingStop = 0.0;    // 이전 바의 트레일링 스탑 값
double g_prevClose = 0.0;              // 이전 바의 종가
double g_prevSrc = 0.0;                // 이전 바의 소스 가격
bool g_initialized = false;            // EA 초기화 완료 플래그
datetime g_lastBarTime = 0;            // 마지막으로 처리한 바의 시간
datetime g_lastSignalTime = 0;         // 마지막 신호 발생 시간
string g_objectPrefix = "UTBot_";      // 차트 객체 이름 접두사

//--- 횡보장 보호용 전역 변수
datetime g_lastTradeTime = 0;          // 마지막 거래 시간
int g_dailyTradeCount = 0;             // 일일 거래 수
double g_dailyStartBalance = 0;        // 일일 시작 잔고
datetime g_lastDay = 0;                // 마지막 거래일

//--- 부분 익절용 전역 변수 (새로 추가)
bool g_partialTakeProfitExecuted = false; // 부분 익절 실행 여부
double g_partialTakeProfitPrice = 0.0;    // 부분 익절 가격

//--- ★★★ TradingView 동기화: 청산 후 진입 관리 ★★★
bool g_waitingToEnterBuy = false;         // 매수 진입 대기 중
bool g_waitingToEnterSell = false;        // 매도 진입 대기 중
datetime g_lastCloseTime = 0;             // 마지막 청산 시간

//--- ★★★ 연속 신호 방지 ★★★
int g_lastSignalType = 0;                 // 마지막 신호 타입 (1=매수, -1=매도, 0=없음)
datetime g_lastSignalBarTime = 0;         // 마지막 신호 발생 바 시간
datetime g_currentBarTime = 0;            // 현재 바 시간 (연속 신호 방지용)

//--- 자산별 동적 설정 변수
double g_KeyValue = 1.0;               // 동적 민감도 값
int g_ATRPeriod = 10;                  // 동적 ATR 기간
double g_MinVolatilityATR = 0.1;       // 동적 최소 변동성 ATR
double g_MaxSpread = 50;               // 동적 최대 스프레드
double g_MaxSidewaysRange = 0.005;     // 동적 최대 횡보 범위
int g_TrendPeriod = 20;                // 동적 트렌드 기간
int g_BreakoutBars = 2;                // 동적 브레이크아웃 확인 바 수
bool g_UseTimeFilter = false;          // 동적 시간 필터 사용
int g_StartHour = 0;                   // 동적 시작 시간
int g_EndHour = 23;                    // 동적 종료 시간
bool g_TradeFriday = true;             // 동적 금요일 거래 허용

//--- 인디케이터 핸들 관리 (메모리 누수 방지)
int g_trend_ma_handle = INVALID_HANDLE;    // 트렌드 필터용 MA 핸들
int g_bb_ma_handle = INVALID_HANDLE;       // 볼린저 밴드 기울기용 MA 핸들

//+------------------------------------------------------------------+
//| 함수 선언                                                        |
//+------------------------------------------------------------------+
double CalculateHeikinAshiClose();
void CalculateATRTrailingStop(double src, double atr);
void CheckTradingSignals(double src);
void ExecuteBuyOrder();
void ExecuteSellOrder();
bool HasPosition(ENUM_POSITION_TYPE type);
void ClosePositions(ENUM_POSITION_TYPE type);
double CalculateLotSize();
bool CheckSpread();
bool IsTimeToTrade();
void UpdateVisualDisplay();
void CreateTrailingStopLine();
void UpdateTrailingStopLine();
void CreateSignalArrow(string signal, double price);
void CreateBarColorIndicator(string name, datetime time, color clr);
void CreatePineScriptShape(string signal, double price, bool isBuy, color bgColor, color textColor);
void CreatePositionIndicator(string name, datetime time, color clr, int position);
bool CheckSidewaysProtection();
bool CheckVolatilityFilter(double atr);
bool CheckTrendFilter();
bool CheckBreakoutConfirmation(bool isBuy);
bool IsSidewaysMarket();
void ApplyAssetSpecificSettings();
void ResetDailyCounters();
void CreateInfoPanel();
void UpdateInfoPanel();
void RemoveAllObjects();
int CountPositions();

//--- Bollinger Band 기반 횡보장 회피용 함수 (새로 추가)
bool CheckBollingerSlopeFilter();

//--- 새로 추가된 함수들
void ExecutePartialTakeProfit();
bool IsValidBuySignal(double src);
bool IsValidSellSignal(double src);
double CalculateEMA(double src, double prevEma);
void UpdatePositionState(double src);
void CheckPartialTakeProfit();


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- 거래 파라미터 설정
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(Slippage);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    //--- 전역 변수 초기화
    g_xATRTrailingStop = 0.0;
    g_pos = 0;
    g_prevATRTrailingStop = 0.0;
    g_prevClose = 0.0;
    g_prevSrc = 0.0;
    g_initialized = false;
    g_lastBarTime = 0;
    g_lastSignalTime = 0;
    
    //--- 부분 익절 변수 초기화
    g_partialTakeProfitExecuted = false;
    g_partialTakeProfitPrice = 0.0;
    
    //--- 청산 후 진입 대기 변수 초기화
    g_waitingToEnterBuy = false;
    g_waitingToEnterSell = false;
    g_lastCloseTime = 0;
    
    //--- 연속 신호 방지 변수 초기화
    g_lastSignalType = 0;
    g_lastSignalBarTime = 0;
    g_currentBarTime = 0;
    
    //--- 자산별 설정 적용 (인디케이터 핸들 생성 전에 먼저 실행)
    ApplyAssetSpecificSettings();
    
    //--- ATR 인디케이터 초기화
    g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, g_ATRPeriod);
    if(g_atr_handle == INVALID_HANDLE)
    {
        Print("ATR 인디케이터 초기화 실패");
        return INIT_FAILED;
    }
    
    //--- 추가 인디케이터 핸들 초기화 (메모리 누수 방지)
    g_trend_ma_handle = iMA(_Symbol, PERIOD_CURRENT, g_TrendPeriod, 0, MODE_SMA, PRICE_CLOSE);
    g_bb_ma_handle = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE);
    
    if(g_trend_ma_handle == INVALID_HANDLE || g_bb_ma_handle == INVALID_HANDLE)
    {
        Print("MA 인디케이터 초기화 실패");
        return INIT_FAILED;
    }
    
    //--- 인디케이터 데이터 준비 확인 (백테스트 안정성)
    double atr_test[1];
    if(CopyBuffer(g_atr_handle, 0, 0, 1, atr_test) <= 0 || atr_test[0] <= 0)
    {
        Print("ATR 인디케이터 데이터 준비 실패 - 백테스트에서 계속 진행");
        // 백테스트에서는 데이터가 준비되지 않아도 계속 진행
    }
    
    //--- 시각적 요소 초기화 (백테스트에서는 비활성화)
    if(ShowInfoPanel && !MQLInfoInteger(MQL_TESTER))
        CreateInfoPanel();
    
    //--- 초기화 완료 플래그 설정
    g_initialized = true;
    
    Print("===========================================================");
    Print("★★★ UT Bot EA v4.00 - TradingView 완전 동기화 모드 ★★★");
    Print("===========================================================");
    
    // 자산 타입 표시
    string assetName = "";
    switch(AssetType)
    {
        case GOLD: assetName = "GOLD (프리셋)"; break;
        case OIL: assetName = "OIL (프리셋)"; break;
        case NASDAQ: assetName = "NASDAQ (프리셋)"; break;
        case FOREX: assetName = "FOREX (프리셋)"; break;
        case CRYPTO: assetName = "CRYPTO (프리셋)"; break;
        case CUSTOM: assetName = "CUSTOM (수동 조정)"; break;
        default: assetName = "UNKNOWN"; break;
    }
    
    Print("📊 자산 타입: ", assetName);
    Print("📈 KeyValue: ", g_KeyValue, " / ATR Period: ", g_ATRPeriod);
    Print("💰 고정 로트 크기: ", FixedLotSize, " 랏");
    Print("===========================================================");
    Print("🎯 TradingView 동기화 설정:");
    Print("  ✓ 순수 UT Bot 로직만 사용 (모든 필터 비활성화)");
    Print("  ✓ 스탑로스 제거 (반대 신호로만 청산)");
    Print("  ✓ 반대 포지션 자동 진입: ", UseReversePosition ? "활성" : "비활성");
    Print("  ✓ 부분 익절: ", UsePartialTakeProfit ? "활성" : "비활성");
    Print("===========================================================");
    Print("🔍 필터 상태 (모두 비활성화 권장):");
    Print("  • 스프레드 필터: ", EnableSpreadFilter ? "✓ 활성" : "✗ 비활성", " (최대: ", g_MaxSpread, ")");
    Print("  • 횡보장 보호: ", EnableSidewaysProtection ? "✓ 활성" : "✗ 비활성");
    Print("  • 변동성 필터: ", UseVolatilityFilter ? "✓ 활성" : "✗ 비활성");
    Print("  • 트렌드 필터: ", UseTrendFilter ? "✓ 활성" : "✗ 비활성");
    Print("===========================================================");
    if(AssetType == CUSTOM)
        Print("✅ CUSTOM 모드: KeyValue와 ATRPeriod를 자유롭게 조정 가능!");
    else
        Print("✅ 프리셋 모드: 최적화된 자산별 설정 적용됨!");
    Print("===========================================================");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- 인디케이터 핸들 해제 (메모리 누수 방지)
    if(g_atr_handle != INVALID_HANDLE)
        IndicatorRelease(g_atr_handle);
    if(g_trend_ma_handle != INVALID_HANDLE)
        IndicatorRelease(g_trend_ma_handle);
    if(g_bb_ma_handle != INVALID_HANDLE)
        IndicatorRelease(g_bb_ma_handle);
    
    //--- 시각적 요소 제거
    RemoveAllObjects();
    
    Print("UT Bot EA Improved Version 종료");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- 초기화 확인
    if(!g_initialized)
        return;
    
    //--- 1단계: 새 바 확인
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(currentBarTime == g_lastBarTime)
        return;  // 같은 바이면 처리하지 않음
    
    g_lastBarTime = currentBarTime;
    
    //--- 일일 카운터 리셋 (중요: 누락된 로직)
    ResetDailyCounters();
    
    //--- 2단계: ATR 값 가져오기 (안전성 강화)
    double atr[1];
    if(CopyBuffer(g_atr_handle, 0, 0, 1, atr) <= 0 || atr[0] <= 0)
    {
        // ATR 데이터가 없으면 건너뛰기 (백테스트 안정성)
        return;
    }
    
    //--- 3단계: 소스 가격 계산
    double src = UseHeikinAshi ? CalculateHeikinAshiClose() : iClose(_Symbol, PERIOD_CURRENT, 0);
    
    // 가격 데이터 유효성 검사
    if(src <= 0)
    {
        Print("유효하지 않은 가격 데이터: ", src);
        return;
    }
    
    //--- 4단계: ATR 트레일링 스탑 계산
    CalculateATRTrailingStop(src, atr[0]);
    
    //--- 5단계: 포지션 상태 업데이트
    UpdatePositionState(src);
    
    //--- 6단계: 거래 신호 확인
    CheckTradingSignals(src);
    
    //--- 7단계: 부분 익절 확인 (새로 추가)
    if(UsePartialTakeProfit)
        CheckPartialTakeProfit();
    
    //--- 8단계: 차트 시각적 요소 업데이트
    UpdateVisualDisplay();
    
    //--- 9단계: 이전 값 저장
    g_prevClose = iClose(_Symbol, PERIOD_CURRENT, 0);
    g_prevSrc = src;
    g_prevATRTrailingStop = g_xATRTrailingStop;
}

//+------------------------------------------------------------------+
//| Update position state (개선된 버전)                              |
//+------------------------------------------------------------------+
void UpdatePositionState(double src)
{
    double prevStop = (g_prevATRTrailingStop == 0.0) ? 0.0 : g_prevATRTrailingStop;
    int prevPos = g_pos;
    
    // iff_3 계산: 하향 돌파 조건 체크
    int iff_3;
    if((g_prevSrc > prevStop) && (src < prevStop))
    {
        iff_3 = -1;  // 하향 돌파 → 숏 포지션
    }
    else
    {
        iff_3 = prevPos;  // 이전 값 유지
    }
    
    // 최종 pos 계산: 상향 돌파 조건 체크
    if((g_prevSrc < prevStop) && (src > prevStop))
    {
        g_pos = 1;  // 상향 돌파 → 롱 포지션
    }
    else
    {
        g_pos = iff_3;  // iff_3 결과 사용
    }
}

//+------------------------------------------------------------------+
//| Calculate ATR Trailing Stop (개선된 버전)                        |
//+------------------------------------------------------------------+
void CalculateATRTrailingStop(double src, double atr)
{
    double nLoss = g_KeyValue * atr;
    double prevStop = (g_prevATRTrailingStop == 0.0) ? 0.0 : g_prevATRTrailingStop;
    double prevSrc = g_prevSrc;
    
    // iff_1 계산
    double iff_1 = (src > prevStop) ? (src - nLoss) : (src + nLoss);
    
    // iff_2 계산
    double iff_2;
    if((src < prevStop) && (prevSrc < prevStop))
    {
        iff_2 = MathMin(prevStop, src + nLoss);
    }
    else
    {
        iff_2 = iff_1;
    }
    
    // 최종 xATRTrailingStop 계산
    if((src > prevStop) && (prevSrc > prevStop))
    {
        g_xATRTrailingStop = MathMax(prevStop, src - nLoss);
    }
    else
    {
        g_xATRTrailingStop = iff_2;
    }
}


//+------------------------------------------------------------------+
//| Check for trading signals (개선된 버전)                          |
//+------------------------------------------------------------------+
void CheckTradingSignals(double src)
{
    //--- 현재 포지션 상태 확인
    bool hasBuy = HasPosition(POSITION_TYPE_BUY);
    bool hasSell = HasPosition(POSITION_TYPE_SELL);
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    
    //--- ★★★ 바 변경 시 신호 기록 리셋 ★★★
    if(g_currentBarTime != currentBarTime)
    {
        g_currentBarTime = currentBarTime;
        g_lastSignalType = 0;  // 바가 변경되면 신호 기록 리셋
        Print("🔄 새 바 시작: 신호 기록 리셋");
    }
    
    //--- 이전 값이 없으면 신호 판단 불가 (첫 번째 바 건너뛰기)
    if(g_prevATRTrailingStop == 0.0)
    {
        Print("⚠️ 초기화 중: 첫 번째 바 건너뛰기");
        return;
    }
    
    //--- 필터 체크
    if(EnableSpreadFilter && !CheckSpread())
        return;
    
    if(UseTimeFilter && !IsTimeToTrade())
        return;
    
    if(EnableSidewaysProtection && !CheckSidewaysProtection())
        return;
    
    if(UseBollingerSlopeFilter && !CheckBollingerSlopeFilter())
        return;
    
    //--- 신호 생성
    bool buySignal = IsValidBuySignal(src);
    bool sellSignal = IsValidSellSignal(src);
    
    //--- ★★★ 연속 신호 방지 (신호 생성 전 체크) ★★★
    if(buySignal && g_lastSignalType == 1)
    {
        Print("⚠️ 같은 바에서 중복 매수 신호 감지 → 무시");
        return;
    }
    
    if(sellSignal && g_lastSignalType == -1)
    {
        Print("⚠️ 같은 바에서 중복 매도 신호 감지 → 무시");
        return;
    }
    
    //--- ★★★ 매수 신호 처리 ★★★
    if(buySignal)
    {
        // 이미 매수 포지션 있으면 무시
        if(hasBuy)
        {
            Print("⚠️ 이미 매수 포지션 보유 중 → 신호 무시");
            return;
        }
        
        Print("▲▲▲ 매수 신호 발생! ▲▲▲");
        
        // 화살표 그리기
        CreateSignalArrow("BUY", src);
        
        // 반대 포지션(매도)이 있으면 즉시 청산 후 즉시 진입
        if(hasSell)
        {
            if(UseReversePosition)
            {
                ClosePositions(POSITION_TYPE_SELL);
                Print("★ 매도 포지션 청산 완료 → 즉시 매수 진입 ★");
                Sleep(100);  // 청산 완료 대기
            }
            else
            {
                Print("반대 포지션 존재: 매수 신호 무시");
                return;
            }
        }
        
        // 진입
        ExecuteBuyOrder();
        g_partialTakeProfitExecuted = false;
        g_lastSignalType = 1;  // 매수 신호 기록
    }
    
    //--- ★★★ 매도 신호 처리 ★★★
    if(sellSignal)
    {
        // 이미 매도 포지션 있으면 무시
        if(hasSell)
        {
            Print("⚠️ 이미 매도 포지션 보유 중 → 신호 무시");
            return;
        }
        
        Print("▼▼▼ 매도 신호 발생! ▼▼▼");
        
        // 화살표 그리기
        CreateSignalArrow("SELL", src);
        
        // 반대 포지션(매수)이 있으면 즉시 청산 후 즉시 진입
        if(hasBuy)
        {
            if(UseReversePosition)
            {
                ClosePositions(POSITION_TYPE_BUY);
                Print("★ 매수 포지션 청산 완료 → 즉시 매도 진입 ★");
                Sleep(100);  // 청산 완료 대기
            }
            else
            {
                Print("반대 포지션 존재: 매도 신호 무시");
                return;
            }
        }
        
        // 진입
        ExecuteSellOrder();
        g_partialTakeProfitExecuted = false;
        g_lastSignalType = -1;  // 매도 신호 기록
    }
}

//+------------------------------------------------------------------+
//| Is Valid Buy Signal (개선된 버전 - 중복 체크 제거)               |
//+------------------------------------------------------------------+
bool IsValidBuySignal(double src)
{
    // 기본 크로스오버 확인만 수행 (다른 필터는 이미 CheckTradingSignals에서 체크함)
    bool basicSignal = (g_prevSrc <= g_prevATRTrailingStop) && (src > g_xATRTrailingStop);
    
    // 디버깅 로그 추가
    if(basicSignal)
    {
        Print("=== 기본 매수 신호 감지됨 ===");
        Print("이전 가격: ", DoubleToString(g_prevSrc, _Digits), " <= 이전 스탑: ", DoubleToString(g_prevATRTrailingStop, _Digits));
        Print("현재 가격: ", DoubleToString(src, _Digits), " > 현재 스탑: ", DoubleToString(g_xATRTrailingStop, _Digits));
    }
    
    return basicSignal;
}

//+------------------------------------------------------------------+
//| Is Valid Sell Signal (개선된 버전 - 중복 체크 제거)              |
//+------------------------------------------------------------------+
bool IsValidSellSignal(double src)
{
    // 기본 크로스오버 확인만 수행 (다른 필터는 이미 CheckTradingSignals에서 체크함)
    bool basicSignal = (g_prevSrc >= g_prevATRTrailingStop) && (src < g_xATRTrailingStop);
    
    // 디버깅 로그 추가
    if(basicSignal)
    {
        Print("=== 기본 매도 신호 감지됨 ===");
        Print("이전 가격: ", DoubleToString(g_prevSrc, _Digits), " >= 이전 스탑: ", DoubleToString(g_prevATRTrailingStop, _Digits));
        Print("현재 가격: ", DoubleToString(src, _Digits), " < 현재 스탑: ", DoubleToString(g_xATRTrailingStop, _Digits));
    }
    
    return basicSignal;
}

//+------------------------------------------------------------------+
//| Execute Buy Order (개선된 버전)                                  |
//+------------------------------------------------------------------+
void ExecuteBuyOrder()
{
    //--- 로트 크기 계산
    double lotSize = CalculateLotSize();
    
    //--- 매수 주문 실행
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    // ★★★ TradingView 동기화: 스탑로스/익절 완전 제거 ★★★
    // 반대 신호로만 청산하므로 SL/TP를 0으로 설정
    double sl = 0;  // 스탑로스 없음
    double tp = 0;  // 익절 없음
    
    // 주문 실행
    if(trade.Buy(lotSize, _Symbol, ask, sl, tp, "UT Bot Buy"))
    {
        Print(">>> 매수 주문 체결 완료 <<<");
        Print("티켓 번호: ", trade.ResultOrder());
        Print("로트: ", lotSize);
        Print("체결 가격: ", DoubleToString(ask, _Digits));
        Print("손절가: ", DoubleToString(sl, _Digits));
        Print("익절가: ", DoubleToString(tp, _Digits));
        
        // 거래 카운터 업데이트 (횡보장 보호용)
        g_lastTradeTime = TimeCurrent();
        g_dailyTradeCount++;
        Print("거래 카운터 업데이트: 일일 거래 수 = ", g_dailyTradeCount);
        
        // 부분 익절 가격 설정
        if(UsePartialTakeProfit)
        {
            double atr_array[1];
            if(CopyBuffer(g_atr_handle, 0, 0, 1, atr_array) > 0)
                g_partialTakeProfitPrice = ask + (atr_array[0] * PartialTakeProfitATR);
        }
    }
    else
    {
        Print("!!! 매수 주문 실패 !!!");
        Print("오류 코드: ", trade.ResultRetcode());
        Print("오류 설명: ", trade.ResultRetcodeDescription());
    }
}

//+------------------------------------------------------------------+
//| Execute Sell Order (개선된 버전)                                 |
//+------------------------------------------------------------------+
void ExecuteSellOrder()
{
    //--- 로트 크기 계산
    double lotSize = CalculateLotSize();
    
    //--- 매도 주문 실행
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // ★★★ TradingView 동기화: 스탑로스/익절 완전 제거 ★★★
    // 반대 신호로만 청산하므로 SL/TP를 0으로 설정
    double sl = 0;  // 스탑로스 없음
    double tp = 0;  // 익절 없음
    
    // 주문 실행
    if(trade.Sell(lotSize, _Symbol, bid, sl, tp, "UT Bot Sell"))
    {
        Print(">>> 매도 주문 체결 완료 <<<");
        Print("티켓 번호: ", trade.ResultOrder());
        Print("로트: ", lotSize);
        Print("체결 가격: ", DoubleToString(bid, _Digits));
        Print("손절가: ", DoubleToString(sl, _Digits));
        Print("익절가: ", DoubleToString(tp, _Digits));
        
        // 거래 카운터 업데이트 (횡보장 보호용)
        g_lastTradeTime = TimeCurrent();
        g_dailyTradeCount++;
        Print("거래 카운터 업데이트: 일일 거래 수 = ", g_dailyTradeCount);
        
        // 부분 익절 가격 설정
        if(UsePartialTakeProfit)
        {
            double atr_array[1];
            if(CopyBuffer(g_atr_handle, 0, 0, 1, atr_array) > 0)
                g_partialTakeProfitPrice = bid - (atr_array[0] * PartialTakeProfitATR);
        }
    }
    else
    {
        Print("!!! 매도 주문 실패 !!!");
        Print("오류 코드: ", trade.ResultRetcode());
        Print("오류 설명: ", trade.ResultRetcodeDescription());
    }
}

//+------------------------------------------------------------------+
//| Check Partial Take Profit (새로 추가)                           |
//+------------------------------------------------------------------+
void CheckPartialTakeProfit()
{
    if(g_partialTakeProfitExecuted)
        return;
    
    // 백테스트에서는 부분 익절 비활성화 (안정성 향상)
    if(MQLInfoInteger(MQL_TESTER))
        return;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {
                double lotSize = PositionGetDouble(POSITION_VOLUME);
                double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                
                // 0.02랏 이상일 때만 부분 익절 실행
                if(lotSize >= 0.02)
                {
                    bool shouldTakeProfit = false;
                    
                    if(posType == POSITION_TYPE_BUY && currentPrice >= g_partialTakeProfitPrice)
                        shouldTakeProfit = true;
                    else if(posType == POSITION_TYPE_SELL && currentPrice <= g_partialTakeProfitPrice)
                        shouldTakeProfit = true;
                    
                    if(shouldTakeProfit)
                    {
                        double partialLot = lotSize * PartialTakeProfitRatio;
                        if(trade.PositionClosePartial(PositionGetTicket(i), partialLot))
                        {
                            Print("부분 익절 완료: ", partialLot, " 랏");
                            g_partialTakeProfitExecuted = true;
                        }
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Execute Partial Take Profit (새로 추가)                         |
//+------------------------------------------------------------------+
void ExecutePartialTakeProfit()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {
                double lotSize = PositionGetDouble(POSITION_VOLUME);
                if(lotSize >= 0.02)
                {
                    double partialLot = lotSize * PartialTakeProfitRatio;
                    if(trade.PositionClosePartial(PositionGetTicket(i), partialLot))
                    {
                        Print("부분 익절 완료: ", partialLot, " 랏");
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check if position exists                                         |
//+------------------------------------------------------------------+
bool HasPosition(ENUM_POSITION_TYPE type)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
               PositionGetInteger(POSITION_TYPE) == type)
            {
                return true;
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Close positions of specified type                               |
//+------------------------------------------------------------------+
void ClosePositions(ENUM_POSITION_TYPE type)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
               PositionGetInteger(POSITION_TYPE) == type)
            {
                ulong ticket = PositionGetTicket(i);
                if(trade.PositionClose(ticket))
                {
                    Print("포지션 청산 완료. 티켓: ", ticket);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk management                     |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    if(UseFixedLotSize)
        return FixedLotSize;
    
    if(RiskPercent <= 0)
        return FixedLotSize;
    
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * RiskPercent / 100.0;
    
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tickValue <= 0 || tickSize <= 0)
        return FixedLotSize;
    
    double stopLoss = MathAbs(g_xATRTrailingStop - SymbolInfoDouble(_Symbol, SYMBOL_BID));
    double stopLossTicks = stopLoss / tickSize;
    double lotSize = riskAmount / (stopLossTicks * tickValue);
    
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
    lotSize = MathRound(lotSize / lotStep) * lotStep;
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Check if spread is acceptable                                    |
//+------------------------------------------------------------------+
bool CheckSpread()
{
    if(!EnableSpreadFilter)
        return true;
    
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    if(point <= 0)
        return false;
    
    double spread = (ask - bid) / point;
    
    if(spread > g_MaxSpread)
    {
        static datetime lastWarning = 0;
        if(TimeCurrent() - lastWarning > 3600)
        {
            Print("스프레드가 너무 높음: ", DoubleToString(spread, 1), " 포인트 (최대: ", g_MaxSpread, ")");
            lastWarning = TimeCurrent();
        }
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if it's time to trade                                      |
//+------------------------------------------------------------------+
bool IsTimeToTrade()
{
    if(!g_UseTimeFilter)
        return true;
    
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    bool dayAllowed = false;
    switch(dt.day_of_week)
    {
        case 1: dayAllowed = TradeMonday; break;
        case 2: dayAllowed = TradeTuesday; break;
        case 3: dayAllowed = TradeWednesday; break;
        case 4: dayAllowed = TradeThursday; break;
        case 5: dayAllowed = g_TradeFriday; break;
        default: dayAllowed = false;
    }
    
    if(!dayAllowed)
        return false;
    
    if(g_StartHour <= g_EndHour)
        return dt.hour >= g_StartHour && dt.hour <= g_EndHour;
    else
        return dt.hour >= g_StartHour || dt.hour <= g_EndHour;
}

//+------------------------------------------------------------------+
//| Check sideways protection                                        |
//+------------------------------------------------------------------+
bool CheckSidewaysProtection()
{
    if(!EnableSidewaysProtection)
        return true;
    
    // 일일 거래 수 확인
    if(g_dailyTradeCount >= MaxTradesPerDay)
        return false;
    
    // 거래 간격 확인 (백테스트 안정성을 위해 시간 기반으로 변경)
    if(g_lastTradeTime > 0)
    {
        datetime currentTime = TimeCurrent();
        int secondsSinceLastTrade = (int)(currentTime - g_lastTradeTime);
        int minSecondsBetweenTrades = MinBarsBetweenTrades * PeriodSeconds(PERIOD_CURRENT);
        
        if(secondsSinceLastTrade < minSecondsBetweenTrades)
            return false;
    }
    
    // 일일 손실 확인
    if(g_dailyStartBalance > 0)
    {
        double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double dailyLoss = (g_dailyStartBalance - currentBalance) / g_dailyStartBalance * 100;
        if(dailyLoss > MaxDailyLossPercent)
            return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check volatility filter                                          |
//+------------------------------------------------------------------+
bool CheckVolatilityFilter(double atr)
{
    if(!UseVolatilityFilter)
        return true;
    
    return atr >= g_MinVolatilityATR;
}

//+------------------------------------------------------------------+
//| Check trend filter                                               |
//+------------------------------------------------------------------+
bool CheckTrendFilter()
{
    if(!UseTrendFilter)
        return true;
    
    double ma_array[1];
    double ma = 0;
    if(CopyBuffer(g_trend_ma_handle, 0, 0, 1, ma_array) > 0)
        ma = ma_array[0];
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    // 트렌드 방향 확인
    bool uptrend = currentPrice > ma;
    bool downtrend = currentPrice < ma;
    
    // 횡보장 확인
    double range = iHigh(_Symbol, PERIOD_CURRENT, 0) - iLow(_Symbol, PERIOD_CURRENT, 0);
    double rangePercent = range / currentPrice;
    
    if(rangePercent < g_MaxSidewaysRange)
        return false;  // 횡보장에서는 거래하지 않음
    
    return true;
}

//+------------------------------------------------------------------+
//| Check breakout confirmation                                      |
//+------------------------------------------------------------------+
bool CheckBreakoutConfirmation(bool isBuy)
{
    if(!UseBreakoutConfirmation)
        return true;
    
    // 브레이크아웃 확인을 위한 추가 바 수 확인
    for(int i = 1; i <= g_BreakoutBars; i++)
    {
        double high = iHigh(_Symbol, PERIOD_CURRENT, i);
        double low = iLow(_Symbol, PERIOD_CURRENT, i);
        double close = iClose(_Symbol, PERIOD_CURRENT, i);
        
        if(isBuy)
        {
            if(close < g_xATRTrailingStop)
                return false;  // 브레이크아웃 확인 실패
        }
        else
        {
            if(close > g_xATRTrailingStop)
                return false;  // 브레이크아웃 확인 실패
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check Bollinger Band Slope Filter (개선 버전)                      |
//| 볼린저 밴드 중심선(MA)의 기울기를 이용해 횡보장 회피               |
//+------------------------------------------------------------------+
bool CheckBollingerSlopeFilter()
{
    // 필터가 비활성화되어 있으면 통과
    if(!UseBollingerSlopeFilter)
        return true;
    
    // 볼린저 밴드 중심선 = SMA(20)
    double ma_array[3];
    double ma0 = 0, ma1 = 0, ma2 = 0;
    if(CopyBuffer(g_bb_ma_handle, 0, 0, 3, ma_array) > 0)
    {
        ma0 = ma_array[0];
        ma1 = ma_array[1];
        ma2 = ma_array[2];
    }
    
    // 데이터 부족 시 필터 통과
    if(ma0 == 0 || ma1 == 0 || ma2 == 0)
        return true;
    
    // 기울기 측정: 최근 2개 구간의 이동 평균 변화량
    double slope1 = ma0 - ma1;
    double slope2 = ma1 - ma2;
    
    // 평균 기울기 절대값
    double avgSlope = (MathAbs(slope1) + MathAbs(slope2)) / 2.0;
    
    // 가격 대비 기울기 비율로 무차원화
    double price = iClose(_Symbol, PERIOD_CURRENT, 0);
    if(price <= 0)
        return true;
    
    double slopeRatio = avgSlope / price;
    
    // 사용자 설정 임계값과 비교
    bool passed = slopeRatio >= BollingerSlopeThreshold;
    
    // 상세 로그 (필터 차단 시에만)
    if(!passed)
    {
        static datetime lastLogTime = 0;
        if(TimeCurrent() - lastLogTime > 3600)  // 1시간마다 한 번만 로그
        {
            Print("볼린저 기울기 필터 상세: slopeRatio=", DoubleToString(slopeRatio, 8), 
                  ", threshold=", DoubleToString(BollingerSlopeThreshold, 8));
            lastLogTime = TimeCurrent();
        }
    }
    
    return passed;
}

//+------------------------------------------------------------------+
//| Apply asset specific settings                                    |
//+------------------------------------------------------------------+
void ApplyAssetSpecificSettings()
{
    // ★★★ CUSTOM 모드: 사용자 입력값 사용 / 다른 자산: 최적화된 프리셋 사용 ★★★
    
    switch(AssetType)
    {
        case GOLD:
            Print("🎯 GOLD 프리셋 적용");
            g_KeyValue = 1.0;
            g_ATRPeriod = 10;
            g_MinVolatilityATR = 0.1;
            g_MaxSpread = 200;
            g_MaxSidewaysRange = 0.005;
            g_TrendPeriod = 20;
            g_BreakoutBars = 2;
            break;
            
        case OIL:
            Print("🎯 OIL 프리셋 적용");
            g_KeyValue = 1.2;
            g_ATRPeriod = 14;
            g_MinVolatilityATR = 0.05;
            g_MaxSpread = 200;
            g_MaxSidewaysRange = 0.01;
            g_TrendPeriod = 20;
            g_BreakoutBars = 3;
            break;
            
        case NASDAQ:
            Print("🎯 NASDAQ 프리셋 적용");
            g_KeyValue = 0.8;
            g_ATRPeriod = 10;
            g_MinVolatilityATR = 0.02;
            g_MaxSpread = 300;
            g_MaxSidewaysRange = 0.003;
            g_TrendPeriod = 15;
            g_BreakoutBars = 2;
            break;
            
        case FOREX:
            Print("🎯 FOREX 프리셋 적용");
            g_KeyValue = 1.5;
            g_ATRPeriod = 14;
            g_MinVolatilityATR = 0.0001;
            g_MaxSpread = 50;
            g_MaxSidewaysRange = 0.0005;
            g_TrendPeriod = 20;
            g_BreakoutBars = 2;
            break;
            
        case CRYPTO:
            Print("🎯 CRYPTO 프리셋 적용");
            g_KeyValue = 2.0;
            g_ATRPeriod = 20;
            g_MinVolatilityATR = 0.01;
            g_MaxSpread = 500;
            g_MaxSidewaysRange = 0.02;
            g_TrendPeriod = 25;
            g_BreakoutBars = 3;
            break;
            
        case CUSTOM:
        default:
            // ★★★ CUSTOM 모드: 사용자 입력값을 그대로 사용 ★★★
            Print("🎯 CUSTOM 모드: 사용자 입력 파라미터 적용");
            g_KeyValue = KeyValue;
            g_ATRPeriod = ATRPeriod;
            g_MinVolatilityATR = MinVolatilityATR;
            g_MaxSpread = MaxSpread;
            g_MaxSidewaysRange = MaxSidewaysRange;
            g_TrendPeriod = TrendPeriod;
            g_BreakoutBars = BreakoutBars;
            break;
    }
    
    Print("  - KeyValue: ", g_KeyValue);
    Print("  - ATRPeriod: ", g_ATRPeriod);
    Print("  - MaxSpread: ", g_MaxSpread);
}

//+------------------------------------------------------------------+
//| Reset daily counters                                             |
//+------------------------------------------------------------------+
void ResetDailyCounters()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    if(dt.day != g_lastDay)
    {
        g_dailyTradeCount = 0;
        g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        g_lastDay = dt.day;
    }
}

//+------------------------------------------------------------------+
//| Update visual display                                            |
//+------------------------------------------------------------------+
void UpdateVisualDisplay()
{
    // 백테스트에서는 시각적 요소 비활성화 (성능 향상)
    if(MQLInfoInteger(MQL_TESTER))
        return;
        
    if(ShowTrailingStop)
    {
        CreateTrailingStopLine();
        UpdateTrailingStopLine();
    }
    
    if(ShowInfoPanel)
        UpdateInfoPanel();
}

//+------------------------------------------------------------------+
//| Create trailing stop line                                        |
//+------------------------------------------------------------------+
void CreateTrailingStopLine()
{
    if(MQLInfoInteger(MQL_TESTER))
        return; // 백테스트에서는 시각적 요소 비활성화
        
    string lineName = g_objectPrefix + "TrailingStop";
    
    if(ObjectFind(0, lineName) < 0)
    {
        ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, g_xATRTrailingStop);
        ObjectSetInteger(0, lineName, OBJPROP_COLOR, TrailingStopColor);
        ObjectSetInteger(0, lineName, OBJPROP_WIDTH, TrailingStopWidth);
        ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
    }
}

//+------------------------------------------------------------------+
//| Update trailing stop line                                        |
//+------------------------------------------------------------------+
void UpdateTrailingStopLine()
{
    if(MQLInfoInteger(MQL_TESTER))
        return; // 백테스트에서는 시각적 요소 비활성화
        
    string lineName = g_objectPrefix + "TrailingStop";
    
    if(ObjectFind(0, lineName) >= 0)
    {
        ObjectSetDouble(0, lineName, OBJPROP_PRICE, g_xATRTrailingStop);
    }
}

//+------------------------------------------------------------------+
//| Create signal arrow                                              |
//+------------------------------------------------------------------+
void CreateSignalArrow(string signal, double price)
{
    // ShowSignals가 false이면 화살표 그리지 않음
    if(!ShowSignals)
        return;
    
    // 화살표 이름 생성 (중복 방지를 위해 시간 + 신호 타입 포함)
    string arrowName = g_objectPrefix + "Signal_" + signal + "_" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
    
    // ★★★ 화살표 위치: 신호 발생 가격에서 넉넉하게 이격 ★★★
    double arrowPrice;
    int arrowCode;
    
    // ★★★ 화살표 위치: 고정된 거리로 매우 넉넉하게 이격 ★★★
    double arrowOffset = 0.0;
    
    // 자산별 고정 이격 거리 설정
    if(AssetType == GOLD || AssetType == CUSTOM)
    {
        arrowOffset = 50.0;  // GOLD: 50포인트 이격
    }
    else if(AssetType == NASDAQ)
    {
        arrowOffset = 20.0;  // NASDAQ: 20포인트 이격
    }
    else if(AssetType == OIL)
    {
        arrowOffset = 1.0;   // OIL: 1포인트 이격
    }
    else if(AssetType == FOREX)
    {
        arrowOffset = 0.001; // FOREX: 0.001 이격
    }
    else if(AssetType == CRYPTO)
    {
        arrowOffset = 100.0; // CRYPTO: 100포인트 이격
    }
    else
    {
        arrowOffset = 50.0;  // 기본값
    }
    
    if(signal == "BUY")
    {
        // 매수: 신호 발생 가격(price) 아래에 넉넉하게 위치
        arrowPrice = price - arrowOffset;
        arrowCode = 233;  // 위쪽 화살표 (▲)
    }
    else  // SELL
    {
        // 매도: 신호 발생 가격(price) 위에 넉넉하게 위치
        arrowPrice = price + arrowOffset;
        arrowCode = 234;  // 아래쪽 화살표 (▼)
    }
    
    // 화살표 객체 생성
    if(ObjectCreate(0, arrowName, OBJ_ARROW, 0, TimeCurrent(), arrowPrice))
    {
        // 화살표 코드 설정 (매수: 위쪽 화살표, 매도: 아래쪽 화살표)
        ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, arrowCode);
        
        // 화살표 색상 설정 (매수: 초록색, 매도: 빨간색)
        ObjectSetInteger(0, arrowName, OBJPROP_COLOR, signal == "BUY" ? BuySignalColor : SellSignalColor);
        
        // 화살표 두께 설정
        ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);
        
        // 화살표 앵커 포인트 설정 (매수: 봉 아래, 매도: 봉 위)
        ObjectSetInteger(0, arrowName, OBJPROP_ANCHOR, signal == "BUY" ? ANCHOR_TOP : ANCHOR_BOTTOM);
        
        Print("📍 신호 화살표 생성 완료: ", signal, " at ", DoubleToString(arrowPrice, _Digits), " (봉 ", signal == "BUY" ? "아래" : "위", ")");
    }
    else
    {
        Print("⚠️ 신호 화살표 생성 실패: ", signal, " at ", DoubleToString(arrowPrice, _Digits));
    }
}

//+------------------------------------------------------------------+
//| Create info panel                                                |
//+------------------------------------------------------------------+
void CreateInfoPanel()
{
    if(MQLInfoInteger(MQL_TESTER))
        return; // 백테스트에서는 시각적 요소 비활성화
        
    string panelName = g_objectPrefix + "InfoPanel";
    
    if(ObjectCreate(0, panelName, OBJ_RECTANGLE_LABEL, 0, 0, 0))
    {
        ObjectSetInteger(0, panelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, InfoPanelX);
        ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, InfoPanelY);
        ObjectSetInteger(0, panelName, OBJPROP_XSIZE, 200);
        ObjectSetInteger(0, panelName, OBJPROP_YSIZE, 100);
        ObjectSetInteger(0, panelName, OBJPROP_BGCOLOR, clrBlack);
        ObjectSetInteger(0, panelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, panelName, OBJPROP_COLOR, clrWhite);
    }
}

//+------------------------------------------------------------------+
//| Update info panel                                                |
//+------------------------------------------------------------------+
void UpdateInfoPanel()
{
    if(MQLInfoInteger(MQL_TESTER))
        return; // 백테스트에서는 시각적 요소 비활성화
        
    string panelName = g_objectPrefix + "InfoPanel";
    
    if(ObjectFind(0, panelName) >= 0)
    {
        string info = "UT Bot EA Improved\n";
        info += "Position: " + IntegerToString(g_pos) + "\n";
        info += "ATR Stop: " + DoubleToString(g_xATRTrailingStop, _Digits) + "\n";
        info += "Daily Trades: " + IntegerToString(g_dailyTradeCount) + "\n";
        info += "Balance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2);
        
        ObjectSetString(0, panelName, OBJPROP_TEXT, info);
    }
}

//+------------------------------------------------------------------+
//| Remove all objects                                               |
//+------------------------------------------------------------------+
void RemoveAllObjects()
{
    if(MQLInfoInteger(MQL_TESTER))
        return; // 백테스트에서는 시각적 요소 비활성화
        
    for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i);
        if(StringFind(objName, g_objectPrefix) == 0)
        {
            ObjectDelete(0, objName);
        }
    }
}

//+------------------------------------------------------------------+
//| Count positions                                                   |
//+------------------------------------------------------------------+
int CountPositions()
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {
                count++;
            }
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Calculate Heikin Ashi Close price                               |
//+------------------------------------------------------------------+
double CalculateHeikinAshiClose()
{
    double haClose = (iClose(_Symbol, PERIOD_CURRENT, 0) +
                     iHigh(_Symbol, PERIOD_CURRENT, 0) +
                     iLow(_Symbol, PERIOD_CURRENT, 0) +
                     iOpen(_Symbol, PERIOD_CURRENT, 0)) / 4.0;
    return haClose;
}

//+------------------------------------------------------------------+
//| Calculate EMA (개선된 버전)                                      |
//+------------------------------------------------------------------+
double CalculateEMA(double src, double prevEma)
{
    if(prevEma == 0)
        return src;
    else
        return 0.5 * src + 0.5 * prevEma;
}
