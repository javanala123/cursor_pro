#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🚀 Exness 백테스트용 과거 데이터 다운로더
Yahoo Finance API를 활용하여 정확한 계약 크기로 백테스트할 수 있는 데이터를 제공합니다.

작성자: AI Trading System
버전: 1.0
날짜: 2024-12-31
"""

import yfinance as yf
import pandas as pd
import numpy as np
import os
import json
from datetime import datetime, timedelta
import logging
from typing import Dict, List, Optional, Tuple
import time

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('data_downloader.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class HistoricalDataDownloader:
    """과거 데이터 다운로더 클래스"""
    
    def __init__(self, data_dir: str = "historical_data"):
        """
        초기화
        
        Args:
            data_dir: 데이터 저장 디렉토리
        """
        self.data_dir = data_dir
        self.symbols_config = self._load_symbols_config()
        self._create_data_directory()
        
    def _create_data_directory(self):
        """데이터 디렉토리 생성"""
        if not os.path.exists(self.data_dir):
            os.makedirs(self.data_dir)
            logger.info(f"📁 데이터 디렉토리 생성: {self.data_dir}")
    
    def _load_symbols_config(self) -> Dict:
        """심볼 설정 로드"""
        config = {
            "crypto": {
                "BTC-USD": {
                    "name": "비트코인",
                    "contract_size": 1.0,  # 1 랏 = 1 BTC
                    "min_lot": 0.01,
                    "max_lot": 100.0,
                    "leverage": 200,
                    "spread": 0.5,
                    "commission": 0.1
                },
                "ETH-USD": {
                    "name": "이더리움",
                    "contract_size": 1.0,  # 1 랏 = 1 ETH
                    "min_lot": 0.01,
                    "max_lot": 100.0,
                    "leverage": 200,
                    "spread": 0.5,
                    "commission": 0.1
                }
            },
            "forex": {
                "EURUSD=X": {
                    "name": "유로/달러",
                    "contract_size": 100000,  # 1 랏 = 100,000 EUR
                    "min_lot": 0.01,
                    "max_lot": 100.0,
                    "leverage": 200,
                    "spread": 0.5,
                    "commission": 0.1
                },
                "GBPUSD=X": {
                    "name": "파운드/달러",
                    "contract_size": 100000,  # 1 랏 = 100,000 GBP
                    "min_lot": 0.01,
                    "max_lot": 100.0,
                    "leverage": 200,
                    "spread": 0.5,
                    "commission": 0.1
                },
                "USDJPY=X": {
                    "name": "달러/엔",
                    "contract_size": 100000,  # 1 랏 = 100,000 USD
                    "min_lot": 0.01,
                    "max_lot": 100.0,
                    "leverage": 200,
                    "spread": 0.5,
                    "commission": 0.1
                }
            },
            "indices": {
                "SPY": {
                    "name": "S&P 500",
                    "contract_size": 1.0,  # 1 랏 = 1 지수
                    "min_lot": 0.01,
                    "max_lot": 100.0,
                    "leverage": 200,
                    "spread": 0.5,
                    "commission": 0.1
                },
                "QQQ": {
                    "name": "NASDAQ 100",
                    "contract_size": 1.0,  # 1 랏 = 1 지수
                    "min_lot": 0.01,
                    "max_lot": 100.0,
                    "leverage": 200,
                    "spread": 0.5,
                    "commission": 0.1
                }
            },
            "commodities": {
                "GC=F": {
                    "name": "금",
                    "contract_size": 100,  # 1 랏 = 100 oz
                    "min_lot": 0.01,
                    "max_lot": 100.0,
                    "leverage": 200,
                    "spread": 0.5,
                    "commission": 0.1
                },
                "CL=F": {
                    "name": "원유",
                    "contract_size": 1000,  # 1 랏 = 1000 배럴
                    "min_lot": 0.01,
                    "max_lot": 100.0,
                    "leverage": 200,
                    "spread": 0.5,
                    "commission": 0.1
                }
            }
        }
        
        # 설정 파일로 저장
        config_path = os.path.join(self.data_dir, "symbols_config.json")
        with open(config_path, 'w', encoding='utf-8') as f:
            json.dump(config, f, ensure_ascii=False, indent=2)
        
        logger.info(f"📋 심볼 설정 저장: {config_path}")
        return config
    
    def download_symbol_data(self, 
                           symbol: str, 
                           period: str = "5y", 
                           interval: str = "1h",
                           category: str = "crypto") -> Optional[pd.DataFrame]:
        """
        특정 심볼의 과거 데이터 다운로드
        
        Args:
            symbol: 심볼 이름 (예: "BTC-USD")
            period: 기간 ("1d", "5d", "1mo", "3mo", "6mo", "1y", "2y", "5y", "10y", "ytd", "max")
            interval: 간격 ("1m", "2m", "5m", "15m", "30m", "60m", "90m", "1h", "1d", "5d", "1wk", "1mo", "3mo")
            category: 카테고리 ("crypto", "forex", "indices", "commodities")
        
        Returns:
            다운로드된 데이터프레임 또는 None
        """
        try:
            logger.info(f"📥 데이터 다운로드 시작: {symbol} ({period}, {interval})")
            
            # Yahoo Finance에서 데이터 다운로드
            ticker = yf.Ticker(symbol)
            data = ticker.history(period=period, interval=interval)
            
            if data.empty:
                logger.warning(f"⚠️ {symbol}에 대한 데이터가 없습니다.")
                return None
            
            # 데이터 정리
            data = self._clean_data(data)
            
            # 심볼 설정 추가
            if category in self.symbols_config:
                symbol_config = self.symbols_config[category].get(symbol, {})
                if symbol_config:
                    data.attrs['config'] = symbol_config
            
            # 파일로 저장
            filename = f"{symbol.replace('=', '_').replace('-', '_')}_{period}_{interval}.csv"
            filepath = os.path.join(self.data_dir, filename)
            data.to_csv(filepath, encoding='utf-8')
            
            logger.info(f"✅ 데이터 저장 완료: {filepath} ({len(data)}개 바)")
            return data
            
        except Exception as e:
            logger.error(f"❌ {symbol} 데이터 다운로드 실패: {str(e)}")
            return None
    
    def _clean_data(self, data: pd.DataFrame) -> pd.DataFrame:
        """
        데이터 정리 및 검증
        
        Args:
            data: 원본 데이터
            
        Returns:
            정리된 데이터
        """
        # 결측값 제거
        data = data.dropna()
        
        # 중복 인덱스 제거
        data = data[~data.index.duplicated(keep='first')]
        
        # 정렬
        data = data.sort_index()
        
        # OHLCV 컬럼 확인
        required_columns = ['Open', 'High', 'Low', 'Close', 'Volume']
        for col in required_columns:
            if col not in data.columns:
                logger.warning(f"⚠️ {col} 컬럼이 없습니다.")
        
        # 가격 데이터 검증
        for col in ['Open', 'High', 'Low', 'Close']:
            if col in data.columns:
                # 음수 가격 제거
                data = data[data[col] > 0]
                
                # 비정상적으로 큰 값 제거 (평균의 10배 이상)
                mean_price = data[col].mean()
                data = data[data[col] < mean_price * 10]
        
        # High >= Low 검증
        if 'High' in data.columns and 'Low' in data.columns:
            data = data[data['High'] >= data['Low']]
        
        # High >= Open, Close 검증
        if 'High' in data.columns and 'Open' in data.columns:
            data = data[data['High'] >= data['Open']]
        if 'High' in data.columns and 'Close' in data.columns:
            data = data[data['High'] >= data['Close']]
        
        # Low <= Open, Close 검증
        if 'Low' in data.columns and 'Open' in data.columns:
            data = data[data['Low'] <= data['Open']]
        if 'Low' in data.columns and 'Close' in data.columns:
            data = data[data['Low'] <= data['Close']]
        
        logger.info(f"🧹 데이터 정리 완료: {len(data)}개 바 유효")
        return data
    
    def download_all_symbols(self, 
                           period: str = "2y", 
                           interval: str = "1h",
                           delay: float = 1.0) -> Dict[str, pd.DataFrame]:
        """
        모든 심볼의 데이터 다운로드
        
        Args:
            period: 기간
            interval: 간격
            delay: 요청 간 지연 시간 (초)
        
        Returns:
            다운로드된 데이터 딕셔너리
        """
        all_data = {}
        
        for category, symbols in self.symbols_config.items():
            logger.info(f"📊 {category} 카테고리 처리 중...")
            
            for symbol in symbols.keys():
                logger.info(f"🔄 {symbol} 처리 중...")
                
                data = self.download_symbol_data(symbol, period, interval, category)
                if data is not None:
                    all_data[symbol] = data
                
                # API 제한 방지를 위한 지연
                time.sleep(delay)
        
        logger.info(f"🎉 전체 다운로드 완료: {len(all_data)}개 심볼")
        return all_data
    
    def create_mt5_format_data(self, symbol: str, data: pd.DataFrame) -> pd.DataFrame:
        """
        MT5 형식으로 데이터 변환
        
        Args:
            symbol: 심볼 이름
            data: 원본 데이터
            
        Returns:
            MT5 형식 데이터
        """
        # MT5 형식으로 변환
        mt5_data = data.copy()
        
        # 컬럼명을 MT5 형식으로 변경
        column_mapping = {
            'Open': 'open',
            'High': 'high', 
            'Low': 'low',
            'Close': 'close',
            'Volume': 'tick_volume'
        }
        
        mt5_data = mt5_data.rename(columns=column_mapping)
        
        # 시간 컬럼 추가
        mt5_data['time'] = mt5_data.index.astype(np.int64) // 10**9
        
        # 컬럼 순서 조정
        mt5_data = mt5_data[['time', 'open', 'high', 'low', 'close', 'tick_volume']]
        
        # 심볼 설정 추가
        if hasattr(data, 'attrs') and 'config' in data.attrs:
            mt5_data.attrs['symbol_config'] = data.attrs['config']
        
        return mt5_data
    
    def generate_backtest_report(self, symbol: str, data: pd.DataFrame) -> Dict:
        """
        백테스트 리포트 생성
        
        Args:
            symbol: 심볼 이름
            data: 데이터
            
        Returns:
            리포트 딕셔너리
        """
        if data.empty:
            return {}
        
        # 기본 통계
        report = {
            "symbol": symbol,
            "period": f"{data.index[0]} ~ {data.index[-1]}",
            "total_bars": len(data),
            "price_range": {
                "min": float(data['Close'].min()),
                "max": float(data['Close'].max()),
                "avg": float(data['Close'].mean())
            },
            "volatility": {
                "daily_return_std": float(data['Close'].pct_change().std()),
                "max_drawdown": self._calculate_max_drawdown(data['Close'])
            }
        }
        
        # 심볼 설정 정보 추가
        if hasattr(data, 'attrs') and 'config' in data.attrs:
            report['symbol_config'] = data.attrs['config']
        
        return report
    
    def _calculate_max_drawdown(self, prices: pd.Series) -> float:
        """최대 낙폭 계산"""
        peak = prices.expanding().max()
        drawdown = (prices - peak) / peak
        return float(drawdown.min())
    
    def save_backtest_data(self, symbol: str, data: pd.DataFrame, format: str = "csv"):
        """
        백테스트 데이터 저장
        
        Args:
            symbol: 심볼 이름
            data: 데이터
            format: 저장 형식 ("csv", "json", "mt5")
        """
        if data.empty:
            logger.warning(f"⚠️ {symbol} 데이터가 비어있습니다.")
            return
        
        # 파일명 생성
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        base_filename = f"{symbol.replace('=', '_').replace('-', '_')}_backtest_{timestamp}"
        
        if format == "csv":
            filepath = os.path.join(self.data_dir, f"{base_filename}.csv")
            data.to_csv(filepath, encoding='utf-8')
            logger.info(f"💾 CSV 저장: {filepath}")
            
        elif format == "json":
            filepath = os.path.join(self.data_dir, f"{base_filename}.json")
            data.to_json(filepath, orient='records', date_format='iso')
            logger.info(f"💾 JSON 저장: {filepath}")
            
        elif format == "mt5":
            mt5_data = self.create_mt5_format_data(symbol, data)
            filepath = os.path.join(self.data_dir, f"{base_filename}_mt5.csv")
            mt5_data.to_csv(filepath, encoding='utf-8', index=False)
            logger.info(f"💾 MT5 형식 저장: {filepath}")
        
        # 리포트 생성 및 저장
        report = self.generate_backtest_report(symbol, data)
        report_path = os.path.join(self.data_dir, f"{base_filename}_report.json")
        with open(report_path, 'w', encoding='utf-8') as f:
            json.dump(report, f, ensure_ascii=False, indent=2, default=str)
        logger.info(f"📊 리포트 저장: {report_path}")

def main():
    """메인 실행 함수"""
    print("🚀 Exness 백테스트용 과거 데이터 다운로더 시작!")
    print("=" * 60)
    
    # 다운로더 초기화
    downloader = HistoricalDataDownloader()
    
    # 사용자 선택
    print("\n📋 다운로드 옵션을 선택하세요:")
    print("1. 비트코인만 다운로드 (빠른 테스트)")
    print("2. 모든 암호화폐 다운로드")
    print("3. 모든 심볼 다운로드 (전체)")
    print("4. 사용자 정의 다운로드")
    
    choice = input("\n선택 (1-4): ").strip()
    
    if choice == "1":
        # 비트코인만 다운로드
        print("\n🪙 비트코인 데이터 다운로드 중...")
        data = downloader.download_symbol_data("BTC-USD", period="2y", interval="1h")
        if data is not None:
            downloader.save_backtest_data("BTC-USD", data, format="mt5")
    
    elif choice == "2":
        # 모든 암호화폐 다운로드
        print("\n🪙 모든 암호화폐 데이터 다운로드 중...")
        crypto_symbols = list(downloader.symbols_config["crypto"].keys())
        for symbol in crypto_symbols:
            data = downloader.download_symbol_data(symbol, period="2y", interval="1h")
            if data is not None:
                downloader.save_backtest_data(symbol, data, format="mt5")
            time.sleep(1)  # API 제한 방지
    
    elif choice == "3":
        # 모든 심볼 다운로드
        print("\n🌍 모든 심볼 데이터 다운로드 중...")
        all_data = downloader.download_all_symbols(period="2y", interval="1h")
        for symbol, data in all_data.items():
            downloader.save_backtest_data(symbol, data, format="mt5")
    
    elif choice == "4":
        # 사용자 정의 다운로드
        symbol = input("심볼 입력 (예: BTC-USD): ").strip()
        period = input("기간 입력 (예: 2y): ").strip() or "2y"
        interval = input("간격 입력 (예: 1h): ").strip() or "1h"
        
        print(f"\n📥 {symbol} 데이터 다운로드 중...")
        data = downloader.download_symbol_data(symbol, period, interval)
        if data is not None:
            downloader.save_backtest_data(symbol, data, format="mt5")
    
    else:
        print("❌ 잘못된 선택입니다.")
        return
    
    print("\n🎉 다운로드 완료!")
    print(f"📁 데이터 저장 위치: {downloader.data_dir}")
    print("\n💡 다음 단계:")
    print("1. MT5에서 커스텀 심볼 생성 스크립트 실행")
    print("2. 다운로드된 데이터를 커스텀 심볼에 로드")
    print("3. 백테스트 실행")

if __name__ == "__main__":
    main()
