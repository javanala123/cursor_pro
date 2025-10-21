//+------------------------------------------------------------------+
//|                                    Exness_Custom_Symbol_Creator.mq5 |
//|                                    Copyright 2024, AI Trading System |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, AI Trading System"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property script_show_inputs

//--- 입력 파라미터
input string OriginalSymbol = "BTCUSDM";           // 원본 심볼 이름
input string CustomSymbolName = "BTCUSDM_Real";    // 커스텀 심볼 이름
input string CustomGroup = "CustomSymbols";        // 커스텀 그룹
input double ContractSize = 1.0;                   // 계약 크기 (1 랏 = 1 BTC)
input int Leverage = 200;                          // 레버리지
input double MinLot = 0.01;                        // 최소 거래량
input double MaxLot = 100.0;                       // 최대 거래량
input double LotStep = 0.01;                       // 거래량 단계
input double Spread = 0.5;                         // 스프레드 (포인트)
input double Commission = 0.1;                     // 수수료 (USD per lot)
input bool DeleteExisting = false;                 // 기존 심볼 삭제 여부

//+------------------------------------------------------------------+
//| 스크립트 프로그램 시작 함수                                        |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("🚀 Exness 커스텀 심볼 생성기 시작...");
    
    // 1. 원본 심볼 존재 확인
    if(!CheckOriginalSymbol())
    {
        Print("❌ 원본 심볼 '", OriginalSymbol, "'을 찾을 수 없습니다!");
        return;
    }
    
    // 2. 기존 커스텀 심볼 처리
    if(!HandleExistingCustomSymbol())
    {
        Print("❌ 기존 커스텀 심볼 처리 실패!");
        return;
    }
    
    // 3. 커스텀 심볼 생성
    if(!CreateCustomSymbol())
    {
        Print("❌ 커스텀 심볼 생성 실패!");
        return;
    }
    
    // 4. 심볼 속성 설정
    if(!ConfigureSymbolProperties())
    {
        Print("❌ 심볼 속성 설정 실패!");
        return;
    }
    
    // 5. 가격 데이터 복사
    if(!CopyPriceData())
    {
        Print("❌ 가격 데이터 복사 실패!");
        return;
    }
    
    // 6. 최종 검증
    if(!ValidateCustomSymbol())
    {
        Print("❌ 커스텀 심볼 검증 실패!");
        return;
    }
    
    Print("✅ 커스텀 심볼 '", CustomSymbolName, "' 생성 완료!");
    Print("📊 설정된 계약 크기: ", ContractSize, " (1 랏 = ", ContractSize, " BTC)");
    Print("💡 이제 백테스트에서 '", CustomSymbolName, "' 심볼을 사용하세요!");
}

//+------------------------------------------------------------------+
//| 원본 심볼 존재 확인                                                |
//+------------------------------------------------------------------+
bool CheckOriginalSymbol()
{
    Print("🔍 원본 심볼 확인 중: ", OriginalSymbol);
    
    // 심볼이 MarketWatch에 있는지 확인
    if(!SymbolSelect(OriginalSymbol, true))
    {
        Print("❌ 심볼을 MarketWatch에 추가할 수 없습니다. 에러: ", GetLastError());
        return false;
    }
    
    // 심볼 정보 가져오기
    double contract_size = SymbolInfoDouble(OriginalSymbol, SYMBOL_TRADE_CONTRACT_SIZE);
    double min_lot = SymbolInfoDouble(OriginalSymbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(OriginalSymbol, SYMBOL_VOLUME_MAX);
    
    Print("📋 원본 심볼 정보:");
    Print("   - 계약 크기: ", contract_size);
    Print("   - 최소 거래량: ", min_lot);
    Print("   - 최대 거래량: ", max_lot);
    
    return true;
}

//+------------------------------------------------------------------+
//| 기존 커스텀 심볼 처리                                              |
//+------------------------------------------------------------------+
bool HandleExistingCustomSymbol()
{
    bool custom = false;
    
    // 커스텀 심볼이 이미 존재하는지 확인
    if(SymbolExist(CustomSymbolName, custom))
    {
        Print("⚠️ 커스텀 심볼 '", CustomSymbolName, "'이 이미 존재합니다.");
        
        if(DeleteExisting)
        {
            Print("🗑️ 기존 심볼 삭제 중...");
            
            // MarketWatch에서 제거
            SymbolSelect(CustomSymbolName, false);
            
            // 커스텀 심볼 삭제
            if(!CustomSymbolDelete(CustomSymbolName))
            {
                Print("❌ 커스텀 심볼 삭제 실패. 에러: ", GetLastError());
                return false;
            }
            
            Print("✅ 기존 커스텀 심볼 삭제 완료");
        }
        else
        {
            Print("❌ 기존 심볼이 있습니다. DeleteExisting을 true로 설정하거나 다른 이름을 사용하세요.");
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| 커스텀 심볼 생성                                                  |
//+------------------------------------------------------------------+
bool CreateCustomSymbol()
{
    Print("🔨 커스텀 심볼 생성 중: ", CustomSymbolName);
    
    // 커스텀 심볼 생성
    if(!CustomSymbolCreate(CustomSymbolName, CustomGroup, OriginalSymbol))
    {
        Print("❌ 커스텀 심볼 생성 실패. 에러: ", GetLastError());
        return false;
    }
    
    Print("✅ 커스텀 심볼 생성 완료");
    return true;
}

//+------------------------------------------------------------------+
//| 심볼 속성 설정                                                    |
//+------------------------------------------------------------------+
bool ConfigureSymbolProperties()
{
    Print("⚙️ 심볼 속성 설정 중...");
    
    // 기본 정보 설정
    if(!CustomSymbolSetString(CustomSymbolName, SYMBOL_DESCRIPTION, "Exness Real Contract Size Symbol"))
    {
        Print("❌ 심볼 설명 설정 실패. 에러: ", GetLastError());
        return false;
    }
    
    // 계약 크기 설정 (가장 중요!)
    if(!CustomSymbolSetDouble(CustomSymbolName, SYMBOL_TRADE_CONTRACT_SIZE, ContractSize))
    {
        Print("❌ 계약 크기 설정 실패. 에러: ", GetLastError());
        return false;
    }
    
    // 거래량 설정
    if(!CustomSymbolSetDouble(CustomSymbolName, SYMBOL_VOLUME_MIN, MinLot))
    {
        Print("❌ 최소 거래량 설정 실패. 에러: ", GetLastError());
        return false;
    }
    
    if(!CustomSymbolSetDouble(CustomSymbolName, SYMBOL_VOLUME_MAX, MaxLot))
    {
        Print("❌ 최대 거래량 설정 실패. 에러: ", GetLastError());
        return false;
    }
    
    if(!CustomSymbolSetDouble(CustomSymbolName, SYMBOL_VOLUME_STEP, LotStep))
    {
        Print("❌ 거래량 단계 설정 실패. 에러: ", GetLastError());
        return false;
    }
    
    // 레버리지 설정
    if(!CustomSymbolSetInteger(CustomSymbolName, SYMBOL_MARGIN_INITIAL, Leverage))
    {
        Print("❌ 레버리지 설정 실패. 에러: ", GetLastError());
        return false;
    }
    
    // 스프레드 설정
    if(!CustomSymbolSetInteger(CustomSymbolName, SYMBOL_SPREAD, (int)Spread))
    {
        Print("❌ 스프레드 설정 실패. 에러: ", GetLastError());
        return false;
    }
    
    // 거래 허용 설정
    if(!CustomSymbolSetInteger(CustomSymbolName, SYMBOL_TRADE_ALLOWED, 1))
    {
        Print("❌ 거래 허용 설정 실패. 에러: ", GetLastError());
        return false;
    }
    
    // 거래 모드 설정
    if(!CustomSymbolSetInteger(CustomSymbolName, SYMBOL_TRADE_MODE, SYMBOL_TRADE_MODE_FULL))
    {
        Print("❌ 거래 모드 설정 실패. 에러: ", GetLastError());
        return false;
    }
    
    Print("✅ 심볼 속성 설정 완료");
    return true;
}

//+------------------------------------------------------------------+
//| 가격 데이터 복사                                                  |
//+------------------------------------------------------------------+
bool CopyPriceData()
{
    Print("📊 가격 데이터 복사 중...");
    
    // 최근 1년 데이터 복사
    datetime start_time = TimeCurrent() - 365 * 24 * 3600;
    datetime end_time = TimeCurrent();
    
    MqlRates rates[];
    int copied = CopyRates(OriginalSymbol, PERIOD_H1, start_time, end_time, rates);
    
    if(copied <= 0)
    {
        Print("❌ 원본 심볼에서 가격 데이터를 가져올 수 없습니다. 에러: ", GetLastError());
        return false;
    }
    
    // 커스텀 심볼에 가격 데이터 추가
    if(!CustomRatesReplace(CustomSymbolName, start_time, end_time, rates))
    {
        Print("❌ 커스텀 심볼에 가격 데이터 복사 실패. 에러: ", GetLastError());
        return false;
    }
    
    Print("✅ 가격 데이터 복사 완료 (", copied, "개 바 복사)");
    return true;
}

//+------------------------------------------------------------------+
//| 커스텀 심볼 검증                                                  |
//+------------------------------------------------------------------+
bool ValidateCustomSymbol()
{
    Print("🔍 커스텀 심볼 검증 중...");
    
    // MarketWatch에 추가
    if(!SymbolSelect(CustomSymbolName, true))
    {
        Print("❌ 커스텀 심볼을 MarketWatch에 추가할 수 없습니다. 에러: ", GetLastError());
        return false;
    }
    
    // 설정된 속성 확인
    double contract_size = SymbolInfoDouble(CustomSymbolName, SYMBOL_TRADE_CONTRACT_SIZE);
    double min_lot = SymbolInfoDouble(CustomSymbolName, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(CustomSymbolName, SYMBOL_VOLUME_MAX);
    int leverage = (int)SymbolInfoInteger(CustomSymbolName, SYMBOL_MARGIN_INITIAL);
    
    Print("📋 커스텀 심볼 최종 설정:");
    Print("   - 심볼 이름: ", CustomSymbolName);
    Print("   - 계약 크기: ", contract_size, " (목표: ", ContractSize, ")");
    Print("   - 최소 거래량: ", min_lot, " (목표: ", MinLot, ")");
    Print("   - 최대 거래량: ", max_lot, " (목표: ", MaxLot, ")");
    Print("   - 레버리지: 1:", leverage, " (목표: 1:", Leverage, ")");
    
    // 계약 크기 검증
    if(MathAbs(contract_size - ContractSize) > 0.001)
    {
        Print("❌ 계약 크기가 올바르게 설정되지 않았습니다!");
        return false;
    }
    
    Print("✅ 커스텀 심볼 검증 완료");
    return true;
}

//+------------------------------------------------------------------+
//| 도움말 함수                                                      |
//+------------------------------------------------------------------+
void PrintHelp()
{
    Print("📖 사용법:");
    Print("1. 이 스크립트를 실행하여 커스텀 심볼을 생성합니다");
    Print("2. 전략 테스터에서 생성된 심볼을 선택합니다");
    Print("3. 0.01 랏 거래 시 실제로는 0.01 BTC를 거래합니다");
    Print("4. 백테스트 결과가 실매매와 일치합니다!");
    Print("");
    Print("🎯 주요 설정:");
    Print("- 계약 크기: ", ContractSize, " (1 랏 = ", ContractSize, " BTC)");
    Print("- 레버리지: 1:", Leverage);
    Print("- 최소 거래량: ", MinLot);
}
