#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
다중 심볼 다중 시간프레임(5m,15m,30m,1h,4h) 데이터 다운로드 스크립트
메모:
- yfinance는 무료 API 특성상 5m는 최대 약 60일, 15m/30m는 수개월, 1h/4h는 더 길게 제공됩니다.
- 파일명 규칙: SYMBOL_UNDERSCORE_TIMEFRAME.csv (예: BTC_USD_5m.csv, NQ_F_1h.csv)
"""

import os
from datetime import datetime, timedelta
from pathlib import Path
import yfinance as yf
import pandas as pd

# 한글 주석: 다운로드 대상 심볼과 시간프레임 정의
SYMBOLS = [
    "BTC-USD",   # 비트코인
    "NQ=F",      # 나스닥 선물
    "GC=F",      # 금 선물
]

TIMEFRAMES = [
    ("5m", 30),   # 최대 30일 권장
    ("15m", 60),  # 2개월 권장
    ("30m", 120), # 4개월 권장
    ("1h", 365),  # 12개월 권장
    ("4h", 730),  # 24개월 권장(가용 범위 내)
]

OUTPUT_DIR = Path("historical_data")
OUTPUT_DIR.mkdir(exist_ok=True)

def symbol_to_filename(symbol: str) -> str:
    """한글 주석: 심볼명 파일용으로 변환 (하이픈/등호를 언더스코어로)"""
    return symbol.replace('-', '_').replace('=', '_')

def download(symbol: str, interval: str, days: int) -> pd.DataFrame:
    """한글 주석: yfinance로 interval 기준 데이터 다운로드"""
    end = datetime.utcnow()
    start = end - timedelta(days=days)
    df = yf.download(symbol, start=start.strftime('%Y-%m-%d'), end=end.strftime('%Y-%m-%d'), interval=interval, progress=False)
    if df is None or df.empty:
        return pd.DataFrame()
    # 한글 주석: 필요 컬럼만 정리 및 저장 일관성
    cols = [c for c in ["Open","High","Low","Close","Volume"] if c in df.columns]
    df = df[cols]
    return df

def main():
    print("🚀 고해상도 데이터 다운로드 시작")
    for sym in SYMBOLS:
        for interval, days in TIMEFRAMES:
            try:
                print(f"📥 {sym} / {interval} / {days}d")
                df = download(sym, interval, days)
                if df.empty:
                    print(f"⚠️ 데이터 없음: {sym} {interval}")
                    continue
                fname = f"{symbol_to_filename(sym)}_{interval}.csv"
                df.to_csv(OUTPUT_DIR / fname)
                print(f"✅ 저장: {fname} ({len(df)} 바)")
            except Exception as e:
                print(f"❌ 실패: {sym} {interval} - {e}")
    print("🎉 완료")

if __name__ == "__main__":
    main()


