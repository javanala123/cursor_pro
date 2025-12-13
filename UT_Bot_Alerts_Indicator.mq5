//+------------------------------------------------------------------+
//|                                      UT_Bot_Alerts_Indicator.mq5 |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "UT Bot Alerts - Custom Indicator for MQL5"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   3

//--- Plot settings
#property indicator_label1  "Trailing Stop"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_style1  STYLE_DASH
#property indicator_width1  2

#property indicator_label2  "Buy Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrLime
#property indicator_width2  3

#property indicator_label3  "Sell Signal"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrRed
#property indicator_width3  3

//--- Input parameters
input double KeyValue = 1.0;           // Key Value (sensitivity)
input int ATRPeriod = 10;              // ATR Period
input bool UseHeikinAshi = false;      // Use Heikin Ashi Candles
input int MaxBarsOnLoad = 3000;        // 최초 부하 시 계산할 최대 바 수(가시성 향상용)
//--- CSV export
input bool ExportSignals = false;               // Export BUY/SELL signals to CSV
input string ExportFile = "signals_indi.csv";  // CSV filename (Common Files)
//--- 상태 CSV 내보내기(바-클로즈 기준 상태 기록)
input bool ExportState = false;                 // Export state timeline to CSV
input string ExportStateFile = "signals_indi_state.csv"; // State CSV filename

//--- Indicator buffers
double TrailingStopBuffer[];
double BuySignalBuffer[];
double SellSignalBuffer[];
double ATRBuffer[];
double PosBuffer[];

//--- Global variables
int atr_handle;
int g_csvInitialized = 0;  // 0:not ready, 1:header written
int g_exportDone = 0;      // prevent duplicate full export on recalculation
int g_stateCsvInitialized = 0; // 상태 CSV 헤더 초기화 상태

//--- Ensure CSV header
void EnsureCsvHeader(bool truncate=false)
{
    if(!ExportSignals) return;
    int mode = FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_SHARE_WRITE;
    if(truncate) mode |= FILE_TXT;
    // 한글 주석: Common 경로 우선, 실패 시 로컬 MQL5\\Files로 폴백
    string commonPath = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + ExportFile;
    string localPath  = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\" + ExportFile;
    PrintFormat("[INDI] CSV Common 경로 시도: %s", commonPath);
    int h = FileOpen(ExportFile, mode);
    if(h==INVALID_HANDLE)
    {
        int err = GetLastError();
        PrintFormat("[INDI] Common 열기 실패(%d). 로컬 폴백: %s", err, localPath);
        h = FileOpen(ExportFile, FILE_READ|FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE|((truncate)?FILE_TXT:0));
        if(h==INVALID_HANDLE)
        {
            Print("[INDI] CSV open failed: ", GetLastError());
            return;
        }
    }
    if(FileSize(h)==0)
    {
        FileWrite(h, "time","symbol","tf","signal","price","atr_stop","atr","KeyValue","ATRPeriod","UseHeikinAshi");
    }
    FileClose(h);
    g_csvInitialized = 1;
}

//--- Ensure State CSV header
void EnsureStateCsvHeader(bool truncate=false)
{
    if(!ExportState) return;
    int mode = FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_SHARE_WRITE;
    if(truncate) mode |= FILE_TXT;
    // 한글 주석: Common 우선, 실패 시 로컬로 폴백
    string commonPath = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + ExportStateFile;
    string localPath  = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\" + ExportStateFile;
    PrintFormat("[INDI] STATE CSV Common 경로 시도: %s", commonPath);
    int h = FileOpen(ExportStateFile, mode);
    if(h==INVALID_HANDLE)
    {
        int err = GetLastError();
        PrintFormat("[INDI] STATE Common 열기 실패(%d). 로컬 폴백: %s", err, localPath);
        h = FileOpen(ExportStateFile, FILE_READ|FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE|((truncate)?FILE_TXT:0));
        if(h==INVALID_HANDLE)
        {
            Print("[INDI] STATE CSV open failed: ", GetLastError());
            return;
        }
    }
    if(FileSize(h)==0)
    {
        FileWrite(h, "time","symbol","tf","state","KeyValue","ATRPeriod","UseHeikinAshi");
    }
    FileClose(h);
    g_stateCsvInitialized = 1;
}

//--- Append one signal row
void AppendSignalCsv(datetime t, string sig, double price, double stop, double atr)
{
    if(!ExportSignals) return;
    if(!g_csvInitialized) EnsureCsvHeader(false);
    // 한글 주석: Common 우선, 실패 시 로컬로 폴백
    int h = FileOpen(ExportFile, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_SHARE_WRITE);
    if(h==INVALID_HANDLE)
    {
        int err = GetLastError();
        PrintFormat("[INDI] Append Common 실패(%d). 로컬 폴백", err);
        h = FileOpen(ExportFile, FILE_READ|FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE);
        if(h==INVALID_HANDLE) { Print("[INDI] CSV append open failed: ", GetLastError()); return; }
    }
    FileSeek(h, 0, SEEK_END);
    string tf = IntegerToString(Period());
    FileWrite(h, (long)t, _Symbol, tf, sig, DoubleToString(price, _Digits), DoubleToString(stop, _Digits), DoubleToString(atr, _Digits), DoubleToString(KeyValue, 2), ATRPeriod, (int)UseHeikinAshi);
    FileClose(h);
}

//--- Append one state row
void AppendStateCsv(datetime t, string state)
{
    if(!ExportState) return;
    if(!g_stateCsvInitialized) EnsureStateCsvHeader(false);
    // 한글 주석: Common 우선, 실패 시 로컬로 폴백
    int h = FileOpen(ExportStateFile, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_SHARE_WRITE);
    if(h==INVALID_HANDLE)
    {
        int err = GetLastError();
        PrintFormat("[INDI] STATE Append Common 실패(%d). 로컬 폴백", err);
        h = FileOpen(ExportStateFile, FILE_READ|FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE);
        if(h==INVALID_HANDLE) { Print("[INDI] STATE CSV append open failed: ", GetLastError()); return; }
    }
    FileSeek(h, 0, SEEK_END);
    string tf = IntegerToString(Period());
    FileWrite(h, (long)t, _Symbol, tf, state, DoubleToString(KeyValue, 2), ATRPeriod, (int)UseHeikinAshi);
    FileClose(h);
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Indicator buffers mapping
    SetIndexBuffer(0, TrailingStopBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, BuySignalBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, SellSignalBuffer, INDICATOR_DATA);
    SetIndexBuffer(3, ATRBuffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(4, PosBuffer, INDICATOR_CALCULATIONS);
    
    //--- Set arrow codes for signals
    PlotIndexSetInteger(1, PLOT_ARROW, 233);  // Up arrow for buy
    PlotIndexSetInteger(2, PLOT_ARROW, 234);  // Down arrow for sell
    
    //--- Set empty values (그리지 않도록 EMPTY_VALUE 사용)
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    
    //--- Set indicator name
    IndicatorSetString(INDICATOR_SHORTNAME, "UT Bot Alerts");
    IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
    
    //--- Create ATR indicator handle
    atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
    
    if(atr_handle == INVALID_HANDLE)
    {
        Print("Failed to create ATR indicator handle. Error: ", GetLastError());
        return(INIT_FAILED);
    }
    
    Print("UT Bot Alerts Indicator initialized successfully");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Release indicator handle
    if(atr_handle != INVALID_HANDLE)
        IndicatorRelease(atr_handle);
    
    Print("UT Bot Alerts Indicator deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    //--- Check for minimum bars
    if(rates_total < ATRPeriod + 1)
        return(0);
    
    //--- Get ATR values
    if(CopyBuffer(atr_handle, 0, 0, rates_total, ATRBuffer) < 0)
    {
        Print("Failed to copy ATR buffer. Error: ", GetLastError());
        return(0);
    }
    
    //--- Set array as series
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(time, true);
    ArraySetAsSeries(TrailingStopBuffer, true);
    ArraySetAsSeries(BuySignalBuffer, true);
    ArraySetAsSeries(SellSignalBuffer, true);
    ArraySetAsSeries(ATRBuffer, true);
    ArraySetAsSeries(PosBuffer, true);
    
    //--- Calculate starting position (최초 부하 시 계산 구간 축소로 초기 표시 지연 완화)
    int start_pos;
    if(prev_calculated > 0)
        start_pos = prev_calculated - 1;
    else
        start_pos = MathMax(ATRPeriod, rates_total - MaxBarsOnLoad);
    bool do_full_export = ((ExportSignals || ExportState) && prev_calculated==0 && g_exportDone==0);
    if(do_full_export)
    {
        if(ExportSignals) EnsureCsvHeader(true);
        if(ExportState)  EnsureStateCsvHeader(true);
    }
    
    //--- Main calculation loop
    for(int i = start_pos; i < rates_total && !IsStopped(); i++)
    {
        int pos = rates_total - 1 - i;
        
        //--- Calculate source price
        double src = UseHeikinAshi ? CalculateHeikinAshiClose(pos, open, high, low, close) : close[pos];
        
        //--- Calculate nLoss
        double nLoss = KeyValue * ATRBuffer[pos];
        
        //--- Calculate ATR Trailing Stop
        if(pos == 0 || TrailingStopBuffer[pos + 1] == 0.0)
        {
            // First calculation
            TrailingStopBuffer[pos] = src - nLoss;
        }
        else
        {
            double prevStop = TrailingStopBuffer[pos + 1];
            double prevSrc = UseHeikinAshi ? CalculateHeikinAshiClose(pos + 1, open, high, low, close) : close[pos + 1];
            
            if(src > prevStop && prevSrc > prevStop)
            {
                TrailingStopBuffer[pos] = MathMax(prevStop, src - nLoss);
            }
            else if(src < prevStop && prevSrc < prevStop)
            {
                TrailingStopBuffer[pos] = MathMin(prevStop, src + nLoss);
            }
            else if(src > prevStop)
            {
                TrailingStopBuffer[pos] = src - nLoss;
            }
            else
            {
                TrailingStopBuffer[pos] = src + nLoss;
            }
        }
        
        //--- Calculate position state
        if(pos == 0)
        {
            PosBuffer[pos] = 0;
        }
        else
        {
            double prevStop = TrailingStopBuffer[pos + 1];
            double prevSrc = UseHeikinAshi ? CalculateHeikinAshiClose(pos + 1, open, high, low, close) : close[pos + 1];
            
            if(prevSrc < prevStop && src > TrailingStopBuffer[pos])
            {
                PosBuffer[pos] = 1;  // Long
            }
            else if(prevSrc > prevStop && src < TrailingStopBuffer[pos])
            {
                PosBuffer[pos] = -1; // Short
            }
            else
            {
                PosBuffer[pos] = PosBuffer[pos + 1];
            }
        }
        
        //--- Calculate signals
        BuySignalBuffer[pos] = 0.0;
        SellSignalBuffer[pos] = 0.0;
        
        if(pos > 0)
        {
            double ema = src; // EMA(1) is just src
            double prevSrc = UseHeikinAshi ? CalculateHeikinAshiClose(pos + 1, open, high, low, close) : close[pos + 1];
            double prevStop = TrailingStopBuffer[pos + 1];
            
            bool above = (ema > TrailingStopBuffer[pos]) && (prevSrc <= prevStop);
            bool below = (ema < TrailingStopBuffer[pos]) && (prevSrc >= prevStop);
            
            bool buy = (src > TrailingStopBuffer[pos]) && above;
            bool sell = (src < TrailingStopBuffer[pos]) && below;
            
            if(buy)
            {
                BuySignalBuffer[pos] = low[pos] - (ATRBuffer[pos] * 0.5);
                if(do_full_export && ExportSignals)
                    AppendSignalCsv(time[pos], "BUY", src, TrailingStopBuffer[pos], ATRBuffer[pos]);
            }
            
            if(sell)
            {
                SellSignalBuffer[pos] = high[pos] + (ATRBuffer[pos] * 0.5);
                if(do_full_export && ExportSignals)
                    AppendSignalCsv(time[pos], "SELL", src, TrailingStopBuffer[pos], ATRBuffer[pos]);
            }
        }
    }
    // 한글 주석: 상태 타임라인 전체 내보내기(도입 시 1회 전체 기록)
    if(do_full_export && ExportState)
    {
        for(int i = start_pos; i < rates_total && !IsStopped(); i++)
        {
            int pos = rates_total - 1 - i;
            string st = (PosBuffer[pos] > 0.5) ? "BUY" : ((PosBuffer[pos] < -0.5) ? "SELL" : "FLAT");
            AppendStateCsv(time[pos], st);
        }
    }
    if(do_full_export) g_exportDone = 1;
    
    //--- Return value for next call
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate Heikin Ashi Close price                               |
//+------------------------------------------------------------------+
double CalculateHeikinAshiClose(int pos, const double &open[], const double &high[], 
                                const double &low[], const double &close[])
{
    double haClose = (close[pos] + high[pos] + low[pos] + open[pos]) / 4.0;
    return haClose;
}
//+------------------------------------------------------------------+
