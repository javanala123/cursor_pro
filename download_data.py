#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
데이터 다운로드 스크립트
"""

import yfinance as yf
import pandas as pd
import os

def download_data():
    """데이터 다운로드"""
    print("🚀 데이터 다운로드 시작!")
    
    # 데이터 디렉토리 생성
    os.makedirs('historical_data', exist_ok=True)
    
    # 비트코인 데이터 다운로드
    print("📊 비트코인 데이터 다운로드 중...")
    try:
        btc_data = yf.download('BTC-USD', start='2020-01-01', end='2024-12-31')
        btc_data.to_csv('historical_data/BTC_USD_1d.csv')
        print(f"✅ 비트코인 데이터 다운로드 완료! ({len(btc_data)}개 바)")
    except Exception as e:
        print(f"❌ 비트코인 데이터 다운로드 실패: {e}")
    
    # 이더리움 데이터 다운로드
    print("📊 이더리움 데이터 다운로드 중...")
    try:
        eth_data = yf.download('ETH-USD', start='2020-01-01', end='2024-12-31')
        eth_data.to_csv('historical_data/ETH_USD_1d.csv')
        print(f"✅ 이더리움 데이터 다운로드 완료! ({len(eth_data)}개 바)")
    except Exception as e:
        print(f"❌ 이더리움 데이터 다운로드 실패: {e}")
    
    print("🎉 데이터 다운로드 완료!")

if __name__ == "__main__":
    download_data()
