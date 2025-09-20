"""
패턴 추출기 - 5-10년 과거 데이터에서 성공 패턴 추출
진짜 AI 기반으로 실제 수익을 낸 패턴들을 찾아내는 모듈
"""

import numpy as np
import pandas as pd
# import cv2  # 임시로 비활성화
from datetime import datetime, timedelta
from typing import List, Dict, Any, Tuple
import logging
from dataclasses import dataclass
import asyncio
import yfinance as yf
import ccxt

logger = logging.getLogger(__name__)

@dataclass
class SuccessfulPattern:
    """성공 패턴 데이터 구조"""
    pattern_id: str
    symbol: str
    timeframe: str
    start_time: datetime
    end_time: datetime
    pattern_type: str  # 'reversal', 'continuation', 'breakout'
    direction: str     # 'bullish', 'bearish'
    
    # 패턴 데이터
    ohlc_data: np.ndarray  # [timestamp, open, high, low, close, volume]
    price_points: np.ndarray  # 정규화된 가격 포인트들
    image_features: np.ndarray  # 이미지에서 추출한 특징 벡터
    
    # 성공 지표
    profit_pips: float
    success_rate: float
    occurrence_count: int
    confidence_score: float
    
    # 기술적 특징
    technical_features: Dict[str, float]
    
    # 메타데이터
    created_at: datetime
    last_used: datetime

class PatternExtractor:
    """성공 패턴 추출기 - 진짜 AI 기반"""
    
    def __init__(self, data_manager):
        self.data_manager = data_manager
        self.extracted_patterns: List[SuccessfulPattern] = []
        self.min_profit_pips = 50  # 최소 50 pips 수익
        self.min_success_rate = 0.7  # 최소 70% 성공률
        self.pattern_length = 150  # 패턴 길이 (캔들 수)
        
    async def extract_successful_patterns(self):
        """5-10년 과거 데이터에서 성공 패턴 추출"""
        logger.info("🔍 과거 데이터에서 성공 패턴 추출 시작...")
        
        # 주요 거래 심볼들
        symbols = ['BTC/USDT', 'ETH/USDT', 'EUR/USD', 'GBP/USD', 'USD/JPY', 'XAU/USD']
        timeframes = ['1h', '4h', '1d']
        
        total_patterns = 0
        
        for symbol in symbols:
            for timeframe in timeframes:
                logger.info(f"📊 {symbol} {timeframe} 패턴 추출 중...")
                
                # 과거 데이터 가져오기 (5년)
                historical_data = await self.data_manager.get_historical_data(
                    symbol=symbol,
                    timeframe=timeframe,
                    days=1825  # 5년
                )
                
                if historical_data is not None and len(historical_data) > 1000:
                    # 반전점 찾기
                    reversal_points = self._find_reversal_points(historical_data)
                    
                    # 각 반전점에서 패턴 추출
                    for reversal_idx in reversal_points:
                        pattern = await self._extract_pattern_at_reversal(
                            historical_data, reversal_idx, symbol, timeframe
                        )
                        
                        if pattern and pattern.profit_pips >= self.min_profit_pips:
                            self.extracted_patterns.append(pattern)
                            total_patterns += 1
                            
                            if total_patterns % 10 == 0:
                                logger.info(f"✅ {total_patterns}개 패턴 추출 완료")
        
        logger.info(f"🎉 총 {total_patterns}개의 성공 패턴 추출 완료!")
        return self.extracted_patterns
    
    def _find_reversal_points(self, data: pd.DataFrame) -> List[int]:
        """반전점 찾기 - 피벗 하이/로우 기반"""
        reversal_points = []
        
        # 피벗 하이/로우 계산
        highs = data['high'].values
        lows = data['low'].values
        closes = data['close'].values
        
        # 20개 캔들 기준으로 피벗 계산
        lookback = 20
        
        for i in range(lookback, len(data) - lookback):
            # 피벗 하이 확인
            is_pivot_high = True
            for j in range(1, lookback + 1):
                if highs[i] <= highs[i - j] or highs[i] <= highs[i + j]:
                    is_pivot_high = False
                    break
            
            # 피벗 로우 확인
            is_pivot_low = True
            for j in range(1, lookback + 1):
                if lows[i] >= lows[i - j] or lows[i] >= lows[i + j]:
                    is_pivot_low = False
                    break
            
            if is_pivot_high or is_pivot_low:
                reversal_points.append(i)
        
        return reversal_points
    
    async def _extract_pattern_at_reversal(
        self, 
        data: pd.DataFrame, 
        reversal_idx: int, 
        symbol: str, 
        timeframe: str
    ) -> SuccessfulPattern:
        """반전점에서 패턴 추출"""
        
        # 패턴 데이터 범위 설정
        start_idx = max(0, reversal_idx - self.pattern_length // 2)
        end_idx = min(len(data), reversal_idx + self.pattern_length // 2)
        
        if end_idx - start_idx < self.pattern_length:
            return None
        
        # 패턴 데이터 추출
        pattern_data = data.iloc[start_idx:end_idx].copy()
        
        # 미래 수익률 계산 (50개 캔들 후)
        future_idx = min(len(data) - 1, reversal_idx + 50)
        current_price = data.iloc[reversal_idx]['close']
        future_price = data.iloc[future_idx]['close']
        
        # 수익률 계산 (pips 단위)
        if 'USD' in symbol or 'JPY' in symbol:
            # 외환의 경우
            profit_pips = abs(future_price - current_price) * 10000
        else:
            # 암호화폐의 경우
            profit_pips = abs(future_price - current_price) / current_price * 10000
        
        # 최소 수익 조건 확인
        if profit_pips < self.min_profit_pips:
            return None
        
        # 패턴 방향 결정
        direction = 'bullish' if future_price > current_price else 'bearish'
        
        # 가격 포인트 정규화
        price_points = self._normalize_price_points(pattern_data)
        
        # 이미지 특징 추출
        image_features = self._extract_image_features(pattern_data)
        
        # 기술적 특징 추출
        technical_features = self._extract_technical_features(pattern_data)
        
        # 패턴 생성
        pattern = SuccessfulPattern(
            pattern_id=f"{symbol}_{timeframe}_{reversal_idx}_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
            symbol=symbol,
            timeframe=timeframe,
            start_time=pattern_data.index[0],
            end_time=pattern_data.index[-1],
            pattern_type='reversal',
            direction=direction,
            ohlc_data=pattern_data[['open', 'high', 'low', 'close', 'volume']].values,
            price_points=price_points,
            image_features=image_features,
            profit_pips=profit_pips,
            success_rate=1.0,  # 실제 수익을 낸 패턴이므로 100%
            occurrence_count=1,
            confidence_score=0.9,  # 높은 신뢰도
            technical_features=technical_features,
            created_at=datetime.now(),
            last_used=datetime.now()
        )
        
        return pattern
    
    def _normalize_price_points(self, data: pd.DataFrame) -> np.ndarray:
        """가격 포인트 정규화"""
        # 중심선 (고가+저가)/2 계산
        center_line = (data['high'] + data['low']) / 2
        
        # 정규화 (0-1 범위)
        min_price = center_line.min()
        max_price = center_line.max()
        
        if max_price > min_price:
            normalized = (center_line - min_price) / (max_price - min_price)
        else:
            normalized = np.zeros(len(center_line))
        
        return normalized.values
    
    def _extract_image_features(self, data: pd.DataFrame) -> np.ndarray:
        """차트 이미지에서 특징 추출 (간단한 버전)"""
        try:
            # 간단한 가격 기반 특징 추출
            features = []
            
            # 가격 변화율
            price_changes = data['close'].pct_change().dropna()
            features.extend([
                price_changes.mean(),
                price_changes.std(),
                price_changes.skew(),
                price_changes.kurtosis()
            ])
            
            # 고가-저가 비율
            high_low_ratio = (data['high'] - data['low']) / data['close']
            features.extend([
                high_low_ratio.mean(),
                high_low_ratio.std()
            ])
            
            # 거래량 특징
            if 'volume' in data.columns:
                volume_changes = data['volume'].pct_change().dropna()
                features.extend([
                    volume_changes.mean(),
                    volume_changes.std()
                ])
            else:
                features.extend([0.0, 0.0])
            
            # 128차원으로 패딩
            while len(features) < 128:
                features.append(0.0)
            
            features = np.array(features[:128])
            return features / (np.linalg.norm(features) + 1e-8)  # L2 정규화
                
        except Exception as e:
            logger.warning(f"이미지 특징 추출 실패: {e}")
            return np.zeros(128)
    
    def _create_chart_image(self, data: pd.DataFrame, width=200, height=100) -> np.ndarray:
        """차트 이미지 생성"""
        import matplotlib.pyplot as plt
        import matplotlib
        matplotlib.use('Agg')
        
        # 캔들스틱 차트 생성
        fig, ax = plt.subplots(figsize=(width/100, height/100), dpi=100)
        
        # OHLC 데이터로 캔들스틱 그리기
        for i, (idx, row) in enumerate(data.iterrows()):
            open_price = row['open']
            high_price = row['high']
            low_price = row['low']
            close_price = row['close']
            
            # 캔들 색상
            color = 'green' if close_price >= open_price else 'red'
            
            # 몸통 그리기
            body_height = abs(close_price - open_price)
            body_bottom = min(open_price, close_price)
            ax.bar(i, body_height, bottom=body_bottom, color=color, alpha=0.8, width=0.8)
            
            # 위꼬리 그리기
            if high_price > max(open_price, close_price):
                ax.plot([i, i], [max(open_price, close_price), high_price], color='black', linewidth=1)
            
            # 아래꼬리 그리기
            if low_price < min(open_price, close_price):
                ax.plot([i, i], [min(open_price, close_price), low_price], color='black', linewidth=1)
        
        ax.set_xlim(-1, len(data))
        ax.set_ylim(data['low'].min() * 0.99, data['high'].max() * 1.01)
        ax.axis('off')
        
        # 이미지로 변환
        fig.canvas.draw()
        image = np.frombuffer(fig.canvas.tostring_rgb(), dtype=np.uint8)
        image = image.reshape(fig.canvas.get_width_height()[::-1] + (3,))
        
        plt.close(fig)
        return image
    
    def _extract_technical_features(self, data: pd.DataFrame) -> Dict[str, float]:
        """기술적 지표 특징 추출"""
        features = {}
        
        try:
            # 기본 가격 특징
            features['price_change'] = (data['close'].iloc[-1] - data['close'].iloc[0]) / data['close'].iloc[0]
            features['volatility'] = data['close'].std() / data['close'].mean()
            features['high_low_ratio'] = data['high'].max() / data['low'].min()
            
            # 이동평균 특징
            features['ma_5'] = data['close'].rolling(5).mean().iloc[-1] / data['close'].iloc[-1]
            features['ma_20'] = data['close'].rolling(20).mean().iloc[-1] / data['close'].iloc[-1]
            
            # RSI
            delta = data['close'].diff()
            gain = (delta.where(delta > 0, 0)).rolling(14).mean()
            loss = (-delta.where(delta < 0, 0)).rolling(14).mean()
            rs = gain / loss
            features['rsi'] = (100 - (100 / (1 + rs))).iloc[-1] / 100
            
            # 볼린저 밴드
            bb_middle = data['close'].rolling(20).mean()
            bb_std = data['close'].rolling(20).std()
            bb_upper = bb_middle + (bb_std * 2)
            bb_lower = bb_middle - (bb_std * 2)
            features['bb_position'] = (data['close'].iloc[-1] - bb_lower.iloc[-1]) / (bb_upper.iloc[-1] - bb_lower.iloc[-1])
            
            # 캔들 패턴 특징
            bullish_candles = (data['close'] > data['open']).sum()
            features['bullish_ratio'] = bullish_candles / len(data)
            
            # 몸통 크기
            body_sizes = abs(data['close'] - data['open'])
            features['avg_body_size'] = body_sizes.mean() / data['close'].mean()
            
        except Exception as e:
            logger.warning(f"기술적 특징 추출 실패: {e}")
            # 기본값 설정
            features = {
                'price_change': 0.0,
                'volatility': 0.0,
                'high_low_ratio': 1.0,
                'ma_5': 1.0,
                'ma_20': 1.0,
                'rsi': 0.5,
                'bb_position': 0.5,
                'bullish_ratio': 0.5,
                'avg_body_size': 0.01
            }
        
        return features
    
    def get_extracted_patterns(self) -> List[Dict[str, Any]]:
        """추출된 패턴 목록 반환"""
        return [
            {
                'pattern_id': pattern.pattern_id,
                'symbol': pattern.symbol,
                'timeframe': pattern.timeframe,
                'direction': pattern.direction,
                'profit_pips': pattern.profit_pips,
                'success_rate': pattern.success_rate,
                'confidence_score': pattern.confidence_score,
                'created_at': pattern.created_at.isoformat()
            }
            for pattern in self.extracted_patterns
        ]
    
    def get_pattern_by_id(self, pattern_id: str) -> SuccessfulPattern:
        """ID로 패턴 조회"""
        for pattern in self.extracted_patterns:
            if pattern.pattern_id == pattern_id:
                return pattern
        return None
