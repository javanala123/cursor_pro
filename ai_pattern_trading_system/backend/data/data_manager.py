"""
데이터 관리자 - 실시간 시장 데이터 수집 및 관리
"""

import asyncio
import ccxt
import yfinance as yf
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
import logging
import json
import redis
from dataclasses import dataclass

logger = logging.getLogger(__name__)

@dataclass
class MarketData:
    """시장 데이터 구조"""
    symbol: str
    timeframe: str
    timestamp: datetime
    ohlc_data: List[Dict[str, float]]
    volume: float
    price_change: float
    volatility: float

class DataManager:
    """데이터 관리자 - 실시간 시장 데이터 수집"""
    
    def __init__(self):
        self.exchanges = {
            'binance': ccxt.binance({
                'apiKey': '',  # 실제 API 키 필요
                'secret': '',  # 실제 시크릿 키 필요
                'sandbox': True,  # 테스트 모드
                'enableRateLimit': True,
            }),
            'yahoo': yf  # Yahoo Finance
        }
        
        # Redis 연결 (캐싱용)
        try:
            self.redis_client = redis.Redis(host='localhost', port=6379, db=0)
            self.redis_available = True
        except:
            self.redis_available = False
            logger.warning("Redis 연결 실패 - 캐싱 비활성화")
        
        # 지원 심볼들
        self.supported_symbols = [
            'BTC/USDT', 'ETH/USDT', 'BNB/USDT', 'ADA/USDT', 'SOL/USDT',
            'EUR/USD', 'GBP/USD', 'USD/JPY', 'AUD/USD', 'USD/CAD',
            'XAU/USD', 'XAG/USD', 'WTI', 'BRENT'
        ]
        
        # 지원 타임프레임들
        self.supported_timeframes = ['1m', '5m', '15m', '1h', '4h', '1d']
    
    async def initialize(self):
        """데이터 관리자 초기화"""
        logger.info("📊 데이터 관리자 초기화 중...")
        
        # 거래소 연결 테스트
        for exchange_name, exchange in self.exchanges.items():
            try:
                if hasattr(exchange, 'load_markets'):
                    await exchange.load_markets()
                    logger.info(f"✅ {exchange_name} 연결 성공")
                else:
                    logger.info(f"✅ {exchange_name} 준비 완료")
            except Exception as e:
                logger.warning(f"⚠️ {exchange_name} 연결 실패: {e}")
        
        logger.info("✅ 데이터 관리자 초기화 완료")
    
    async def get_current_market_data(self, symbol: str = 'BTC/USDT', timeframe: str = '1h') -> Dict[str, Any]:
        """현재 시장 데이터 가져오기"""
        try:
            # 캐시 확인
            cache_key = f"market_data:{symbol}:{timeframe}"
            if self.redis_available:
                cached_data = self.redis_client.get(cache_key)
                if cached_data:
                    data = json.loads(cached_data)
                    # 1분 이내 데이터면 캐시 사용
                    if datetime.now().timestamp() - data['timestamp'] < 60:
                        return data
            
            # 실시간 데이터 가져오기
            if 'USD' in symbol or 'JPY' in symbol or 'EUR' in symbol or 'GBP' in symbol:
                # 외환 데이터 (Yahoo Finance)
                data = await self._get_forex_data(symbol, timeframe)
            elif 'XAU' in symbol or 'XAG' in symbol:
                # 금/은 데이터 (Yahoo Finance)
                data = await self._get_metal_data(symbol, timeframe)
            elif 'WTI' in symbol or 'BRENT' in symbol:
                # 원유 데이터 (Yahoo Finance)
                data = await self._get_oil_data(symbol, timeframe)
            else:
                # 암호화폐 데이터 (Binance)
                data = await self._get_crypto_data(symbol, timeframe)
            
            # 캐시 저장
            if self.redis_available and data:
                self.redis_client.setex(cache_key, 60, json.dumps(data))  # 1분 캐시
            
            return data
            
        except Exception as e:
            logger.error(f"시장 데이터 가져오기 오류 {symbol}: {e}")
            return None
    
    async def get_historical_data(
        self, 
        symbol: str, 
        timeframe: str, 
        days: int = 365
    ) -> Optional[pd.DataFrame]:
        """과거 데이터 가져오기"""
        try:
            # 캐시 확인
            cache_key = f"historical:{symbol}:{timeframe}:{days}"
            if self.redis_available:
                cached_data = self.redis_client.get(cache_key)
                if cached_data:
                    data = json.loads(cached_data)
                    return pd.DataFrame(data)
            
            # 과거 데이터 가져오기
            if 'USD' in symbol or 'JPY' in symbol or 'EUR' in symbol or 'GBP' in symbol:
                df = await self._get_forex_historical(symbol, timeframe, days)
            elif 'XAU' in symbol or 'XAG' in symbol:
                df = await self._get_metal_historical(symbol, timeframe, days)
            elif 'WTI' in symbol or 'BRENT' in symbol:
                df = await self._get_oil_historical(symbol, timeframe, days)
            else:
                df = await self._get_crypto_historical(symbol, timeframe, days)
            
            # 캐시 저장 (1시간)
            if self.redis_available and df is not None:
                data_json = df.to_json(orient='records', date_format='iso')
                self.redis_client.setex(cache_key, 3600, data_json)
            
            return df
            
        except Exception as e:
            logger.error(f"과거 데이터 가져오기 오류 {symbol}: {e}")
            return None
    
    async def _get_crypto_data(self, symbol: str, timeframe: str) -> Dict[str, Any]:
        """암호화폐 실시간 데이터"""
        try:
            exchange = self.exchanges['binance']
            
            # 심볼 변환 (BTC/USDT -> BTCUSDT)
            binance_symbol = symbol.replace('/', '')
            
            # 현재 가격
            ticker = await exchange.fetch_ticker(binance_symbol)
            
            # OHLC 데이터 (최근 150개 캔들)
            ohlcv = await exchange.fetch_ohlcv(
                binance_symbol, 
                timeframe, 
                limit=150
            )
            
            # 데이터 변환
            ohlc_data = []
            for candle in ohlcv:
                ohlc_data.append({
                    'timestamp': datetime.fromtimestamp(candle[0] / 1000),
                    'open': candle[1],
                    'high': candle[2],
                    'low': candle[3],
                    'close': candle[4],
                    'volume': candle[5]
                })
            
            # 가격 변화율 계산
            if len(ohlc_data) >= 2:
                price_change = (ohlc_data[-1]['close'] - ohlc_data[-2]['close']) / ohlc_data[-2]['close']
            else:
                price_change = 0.0
            
            # 변동성 계산
            closes = [candle['close'] for candle in ohlc_data]
            volatility = np.std(closes) / np.mean(closes) if closes else 0.0
            
            return {
                'symbol': symbol,
                'timeframe': timeframe,
                'timestamp': datetime.now().isoformat(),
                'ohlc_data': ohlc_data,
                'current_price': ticker['last'],
                'price_change': price_change,
                'volatility': volatility,
                'volume': ticker['quoteVolume']
            }
            
        except Exception as e:
            logger.error(f"암호화폐 데이터 오류: {e}")
            return None
    
    async def _get_forex_data(self, symbol: str, timeframe: str) -> Dict[str, Any]:
        """외환 실시간 데이터"""
        try:
            # Yahoo Finance 심볼 변환
            yahoo_symbol = symbol.replace('/', '=X')
            
            # 실시간 데이터 가져오기
            ticker = yf.Ticker(yahoo_symbol)
            hist = ticker.history(period="5d", interval="1h")
            
            if hist.empty:
                return None
            
            # OHLC 데이터 변환
            ohlc_data = []
            for timestamp, row in hist.iterrows():
                ohlc_data.append({
                    'timestamp': timestamp,
                    'open': float(row['Open']),
                    'high': float(row['High']),
                    'low': float(row['Low']),
                    'close': float(row['Close']),
                    'volume': float(row['Volume'])
                })
            
            # 최근 150개만 사용
            ohlc_data = ohlc_data[-150:]
            
            # 가격 변화율 계산
            if len(ohlc_data) >= 2:
                price_change = (ohlc_data[-1]['close'] - ohlc_data[-2]['close']) / ohlc_data[-2]['close']
            else:
                price_change = 0.0
            
            # 변동성 계산
            closes = [candle['close'] for candle in ohlc_data]
            volatility = np.std(closes) / np.mean(closes) if closes else 0.0
            
            return {
                'symbol': symbol,
                'timeframe': timeframe,
                'timestamp': datetime.now().isoformat(),
                'ohlc_data': ohlc_data,
                'current_price': ohlc_data[-1]['close'],
                'price_change': price_change,
                'volatility': volatility,
                'volume': sum([candle['volume'] for candle in ohlc_data])
            }
            
        except Exception as e:
            logger.error(f"외환 데이터 오류: {e}")
            return None
    
    async def _get_metal_data(self, symbol: str, timeframe: str) -> Dict[str, Any]:
        """금/은 실시간 데이터"""
        try:
            # Yahoo Finance 심볼
            yahoo_symbol = symbol.replace('XAU', 'GC').replace('XAG', 'SI')
            
            ticker = yf.Ticker(yahoo_symbol)
            hist = ticker.history(period="5d", interval="1h")
            
            if hist.empty:
                return None
            
            # OHLC 데이터 변환
            ohlc_data = []
            for timestamp, row in hist.iterrows():
                ohlc_data.append({
                    'timestamp': timestamp,
                    'open': float(row['Open']),
                    'high': float(row['High']),
                    'low': float(row['Low']),
                    'close': float(row['Close']),
                    'volume': float(row['Volume'])
                })
            
            ohlc_data = ohlc_data[-150:]
            
            # 가격 변화율 계산
            if len(ohlc_data) >= 2:
                price_change = (ohlc_data[-1]['close'] - ohlc_data[-2]['close']) / ohlc_data[-2]['close']
            else:
                price_change = 0.0
            
            # 변동성 계산
            closes = [candle['close'] for candle in ohlc_data]
            volatility = np.std(closes) / np.mean(closes) if closes else 0.0
            
            return {
                'symbol': symbol,
                'timeframe': timeframe,
                'timestamp': datetime.now().isoformat(),
                'ohlc_data': ohlc_data,
                'current_price': ohlc_data[-1]['close'],
                'price_change': price_change,
                'volatility': volatility,
                'volume': sum([candle['volume'] for candle in ohlc_data])
            }
            
        except Exception as e:
            logger.error(f"금/은 데이터 오류: {e}")
            return None
    
    async def _get_oil_data(self, symbol: str, timeframe: str) -> Dict[str, Any]:
        """원유 실시간 데이터"""
        try:
            # Yahoo Finance 심볼
            yahoo_symbol = 'CL=F' if 'WTI' in symbol else 'BZ=F'
            
            ticker = yf.Ticker(yahoo_symbol)
            hist = ticker.history(period="5d", interval="1h")
            
            if hist.empty:
                return None
            
            # OHLC 데이터 변환
            ohlc_data = []
            for timestamp, row in hist.iterrows():
                ohlc_data.append({
                    'timestamp': timestamp,
                    'open': float(row['Open']),
                    'high': float(row['High']),
                    'low': float(row['Low']),
                    'close': float(row['Close']),
                    'volume': float(row['Volume'])
                })
            
            ohlc_data = ohlc_data[-150:]
            
            # 가격 변화율 계산
            if len(ohlc_data) >= 2:
                price_change = (ohlc_data[-1]['close'] - ohlc_data[-2]['close']) / ohlc_data[-2]['close']
            else:
                price_change = 0.0
            
            # 변동성 계산
            closes = [candle['close'] for candle in ohlc_data]
            volatility = np.std(closes) / np.mean(closes) if closes else 0.0
            
            return {
                'symbol': symbol,
                'timeframe': timeframe,
                'timestamp': datetime.now().isoformat(),
                'ohlc_data': ohlc_data,
                'current_price': ohlc_data[-1]['close'],
                'price_change': price_change,
                'volatility': volatility,
                'volume': sum([candle['volume'] for candle in ohlc_data])
            }
            
        except Exception as e:
            logger.error(f"원유 데이터 오류: {e}")
            return None
    
    async def _get_crypto_historical(self, symbol: str, timeframe: str, days: int) -> Optional[pd.DataFrame]:
        """암호화폐 과거 데이터"""
        try:
            exchange = self.exchanges['binance']
            binance_symbol = symbol.replace('/', '')
            
            # 일수에 따른 제한 계산
            limit = min(days * 24, 1000)  # 최대 1000개 캔들
            
            ohlcv = await exchange.fetch_ohlcv(
                binance_symbol, 
                timeframe, 
                limit=limit
            )
            
            # DataFrame 변환
            df = pd.DataFrame(ohlcv, columns=['timestamp', 'open', 'high', 'low', 'close', 'volume'])
            df['timestamp'] = pd.to_datetime(df['timestamp'], unit='ms')
            df.set_index('timestamp', inplace=True)
            
            return df
            
        except Exception as e:
            logger.error(f"암호화폐 과거 데이터 오류: {e}")
            return None
    
    async def _get_forex_historical(self, symbol: str, timeframe: str, days: int) -> Optional[pd.DataFrame]:
        """외환 과거 데이터"""
        try:
            yahoo_symbol = symbol.replace('/', '=X')
            
            # Yahoo Finance에서 데이터 가져오기
            ticker = yf.Ticker(yahoo_symbol)
            hist = ticker.history(period=f"{days}d")
            
            if hist.empty:
                return None
            
            return hist
            
        except Exception as e:
            logger.error(f"외환 과거 데이터 오류: {e}")
            return None
    
    async def _get_metal_historical(self, symbol: str, timeframe: str, days: int) -> Optional[pd.DataFrame]:
        """금/은 과거 데이터"""
        try:
            yahoo_symbol = symbol.replace('XAU', 'GC').replace('XAG', 'SI')
            
            ticker = yf.Ticker(yahoo_symbol)
            hist = ticker.history(period=f"{days}d")
            
            if hist.empty:
                return None
            
            return hist
            
        except Exception as e:
            logger.error(f"금/은 과거 데이터 오류: {e}")
            return None
    
    async def _get_oil_historical(self, symbol: str, timeframe: str, days: int) -> Optional[pd.DataFrame]:
        """원유 과거 데이터"""
        try:
            yahoo_symbol = 'CL=F' if 'WTI' in symbol else 'BZ=F'
            
            ticker = yf.Ticker(yahoo_symbol)
            hist = ticker.history(period=f"{days}d")
            
            if hist.empty:
                return None
            
            return hist
            
        except Exception as e:
            logger.error(f"원유 과거 데이터 오류: {e}")
            return None
    
    def get_supported_symbols(self) -> List[str]:
        """지원 심볼 목록 반환"""
        return self.supported_symbols.copy()
    
    def get_supported_timeframes(self) -> List[str]:
        """지원 타임프레임 목록 반환"""
        return self.supported_timeframes.copy()
    
    async def get_market_summary(self) -> Dict[str, Any]:
        """시장 요약 정보"""
        try:
            summary = {
                'timestamp': datetime.now().isoformat(),
                'supported_symbols': self.supported_symbols,
                'supported_timeframes': self.supported_timeframes,
                'exchanges': list(self.exchanges.keys()),
                'redis_available': self.redis_available
            }
            
            return summary
            
        except Exception as e:
            logger.error(f"시장 요약 오류: {e}")
            return {}
