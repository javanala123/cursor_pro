//+------------------------------------------------------------------+
//|                                                     UT_Signal_Compare.mq5 |
//|                       EA vs Indicator 신호 CSV 자동 비교 스크립트       |
//|                       (공용 폴더 FILE_COMMON에서 CSV 읽기/쓰기)        |
//+------------------------------------------------------------------+
#property script_show_inputs

// 한글 주석: 두 가지 모드 지원
// 1) CSV 모드: 기존처럼 CSV 파일 두 개를 공용 폴더에서 읽어 비교
// 2) 라이브 모드: 같은 차트에서 EA 화살표(오브젝트) vs 인디케이터 버퍼(iCustom)를 직접 비교

// 공통 입력
input bool UseLive = true;                         // 라이브(iCustom+오브젝트) 비교 사용
input string OutFile  = "signal_compare_report.csv"; // 비교 결과 리포트 CSV(공용 폴더)
input int CompareBars = 500;                       // 최근 N개 바만 비교

// CSV 모드 전용 입력
input string EAFile   = "signals_ea.csv";         // EA가 내보낸 CSV
input string IndiFile = "signals_indi.csv";       // 인디케이터가 내보낸 CSV
input int TimeToleranceSec = 0;                    // 시간 일치 허용 오차(초), CSV 모드에만 적용

// 라이브 모드 전용 입력(인디케이터 파라미터 전달)
input string IndiName = "UT_Bot_Alerts_Indicator"; // iCustom으로 불러올 인디 이름
input double In_KeyValue = 1.0;                    // 인디 KeyValue
input int In_ATRPeriod = 10;                       // 인디 ATRPeriod
input bool In_UseHeikinAshi = false;               // 인디 HeikinAshi 사용 여부

// 데이터 구조
struct SigRow
{
    datetime t;      // 시간 (Epoch)
    string   signal; // "BUY" 또는 "SELL"
    double   price;  // 신호 발생 시점 소스가
    double   stop;   // ATR Stop
    double   atr;    // ATR 값
};
// 라이브 모드: 인디 버퍼 읽기 + EA 오브젝트 화살표 수집
void LiveCompare()
{
    int bars = MathMin(CompareBars, iBars(_Symbol, PERIOD_CURRENT));
    if(bars<=0){ Print("[LIVE] 바 수 0"); return; }
    // iCustom 핸들: 인디케이터는 3개의 플롯 (0=TrailStop, 1=Buy Arrow, 2=Sell Arrow)
    int indi = iCustom(_Symbol, PERIOD_CURRENT, IndiName, In_KeyValue, In_ATRPeriod, In_UseHeikinAshi, false, "signals_indi.csv");
    if(indi==INVALID_HANDLE){ Print("[LIVE] iCustom 핸들 생성 실패: ", GetLastError()); return; }
    double buy[], sell[];
    if(CopyBuffer(indi, 1, 0, bars, buy)<=0 || CopyBuffer(indi, 2, 0, bars, sell)<=0)
    { Print("[LIVE] 인디 버퍼 복사 실패: ", GetLastError()); IndicatorRelease(indi); return; }
    // EA 화살표 수집: 현재 차트의 오브젝트에서 our prefix 추정 불가 → 텍스트 포함 규칙으로 수집
    // 규칙: 이름에 "UTB_" 포함, "_BUY" 또는 "_SELL" 포함
    int total = ObjectsTotal(0, -1, -1);
    bool eaBuy[]; ArrayResize(eaBuy, bars); ArrayInitialize(eaBuy, false);
    bool eaSell[]; ArrayResize(eaSell, bars); ArrayInitialize(eaSell, false);
    for(int i=0;i<total;i++)
    {
        string name = ObjectName(0, i, -1, -1);
        if(ObjectGetInteger(0, name, OBJPROP_TYPE)!=OBJ_ARROW) continue;
        bool hasUT = (StringFind(name, "UTB_", 0) == 0);
        bool isBuy = (StringFind(name, "_BUY", 0) > 0);
        bool isSell= (StringFind(name, "_SELL",0) > 0);
        if(!hasUT || (!isBuy && !isSell)) continue;
        datetime t = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
        int shift = iBarShift(_Symbol, PERIOD_CURRENT, t, true);
        if(shift>=0 && shift<bars)
        {
            int idx = shift; // 인디 버퍼와 동일한 인덱스 체계 사용
            if(isBuy)  eaBuy[idx]  = true;
            if(isSell) eaSell[idx] = true;
        }
    }
    // 비교: 같은 바에서 인디 Buy/Sell 화살표가 비어있지 않으면 신호로 간주
    int match=0, diff=0, onlyEA=0, onlyIndi=0;
    int out = FileOpen(OutFile, FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_SHARE_WRITE);
    if(out==INVALID_HANDLE){ Print("[LIVE] 결과 파일 열기 실패"); IndicatorRelease(indi); return; }
    FileWrite(out, "time","ea_signal","indi_signal","match");
    for(int k=0;k<bars;k++)
    {
        datetime t = iTime(_Symbol, PERIOD_CURRENT, k);
        string iSig = (buy[k]!=EMPTY_VALUE && buy[k]!=0.0) ? "BUY" : ((sell[k]!=EMPTY_VALUE && sell[k]!=0.0)?"SELL":"");
        string eSig = eaBuy[k]?"BUY":(eaSell[k]?"SELL":"");
        int isMatch = (iSig==eSig && iSig!="") ? 1 : 0;
        if(iSig=="" && eSig!="") onlyEA++;
        else if(iSig!="" && eSig=="") onlyIndi++;
        else if(iSig!="" && eSig!="" && !isMatch) diff++;
        if(isMatch) match++;
        if(iSig!="" || eSig!="")
            FileWrite(out, (long)t, eSig, iSig, isMatch);
    }
    FileClose(out);
    int considered = match+diff+onlyEA+onlyIndi;
    double rate = considered? (100.0*match/(double)considered) : 0.0;
    PrintFormat("[LIVE] 완료: bars=%d, match=%d, diff=%d, onlyEA=%d, onlyIndi=%d, matchRate=%.2f%%, report=%s",
               bars, match, diff, onlyEA, onlyIndi, rate, OutFile);
    IndicatorRelease(indi);
}

// 동적 배열
SigRow eaRows[];
SigRow indiRows[];

// 유틸: 한 줄 읽기 (CSV: time,symbol,tf,signal,price,atr_stop,atr,KeyValue,ATRPeriod,UseHeikinAshi)
bool ReadOneCsvRow(const int h, SigRow &row)
{
    if(FileIsEnding(h)) return false;
    // 필드 순서대로 읽기
    string f_time   = FileReadString(h); if(FileIsEnding(h)) return false;
    string f_symbol = FileReadString(h); if(FileIsEnding(h)) return false;
    string f_tf     = FileReadString(h); if(FileIsEnding(h)) return false;
    string f_signal = FileReadString(h); if(FileIsEnding(h)) return false;
    string f_price  = FileReadString(h); if(FileIsEnding(h)) return false;
    string f_stop   = FileReadString(h); if(FileIsEnding(h)) return false;
    string f_atr    = FileReadString(h); if(FileIsEnding(h)) return false;
    // 나머지 컬럼(KeyValue, ATRPeriod, UseHeikinAshi)은 비교 핵심이 아니므로 읽어서 버림
    string f_k      = FileReadString(h); if(FileIsEnding(h)) return false;
    string f_ap     = FileReadString(h); if(FileIsEnding(h)) return false;
    string f_ha     = FileReadString(h); // 마지막 필드는 다음 줄로 넘어감

    // 헤더 행 건너뛰기
    if(StringToLower(f_time)=="time") return false;

    row.t      = (datetime)StringToInteger(f_time);
    row.signal = f_signal;
    row.price  = StringToDouble(f_price);
    row.stop   = StringToDouble(f_stop);
    row.atr    = StringToDouble(f_atr);
    return true;
}

// CSV 로드 함수
bool LoadCsv(const string filename, SigRow &rows[])
{
    ArrayResize(rows, 0);
    int h = FileOpen(filename, FILE_READ|FILE_CSV|FILE_COMMON|FILE_SHARE_READ);
    if(h==INVALID_HANDLE)
    {
        PrintFormat("[COMPARE] CSV 열기 실패: %s (err=%d)", filename, GetLastError());
        return false;
    }
    // 첫 줄 헤더는 ReadOneCsvRow 내부에서 무시 처리
    // 전체 반복
    while(!FileIsEnding(h))
    {
        SigRow r;
        int pos_before = FileTell(h);
        if(!ReadOneCsvRow(h, r))
        {
            // 헤더 혹은 비정상 줄이면 다음 라인으로 이동
            // CSV 모드에서는 한 줄 경계 자동 처리됨
            continue;
        }
        int n = ArraySize(rows);
        ArrayResize(rows, n+1);
        rows[n] = r;
    }
    FileClose(h);
    // 시간 오름차순 정렬
    int total = ArraySize(rows);
    if(total>1)
    {
        // 단순 삽입정렬 (데이터 크기 작음 가정)
        for(int i=1;i<total;i++)
        {
            SigRow key = rows[i];
            int j = i-1;
            while(j>=0 && rows[j].t > key.t)
            {
                rows[j+1]=rows[j];
                j--;
            }
            rows[j+1]=key;
        }
    }
    return true;
}

// 시간 비교 (허용 오차 내 동등 판단)
int CmpTime(datetime a, datetime b)
{
    if(TimeToleranceSec<=0)
        return (a==b)?0:((a<b)?-1:1);
    long diff = (long)a - (long)b;
    if(diff<0) diff = -diff;
    if(diff <= (long)TimeToleranceSec) return 0;
    return (a<b)?-1:1;
}

void OnStart()
{
    if(UseLive)
    {
        Print("[COMPARE] 라이브 모드 - iCustom + 오브젝트 비교 시작");
        LiveCompare();
        return;
    }
    Print("[COMPARE] CSV 모드 - EA vs Indicator CSV 비교 시작");
    // CSV 로드
    if(!LoadCsv(EAFile, eaRows))   { Print("[COMPARE] EA CSV 로드 실패");   return; }
    if(!LoadCsv(IndiFile, indiRows)) { Print("[COMPARE] INDI CSV 로드 실패"); return; }

    int i=0, j=0;
    int ne = ArraySize(eaRows);
    int ni = ArraySize(indiRows);
    int match=0, diffType=0, onlyEA=0, onlyIndi=0;

    // 결과 파일 열기
    int out = FileOpen(OutFile, FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_SHARE_WRITE);
    if(out==INVALID_HANDLE) { Print("[COMPARE] 결과 파일 열기 실패"); return; }
    FileWrite(out, "time","ea_signal","indi_signal","match","ea_price","indi_price","ea_stop","indi_stop","ea_atr","indi_atr");

    while(i<ne || j<ni)
    {
        if(i>=ne)
        {
            // INDI만 남음
            FileWrite(out, (long)indiRows[j].t, "", indiRows[j].signal, 0, "", DoubleToString(indiRows[j].price,_Digits), "", DoubleToString(indiRows[j].stop,_Digits), "", DoubleToString(indiRows[j].atr,_Digits));
            onlyIndi++; j++; continue;
        }
        if(j>=ni)
        {
            // EA만 남음
            FileWrite(out, (long)eaRows[i].t, eaRows[i].signal, "", 0, DoubleToString(eaRows[i].price,_Digits), "", DoubleToString(eaRows[i].stop,_Digits), "", DoubleToString(eaRows[i].atr,_Digits), "");
            onlyEA++; i++; continue;
        }
        int c = CmpTime(eaRows[i].t, indiRows[j].t);
        if(c==0)
        {
            // 같은 시간
            bool ok = (eaRows[i].signal==indiRows[j].signal);
            FileWrite(out, (long)eaRows[i].t, eaRows[i].signal, indiRows[j].signal, ok?1:0,
                      DoubleToString(eaRows[i].price,_Digits), DoubleToString(indiRows[j].price,_Digits),
                      DoubleToString(eaRows[i].stop,_Digits),  DoubleToString(indiRows[j].stop,_Digits),
                      DoubleToString(eaRows[i].atr,_Digits),   DoubleToString(indiRows[j].atr,_Digits));
            if(ok) match++; else diffType++;
            i++; j++;
        }
        else if(c<0)
        {
            // EA가 앞선 시간
            FileWrite(out, (long)eaRows[i].t, eaRows[i].signal, "", 0, DoubleToString(eaRows[i].price,_Digits), "", DoubleToString(eaRows[i].stop,_Digits), "", DoubleToString(eaRows[i].atr,_Digits), "");
            onlyEA++; i++;
        }
        else
        {
            // INDI가 앞선 시간
            FileWrite(out, (long)indiRows[j].t, "", indiRows[j].signal, 0, "", DoubleToString(indiRows[j].price,_Digits), "", DoubleToString(indiRows[j].stop,_Digits), "", DoubleToString(indiRows[j].atr,_Digits));
            onlyIndi++; j++;
        }
    }
    FileClose(out);

    int totalEA   = ne;
    int totalIndi = ni;
    int mismatches = diffType + onlyEA + onlyIndi;
    double matchRate = (totalEA>0 || totalIndi>0) ? (100.0 * match / (double)MathMax(totalEA, totalIndi)) : 0.0;

    PrintFormat("[COMPARE] 완료: EA=%d, INDI=%d, match=%d, diffType=%d, onlyEA=%d, onlyIndi=%d, matchRate=%.2f%%",
                totalEA, totalIndi, match, diffType, onlyEA, onlyIndi, matchRate);
    PrintFormat("[COMPARE] 리포트: %s (공용 폴더)", OutFile);
}


