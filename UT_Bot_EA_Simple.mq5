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
//--- 자동매매 및 리스크 필터
input bool AutoTrade = true;               // 자동매매 실행 여부
input bool UseHeikinAshi = false;          // Heikin Ashi 종가 기반 계산 사용
input bool UseTimeFilter = false;          // 시간 필터 사용 여부
input int  StartHour = 9;                  // 매매 시작 시간 (0~23)
input int  EndHour   = 17;                 // 매매 종료 시간 (0~23)
input double MaxSpreadPoints = 0.0;        // 허용 최대 스프레드(포인트, 0이면 비활성)
input double MinBarRangePoints = 0.0;      // 최소 봉 범위(포인트) 필터 (0=비활성)
//--- 고급 필터
input bool UseATRFilter = false;           // ATR(포인트) 하한 필터 사용
input double MinATRPoints = 0.0;           // 최소 ATR(포인트)
input double MaxATRPoints = 0.0;           // 최대 ATR(포인트, 0=비활성)
input int CooldownBars = 0;                // 최근 진입 후 대기할 봉 수
input bool UseHTFTrend = false;            // 상위 TF 추세 필터 사용
input ENUM_TIMEFRAMES HTF_Timeframe = PERIOD_H1; // 상위 TF
input int HTF_MA_Period = 50;              // 상위 TF EMA 기간
input int DailyMaxTrades = 0;              // 일일 최대 진입 횟수(0=제한없음)
input int MaxConsecutiveLosses = 0;        // 최대 연속 손실 허용(0=제한없음)
input bool UseDailyLossLimit = false;      // 일일 손실 한도 사용
input double DailyLossLimitUSD = 0.0;      // 일일 손실 한도 (USD, 0=비활성)
//--- 신호 CSV 내보내기
input bool ExportSignals = false;          // 신호를 CSV로 내보내기
input string ExportFile = "signals_ea.csv"; // CSV 파일명 (공용 폴더)
//--- 상태 CSV 추가 내보내기(각 M5 바 종료 시점의 상태 로그)
input bool ExportState = false;             // 상태를 CSV로 내보내기(BUY/SELL/FLAT)
input string ExportStateFile = "signals_ea_state.csv"; // 상태 CSV 파일명 (공용 폴더)
//--- 고승률 지향 추가 필터(기울기/횡보/급등락 차단)
input bool UseMASlopeFilter = false;        // 이동평균 기울기 필터 사용
input int MASlopeLookback = 10;             // 기울기 확인용 룩백 봉 수
input double MinMASlopePoints = 0.0;        // 최소 기울기(포인트/봉) 요구치 (0=비활성)

input bool UseSidewaysBlock = false;        // 횡보기간 차단 사용
input int SidewaysBars = 20;                // 최근 N봉 범위 평가
input double SidewaysRangeATRMin = 1.0;     // (최근N봉 고저폭 / 현재 ATR 포인트) 최소 비율

input bool UseSpikeBlock = false;           // 급등락(스파이크) 차단 사용
input double SpikeATRMult = 2.0;            // 현재봉 범위 > ATR*이 값이면 스파이크로 간주
input int SpikeBlockBars = 5;               // 스파이크 발생 후 차단할 봉 수
//--- 주문 및 리스크 설정
input bool TradeLong = true;               // 매수 허용
input bool TradeShort = true;              // 매도 허용
input bool UseRiskPerTrade = false;        // 리스크 퍼센트 기반 로트 계산 사용
input double RiskPercent = 1.0;            // 1회 진입 계정 대비 리스크 %
input double InitialStopATR = 1.5;         // 초기 손절 거리(ATR 배수)
input double TakeProfitATR = 2.0;          // 초기 익절 거리(ATR 배수)

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

//--- 동적 손절/추적 기능
input bool UseBreakeven = true;            // BE 활성: 일정 이익 도달 시 손절가 진입가로 이동
input double BreakevenRR = 1.0;            // BE 트리거: 초기 SL의 1R 배 도달 시
input bool UseATRTrailing = true;          // ATR 추적 손절 사용
input double ATRTrailMult = 1.0;           // ATR 추적 손절 배수

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
//--- 고급 필터/상태 변수
int htf_ma_handle = INVALID_HANDLE;   // 상위TF EMA 핸들
datetime lastTradeBarTime = 0;        // 마지막 진입 바 시간
int tradesToday = 0;                  // 일일 진입 횟수
int lastYMD = 0;                      // 일자 변경 감지용(YYYYMMDD)
int consecutiveLosses = 0;            // 연속 손실 카운트
// CSV 내보내기 내부 상태
int g_csvInitialized = 0;             // 0:미초기화, 1:헤더작성완료
int g_stateCsvInitialized = 0;         // 상태 CSV 헤더 초기화 상태

// 신호 CSV 헤더 보장 함수
void EnsureCsvHeader()
{
    if(!ExportSignals || g_csvInitialized==1) return;
    // 한글 주석: 실제 저장 경로를 로그로 알려주고, Common 경로 열기 실패 시 로컬 MQL5\Files로 폴백
    string commonPath = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + ExportFile;
    string localPath  = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\" + ExportFile;
    PrintFormat("[CSV] Common 경로 시도: %s", commonPath);
    int h = FileOpen(ExportFile, FILE_WRITE|FILE_READ|FILE_CSV|FILE_COMMON|FILE_SHARE_WRITE);
    if(h==INVALID_HANDLE)
    {
        int err = GetLastError();
        PrintFormat("[CSV] Common 열기 실패(%d). 로컬로 폴백: %s", err, localPath);
        h = FileOpen(ExportFile, FILE_WRITE|FILE_READ|FILE_CSV|FILE_SHARE_WRITE);
    }
    if(h==INVALID_HANDLE)
    {
        PrintFormat("[CSV] CSV 파일 열기 실패 - 마지막 오류: %d", GetLastError());
        return;
    }
    // 파일 크기가 0이면 헤더 작성
    if(FileSize(h)==0)
    {
        // 한글 주석: 비교에 필요한 핵심 지표를 모두 기록
        FileWrite(h, "time","symbol","tf","signal","price","atr_stop","atr","ma","KeyValue","ATRPeriod","MAPeriod");
    }
    FileClose(h);
    g_csvInitialized = 1;
}

// 상태 CSV 헤더 보장 함수
void EnsureStateCsvHeader()
{
    if(!ExportState || g_stateCsvInitialized==1) return;
    // 한글 주석: 상태 CSV도 Common 우선 저장, 실패 시 로컬 폴백
    string commonPath = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + ExportStateFile;
    string localPath  = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\" + ExportStateFile;
    PrintFormat("[CSV-STATE] Common 경로 시도: %s", commonPath);
    int h = FileOpen(ExportStateFile, FILE_WRITE|FILE_READ|FILE_CSV|FILE_COMMON|FILE_SHARE_WRITE);
    if(h==INVALID_HANDLE)
    {
        int err = GetLastError();
        PrintFormat("[CSV-STATE] Common 열기 실패(%d). 로컬로 폴백: %s", err, localPath);
        h = FileOpen(ExportStateFile, FILE_WRITE|FILE_READ|FILE_CSV|FILE_SHARE_WRITE);
    }
    if(h==INVALID_HANDLE)
    {
        PrintFormat("[CSV-STATE] CSV 파일 열기 실패 - 마지막 오류: %d", GetLastError());
        return;
    }
    if(FileSize(h)==0)
    {
        // 한글 주석: 상태 비교에 필요한 최소 컬럼
        FileWrite(h, "time","symbol","tf","state");
    }
    FileClose(h);
    g_stateCsvInitialized = 1;
}

// 신호 CSV에 한 줄 추가
void AppendSignalCsv(datetime t, string sig, double price, double atrStop, double atrVal, double maVal)
{
    if(!ExportSignals) return;
    if(g_csvInitialized==0) EnsureCsvHeader();
    // 한글 주석: Common 우선 저장, 실패 시 로컬로 폴백
    int h = FileOpen(ExportFile, FILE_WRITE|FILE_READ|FILE_CSV|FILE_COMMON|FILE_SHARE_WRITE);
    if(h==INVALID_HANDLE)
    {
        int err = GetLastError();
        PrintFormat("[CSV] Append용 Common 열기 실패(%d). 로컬로 폴백", err);
        h = FileOpen(ExportFile, FILE_WRITE|FILE_READ|FILE_CSV|FILE_SHARE_WRITE);
    }
    if(h==INVALID_HANDLE)
    {
        PrintFormat("[CSV] Append 실패 - 마지막 오류: %d", GetLastError());
        return;
    }
    FileSeek(h, 0, SEEK_END);
    string tf = IntegerToString((int)Period());
    FileWrite(h, (long)t, _Symbol, tf, sig, DoubleToString(price, _Digits),
                 DoubleToString(atrStop, _Digits), DoubleToString(atrVal, _Digits),
                 DoubleToString(maVal, _Digits), DoubleToString(KeyValue, 6), ATRPeriod, MAPeriod);
    FileClose(h);
}

// 상태 CSV에 한 줄 추가
void AppendStateCsv(datetime t, string state)
{
    if(!ExportState) return;
    if(g_stateCsvInitialized==0) EnsureStateCsvHeader();
    // 한글 주석: Common 우선, 실패 시 로컬
    int h = FileOpen(ExportStateFile, FILE_WRITE|FILE_READ|FILE_CSV|FILE_COMMON|FILE_SHARE_WRITE);
    if(h==INVALID_HANDLE)
    {
        int err = GetLastError();
        PrintFormat("[CSV-STATE] Append용 Common 열기 실패(%d). 로컬로 폴백", err);
        h = FileOpen(ExportStateFile, FILE_WRITE|FILE_READ|FILE_CSV|FILE_SHARE_WRITE);
    }
    if(h==INVALID_HANDLE)
    {
        PrintFormat("[CSV-STATE] Append 실패 - 마지막 오류: %d", GetLastError());
        return;
    }
    FileSeek(h, 0, SEEK_END);
    string tf = IntegerToString((int)Period());
    FileWrite(h, (long)t, _Symbol, tf, state);
    FileClose(h);
}

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
    if(UseHTFTrend)
    {
        htf_ma_handle = iMA(_Symbol, HTF_Timeframe, HTF_MA_Period, 0, MODE_EMA, PRICE_CLOSE);
        if(htf_ma_handle == INVALID_HANDLE)
        {
            Print("❌ 상위TF EMA 핸들 생성 실패");
            return INIT_FAILED;
        }
    }
    
    // 입력값 검증 (안정성 강화)
    if(ATRPeriod <= 0 || ATRPeriod > 100)
    {
        Print("❌ 입력 오류 - ATRPeriod 범위(1~100) 밖:", ATRPeriod);
            return INIT_FAILED;
        }
    if(KeyValue <= 0.0 || KeyValue > 10.0)
    {
        Print("❌ 입력 오류 - KeyValue 범위(>0 ~ 10.0) 밖:", KeyValue);
            return INIT_FAILED;
        }
    if(StartHour < 0 || StartHour > 23 || EndHour < 0 || EndHour > 23)
    {
        Print("❌ 입력 오류 - 시간 필터 시간 범위(0~23) 밖: ", StartHour, "~", EndHour);
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
    // 일자 초기화
    MqlDateTime dt; TimeToStruct(TimeCurrent(), dt); lastYMD = dt.year*10000 + dt.mon*100 + dt.day;
    
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
    bool isNewBar = (bar != lastBar);
    if(isNewBar)
    {
        // 직전 바가 막 닫힌 시점 -> 상태 기록
        if(lastBar != 0)
        {
            // 현재 내부 상태를 BUY/SELL/FLAT 문자열로 결정
            string st = "FLAT";
            if(lastSignal > 0) st = "BUY";
            else if(lastSignal < 0) st = "SELL";
            AppendStateCsv(lastBar + PeriodSeconds(PERIOD_CURRENT), st); // 바 클로즈 시간 기준 기록
        }
    lastBar = bar;
    }
    else
    {
        // 동일 바에서는 아래 로직만 수행
    }
    
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
        EnsureCsvHeader();
        CalculateAllBarsSignals();
        g_firstRun = false;
    }

    // 필터: 시간/스프레드 조건 사전 점검 (자동매매 활성 시)
    if(AutoTrade && !IsTradableNow())
    {
        // 진입은 건너뛰되, 화살표/로그는 유지
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
    
    // Pine src 선택 (Heikin Ashi 옵션 지원), EMA(1) == src
    double src_cur = UseHeikinAshi ? ((rates[0].open + rates[0].high + rates[0].low + rates[0].close)/4.0) : rates[0].close;
    double src_prev = UseHeikinAshi ? ((rates[1].open + rates[1].high + rates[1].low + rates[1].close)/4.0) : rates[1].close;
    double price = src_cur;
    double prevBarPrice = src_prev;
    
    // Pine Script 로직에 따른 ATR 스탑 계산
    double nLoss = atr[0] * KeyValue;
    double currentATRStop = 0.0;
    
    if(prevStop == 0.0) {
        // 초기값 설정 (Pine Script 초기 로직과 동일하게 src - nLoss)
        currentATRStop = price - nLoss;
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
    
    // 교차 조건 (Pine Script의 ta.crossover 동치) - EMA(1)=src
    double ema_cur = price;
    double ema_prev = prevBarPrice;
    bool above = (ema_cur > currentATRStop) && (ema_prev <= prevStop);
    bool below = (currentATRStop > ema_cur) && (prevStop <= ema_prev);
    
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
        if(AutoTrade)
        {
            if(!TradeLong || !IsTradableNow() || !PassAdvancedFilters(true))
            {
                Print("⏸ 시간/스프레드 필터로 인해 매수 주문 생략");
            }
            else
            {
                double lot = UseRiskPerTrade ? CalculateRiskBasedLot(true) : LotSize;
                PrintFormat("🚀 자동매매 매수 시도 - Symbol:%s Lot:%.2f Magic:%d", _Symbol, lot, g_magic);
                if(trade.Buy(lot, _Symbol)) {
                    PrintFormat("✅ 자동매매 매수 성공 - Symbol:%s Lot:%.2f Magic:%d", _Symbol, LotSize, g_magic);
                    lastSignal = 1;
                    lastTradeBarTime = bar;
                    tradesToday++;
                    ApplyInitialSLTP(true);
                } else {
                    PrintFormat("❌ 자동매매 매수 실패 - Symbol:%s ret:%d %s, lastError:%d", 
                               _Symbol, trade.ResultRetcode(), trade.ResultRetcodeDescription(), GetLastError());
                }
            }
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
        if(AutoTrade)
        {
            if(!TradeShort || !IsTradableNow() || !PassAdvancedFilters(false))
            {
                Print("⏸ 시간/스프레드 필터로 인해 매도 주문 생략");
            }
            else
            {
                double lot = UseRiskPerTrade ? CalculateRiskBasedLot(false) : LotSize;
                PrintFormat("🚀 자동매매 매도 시도 - Symbol:%s Lot:%.2f Magic:%d", _Symbol, lot, g_magic);
                if(trade.Sell(lot, _Symbol)) {
                    PrintFormat("✅ 자동매매 매도 성공 - Symbol:%s Lot:%.2f Magic:%d", _Symbol, LotSize, g_magic);
                    lastSignal = -1;
                    lastTradeBarTime = bar;
                    tradesToday++;
                    ApplyInitialSLTP(false);
                } else {
                    PrintFormat("❌ 자동매매 매도 실패 - Symbol:%s ret:%d %s, lastError:%d", 
                               _Symbol, trade.ResultRetcode(), trade.ResultRetcodeDescription(), GetLastError());
                }
            }
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
        // Pine src 선택 (Heikin Ashi 옵션 지원)
        double price = UseHeikinAshi
                        ? ((rates[i].open + rates[i].high + rates[i].low + rates[i].close)/4.0)
                        : rates[i].close;
        double atrValue = atr[i];
        double maValue = ma[i];
        
        // 이전 봉 데이터 (Pine Script의 [1] 인덱스)
        double prevBarPrice = (i > 0)
                              ? (UseHeikinAshi
                                  ? ((rates[i-1].open + rates[i-1].high + rates[i-1].low + rates[i-1].close)/4.0)
                                  : rates[i-1].close)
                              : price;
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
        
        // 교차 조건 (Pine Script의 ta.crossover 동치) - EMA(1) == src
        bool above = (price > currentATRStop) && (prevBarPrice <= prevATRStop);
        bool below = (currentATRStop > price) && (prevATRStop <= prevBarPrice);
        
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
            datetime t = rates[i].time; // 해당 봉의 실제 시간 사용 (인덱스 뒤집기 제거)
            string checkName = g_timeframePrefix + IntegerToString((int)t) + "_" + sig;
            if(ObjectFind(0, checkName) == -1)
            {
                if(buySignal)
                {
                    PrintFormat("🟢 BUY 신호 - Bar:%d Price:%.5f ATRStop:%.5f MA:%.5f", i, price, currentATRStop, maValue);
                    DrawArrowForBar("BUY", price, i);
                    AppendSignalCsv(rates[i].time, "BUY", price, currentATRStop, atrValue, maValue);
                }
                else
                {
                    PrintFormat("🔴 SELL 신호 - Bar:%d Price:%.5f ATRStop:%.5f MA:%.5f", i, price, currentATRStop, maValue);
                    DrawArrowForBar("SELL", price, i);
                    AppendSignalCsv(rates[i].time, "SELL", price, currentATRStop, atrValue, maValue);
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
    // 차트 시간 및 시프트 계산
    int totalBars = iBars(_Symbol, PERIOD_CURRENT);
    if(totalBars <= 0) return;
    int shift = totalBars - 1 - barIndex; // 현재봉 기준 시프트
    if(shift < 0) return;
    datetime bar_time = iTime(_Symbol, PERIOD_CURRENT, shift);
    
    // 고유한 객체 이름 생성 (시간프레임별 접두사 + 시간 + 신호)
    string name = g_timeframePrefix + IntegerToString((int)bar_time) + "_" + signal;
    
    // 화살표 위치 계산: 해당 봉의 High/Low 기준으로 명확히 위/아래에 표시
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double arrowPrice;
    int code;
    color clr;
    
    if(signal == "BUY")
    {
        double lowPrice = iLow(_Symbol, PERIOD_CURRENT, shift);
        arrowPrice = lowPrice - (ArrowDistance * point);
        code = BuyArrowCode;
        clr = BuyArrowColor;
    }
    else
    {
        double highPrice = iHigh(_Symbol, PERIOD_CURRENT, shift);
        arrowPrice = highPrice + (ArrowDistance * point);
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
                        // 연속 손실 카운트 증가
                        consecutiveLosses++;
                    }
                    else
                    {
                        PrintFormat("❌ 스탑로스 실패 - Ticket:%I64u ret:%d", ticket, trade.ResultRetcode());
                    }
                }

                // 일일 손실 한도 체크(모든 우리 포지션 합계는 외부에서 관리하는 것이 바람직하나, 단일 포지션 기준으로도 차단)
                if(UseDailyLossLimit && DailyLossLimitUSD > 0.0)
                {
                    static double dailyPnL = 0.0;
                    static int dailyYMD = 0;
                    MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
                    int ymd = dt.year*10000 + dt.mon*100 + dt.day;
                    if(ymd != dailyYMD){ dailyYMD = ymd; dailyPnL = 0.0; }

                    // 단순히 현재 포지션 손익을 누적하여 임계치 초과 시 강제 청산
                    // (정확한 실현손익 집계는 거래이력 기반 별도 구현 권장)
                    dailyPnL += pos_profit; 
                    if(dailyPnL <= -DailyLossLimitUSD)
                    {
                        PrintFormat("⛔ 일일 손실 한도 도달 - 모든 우리 포지션 청산 시도");
                        CloseOwnPositions();
                    }
                }

                // 동적 BE/ATR 추적 손절
                if(PositionSelectByTicket(ticket))
                {
                    double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                    double atr[1]; if(CopyBuffer(atr_handle, 0, 0, 1, atr) > 0)
                    {
                        double stopPts = (atr[0] / pt) * InitialStopATR;
                        double rValue = stopPts * pt; // 1R 절대 가격
                        double currentSL = PositionGetDouble(POSITION_SL);
                        double newSL = currentSL;

                        // Breakeven: 이익이 1R*BreakevenRR 도달 시 손절가를 진입가로 이동
                        if(UseBreakeven && rValue > 0)
                        {
                            if(pos_type==POSITION_TYPE_BUY && (pos_price_current - pos_price_open) >= (rValue * BreakevenRR))
                                newSL = MathMax(currentSL, pos_price_open);
                            if(pos_type==POSITION_TYPE_SELL && (pos_price_open - pos_price_current) >= (rValue * BreakevenRR))
                                newSL = MathMin(currentSL, pos_price_open);
                        }

                        // ATR 추적 손절
                        if(UseATRTrailing && ATRTrailMult > 0.0)
                        {
                            double trailPts = (atr[0] / pt) * ATRTrailMult;
                            if(pos_type==POSITION_TYPE_BUY)
                                newSL = MathMax(newSL, pos_price_current - trailPts*pt);
                            if(pos_type==POSITION_TYPE_SELL)
                                newSL = MathMin(newSL, pos_price_current + trailPts*pt);
                        }

                        // SL만 수정 (TP는 유지)
                        double tp = PositionGetDouble(POSITION_TP);
                        if(newSL>0 && newSL!=currentSL)
                            trade.PositionModify(_Symbol, newSL, tp);
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
    
    // 정확한 봉 High/Low 기준 위치 계산 (화면 겹침 방지)
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double arrowPrice;
    int code;
    color clr;
    int barIndex = iBarShift(_Symbol, PERIOD_CURRENT, current_time, true);
    if(barIndex < 0) return;
    if(signal == "BUY")
    {
        double low = iLow(_Symbol, PERIOD_CURRENT, barIndex);
        arrowPrice = low - (ArrowDistance * point);
        code = BuyArrowCode;
        clr = BuyArrowColor;
    }
    else
    {
        double high = iHigh(_Symbol, PERIOD_CURRENT, barIndex);
        arrowPrice = high + (ArrowDistance * point);
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
    
    // 키보드 이벤트 감지 (R 리셋)
    if(id == CHARTEVENT_KEYDOWN && EnableManualReset)
    {
        if(lparam == 82) // R 키
        {
            Print("⌨️ R키 감지 - 화살표 리셋 실행");
            ManualResetArrows();
        }
    }
}

//+------------------------------------------------------------------+
//| 리스크 기반 로트 계산 및 SL/TP 설정                               |
//+------------------------------------------------------------------+
double CalculateRiskBasedLot(bool isBuy)
{
    if(!UseRiskPerTrade) return LotSize;
    double bal = AccountInfoDouble(ACCOUNT_BALANCE);
    double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double atr[1]; if(CopyBuffer(atr_handle, 0, 0, 1, atr) <= 0) return LotSize;
    double stopPts = (atr[0] / pt) * InitialStopATR; // ATR 배수 기반 포인트 거리
    if(stopPts <= 0) return LotSize;
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    if(tickValue <= 0 || tickSize <= 0) return LotSize;
    double riskMoney = bal * (RiskPercent / 100.0);
    double moneyPerPointPerLot = (tickValue / (tickSize/pt));
    double lot = riskMoney / (stopPts * moneyPerPointPerLot);
    // 최소/최대 로트 한도 적용
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    lot = MathMax(minLot, MathMin(maxLot, MathFloor(lot/lotStep)*lotStep));
    return lot;
}

void ApplyInitialSLTP(bool isBuy)
{
    double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double atr[1]; if(CopyBuffer(atr_handle, 0, 0, 1, atr) <= 0) return;
    double stopPts = (atr[0] / pt) * InitialStopATR;
    double tpPts   = (atr[0] / pt) * TakeProfitATR;
    if(stopPts <= 0 || tpPts <= 0) return;
    if(!PositionSelect(_Symbol)) return;
    double open = PositionGetDouble(POSITION_PRICE_OPEN);
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double sl=0, tp=0;
    if(type==POSITION_TYPE_BUY){ sl = open - stopPts*pt; tp = open + tpPts*pt; }
    else if(type==POSITION_TYPE_SELL){ sl = open + stopPts*pt; tp = open - tpPts*pt; }
    if(sl>0 && tp>0) trade.PositionModify(_Symbol, sl, tp);
}

//+------------------------------------------------------------------+
//| 시간/스프레드 필터                                                |
//+------------------------------------------------------------------+
bool IsTradableNow()
{
    // 시간 필터
    if(UseTimeFilter)
    {
        MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
        int h = dt.hour;
        bool inRange = (StartHour <= EndHour) ? (h >= StartHour && h <= EndHour)
                                             : (h >= StartHour || h <= EndHour); // 자정 교차 케이스
        if(!inRange) return false;
    }
    // 스프레드 필터
    if(MaxSpreadPoints > 0.0)
    {
        double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double spreadPts = (SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_DISABLED)
                         ? (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / pt
                         : 0.0;
        if(spreadPts > MaxSpreadPoints) return false;
    }
    // 최소 봉 범위(고저차) 필터
    if(MinBarRangePoints > 0.0)
    {
        double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double hi = iHigh(_Symbol, PERIOD_CURRENT, 0);
        double lo = iLow(_Symbol, PERIOD_CURRENT, 0);
        if((hi - lo)/pt < MinBarRangePoints) return false;
    }
    
    // 급등락(스파이크) 차단: 현봉 고저폭 > ATR*SpikeATRMult 이면 SpikeBlockBars 동안 차단
    if(UseSpikeBlock && SpikeATRMult > 0.0)
    {
        double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double hi = iHigh(_Symbol, PERIOD_CURRENT, 0);
        double lo = iLow(_Symbol, PERIOD_CURRENT, 0);
        double rngPts = (hi - lo) / pt;
        double atr[1];
        if(CopyBuffer(atr_handle, 0, 0, 1, atr) > 0)
        {
            double atrPts = atr[0] / pt;
            if(rngPts > atrPts * SpikeATRMult)
            {
                // 최근 SpikeBlockBars 내 스파이크 있으면 차단
                for(int k=0; k<SpikeBlockBars; ++k)
                {
                    double hiK = iHigh(_Symbol, PERIOD_CURRENT, k);
                    double loK = iLow(_Symbol, PERIOD_CURRENT, k);
                    if(((hiK - loK)/pt) > atrPts * SpikeATRMult)
        return false;
    }
            }
        }
    }
    return true;
}

//+------------------------------------------------------------------+
//| 고급 필터 통과 여부                                               |
//+------------------------------------------------------------------+
bool PassAdvancedFilters(bool isBuy)
{
    // 일자 변경 시 일일 카운터 리셋
    MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
    int ymd = dt.year*10000 + dt.mon*100 + dt.day;
    if(ymd != lastYMD){ lastYMD = ymd; tradesToday = 0; consecutiveLosses = 0; }

    // 일일 최대 진입 제한
    if(DailyMaxTrades > 0 && tradesToday >= DailyMaxTrades)
        return false;

    // 연속 손실 제한
    if(MaxConsecutiveLosses > 0 && consecutiveLosses >= MaxConsecutiveLosses)
        return false;

    // 쿨다운: 마지막 진입 후 N봉 경과 필요
    if(CooldownBars > 0 && lastTradeBarTime != 0)
    {
        int barsSince = iBarShift(_Symbol, PERIOD_CURRENT, lastTradeBarTime, true);
        if(barsSince >= 0 && barsSince < CooldownBars)
            return false;
    }

    // ATR(포인트) 하한 필터
    if(UseATRFilter && (MinATRPoints > 0.0 || MaxATRPoints > 0.0))
    {
        double atr[1];
        if(CopyBuffer(atr_handle, 0, 0, 1, atr) <= 0) return false;
        double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double atrPts = atr[0] / pt;
        if(MinATRPoints > 0.0 && atrPts < MinATRPoints) return false;
        if(MaxATRPoints > 0.0 && atrPts > MaxATRPoints) return false;
    }

    // 상위TF 추세 필터(EMA 기준)
    if(UseHTFTrend && htf_ma_handle != INVALID_HANDLE)
    {
        double emaHTF[1];
        if(CopyBuffer(htf_ma_handle, 0, 0, 1, emaHTF) <= 0) return false;
        double htfClose[1];
        if(CopyClose(_Symbol, HTF_Timeframe, 0, 1, htfClose) <= 0) return false;
        bool up = htfClose[0] > emaHTF[0];
        if(isBuy && !up) return false;
        if(!isBuy && up) return false;
    }
    
    // 이동평균 기울기 필터: 최근 MASlopeLookback 봉의 MA 변화량을 포인트/봉으로 평가
    if(UseMASlopeFilter && MinMASlopePoints > 0.0 && MASlopeLookback > 0)
    {
        double maNow[1];
        if(CopyBuffer(ma_handle, 0, 0, 1, maNow) <= 0) return false;
        double maPrev[1];
        if(CopyBuffer(ma_handle, 0, MASlopeLookback, 1, maPrev) <= 0) return false;
        double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double slopePtsPerBar = (maNow[0] - maPrev[0]) / pt / MASlopeLookback;
        if(MathAbs(slopePtsPerBar) < MinMASlopePoints) return false;
        if(isBuy && slopePtsPerBar <= 0.0) return false;
        if(!isBuy && slopePtsPerBar >= 0.0) return false;
    }

    // 횡보기간 차단: 최근 SidewaysBars 고저폭 / ATR 포인트 비율이 임계 미만이면 차단
    if(UseSidewaysBlock && SidewaysBars > 1)
    {
        double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double hi = iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, SidewaysBars, 0));
        double lo = iLow(_Symbol, PERIOD_CURRENT, iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, SidewaysBars, 0));
        double atr[1];
        if(CopyBuffer(atr_handle, 0, 0, 1, atr) <= 0) return false;
        double atrPts = atr[0] / pt;
        double rangePts = (hi - lo) / pt;
        if(atrPts <= 0) return false;
        double ratio = rangePts / atrPts;
        if(ratio < SidewaysRangeATRMin) return false;
    }
    return true;
}