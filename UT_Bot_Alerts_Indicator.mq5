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

//--- Indicator buffers
double TrailingStopBuffer[];
double BuySignalBuffer[];
double SellSignalBuffer[];
double ATRBuffer[];
double PosBuffer[];

//--- Global variables
int atr_handle;

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
    
    //--- Set empty values
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
    PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);
    
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
    
    //--- Calculate starting position
    int start_pos = prev_calculated > 0 ? prev_calculated - 1 : ATRPeriod;
    
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
            }
            
            if(sell)
            {
                SellSignalBuffer[pos] = high[pos] + (ATRBuffer[pos] * 0.5);
            }
        }
    }
    
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
