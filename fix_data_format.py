#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
데이터 형식 수정 스크립트
"""

import pandas as pd
import os

def fix_data_format():
    """데이터 형식 수정"""
    print("🔧 데이터 형식 수정 중...")
    
    # BTC 데이터 수정
    btc_file = 'historical_data/BTC_USD_1d.csv'
    if os.path.exists(btc_file):
        print("📊 BTC 데이터 형식 수정 중...")
        df = pd.read_csv(btc_file)
        
        # 올바른 형식으로 변환
        df_fixed = pd.DataFrame()
        df_fixed['Date'] = pd.to_datetime(df.iloc[2:, 0])  # 날짜
        df_fixed['Open'] = pd.to_numeric(df.iloc[2:, 4])   # 시가
        df_fixed['High'] = pd.to_numeric(df.iloc[2:, 2])   # 고가
        df_fixed['Low'] = pd.to_numeric(df.iloc[2:, 3])    # 저가
        df_fixed['Close'] = pd.to_numeric(df.iloc[2:, 1])  # 종가
        df_fixed['Volume'] = pd.to_numeric(df.iloc[2:, 5]) # 거래량
        
        df_fixed = df_fixed.set_index('Date')
        df_fixed = df_fixed.sort_index()
        df_fixed.to_csv(btc_file)
        print(f"✅ BTC 데이터 수정 완료! ({len(df_fixed)}개 바)")
    
    # ETH 데이터 수정
    eth_file = 'historical_data/ETH_USD_1d.csv'
    if os.path.exists(eth_file):
        print("📊 ETH 데이터 형식 수정 중...")
        df = pd.read_csv(eth_file)
        
        # 올바른 형식으로 변환
        df_fixed = pd.DataFrame()
        df_fixed['Date'] = pd.to_datetime(df.iloc[2:, 0])  # 날짜
        df_fixed['Open'] = pd.to_numeric(df.iloc[2:, 4])   # 시가
        df_fixed['High'] = pd.to_numeric(df.iloc[2:, 2])   # 고가
        df_fixed['Low'] = pd.to_numeric(df.iloc[2:, 3])    # 저가
        df_fixed['Close'] = pd.to_numeric(df.iloc[2:, 1])  # 종가
        df_fixed['Volume'] = pd.to_numeric(df.iloc[2:, 5]) # 거래량
        
        df_fixed = df_fixed.set_index('Date')
        df_fixed = df_fixed.sort_index()
        df_fixed.to_csv(eth_file)
        print(f"✅ ETH 데이터 수정 완료! ({len(df_fixed)}개 바)")
    
    print("🎉 데이터 형식 수정 완료!")

if __name__ == "__main__":
    fix_data_format()
