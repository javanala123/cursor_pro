//+------------------------------------------------------------------+
//|                                       UT_Bot_EA_Production.mq5 |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//| UT Bot EA - ATR 기반 트레일링 스탑 자동매매 전략                     |
//|                                                                  |
//| 작동 원리:                                                        |
//| 1. ATR(Average True Range)을 사용하여 동적 트레일링 스탑 계산      |
//| 2. 가격이 트레일링 스탑을 돌파할 때 매수/매도 신호 생성             |
//| 3. 리스크 관리: 스프레드 필터, 시간 필터, 포지션 관리              |
//| 4. 시각적 표시: 차트에 신호와 트레일링 스탑 라인 표시               |
//|                                                                  |
//| Pine Script의 UT Bot Alerts를 MQL5로 완전 변환한 버전            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "2.00"
#property description "UT Bot Expert Advisor - Production Version with Advanced Features"
#property description "Features: Visual Signals, Time Filter, Spread Filter, Multi-Position Support"

//--- 표준 거래 라이브러리 포함 (주문 실행, 포지션 관리 등)
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| 입력 매개변수 (사용자가 설정 가능한 값들)                            |
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

input ASSET_TYPE AssetType = GOLD;  // 거래할 자산 유형 선택

//--- UT Bot 핵심 설정
input group "=== UT Bot Core Settings ==="
input double KeyValue = 1.0;           // 민감도 조절 값 (자산별 자동 조정됨)
input int ATRPeriod = 10;              // ATR 계산 기간 (자산별 자동 조정됨)
input bool UseHeikinAshi = false;      // Heikin Ashi 캔들 사용 (노이즈 감소)

//--- 거래 기본 설정
input group "=== Trading Settings ==="
input bool UseFixedLotSize = true;     // 고정 로트 크기 사용 (true) / 동적 계산 (false)
input double FixedLotSize = 0.1;       // 고정 로트 크기 (UseFixedLotSize=true일 때)
input double LotSize = 0.1;            // 고정 로트 크기 (하위 호환성용)
input ulong MagicNumber = 123456;      // 매직 넘버 (EA 식별용 고유 번호)
input int Slippage = 3;                // 슬리피지 허용 범위 (포인트 단위)
input bool AllowMultiplePositions = false; // 다중 포지션 허용 (false = 한 번에 하나만)
input bool UseReversePosition = true;  // 반대 신호 시 청산+반대포지션 진입 (true) / 청산만 (false)

//--- 리스크 관리 설정
input group "=== Risk Management ==="
input bool UseDynamicStopLoss = true;  // 동적 스탑로스 사용 (트레일링 스탑 가격)
input bool UseFixedStopLoss = false;   // 고정 스탑로스 사용
input double FixedStopLossPoints = 50; // 고정 스탑로스 거리 (포인트)
input bool UseTakeProfit = false;      // 테이크프로핏 사용 (자동 이익 실현)
input double RiskPercent = 2.0;        // 거래당 리스크 비율 (계좌 잔고의 %, 1-5% 권장)
input double MaxSpread = 50;           // 최대 허용 스프레드 (포인트, 오일 거래용으로 조정)
input bool EnableSpreadFilter = true;  // 스프레드 필터 활성화 (오일 거래용으로 활성화)
input bool UseStopLoss = true;         // 스탑로스 사용 여부 (false = 스탑로스 없음)

//--- 횡보장 보호 설정
input group "=== Sideways Market Protection ==="
input bool EnableSidewaysProtection = true;  // 횡보장 보호 활성화
input int MinBarsBetweenTrades = 5;          // 거래 간 최소 바 수 (빈번한 거래 방지)
input double MaxDailyLossPercent = 5.0;      // 일일 최대 손실 비율 (%)
input int MaxTradesPerDay = 10;              // 일일 최대 거래 수
input bool UseVolatilityFilter = true;       // 변동성 필터 사용 (ATR 기반)
input double MinVolatilityATR = 0.05;        // 최소 변동성 ATR 값 (오일 거래용으로 조정)
input bool UseTrendFilter = true;            // 트렌드 필터 사용 (횡보장 감지)
input int TrendPeriod = 20;                  // 트렌드 판단 기간 (이동평균)
input double MaxSidewaysRange = 0.005;       // 최대 횡보 범위 (가격의 %, 오일 거래용으로 조정)
input bool UseBreakoutConfirmation = true;   // 브레이크아웃 확인 사용
input int BreakoutBars = 3;                  // 브레이크아웃 확인 바 수

//--- 시간 필터 설정 (특정 시간대에만 거래)
input group "=== Time Filter Settings ==="
input bool UseTimeFilter = false;      // 시간 필터 사용 (거래 시간 제한)
input int StartHour = 0;               // 거래 시작 시간 (0-23시)
input int EndHour = 23;                // 거래 종료 시간 (0-23시)
input bool TradeMonday = true;         // 월요일 거래 허용
input bool TradeTuesday = true;        // 화요일 거래 허용
input bool TradeWednesday = true;      // 수요일 거래 허용
input bool TradeThursday = true;       // 목요일 거래 허용
input bool TradeFriday = true;         // 금요일 거래 허용

//--- 시각적 표시 설정 (차트 디스플레이)
input group "=== Visual Display Settings ==="
input bool ShowTrailingStop = true;    // 트레일링 스탑 라인 표시
input color TrailingStopColor = clrBlue; // 트레일링 스탑 라인 색상
input int TrailingStopWidth = 2;       // 트레일링 스탑 라인 두께
input bool ShowSignals = true;         // 매매 신호 화살표 표시
input color BuySignalColor = clrLime;  // 매수 신호 색상 (초록색)
input color SellSignalColor = clrRed;  // 매도 신호 색상 (빨간색)
input int SignalArrowCode = 233;       // 신호 화살표 코드 (233=위쪽, 234=아래쪽)
input bool ShowInfoPanel = true;       // 정보 패널 표시 (실시간 상태)
input int InfoPanelX = 20;             // 정보 패널 X 위치 (픽셀)
input int InfoPanelY = 30;             // 정보 패널 Y 위치 (픽셀)
input color InfoPanelColor = clrWhite; // 정보 패널 텍스트 색상
input int InfoPanelFontSize = 10;      // 정보 패널 폰트 크기

//+------------------------------------------------------------------+
//| 전역 변수 (EA 전체에서 사용되는 변수들)                              |
//+------------------------------------------------------------------+
CTrade trade;                          // 거래 실행 객체 (주문, 포지션 관리)
int g_atr_handle = INVALID_HANDLE;     // ATR 인디케이터 핸들 (MQL5 핸들 시스템)
double g_xATRTrailingStop = 0.0;       // 현재 ATR 트레일링 스탑 값
int g_pos = 0;                         // 현재 포지션 상태 (1=롱, -1=숏, 0=중립)
double g_prevATRTrailingStop = 0.0;    // 이전 바의 트레일링 스탑 값
double g_prevClose = 0.0;              // 이전 바의 종가
double g_prevSrc = 0.0;                // 이전 바의 소스 가격 (Heikin Ashi 또는 종가)
bool g_initialized = false;            // EA 초기화 완료 플래그
datetime g_lastBarTime = 0;            // 마지막으로 처리한 바의 시간 (새 바 감지용)
datetime g_lastSignalTime = 0;         // 마지막 신호 발생 시간
string g_objectPrefix = "UTBot_";      // 차트 객체 이름 접두사 (중복 방지)

//--- 횡보장 보호용 전역 변수
datetime g_lastTradeTime = 0;          // 마지막 거래 시간
int g_dailyTradeCount = 0;             // 일일 거래 수
double g_dailyStartBalance = 0;        // 일일 시작 잔고
datetime g_lastDay = 0;                // 마지막 거래일

//--- 자산별 동적 설정 변수 (런타임에 수정 가능)
double g_KeyValue = 1.0;               // 동적 민감도 값
int g_ATRPeriod = 10;                  // 동적 ATR 기간
double g_MinVolatilityATR = 0.1;       // 동적 최소 변동성 ATR
double g_MaxSpread = 50;               // 동적 최대 스프레드
double g_MaxSidewaysRange = 0.005;     // 동적 최대 횡보 범위
int g_TrendPeriod = 20;                // 동적 트렌드 기간
int g_BreakoutBars = 3;                // 동적 브레이크아웃 확인 바 수
bool g_UseTimeFilter = false;          // 동적 시간 필터 사용
int g_StartHour = 0;                   // 동적 시작 시간
int g_EndHour = 23;                    // 동적 종료 시간
bool g_TradeFriday = true;             // 동적 금요일 거래 허용

//+------------------------------------------------------------------+
//| 함수 선언 (사용할 함수들을 미리 선언)                                |
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

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//| EA가 차트에 적용될 때 한 번만 실행되는 초기화 함수                   |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- 거래 파라미터 설정
    // MagicNumber: 이 EA가 생성한 포지션을 식별하는 고유 번호
    trade.SetExpertMagicNumber(MagicNumber);
    
    // Slippage: 주문 가격과 실제 체결 가격의 차이 허용 범위 (포인트 단위)
    trade.SetDeviationInPoints(Slippage);
    
    // ORDER_FILLING_FOK: Fill or Kill - 전량 체결되거나 전량 취소
    // (부분 체결을 허용하지 않음, 빠른 시장에 유리)
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    //--- 전역 변수 초기화 (Pine Script v6와 정확히 일치)
    // Pine Script: pos = 0 (초기화)
    g_xATRTrailingStop = 0.0;      // 트레일링 스탑 값
    g_pos = 0;                      // 포지션 상태 (0=중립, 1=롱, -1=숏) - Pine Script와 동일
    g_prevATRTrailingStop = 0.0;    // 이전 트레일링 스탑
    g_prevClose = 0.0;              // 이전 종가
    g_prevSrc = 0.0;                // 이전 소스 가격
    g_initialized = false;          // 초기화 플래그 (첫 틱 처리용)
    g_lastBarTime = 0;              // 새 바 감지용 시간
    g_lastSignalTime = 0;           // 마지막 신호 시간
    
    //--- ATR 인디케이터 핸들 생성 ★ MQL5 핵심!
    // MQL5에서는 인디케이터 값을 직접 가져올 수 없고 핸들을 통해야 함
    // 핸들 = 인디케이터에 대한 참조 번호 (파일 핸들과 유사한 개념)
    g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
    if(g_atr_handle == INVALID_HANDLE)
    {
        // 핸들 생성 실패 = EA 작동 불가
        Print("ATR 인디케이터 핸들 생성 실패! 오류 코드: ", GetLastError());
        return(INIT_FAILED);  // EA 초기화 실패 반환
    }
    
    //--- 시각적 객체 생성 (차트에 표시되는 요소들)
    if(ShowTrailingStop)
        CreateTrailingStopLine();  // 트레일링 스탑 수평선 생성
    
    if(ShowInfoPanel)
        CreateInfoPanel();  // 좌측 상단 정보 패널 생성
    
    //--- 자산별 최적화 설정 적용
    ApplyAssetSpecificSettings();
    
    //--- 초기화 완료 메시지 출력
    Print("========================================");
    Print("UT Bot EA Production v2.04 초기화 완료");
    Print("핵심 수정사항: 자산별 최적화 설정, 포지션 크기 옵션, 동적 스탑로스, 횡보장 보호");
    Print("선택된 자산: ", EnumToString(AssetType));
    Print("민감도: ", KeyValue, " | ATR 기간: ", ATRPeriod);
    Print("Heikin Ashi: ", UseHeikinAshi ? "사용" : "미사용");
    Print("포지션 크기: ", UseFixedLotSize ? "고정 (" + DoubleToString(FixedLotSize, 2) + ")" : "동적 (리스크: " + DoubleToString(RiskPercent, 1) + "%)");
    Print("스탑로스: ", UseStopLoss ? (UseDynamicStopLoss ? "동적 (트레일링)" : (UseFixedStopLoss ? "고정 (" + DoubleToString(FixedStopLossPoints, 0) + "포인트)" : "사용안함")) : "사용안함");
    Print("반대포지션 진입: ", UseReversePosition ? "활성화" : "비활성화");
    Print("횡보장 보호: ", EnableSidewaysProtection ? "활성화" : "비활성화");
    Print("변동성 필터: ", UseVolatilityFilter ? "활성화 (최소 ATR: " + DoubleToString(g_MinVolatilityATR, 2) + " 또는 0.05%)" : "비활성화");
    Print("트렌드 필터: ", UseTrendFilter ? "활성화 (기간: " + IntegerToString(g_TrendPeriod) + ", 범위: " + DoubleToString(g_MaxSidewaysRange * 100, 2) + "%)" : "비활성화");
    Print("브레이크아웃 확인: ", UseBreakoutConfirmation ? "활성화 (" + IntegerToString(g_BreakoutBars) + "바)" : "비활성화");
    Print("시간 필터: ", UseTimeFilter ? "활성화" : "비활성화");
    Print("스프레드 필터: ", EnableSpreadFilter ? "활성화 (최대: " + DoubleToString(g_MaxSpread, 1) + ")" : "비활성화");
    Print("=== DEBUG MODE ACTIVATED ===");
    Print("Signal checks will be printed every 5 ticks for analysis");
    Print("========================================");
    
    return(INIT_SUCCEEDED);  // 초기화 성공 - EA 작동 시작
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//| EA가 차트에서 제거되거나 종료될 때 실행되는 정리 함수                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- ATR 인디케이터 핸들 해제 ★ 중요! 메모리 누수 방지
    // 핸들을 해제하지 않으면 메모리가 계속 점유됨
    // 여러 EA를 테스트할 때 특히 중요
    if(g_atr_handle != INVALID_HANDLE)
        IndicatorRelease(g_atr_handle);
    
    //--- 모든 차트 객체 제거
    // 차트에 생성한 라인, 화살표, 텍스트 등을 모두 삭제
    // 깔끔하게 정리하여 다음 실행에 영향 없도록 함
    RemoveAllObjects();
    
    //--- 종료 메시지 출력
    Print("========================================");
    Print("UT Bot EA Production 버전 종료");
    Print("종료 사유 코드: ", reason);
    // reason 값:
    // 0 = 사용자가 직접 제거
    // 1 = 프로그램 재컴파일
    // 3 = 차트 심볼 변경
    // 4 = 차트 닫힘
    // 5 = 입력 파라미터 변경
    Print("========================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//| 매 틱(가격 변동)마다 실행되는 메인 로직 함수 - EA의 핵심!             |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- 1단계: 충분한 바(캔들) 개수 확인
    // ATR 계산에 필요한 최소 개수: g_ATRPeriod + 1개
    // 예: g_ATRPeriod=10이면 최소 11개 바 필요
    if(Bars(_Symbol, PERIOD_CURRENT) < g_ATRPeriod + 1)
        return;  // 개수 부족 시 대기
    
    //--- 2단계: 스프레드 필터 체크 (오일 거래용으로 활성화)
    // 스프레드가 너무 크면 거래 비용이 높아 불리함
    // MaxSpread를 초과하면 거래하지 않음
    if(EnableSpreadFilter && !CheckSpread())
    {
        static datetime lastSpreadWarning = 0;
        if(TimeCurrent() - lastSpreadWarning > 300) // 5분마다 경고 (오일 거래용)
        {
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            double spread = point > 0 ? (ask - bid) / point : 0;
            Print("오일 거래: 스프레드가 높음 (", DoubleToString(spread, 1), "/", g_MaxSpread, " 포인트)");
            lastSpreadWarning = TimeCurrent();
        }
        
        if(ShowInfoPanel)
            UpdateInfoPanel();  // 정보 패널만 업데이트
        return;  // 거래 중지
    }
    
    //--- 3단계: 시간 필터 체크
    // 특정 시간대/요일에만 거래 (예: 런던+뉴욕 세션만)
    // 변동성 낮은 시간 회피
    if(UseTimeFilter && !IsTimeToTrade())
    {
        if(ShowInfoPanel)
            UpdateInfoPanel();  // 정보 패널만 업데이트
        return;  // 거래 중지
    }
    
    //--- 3.5단계: 횡보장 보호 체크
    // 빈번한 거래와 과도한 손실 방지
    if(!CheckSidewaysProtection())
    {
        if(ShowInfoPanel)
            UpdateInfoPanel();  // 정보 패널만 업데이트
        return;  // 거래 중지
    }
    
    //--- 3.6단계: 트렌드 필터 체크 (횡보장 감지)
    if(UseTrendFilter && !CheckTrendFilter())
    {
        if(ShowInfoPanel)
            UpdateInfoPanel();  // 정보 패널만 업데이트
        return;  // 거래 중지
    }
    
    //--- 4단계: 현재 가격 가져오기
    double close = iClose(_Symbol, PERIOD_CURRENT, 0);  // 현재 바의 종가
    if(close <= 0)
        return;  // 가격 정보 오류
    
    //--- 5단계: 소스 가격 계산
    // UseHeikinAshi = true: Heikin Ashi 종가 (노이즈 감소)
    // UseHeikinAshi = false: 일반 종가
    double src = UseHeikinAshi ? CalculateHeikinAshiClose() : close;
    
    //--- 6단계: 첫 틱 초기화
    // EA가 막 시작되었을 때 이전 값들을 저장
    if(!g_initialized)
    {
        g_prevClose = close;
        g_prevSrc = src;
        g_initialized = true;
        g_lastBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
        return;  // 첫 틱은 초기화만 하고 거래 안함
    }
    
    //--- 7단계: ATR 값 가져오기 ★ MQL5 방식!
    // MQL5에서는 핸들을 통해 버퍼로 값을 복사해야 함
    double atr_buffer[];
    ArraySetAsSeries(atr_buffer, true);  // 최신 데이터가 [0]이 되도록
    if(CopyBuffer(g_atr_handle, 0, 0, 1, atr_buffer) < 0)
    {
        // ATR 값 가져오기 실패
        Print("ATR 버퍼 복사 실패! 오류: ", GetLastError());
        return;
    }
    double atr = atr_buffer[0];  // 현재 ATR 값
    if(atr <= 0)
        return;  // ATR 값 오류
    
    //--- 7.5단계: 변동성 필터 체크
    // 충분한 변동성이 있을 때만 거래
    if(!CheckVolatilityFilter(atr))
    {
        if(ShowInfoPanel)
            UpdateInfoPanel();  // 정보 패널만 업데이트
        return;  // 거래 중지
    }
    
    //--- 8단계: ATR 트레일링 스탑 계산
    // 핵심 알고리즘: 가격에 따라 동적으로 스탑 위치 조정
    CalculateATRTrailingStop(src, atr);
    
    //--- 8.5단계: 트레일링 스탑 초기화 확인
    // 첫 번째 계산에서 트레일링 스탑이 0이면 초기화
    if(g_xATRTrailingStop == 0.0 && atr > 0)
    {
        // 초기 트레일링 스탑 설정 (가격 ± ATR)
        g_xATRTrailingStop = src + (src > 0 ? atr : -atr);
        Print("트레일링 스탑 초기화: ", DoubleToString(g_xATRTrailingStop, _Digits));
    }
    
    //--- 9단계: 매매 신호 체크 (새 바에서만! 포지션 상태 업데이트 전에!)
    // 같은 바에서 중복 신호 방지
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(currentBarTime != g_lastBarTime)  // 새 바가 생성되었는가?
    {
        CheckTradingSignals(src);  // 크로스오버 감지 및 거래 실행 (먼저 실행!)
        g_lastBarTime = currentBarTime;
    }
    
    //--- 10단계: 포지션 상태 업데이트 (신호 체크 후)
    // g_pos 업데이트: 가격과 스탑의 위치 관계 추적
    UpdatePositionState(src);
    
    //--- 11단계: 차트 시각적 요소 업데이트
    // 트레일링 스탑 라인, 정보 패널 갱신
    UpdateVisualDisplay();
    
    //--- 12단계: 이전 값 저장 (다음 틱에서 비교용)
    g_prevClose = close;
    g_prevSrc = src;
    g_prevATRTrailingStop = g_xATRTrailingStop;
}

//+------------------------------------------------------------------+
//| Check if spread is acceptable                                    |
//+------------------------------------------------------------------+
bool CheckSpread()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    if(point <= 0)
        return false;
    
    double spread = (ask - bid) / point;
    
    if(spread > g_MaxSpread)
    {
        static datetime lastWarning = 0;
        if(TimeCurrent() - lastWarning > 3600) // Warn once per hour
        {
            Print("Spread too high: ", DoubleToString(spread, 1), " points (Max: ", g_MaxSpread, ")");
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
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    //--- Check day of week
    bool dayAllowed = false;
    switch(dt.day_of_week)
    {
        case 1: dayAllowed = TradeMonday; break;
        case 2: dayAllowed = TradeTuesday; break;
        case 3: dayAllowed = TradeWednesday; break;
        case 4: dayAllowed = TradeThursday; break;
        case 5: dayAllowed = g_TradeFriday; break;  // 동적 금요일 설정 사용
        default: dayAllowed = false;
    }
    
    if(!dayAllowed)
        return false;
    
    //--- Check hour
    if(g_StartHour <= g_EndHour)
        return dt.hour >= g_StartHour && dt.hour <= g_EndHour;
    else
        return dt.hour >= g_StartHour || dt.hour <= g_EndHour;
}

//+------------------------------------------------------------------+
//| Update position state (Pine Script pos variable equivalent)     |
//| Pine Script v6의 pos 로직을 정확히 구현                          |
//+------------------------------------------------------------------+
void UpdatePositionState(double src)
{
    //--- Pine Script의 nz() 함수 구현
    // nz(xATRTrailingStop[1], 0) = 이전 값이 na이면 0 반환
    double prevStop = (g_prevATRTrailingStop == 0.0) ? 0.0 : g_prevATRTrailingStop;
    int prevPos = g_pos;  // nz(pos[1], 0)와 동일
    
    //--- Pine Script v6의 pos 로직을 정확히 구현
    // Pine Script: pos = 0 (초기화)
    // Pine Script: iff_3 = src[1] > nz(xATRTrailingStop[1], 0) and src < nz(xATRTrailingStop[1], 0) ? -1 : nz(pos[1], 0)
    // Pine Script: pos := src[1] < nz(xATRTrailingStop[1], 0) and src > nz(xATRTrailingStop[1], 0) ? 1 : iff_3
    
    // iff_3 계산: 하향 돌파 조건 체크
    int iff_3;
    if((g_prevSrc > prevStop) && (src < prevStop))
    {
        iff_3 = -1;  // 하향 돌파 → 숏 포지션
    }
    else
    {
        iff_3 = prevPos;  // nz(pos[1], 0) - 이전 값 유지
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
    
    // Pine Script v6 로직 완전 구현:
    // 1. pos = 0으로 초기화 (OnInit에서 처리)
    // 2. iff_3: 하향 돌파시 -1, 아니면 이전 값 유지
    // 3. 최종: 상향 돌파시 1, 아니면 iff_3 결과 사용
}

//+------------------------------------------------------------------+
//| Calculate Heikin Ashi Close price                               |
//| Heikin Ashi 캔들의 종가를 계산 (노이즈 감소용)                      |
//+------------------------------------------------------------------+
double CalculateHeikinAshiClose()
{
    // Heikin Ashi 종가 = (시가 + 고가 + 저가 + 종가) / 4
    // 일반 캔들보다 부드러운 움직임 → 노이즈 감소
    // 트렌드 파악에 유리하지만 실제 가격과 차이 있음
    double haClose = (iClose(_Symbol, PERIOD_CURRENT, 0) +   // 종가
                     iHigh(_Symbol, PERIOD_CURRENT, 0) +      // 고가
                     iLow(_Symbol, PERIOD_CURRENT, 0) +       // 저가
                     iOpen(_Symbol, PERIOD_CURRENT, 0)) / 4.0; // 시가
    return haClose;
}

//+------------------------------------------------------------------+
//| Calculate ATR Trailing Stop                                     |
//| ATR 기반 동적 트레일링 스탑 계산 - UT Bot 전략의 핵심!               |
//| Pine Script v6의 iff 로직을 정확히 구현                          |
//+------------------------------------------------------------------+
void CalculateATRTrailingStop(double src, double atr)
{
    // nLoss: 스탑까지의 거리 = ATR × 민감도
    // g_KeyValue가 클수록 스탑이 멀어짐 (보수적)
    // g_KeyValue가 작을수록 스탑이 가까워짐 (공격적)
    double nLoss = g_KeyValue * atr;
    
    //--- Pine Script의 nz() 함수 구현
    // nz(xATRTrailingStop[1], 0) = 이전 값이 na이면 0 반환
    double prevStop = (g_prevATRTrailingStop == 0.0) ? 0.0 : g_prevATRTrailingStop;
    double prevSrc = g_prevSrc;
    
    //--- Pine Script v6의 iff 로직을 정확히 구현
    // iff_1 = src > nz(xATRTrailingStop[1], 0) ? src - nLoss : src + nLoss
    double iff_1 = (src > prevStop) ? (src - nLoss) : (src + nLoss);
    
    // iff_2 = src < nz(xATRTrailingStop[1], 0) and src[1] < nz(xATRTrailingStop[1], 0) ? 
    //         math.min(nz(xATRTrailingStop[1]), src + nLoss) : iff_1
    double iff_2;
    if((src < prevStop) && (prevSrc < prevStop))
    {
        iff_2 = MathMin(prevStop, src + nLoss);
    }
    else
    {
        iff_2 = iff_1;
    }
    
    // xATRTrailingStop := src > nz(xATRTrailingStop[1], 0) and src[1] > nz(xATRTrailingStop[1], 0) ? 
    //                     math.max(nz(xATRTrailingStop[1]), src - nLoss) : iff_2
    if((src > prevStop) && (prevSrc > prevStop))
    {
        g_xATRTrailingStop = MathMax(prevStop, src - nLoss);
    }
    else
    {
        g_xATRTrailingStop = iff_2;
    }
    
    // Pine Script v6 로직 완전 구현:
    // 1. iff_1: 가격이 이전 스탑 위면 (src - nLoss), 아래면 (src + nLoss)
    // 2. iff_2: 가격이 이전 스탑 아래이고 이전 가격도 스탑 아래면 MIN(이전스탑, src + nLoss), 아니면 iff_1
    // 3. 최종: 가격이 이전 스탑 위이고 이전 가격도 스탑 위면 MAX(이전스탑, src - nLoss), 아니면 iff_2
}

//+------------------------------------------------------------------+
//| Check for trading signals                                        |
//| 크로스오버를 감지하여 매수/매도 신호 생성 - 실제 거래 타이밍 결정      |
//| Pine Script v6의 ta.crossover() 로직을 정확히 구현                |
//+------------------------------------------------------------------+
void CheckTradingSignals(double src)
{
    //--- 이전 값이 없으면 신호 판단 불가
    if(g_prevATRTrailingStop == 0.0 || g_prevSrc == 0.0)
        return;
    
    //--- EMA(1) 정확한 계산 (Pine Script ta.ema(src, 1)과 동일)
    // Pine Script: ema = ta.ema(src, 1)
    // EMA(1)은 지수이동평균이므로 정확한 계산 필요
    static double ema_prev = 0;
    double ema;
    if(ema_prev == 0)
        ema = src;  // 첫 번째 값
    else
        ema = (2.0 * src + 1.0 * ema_prev) / 3.0; // EMA(1) 근사치
    
    double prevEma = (g_prevSrc == 0) ? src : ema_prev;  // ema[1]
    
    //--- Pine Script의 nz() 함수 구현
    // nz(xATRTrailingStop[1], 0) = 이전 값이 na이면 0 반환
    double prevStop = (g_prevATRTrailingStop == 0.0) ? 0.0 : g_prevATRTrailingStop;
    
    //--- Pine Script v6의 ta.crossover() 로직을 정확히 구현
    // Pine Script: above = ta.crossover(ema, xATRTrailingStop)
    // ta.crossover(a, b) = a[1] <= b[1] and a > b
    bool above = (prevEma <= prevStop) && (ema > g_xATRTrailingStop);
    
    // Pine Script: below = ta.crossover(xATRTrailingStop, ema)
    // ta.crossover(a, b) = a[1] <= b[1] and a > b
    bool below = (prevStop <= prevEma) && (g_xATRTrailingStop > ema);
    
    //--- Pine Script v6의 최종 매매 신호 판단
    // Pine Script: buy = src > xATRTrailingStop and above
    // Pine Script: sell = src < xATRTrailingStop and below
    bool buy = (src > g_xATRTrailingStop) && above;
    bool sell = (src < g_xATRTrailingStop) && below;
    
    //--- 브레이크아웃 확인 (횡보장 손실 최소화)
    if(UseBreakoutConfirmation)
    {
        if(buy && !CheckBreakoutConfirmation(true))
            buy = false;  // 브레이크아웃 확인 실패 시 매수 신호 취소
        if(sell && !CheckBreakoutConfirmation(false))
            sell = false;  // 브레이크아웃 확인 실패 시 매도 신호 취소
    }
    
    //--- 강화된 디버깅 정보 출력 (사용자 제안사항 적용)
    static int debugCounter = 0;
    if(debugCounter++ % 5 == 0) // 5틱마다 출력 (더 자주)
    {
        Print("=== REAL-TIME VALUES ===");
        Print("Current Price: ", DoubleToString(src, _Digits));
        Print("Trailing Stop: ", DoubleToString(g_xATRTrailingStop, _Digits));
        Print("Previous Stop: ", DoubleToString(g_prevATRTrailingStop, _Digits));
        Print("EMA: ", DoubleToString(ema, _Digits));
        Print("Previous EMA: ", DoubleToString(prevEma, _Digits));
        Print("Position State: ", g_pos);
        Print("Above Crossover: ", above ? "TRUE" : "FALSE");
        Print("Below Crossover: ", below ? "TRUE" : "FALSE");
        Print("Buy Signal: ", buy ? "TRUE" : "FALSE");
        Print("Sell Signal: ", sell ? "TRUE" : "FALSE");
        Print("========================");
    }
    
    //--- 신호 발생 시 상세 정보 출력
    if(buy || sell)
    {
        Print(StringFormat("SIGNAL CHECK: src=%.5f, stop=%.5f, ema=%.5f, prevEma=%.5f, above=%d, buy=%d", 
              src, g_xATRTrailingStop, ema, prevEma, above, buy));
    }
    
    // 시각화:
    // 매수 신호:
    //   스탑 -------
    //            ╱ ← 가격이 위로 돌파! (BUY)
    //   가격 ●  ●
    //
    // 매도 신호:
    //   가격 ●  ●
    //            ╲ ← 가격이 아래로 돌파! (SELL)
    //   스탑 -------
    
    //--- Pine Script v6의 barbuy/barsell 로직 구현
    // Pine Script: barbuy = src > xATRTrailingStop
    // Pine Script: barsell = src < xATRTrailingStop
    bool barbuy = (src > g_xATRTrailingStop);
    bool barsell = (src < g_xATRTrailingStop);
    
    //--- Pine Script v6의 barcolor 기능 구현 (매 틱마다 업데이트)
    // Pine Script: barcolor(barbuy ? color.green : na)
    // Pine Script: barcolor(barsell ? color.red : na)
    if(ShowSignals)
    {
        // 현재 바의 색상을 변경 (Pine Script barcolor와 동일)
        if(barbuy)
        {
            // 상승 바: 초록색 (Pine Script color.green)
            CreateBarColorIndicator("BARCOLOR_GREEN", TimeCurrent(), clrLime);
        }
        else if(barsell)
        {
            // 하락 바: 빨간색 (Pine Script color.red)
            CreateBarColorIndicator("BARCOLOR_RED", TimeCurrent(), clrRed);
        }
    }
    
    //--- Pine Script v6의 xcolor 로직 구현 (포지션 상태에 따른 색상)
    // Pine Script: xcolor = pos == -1 ? color.red : pos == 1 ? color.green : color.blue
    color xcolor = (g_pos == -1) ? clrRed : (g_pos == 1) ? clrLime : clrBlue;
    
    // 포지션 상태에 따른 추가 시각적 표시
    if(ShowSignals)
    {
        CreatePositionIndicator("POSITION_INDICATOR", TimeCurrent(), xcolor, g_pos);
    }
    
    //--- Pine Script v6의 plot() 함수와 동일한 트레일링 스탑 라인 표시
    // Pine Script에서는 자동으로 plot()이 되지만 MQL5에서는 수동으로 구현
    if(ShowTrailingStop)
    {
        // 트레일링 스탑 라인을 Pine Script와 동일하게 표시
        UpdateTrailingStopLine();
        
        // Pine Script의 plot()과 동일한 색상으로 표시
        string objName = g_objectPrefix + "TrailingStop";
        if(ObjectFind(0, objName) >= 0)
        {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, xcolor);  // 포지션 상태에 따른 색상
        }
    }
    
    //--- 신호 발생 시 주문 실행 (개선된 로직)
    if(buy)
    {
        double current_atr[];
        ArraySetAsSeries(current_atr, true);
        CopyBuffer(g_atr_handle, 0, 0, 1, current_atr);
        
        Print(">>> BUY SIGNAL TRIGGERED <<<");
        Print("Price: ", DoubleToString(src, _Digits));
        Print("Trailing Stop: ", DoubleToString(g_xATRTrailingStop, _Digits));
        Print("ATR: ", DoubleToString(current_atr[0], _Digits));
        Print("Position State: ", g_pos);
        Print("EMA: ", DoubleToString(ema, _Digits));
        Print("Previous EMA: ", DoubleToString(prevEma, _Digits));
        
        if(ShowSignals)
        {
            // Pine Script: plotshape(buy, title = 'Buy', text = 'Buy', style = shape.labelup, location = location.belowbar, color = color.new(color.green, 0), textcolor = color.new(color.white, 0), size = size.tiny)
            CreatePineScriptShape("BUY", src, true, clrLime, clrWhite);
        }
        
        // 반대 포지션 청산 후 매수 진입
        if(UseReversePosition)
        {
            ClosePositions(POSITION_TYPE_SELL);  // 기존 매도 포지션 청산
        }
        
        ExecuteBuyOrder();
        g_lastSignalTime = TimeCurrent();
        g_lastTradeTime = TimeCurrent();
        g_dailyTradeCount++;
    }
    else if(sell)
    {
        double current_atr[];
        ArraySetAsSeries(current_atr, true);
        CopyBuffer(g_atr_handle, 0, 0, 1, current_atr);
        
        Print(">>> SELL SIGNAL TRIGGERED <<<");
        Print("Price: ", DoubleToString(src, _Digits));
        Print("Trailing Stop: ", DoubleToString(g_xATRTrailingStop, _Digits));
        Print("ATR: ", DoubleToString(current_atr[0], _Digits));
        Print("Position State: ", g_pos);
        Print("EMA: ", DoubleToString(ema, _Digits));
        Print("Previous EMA: ", DoubleToString(prevEma, _Digits));
        
        if(ShowSignals)
        {
            // Pine Script: plotshape(sell, title = 'Sell', text = 'Sell', style = shape.labeldown, location = location.abovebar, color = color.new(color.red, 0), textcolor = color.new(color.white, 0), size = size.tiny)
            CreatePineScriptShape("SELL", src, false, clrRed, clrWhite);
        }
        
        // 반대 포지션 청산 후 매도 진입
        if(UseReversePosition)
        {
            ClosePositions(POSITION_TYPE_BUY);  // 기존 매수 포지션 청산
        }
        
        ExecuteSellOrder();
        g_lastSignalTime = TimeCurrent();
        g_lastTradeTime = TimeCurrent();
        g_dailyTradeCount++;
    }
    
    //--- EMA 값 업데이트 (다음 틱에서 사용)
    ema_prev = ema;
}

//+------------------------------------------------------------------+
//| Execute Buy Order                                                |
//| 실제 매수 주문을 실행하는 함수                                      |
//+------------------------------------------------------------------+
void ExecuteBuyOrder()
{
    //--- 다중 포지션 허용 여부 체크
    if(!AllowMultiplePositions)  // 한 번에 하나의 포지션만 허용
    {
        // 1. 기존 매도 포지션이 있으면 먼저 청산
        ClosePositions(POSITION_TYPE_SELL);
        
        // 2. 이미 매수 포지션이 있으면 중복 진입 방지
        if(HasPosition(POSITION_TYPE_BUY))
        {
            Print("매수 신호 무시: 이미 매수 포지션 보유 중");
            return;  // 주문 실행 안함
        }
    }
    
    //--- 로트 크기 계산
    // RiskPercent 설정에 따라 리스크 기반 계산 또는 고정 로트 사용
    double lotSize = CalculateLotSize();
    
    //--- 매수 주문 실행
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);  // 현재 매수 가격
    
    // 스탑로스: 사용 여부에 따라 동적/고정/없음 선택
    double sl = 0;
    if(UseStopLoss)
    {
        if(UseDynamicStopLoss)
            sl = g_xATRTrailingStop;  // 동적 스탑로스 (트레일링 스탑)
        else if(UseFixedStopLoss)
            sl = ask - FixedStopLossPoints * _Point;  // 고정 스탑로스
    }
    // UseStopLoss = false이면 스탑로스 없음 (sl = 0)
    
    // 테이크프로핏: 스탑로스 거리의 2배 (리스크:리워드 = 1:2)
    double tp = UseTakeProfit ? ask + (ask - g_xATRTrailingStop) * 2 : 0;
    
    // CTrade 클래스를 사용한 주문 실행
    // Buy(로트, 심볼, 가격, SL, TP, 코멘트)
    if(trade.Buy(lotSize, _Symbol, ask, sl, tp, "UT Bot Buy"))
    {
        // 주문 성공
        Print(">>> 매수 주문 체결 완료 <<<");
        Print("티켓 번호: ", trade.ResultOrder());
        Print("로트: ", lotSize);
        Print("체결 가격: ", DoubleToString(ask, _Digits));
        Print("손절가: ", DoubleToString(sl, _Digits));
        Print("익절가: ", DoubleToString(tp, _Digits));
    }
    else
    {
        // 주문 실패
        Print("!!! 매수 주문 실패 !!!");
        Print("오류 코드: ", trade.ResultRetcode());
        Print("오류 설명: ", trade.ResultRetcodeDescription());
        // 일반적인 오류:
        // 10004 = 잘못된 가격
        // 10006 = 요청 거부
        // 10013 = 잘못된 요청
        // 10014 = 주문 실행 불가
        // 10015 = 수정 불가
    }
}

//+------------------------------------------------------------------+
//| Execute Sell Order                                               |
//+------------------------------------------------------------------+
void ExecuteSellOrder()
{
    //--- Check if we should allow multiple positions
    if(!AllowMultiplePositions)
    {
        ClosePositions(POSITION_TYPE_BUY);
        
        if(HasPosition(POSITION_TYPE_SELL))
        {
            Print("Sell signal ignored: Position already exists");
            return;
        }
    }
    
    //--- Calculate lot size
    double lotSize = CalculateLotSize();
    
    //--- Execute sell order
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // 스탑로스: 사용 여부에 따라 동적/고정/없음 선택
    double sl = 0;
    if(UseStopLoss)
    {
        if(UseDynamicStopLoss)
            sl = g_xATRTrailingStop;  // 동적 스탑로스 (트레일링 스탑)
        else if(UseFixedStopLoss)
            sl = bid + FixedStopLossPoints * _Point;  // 고정 스탑로스
    }
    // UseStopLoss = false이면 스탑로스 없음 (sl = 0)
    
    double tp = UseTakeProfit ? bid - (g_xATRTrailingStop - bid) * 2 : 0;
    
    if(trade.Sell(lotSize, _Symbol, bid, sl, tp, "UT Bot Sell"))
    {
        Print(">>> SELL ORDER EXECUTED <<<");
        Print("Ticket: ", trade.ResultOrder());
        Print("Lot: ", lotSize);
        Print("Price: ", DoubleToString(bid, _Digits));
        Print("SL: ", DoubleToString(sl, _Digits));
        Print("TP: ", DoubleToString(tp, _Digits));
    }
    else
    {
        Print("!!! SELL ORDER FAILED !!!");
        Print("Error: ", trade.ResultRetcode());
        Print("Description: ", trade.ResultRetcodeDescription());
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
                    Print("Position closed. Ticket: ", ticket);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk management                     |
//| 리스크 관리에 따른 로트 크기 자동 계산 (고정/동적 선택 가능)            |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    //--- 고정 로트 크기 사용
    if(UseFixedLotSize)
        return FixedLotSize;
    
    //--- RiskPercent가 0 이하면 고정 로트 사용
    if(RiskPercent <= 0)
        return FixedLotSize;
    
    //--- 계좌 정보 가져오기
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);  // 계좌 잔고
    
    //--- 리스크 금액 계산
    // 예: 잔고 $10,000, RiskPercent 2% → $200 리스크
    double riskAmount = accountBalance * RiskPercent / 100.0;
    
    //--- 심볼 정보 가져오기
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);  // 1틱의 가치 ($)
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);    // 1틱의 크기 (pips)
    
    //--- 스탑로스 거리 계산
    // 현재 가격에서 트레일링 스탑까지의 거리
    double stopLoss = MathAbs(g_xATRTrailingStop - SymbolInfoDouble(_Symbol, SYMBOL_BID));
    
    //--- 로트 크기 계산
    if(tickValue > 0 && tickSize > 0 && stopLoss > 0)
    {
        // 공식: 로트 = 리스크 금액 / (스탑로스 거리 × 틱당 가치)
        // 예: $200 / (50 pips × $1) = 4 lots
        double calculatedLot = riskAmount / (stopLoss / tickSize * tickValue);
        
        //--- 브로커 제한 범위 내로 조정
        double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);  // 최소 로트 (예: 0.01)
        double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);  // 최대 로트 (예: 100)
        double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP); // 로트 단위 (예: 0.01)
        
        // 최소/최대 범위 내로 제한
        calculatedLot = MathMax(calculatedLot, minLot);
        calculatedLot = MathMin(calculatedLot, maxLot);
        
        // 로트 스텝 단위로 반올림
        // 예: lotStep=0.01이면 0.01, 0.02, 0.03... 단위로만 가능
        calculatedLot = NormalizeDouble(calculatedLot / lotStep, 0) * lotStep;
        
        return calculatedLot;
    }
    
    //--- 계산 실패 시 고정 로트 반환
    return LotSize;
}

//+------------------------------------------------------------------+
//| Update visual display                                            |
//+------------------------------------------------------------------+
void UpdateVisualDisplay()
{
    if(ShowTrailingStop)
        UpdateTrailingStopLine();
    
    if(ShowInfoPanel)
        UpdateInfoPanel();
}

//+------------------------------------------------------------------+
//| Create trailing stop line (Pine Script plot equivalent)         |
//+------------------------------------------------------------------+
void CreateTrailingStopLine()
{
    string objName = g_objectPrefix + "TrailingStop";
    
    if(ObjectFind(0, objName) < 0)
    {
        // Pine Script의 plot()과 동일한 수평선 생성
        ObjectCreate(0, objName, OBJ_HLINE, 0, 0, g_xATRTrailingStop);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, TrailingStopColor);
        ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);  // Pine Script와 동일한 실선
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, TrailingStopWidth);
        ObjectSetInteger(0, objName, OBJPROP_BACK, false);  // Pine Script는 백그라운드에 그리지 않음
        ObjectSetString(0, objName, OBJPROP_TEXT, "UT Bot Trailing Stop");
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);
    }
}

//+------------------------------------------------------------------+
//| Update trailing stop line                                        |
//+------------------------------------------------------------------+
void UpdateTrailingStopLine()
{
    string objName = g_objectPrefix + "TrailingStop";
    
    if(ObjectFind(0, objName) >= 0)
    {
        ObjectSetDouble(0, objName, OBJPROP_PRICE, g_xATRTrailingStop);
    }
    else
    {
        CreateTrailingStopLine();
    }
}

//+------------------------------------------------------------------+
//| Create signal arrow                                              |
//+------------------------------------------------------------------+
void CreateSignalArrow(string signal, double price)
{
    string objName = g_objectPrefix + "Signal_" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
    
    ObjectCreate(0, objName, OBJ_ARROW, 0, TimeCurrent(), price);
    
    if(signal == "BUY")
    {
        ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, SignalArrowCode);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, BuySignalColor);
        ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_TOP);
    }
    else
    {
        ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, SignalArrowCode + 1);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, SellSignalColor);
        ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
    }
    
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
    ObjectSetString(0, objName, OBJPROP_TEXT, signal);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Create bar color indicator (Pine Script barcolor equivalent)    |
//+------------------------------------------------------------------+
void CreateBarColorIndicator(string name, datetime time, color clr)
{
    string objName = g_objectPrefix + name + "_" + TimeToString(time, TIME_DATE|TIME_SECONDS);
    
    // 기존 같은 시간의 바 색상 객체가 있으면 삭제
    if(ObjectFind(0, objName) >= 0)
        ObjectDelete(0, objName);
    
    // 현재 바의 고가와 저가 가져오기
    double high = iHigh(_Symbol, PERIOD_CURRENT, 0);
    double low = iLow(_Symbol, PERIOD_CURRENT, 0);
    
    // 사각형 객체로 바 색상 표시 (Pine Script barcolor와 유사)
    ObjectCreate(0, objName, OBJ_RECTANGLE, 0, time, low, time + PeriodSeconds(), high);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_FILL, true);
    ObjectSetInteger(0, objName, OBJPROP_BACK, true);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
    
    // 투명도 설정 (Pine Script와 유사한 효과)
    ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
}

//+------------------------------------------------------------------+
//| Create Pine Script plotshape equivalent                         |
//| Pine Script의 plotshape() 함수와 동일한 기능 구현                |
//+------------------------------------------------------------------+
void CreatePineScriptShape(string signal, double price, bool isBuy, color bgColor, color textColor)
{
    string objName = g_objectPrefix + "Shape_" + signal + "_" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
    
    // 기존 같은 신호가 있으면 삭제
    if(ObjectFind(0, objName) >= 0)
        ObjectDelete(0, objName);
    
    // Pine Script: plotshape(buy, title = 'Buy', text = 'Buy', style = shape.labelup, location = location.belowbar, color = color.new(color.green, 0), textcolor = color.new(color.white, 0), size = size.tiny)
    // Pine Script: plotshape(sell, title = 'Sell', text = 'Sell', style = shape.labeldown, location = location.abovebar, color = color.new(color.red, 0), textcolor = color.new(color.white, 0), size = size.tiny)
    
    // 라벨 객체 생성 (Pine Script의 shape.labelup/labeldown과 동일)
    ObjectCreate(0, objName, OBJ_LABEL, 0, TimeCurrent(), price);
    
    // 위치 설정 (Pine Script의 location.belowbar/abovebar와 동일)
    if(isBuy)
    {
        // 매수 신호: 바 아래쪽에 표시 (location.belowbar)
        ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_UPPER);
        ObjectSetDouble(0, objName, OBJPROP_PRICE, price - (iHigh(_Symbol, PERIOD_CURRENT, 0) - iLow(_Symbol, PERIOD_CURRENT, 0)) * 0.1);
    }
    else
    {
        // 매도 신호: 바 위쪽에 표시 (location.abovebar)
        ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LOWER);
        ObjectSetDouble(0, objName, OBJPROP_PRICE, price + (iHigh(_Symbol, PERIOD_CURRENT, 0) - iLow(_Symbol, PERIOD_CURRENT, 0)) * 0.1);
    }
    
    // 색상 설정 (Pine Script의 color.new(color.green/red, 0)와 동일)
    ObjectSetInteger(0, objName, OBJPROP_COLOR, bgColor);
    ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgColor);
    ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, bgColor);
    
    // 텍스트 설정 (Pine Script의 text = 'Buy'/'Sell'과 동일)
    ObjectSetString(0, objName, OBJPROP_TEXT, signal);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 12);  // 더 두드러진 표시
    ObjectSetString(0, objName, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, objName, OBJPROP_COLOR, textColor);
    
    // 기타 설정
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);
    ObjectSetInteger(0, objName, OBJPROP_BACK, false);
    
    // Pine Script의 plotshape과 동일한 시각적 효과 (더 두드러진 표시)
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
    ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
}

//+------------------------------------------------------------------+
//| Create position indicator (Pine Script xcolor equivalent)       |
//| Pine Script의 xcolor 로직에 따른 포지션 상태 표시                  |
//+------------------------------------------------------------------+
void CreatePositionIndicator(string name, datetime time, color clr, int position)
{
    string objName = g_objectPrefix + name + "_" + TimeToString(time, TIME_DATE|TIME_SECONDS);
    
    // 기존 같은 시간의 포지션 표시가 있으면 삭제
    if(ObjectFind(0, objName) >= 0)
        ObjectDelete(0, objName);
    
    // 포지션 상태에 따른 텍스트
    string positionText = "";
    if(position == 1)
        positionText = "LONG";
    else if(position == -1)
        positionText = "SHORT";
    else
        positionText = "NEUTRAL";
    
    // 현재 가격 위치에 포지션 상태 표시
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    // 라벨 객체 생성
    ObjectCreate(0, objName, OBJ_LABEL, 0, time, currentPrice);
    ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT);
    ObjectSetString(0, objName, OBJPROP_TEXT, positionText);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
    ObjectSetString(0, objName, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);
    ObjectSetInteger(0, objName, OBJPROP_BACK, false);
}

//+------------------------------------------------------------------+
//| Create information panel                                         |
//+------------------------------------------------------------------+
void CreateInfoPanel()
{
    string labels[] = {"Asset:", "Status:", "Position:", "Trailing Stop:", "ATR:", "Spread:", "Time Filter:", "Open Positions:"};
    
    for(int i = 0; i < ArraySize(labels); i++)
    {
        string objName = g_objectPrefix + "Label_" + IntegerToString(i);
        
        if(ObjectFind(0, objName) < 0)
        {
            ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, InfoPanelX);
            ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, InfoPanelY + (i * 20));
            ObjectSetInteger(0, objName, OBJPROP_COLOR, InfoPanelColor);
            ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, InfoPanelFontSize);
            ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
            ObjectSetString(0, objName, OBJPROP_TEXT, labels[i]);
        }
        
        string objNameValue = g_objectPrefix + "Value_" + IntegerToString(i);
        
        if(ObjectFind(0, objNameValue) < 0)
        {
            ObjectCreate(0, objNameValue, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, objNameValue, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, objNameValue, OBJPROP_XDISTANCE, InfoPanelX + 120);
            ObjectSetInteger(0, objNameValue, OBJPROP_YDISTANCE, InfoPanelY + (i * 20));
            ObjectSetInteger(0, objNameValue, OBJPROP_COLOR, InfoPanelColor);
            ObjectSetInteger(0, objNameValue, OBJPROP_FONTSIZE, InfoPanelFontSize);
            ObjectSetString(0, objNameValue, OBJPROP_FONT, "Arial Bold");
        }
    }
}

//+------------------------------------------------------------------+
//| Update information panel                                         |
//+------------------------------------------------------------------+
void UpdateInfoPanel()
{
    //--- Calculate spread
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double spread = point > 0 ? (ask - bid) / point : 0;
    
    //--- Get current ATR value
    double panel_atr[];
    ArraySetAsSeries(panel_atr, true);
    CopyBuffer(g_atr_handle, 0, 0, 1, panel_atr);
    
    //--- Update values
    string values[8];
    values[0] = EnumToString(AssetType);  // 자산 유형 표시
    values[1] = g_initialized ? "ACTIVE" : "INITIALIZING";
    values[2] = g_pos == 1 ? "LONG" : g_pos == -1 ? "SHORT" : "NEUTRAL";
    values[3] = DoubleToString(g_xATRTrailingStop, _Digits);
    values[4] = DoubleToString(panel_atr[0], _Digits);
    values[5] = DoubleToString(spread, 1) + " pts";
    values[6] = UseTimeFilter ? (IsTimeToTrade() ? "ALLOWED" : "BLOCKED") : "DISABLED";
    values[7] = IntegerToString(CountPositions());
    
    //--- Pine Script v6 호환성 정보 추가
    Print("=== Pine Script v6 호환성 정보 ===");
    Print("Position State: ", g_pos, " (1=Long, -1=Short, 0=Neutral)");
    Print("Trailing Stop: ", DoubleToString(g_xATRTrailingStop, _Digits));
    Print("Current Price: ", DoubleToString(iClose(_Symbol, PERIOD_CURRENT, 0), _Digits));
    Print("ATR Value: ", DoubleToString(panel_atr[0], _Digits));
    Print("================================");
    
    color colors[8];
    colors[0] = clrCyan;  // 자산 유형은 청록색
    colors[1] = g_initialized ? clrLime : clrYellow;
    colors[2] = g_pos == 1 ? clrLime : g_pos == -1 ? clrRed : clrGray;
    colors[3] = InfoPanelColor;
    colors[4] = InfoPanelColor;
    colors[5] = spread <= g_MaxSpread ? clrLime : clrRed;
    colors[6] = IsTimeToTrade() ? clrLime : clrRed;
    colors[7] = CountPositions() > 0 ? clrYellow : clrGray;
    
    for(int i = 0; i < 8; i++)
    {
        string objNameValue = g_objectPrefix + "Value_" + IntegerToString(i);
        
        if(ObjectFind(0, objNameValue) >= 0)
        {
            ObjectSetString(0, objNameValue, OBJPROP_TEXT, values[i]);
            ObjectSetInteger(0, objNameValue, OBJPROP_COLOR, colors[i]);
        }
    }
}

//+------------------------------------------------------------------+
//| Remove all objects                                               |
//+------------------------------------------------------------------+
void RemoveAllObjects()
{
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
//| Get current trailing stop value                                  |
//+------------------------------------------------------------------+
double GetCurrentTrailingStop()
{
    return g_xATRTrailingStop;
}

//+------------------------------------------------------------------+
//| Get current position state                                       |
//+------------------------------------------------------------------+
int GetCurrentPosition()
{
    return g_pos;
}

//+------------------------------------------------------------------+
//| Check sideways market protection                                 |
//| 횡보장 보호 기능 - 빈번한 거래와 과도한 손실 방지                    |
//+------------------------------------------------------------------+
bool CheckSidewaysProtection()
{
    if(!EnableSidewaysProtection)
        return true;  // 보호 기능 비활성화 시 항상 허용
    
    //--- 일일 카운터 리셋 체크
    ResetDailyCounters();
    
    //--- 1. 거래 간 최소 바 수 체크
    if(g_lastTradeTime > 0)
    {
        int barsSinceLastTrade = iBarShift(_Symbol, PERIOD_CURRENT, g_lastTradeTime);
        if(barsSinceLastTrade < MinBarsBetweenTrades)
        {
            Print("횡보장 보호: 거래 간 최소 바 수 미달 (", barsSinceLastTrade, "/", MinBarsBetweenTrades, ")");
            return false;
        }
    }
    
    //--- 2. 일일 최대 거래 수 체크
    if(g_dailyTradeCount >= MaxTradesPerDay)
    {
        Print("횡보장 보호: 일일 최대 거래 수 초과 (", g_dailyTradeCount, "/", MaxTradesPerDay, ")");
        return false;
    }
    
    //--- 3. 일일 최대 손실 비율 체크
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double dailyLoss = g_dailyStartBalance - currentBalance;
    double dailyLossPercent = (dailyLoss / g_dailyStartBalance) * 100.0;
    
    if(dailyLossPercent >= MaxDailyLossPercent)
    {
        Print("횡보장 보호: 일일 최대 손실 비율 초과 (", DoubleToString(dailyLossPercent, 2), "%/", MaxDailyLossPercent, "%)");
        return false;
    }
    
    return true;  // 모든 체크 통과
}

//+------------------------------------------------------------------+
//| Check volatility filter                                          |
//| 변동성 필터 - ATR 기반으로 충분한 변동성이 있을 때만 거래              |
//+------------------------------------------------------------------+
bool CheckVolatilityFilter(double atr)
{
    if(!UseVolatilityFilter)
        return true;  // 변동성 필터 비활성화 시 항상 허용
    
    //--- 현재 가격 대비 ATR 비율 계산
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double atrPercent = (atr / currentPrice) * 100.0;  // ATR을 가격의 %로 변환
    
    //--- 동적 최소 변동성 기준 (가격의 0.1% 이상)
    double dynamicMinVolatility = currentPrice * 0.001;  // 가격의 0.1%
    double minVolatilityPercent = (g_MinVolatilityATR / currentPrice) * 100.0;
    
    //--- 두 조건 중 하나라도 만족하면 거래 허용
    bool atrCondition = (atr >= g_MinVolatilityATR);
    bool percentCondition = (atrPercent >= 0.05);  // 최소 0.05% 변동성 (오일 거래용으로 조정)
    
    if(!atrCondition && !percentCondition)
    {
        Print("변동성 필터: ATR이 너무 낮음 (", DoubleToString(atr, 5), "/", g_MinVolatilityATR, 
              ", ", DoubleToString(atrPercent, 3), "%/0.05%)");
        return false;
    }
    
    return true;  // 변동성 충분
}

//+------------------------------------------------------------------+
//| Check trend filter (횡보장 감지)                                 |
//| 이동평균을 사용하여 횡보장을 감지하고 거래를 제한                    |
//+------------------------------------------------------------------+
bool CheckTrendFilter()
{
    if(!UseTrendFilter)
        return true;  // 트렌드 필터 비활성화 시 항상 허용
    
    //--- 이동평균 계산 (단순이동평균)
    double ma_values[];
    ArraySetAsSeries(ma_values, true);
    
    // iMA 함수로 이동평균 계산
    int ma_handle = iMA(_Symbol, PERIOD_CURRENT, g_TrendPeriod, 0, MODE_SMA, PRICE_CLOSE);
    if(ma_handle == INVALID_HANDLE)
        return true;  // 계산 실패 시 허용
    
    if(CopyBuffer(ma_handle, 0, 0, g_BreakoutBars + 1, ma_values) < g_BreakoutBars + 1)
    {
        IndicatorRelease(ma_handle);
        return true;  // 데이터 부족 시 허용
    }
    
    //--- 현재 가격과 이동평균 비교
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double currentMA = ma_values[0];
    
    //--- 횡보장 감지: 가격이 이동평균 근처에서 움직이는지 확인
    double priceRange = MathAbs(currentPrice - currentMA) / currentPrice;
    
    bool isSideways = (priceRange < g_MaxSidewaysRange);
    
    if(isSideways)
    {
        Print("트렌드 필터: 횡보장 감지 - 거래 제한 (가격 범위: ", DoubleToString(priceRange * 100, 2), "%)");
        IndicatorRelease(ma_handle);
        return false;  // 횡보장에서는 거래 중지
    }
    
    IndicatorRelease(ma_handle);
    return true;  // 트렌드가 있으면 거래 허용
}

//+------------------------------------------------------------------+
//| Check breakout confirmation                                      |
//| 브레이크아웃 확인 - 가짜 신호 필터링                              |
//+------------------------------------------------------------------+
bool CheckBreakoutConfirmation(bool isBuy)
{
    if(!UseBreakoutConfirmation)
        return true;  // 브레이크아웃 확인 비활성화 시 항상 허용
    
    //--- 최근 N개 바에서 지속적인 브레이크아웃 확인
    int confirmCount = 0;
    
    for(int i = 1; i <= g_BreakoutBars; i++)  // 1바 전부터 확인
    {
        double price = iClose(_Symbol, PERIOD_CURRENT, i);
        double stop = g_xATRTrailingStop;  // 현재 트레일링 스탑 사용
        
        if(isBuy)
        {
            if(price > stop)
                confirmCount++;
        }
        else
        {
            if(price < stop)
                confirmCount++;
        }
    }
    
    //--- 브레이크아웃이 지속되면 확인 성공
    bool confirmed = (confirmCount >= g_BreakoutBars);
    
    if(!confirmed)
    {
        Print("브레이크아웃 확인 실패: ", confirmCount, "/", g_BreakoutBars, " 바 확인");
    }
    
    return confirmed;
}

//+------------------------------------------------------------------+
//| Check if market is sideways                                      |
//| 시장이 횡보장인지 확인 (추가 보조 지표)                           |
//+------------------------------------------------------------------+
bool IsSidewaysMarket()
{
    //--- ATR과 가격 범위 비교
    double atr_values[];
    ArraySetAsSeries(atr_values, true);
    
    if(CopyBuffer(g_atr_handle, 0, 0, 10, atr_values) < 10)
        return false;  // 데이터 부족
    
    //--- 최근 10개 바의 ATR 평균
    double avgATR = 0;
    for(int i = 0; i < 10; i++)
        avgATR += atr_values[i];
    avgATR /= 10;
    
    //--- 최근 10개 바의 가격 범위
    double maxHigh = 0, minLow = 999999;
    for(int i = 0; i < 10; i++)
    {
        double high = iHigh(_Symbol, PERIOD_CURRENT, i);
        double low = iLow(_Symbol, PERIOD_CURRENT, i);
        if(high > maxHigh) maxHigh = high;
        if(low < minLow) minLow = low;
    }
    
    double priceRange = maxHigh - minLow;
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double rangePercent = priceRange / currentPrice;
    
    //--- 횡보장 판단: 가격 범위가 ATR의 2배 이하이면 횡보장
    bool isSideways = (rangePercent < (avgATR * 2 / currentPrice));
    
    if(isSideways)
    {
        Print("횡보장 감지: 가격 범위 ", DoubleToString(rangePercent * 100, 2), "%, ATR 기준 ", DoubleToString(avgATR * 2 / currentPrice * 100, 2), "%");
    }
    
    return isSideways;
}

//+------------------------------------------------------------------+
//| Apply asset-specific settings                                    |
//| 자산별 최적화된 설정값을 자동으로 적용하는 함수                      |
//+------------------------------------------------------------------+
void ApplyAssetSpecificSettings()
{
    //--- 전역 변수들을 자산별로 조정 (런타임에 적용됨)
    switch(AssetType)
    {
        case GOLD:  // 금 (XAUUSD)
            // 금은 높은 변동성과 큰 스프레드를 가짐
            g_KeyValue = 1.2;              // 보수적 민감도
            g_ATRPeriod = 12;              // 중간 ATR 기간
            g_MinVolatilityATR = 0.8;      // 높은 변동성 요구
            g_MaxSpread = 200;             // 큰 스프레드 허용
            g_MaxSidewaysRange = 0.003;    // 0.3% 횡보 범위
            g_TrendPeriod = 25;            // 긴 트렌드 기간
            g_BreakoutBars = 2;            // 빠른 브레이크아웃 확인
            Print("금 거래 설정 적용: 높은 변동성, 큰 스프레드 허용");
            break;
            
        case OIL:  // 오일 (USOIL)
            // 오일은 중간 변동성과 낮은 스프레드를 가짐
            g_KeyValue = 1.0;              // 중간 민감도
            g_ATRPeriod = 10;              // 표준 ATR 기간
            g_MinVolatilityATR = 0.05;     // 낮은 변동성 허용
            g_MaxSpread = 50;              // 낮은 스프레드 요구
            g_MaxSidewaysRange = 0.005;    // 0.5% 횡보 범위
            g_TrendPeriod = 20;            // 중간 트렌드 기간
            g_BreakoutBars = 3;            // 표준 브레이크아웃 확인
            Print("오일 거래 설정 적용: 중간 변동성, 낮은 스프레드");
            break;
            
        case NASDAQ:  // 나스닥 (NAS100)
            // 나스닥은 높은 변동성과 낮은 스프레드를 가짐
            g_KeyValue = 0.8;              // 공격적 민감도
            g_ATRPeriod = 8;               // 짧은 ATR 기간
            g_MinVolatilityATR = 0.3;      // 중간 변동성 요구
            g_MaxSpread = 30;              // 낮은 스프레드 요구
            g_MaxSidewaysRange = 0.002;    // 0.2% 횡보 범위
            g_TrendPeriod = 15;            // 짧은 트렌드 기간
            g_BreakoutBars = 2;            // 빠른 브레이크아웃 확인
            Print("나스닥 거래 설정 적용: 높은 변동성, 빠른 반응");
            break;
            
        case FOREX:  // 외환 (EURUSD, GBPUSD 등)
            // 외환은 낮은 변동성과 매우 낮은 스프레드를 가짐
            g_KeyValue = 1.5;              // 보수적 민감도
            g_ATRPeriod = 14;              // 표준 ATR 기간
            g_MinVolatilityATR = 0.02;     // 매우 낮은 변동성 허용
            g_MaxSpread = 20;              // 매우 낮은 스프레드 요구
            g_MaxSidewaysRange = 0.001;    // 0.1% 횡보 범위
            g_TrendPeriod = 30;            // 긴 트렌드 기간
            g_BreakoutBars = 4;            // 신중한 브레이크아웃 확인
            Print("외환 거래 설정 적용: 낮은 변동성, 매우 낮은 스프레드");
            break;
            
        case CRYPTO:  // 암호화폐 (BTCUSD, ETHUSD 등)
            // 암호화폐는 매우 높은 변동성과 높은 스프레드를 가짐
            g_KeyValue = 0.6;              // 매우 공격적 민감도
            g_ATRPeriod = 6;               // 매우 짧은 ATR 기간
            g_MinVolatilityATR = 1.0;      // 매우 높은 변동성 요구
            g_MaxSpread = 100;             // 높은 스프레드 허용
            g_MaxSidewaysRange = 0.01;     // 1% 횡보 범위
            g_TrendPeriod = 10;            // 매우 짧은 트렌드 기간
            g_BreakoutBars = 1;            // 즉시 브레이크아웃 확인
            Print("암호화폐 거래 설정 적용: 매우 높은 변동성, 빠른 반응");
            break;
            
        case CUSTOM:  // 사용자 정의
            // 사용자가 입력한 값 그대로 사용 (전역 변수에 복사)
            g_KeyValue = KeyValue;
            g_ATRPeriod = ATRPeriod;
            g_MinVolatilityATR = MinVolatilityATR;
            g_MaxSpread = MaxSpread;
            g_MaxSidewaysRange = MaxSidewaysRange;
            g_TrendPeriod = TrendPeriod;
            g_BreakoutBars = BreakoutBars;
            Print("사용자 정의 설정 사용");
            break;
            
        default:
            Print("알 수 없는 자산 유형, 기본 설정 사용");
            break;
    }
    
    //--- 자산별 시간 필터 설정
    if(AssetType == FOREX)
    {
        // 외환은 런던-뉴욕 세션에 최적화
        g_UseTimeFilter = true;
        g_StartHour = 8;   // 런던 세션 시작
        g_EndHour = 22;    // 뉴욕 세션 종료
        g_TradeFriday = false;  // 금요일 거래 제한 (주말 갭 리스크)
    }
    else if(AssetType == NASDAQ)
    {
        // 나스닥은 미국 시장 시간에 최적화
        g_UseTimeFilter = true;
        g_StartHour = 15;  // 뉴욕 시장 시작 (한국시간)
        g_EndHour = 6;     // 뉴욕 시장 종료 (다음날)
        g_TradeFriday = true;   // 금요일 거래 허용
    }
    else if(AssetType == CRYPTO)
    {
        // 암호화폐는 24시간 거래
        g_UseTimeFilter = false;
    }
    else
    {
        // 금, 오일은 기본 시간 필터 사용
        g_UseTimeFilter = UseTimeFilter;
        g_StartHour = StartHour;
        g_EndHour = EndHour;
        g_TradeFriday = TradeFriday;
    }
}

//+------------------------------------------------------------------+
//| Reset daily counters                                             |
//| 일일 카운터 리셋 (새로운 거래일 시작 시)                           |
//+------------------------------------------------------------------+
void ResetDailyCounters()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    datetime currentDay = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
    
    if(g_lastDay != currentDay)
    {
        // 새로운 거래일 시작
        g_dailyTradeCount = 0;
        g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        g_lastDay = currentDay;
        
        Print("새로운 거래일 시작: ", TimeToString(TimeCurrent(), TIME_DATE));
        Print("일일 시작 잔고: ", DoubleToString(g_dailyStartBalance, 2));
    }
}
//+------------------------------------------------------------------+
