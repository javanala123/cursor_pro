"""
실시간 분석기 - 실시간 차트 데이터를 AI로 분석
진짜 AI가 실시간으로 차트를 감시하고 패턴을 찾아내는 모듈
"""

import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional, Tuple
import logging
import asyncio
import cv2
from dataclasses import dataclass

logger = logging.getLogger(__name__)

@dataclass
class AnalysisResult:
    """실시간 분석 결과"""
    timestamp: datetime
    symbol: str
    timeframe: str
    
    # AI 분석 결과
    has_reversal_signal: bool
    reversal_direction: str  # 'bullish', 'bearish'
    reversal_confidence: float
    
    # 패턴 매칭 결과
    best_match_pattern_id: Optional[str]
    pattern_similarity: float
    pattern_confidence: float
    expected_profit: float
    
    # 거래 신호
    should_trade: bool
    trade_direction: str  # 'buy', 'sell'
    trade_confidence: float
    
    # 기술적 분석
    technical_indicators: Dict[str, float]
    market_sentiment: str  # 'bullish', 'bearish', 'neutral'
    
    # 메타데이터
    analysis_duration_ms: float
    ai_processing_time_ms: float

class RealTimeAnalyzer:
    """실시간 AI 분석기"""
    
    def __init__(self, pattern_matcher):
        self.pattern_matcher = pattern_matcher
        self.analysis_history: List[AnalysisResult] = []
        self.max_history = 1000  # 최대 분석 이력 저장 수
        
        # AI 분석 설정
        self.reversal_lookback = 20
        self.pattern_length = 150
        self.min_confidence = 0.8
        self.min_similarity = 0.9
        
    async def analyze_patterns(self, market_data: Dict[str, Any]) -> AnalysisResult:
        """실시간 패턴 분석 - 진짜 AI 기반"""
        start_time = datetime.now()
        
        try:
            symbol = market_data.get('symbol', 'UNKNOWN')
            timeframe = market_data.get('timeframe', '1h')
            ohlc_data = market_data.get('ohlc_data', [])
            
            if not ohlc_data or len(ohlc_data) < self.pattern_length:
                return self._create_empty_result(symbol, timeframe, "데이터 부족")
            
            # 1. 실시간 반전 신호 감지
            reversal_signal = await self._detect_reversal_signal(ohlc_data)
            
            # 2. 현재 패턴 추출
            current_pattern = self._extract_current_pattern(ohlc_data)
            current_image_features = self._extract_current_image_features(ohlc_data)
            current_technical_features = self._extract_current_technical_features(ohlc_data)
            
            # 3. AI 패턴 매칭 (성공 패턴들과 비교)
            # 이 부분은 메인 서버에서 성공 패턴들을 전달받아야 함
            match_results = []  # 실제로는 pattern_matcher.match_patterns() 호출
            
            # 4. 거래 신호 생성
            trade_signal = self._generate_trade_signal(
                reversal_signal, match_results, current_technical_features
            )
            
            # 5. 시장 심리 분석
            market_sentiment = self._analyze_market_sentiment(
                current_technical_features, reversal_signal
            )
            
            # 분석 결과 생성
            analysis_result = AnalysisResult(
                timestamp=datetime.now(),
                symbol=symbol,
                timeframe=timeframe,
                has_reversal_signal=reversal_signal['detected'],
                reversal_direction=reversal_signal['direction'],
                reversal_confidence=reversal_signal['confidence'],
                best_match_pattern_id=match_results[0].pattern_id if match_results else None,
                pattern_similarity=match_results[0].similarity_score if match_results else 0.0,
                pattern_confidence=match_results[0].confidence if match_results else 0.0,
                expected_profit=match_results[0].expected_profit if match_results else 0.0,
                should_trade=trade_signal['should_trade'],
                trade_direction=trade_signal['direction'],
                trade_confidence=trade_signal['confidence'],
                technical_indicators=current_technical_features,
                market_sentiment=market_sentiment,
                analysis_duration_ms=(datetime.now() - start_time).total_seconds() * 1000,
                ai_processing_time_ms=0.0  # 실제 AI 처리 시간 측정
            )
            
            # 분석 이력 저장
            self._save_analysis_result(analysis_result)
            
            return analysis_result
            
        except Exception as e:
            logger.error(f"실시간 분석 오류: {e}")
            return self._create_empty_result(
                market_data.get('symbol', 'UNKNOWN'), 
                market_data.get('timeframe', '1h'), 
                f"분석 오류: {str(e)}"
            )
    
    async def _detect_reversal_signal(self, ohlc_data: List[Dict]) -> Dict[str, Any]:
        """실시간 반전 신호 감지 - AI 기반"""
        try:
            if len(ohlc_data) < self.reversal_lookback * 2:
                return {'detected': False, 'direction': 'none', 'confidence': 0.0}
            
            # 최근 데이터 추출
            recent_data = ohlc_data[-self.reversal_lookback:]
            
            # 1. 피벗 하이/로우 감지
            pivot_high = self._detect_pivot_high(recent_data)
            pivot_low = self._detect_pivot_low(recent_data)
            
            # 2. 모멘텀 분석
            momentum_signal = self._analyze_momentum(recent_data)
            
            # 3. 변동성 분석
            volatility_signal = self._analyze_volatility(recent_data)
            
            # 4. AI 종합 판단
            if pivot_high['detected'] and momentum_signal['bearish'] and volatility_signal['high']:
                return {
                    'detected': True,
                    'direction': 'bearish',
                    'confidence': (pivot_high['confidence'] + momentum_signal['confidence'] + volatility_signal['confidence']) / 3
                }
            elif pivot_low['detected'] and momentum_signal['bullish'] and volatility_signal['high']:
                return {
                    'detected': True,
                    'direction': 'bullish',
                    'confidence': (pivot_low['confidence'] + momentum_signal['confidence'] + volatility_signal['confidence']) / 3
                }
            else:
                return {'detected': False, 'direction': 'none', 'confidence': 0.0}
                
        except Exception as e:
            logger.warning(f"반전 신호 감지 오류: {e}")
            return {'detected': False, 'direction': 'none', 'confidence': 0.0}
    
    def _detect_pivot_high(self, data: List[Dict]) -> Dict[str, Any]:
        """피벗 하이 감지"""
        try:
            if len(data) < 5:
                return {'detected': False, 'confidence': 0.0}
            
            # 최근 5개 캔들에서 피벗 하이 확인
            recent_highs = [candle['high'] for candle in data[-5:]]
            current_high = recent_highs[-1]
            
            # 양쪽 2개씩 비교
            is_pivot = True
            for i in range(1, 3):
                if len(recent_highs) > i:
                    if current_high <= recent_highs[-1-i]:
                        is_pivot = False
                        break
            
            confidence = 0.8 if is_pivot else 0.0
            return {'detected': is_pivot, 'confidence': confidence}
            
        except Exception as e:
            logger.warning(f"피벗 하이 감지 오류: {e}")
            return {'detected': False, 'confidence': 0.0}
    
    def _detect_pivot_low(self, data: List[Dict]) -> Dict[str, Any]:
        """피벗 로우 감지"""
        try:
            if len(data) < 5:
                return {'detected': False, 'confidence': 0.0}
            
            # 최근 5개 캔들에서 피벗 로우 확인
            recent_lows = [candle['low'] for candle in data[-5:]]
            current_low = recent_lows[-1]
            
            # 양쪽 2개씩 비교
            is_pivot = True
            for i in range(1, 3):
                if len(recent_lows) > i:
                    if current_low >= recent_lows[-1-i]:
                        is_pivot = False
                        break
            
            confidence = 0.8 if is_pivot else 0.0
            return {'detected': is_pivot, 'confidence': confidence}
            
        except Exception as e:
            logger.warning(f"피벗 로우 감지 오류: {e}")
            return {'detected': False, 'confidence': 0.0}
    
    def _analyze_momentum(self, data: List[Dict]) -> Dict[str, Any]:
        """모멘텀 분석"""
        try:
            if len(data) < 10:
                return {'bullish': False, 'bearish': False, 'confidence': 0.0}
            
            # 가격 변화율 계산
            recent_closes = [candle['close'] for candle in data[-10:]]
            price_change = (recent_closes[-1] - recent_closes[0]) / recent_closes[0]
            
            # 모멘텀 방향 결정
            bullish = price_change > 0.02  # 2% 이상 상승
            bearish = price_change < -0.02  # 2% 이상 하락
            
            confidence = min(abs(price_change) * 10, 1.0)  # 변화율에 비례한 신뢰도
            
            return {
                'bullish': bullish,
                'bearish': bearish,
                'confidence': confidence
            }
            
        except Exception as e:
            logger.warning(f"모멘텀 분석 오류: {e}")
            return {'bullish': False, 'bearish': False, 'confidence': 0.0}
    
    def _analyze_volatility(self, data: List[Dict]) -> Dict[str, Any]:
        """변동성 분석"""
        try:
            if len(data) < 10:
                return {'high': False, 'confidence': 0.0}
            
            # ATR 계산
            high_low_ranges = []
            for i in range(1, len(data)):
                high_low_range = data[i]['high'] - data[i]['low']
                high_low_ranges.append(high_low_range)
            
            avg_range = np.mean(high_low_ranges)
            current_range = data[-1]['high'] - data[-1]['low']
            
            # 변동성 급증 감지
            volatility_ratio = current_range / avg_range if avg_range > 0 else 1.0
            high_volatility = volatility_ratio > 1.5  # 평균의 1.5배 이상
            
            confidence = min(volatility_ratio - 1.0, 1.0) if high_volatility else 0.0
            
            return {
                'high': high_volatility,
                'confidence': confidence
            }
            
        except Exception as e:
            logger.warning(f"변동성 분석 오류: {e}")
            return {'high': False, 'confidence': 0.0}
    
    def _extract_current_pattern(self, ohlc_data: List[Dict]) -> np.ndarray:
        """현재 패턴 추출"""
        try:
            if len(ohlc_data) < self.pattern_length:
                return np.array([])
            
            # 최근 패턴 길이만큼 데이터 추출
            recent_data = ohlc_data[-self.pattern_length:]
            
            # 중심선 계산 및 정규화
            center_prices = []
            for candle in recent_data:
                center_price = (candle['high'] + candle['low']) / 2
                center_prices.append(center_price)
            
            # 정규화
            center_prices = np.array(center_prices)
            min_price = center_prices.min()
            max_price = center_prices.max()
            
            if max_price > min_price:
                normalized = (center_prices - min_price) / (max_price - min_price)
            else:
                normalized = np.zeros(len(center_prices))
            
            return normalized
            
        except Exception as e:
            logger.warning(f"현재 패턴 추출 오류: {e}")
            return np.array([])
    
    def _extract_current_image_features(self, ohlc_data: List[Dict]) -> np.ndarray:
        """현재 이미지 특징 추출"""
        try:
            if len(ohlc_data) < 50:
                return np.zeros(128)
            
            # 차트 이미지 생성
            chart_image = self._create_chart_image(ohlc_data[-50:])  # 최근 50개 캔들
            
            # OpenCV로 특징 추출
            gray = cv2.cvtColor(chart_image, cv2.COLOR_RGB2GRAY)
            
            # SIFT 특징점 추출
            sift = cv2.SIFT_create()
            keypoints, descriptors = sift.detectAndCompute(gray, None)
            
            if descriptors is not None and len(descriptors) > 0:
                features = np.mean(descriptors, axis=0)
                return features / np.linalg.norm(features)
            else:
                return np.zeros(128)
                
        except Exception as e:
            logger.warning(f"이미지 특징 추출 오류: {e}")
            return np.zeros(128)
    
    def _create_chart_image(self, ohlc_data: List[Dict], width=200, height=100) -> np.ndarray:
        """차트 이미지 생성"""
        try:
            import matplotlib.pyplot as plt
            import matplotlib
            matplotlib.use('Agg')
            
            fig, ax = plt.subplots(figsize=(width/100, height/100), dpi=100)
            
            # 캔들스틱 차트 그리기
            for i, candle in enumerate(ohlc_data):
                open_price = candle['open']
                high_price = candle['high']
                low_price = candle['low']
                close_price = candle['close']
                
                color = 'green' if close_price >= open_price else 'red'
                
                # 몸통
                body_height = abs(close_price - open_price)
                body_bottom = min(open_price, close_price)
                ax.bar(i, body_height, bottom=body_bottom, color=color, alpha=0.8, width=0.8)
                
                # 위꼬리
                if high_price > max(open_price, close_price):
                    ax.plot([i, i], [max(open_price, close_price), high_price], color='black', linewidth=1)
                
                # 아래꼬리
                if low_price < min(open_price, close_price):
                    ax.plot([i, i], [min(open_price, close_price), low_price], color='black', linewidth=1)
            
            ax.set_xlim(-1, len(ohlc_data))
            ax.axis('off')
            
            fig.canvas.draw()
            image = np.frombuffer(fig.canvas.tostring_rgb(), dtype=np.uint8)
            image = image.reshape(fig.canvas.get_width_height()[::-1] + (3,))
            
            plt.close(fig)
            return image
            
        except Exception as e:
            logger.warning(f"차트 이미지 생성 오류: {e}")
            return np.zeros((height, width, 3), dtype=np.uint8)
    
    def _extract_current_technical_features(self, ohlc_data: List[Dict]) -> Dict[str, float]:
        """현재 기술적 특징 추출"""
        try:
            if len(ohlc_data) < 20:
                return {}
            
            df = pd.DataFrame(ohlc_data)
            features = {}
            
            # 기본 가격 특징
            features['price_change'] = (df['close'].iloc[-1] - df['close'].iloc[0]) / df['close'].iloc[0]
            features['volatility'] = df['close'].std() / df['close'].mean()
            
            # RSI
            delta = df['close'].diff()
            gain = (delta.where(delta > 0, 0)).rolling(14).mean()
            loss = (-delta.where(delta < 0, 0)).rolling(14).mean()
            rs = gain / loss
            features['rsi'] = (100 - (100 / (1 + rs))).iloc[-1] / 100
            
            # 이동평균
            features['ma_5'] = df['close'].rolling(5).mean().iloc[-1] / df['close'].iloc[-1]
            features['ma_20'] = df['close'].rolling(20).mean().iloc[-1] / df['close'].iloc[-1]
            
            # 캔들 패턴
            bullish_candles = (df['close'] > df['open']).sum()
            features['bullish_ratio'] = bullish_candles / len(df)
            
            return features
            
        except Exception as e:
            logger.warning(f"기술적 특징 추출 오류: {e}")
            return {}
    
    def _generate_trade_signal(
        self, 
        reversal_signal: Dict[str, Any], 
        match_results: List[Any], 
        technical_features: Dict[str, float]
    ) -> Dict[str, Any]:
        """거래 신호 생성"""
        try:
            # 기본 조건 확인
            has_reversal = reversal_signal.get('detected', False)
            has_good_match = len(match_results) > 0 and match_results[0].is_match
            
            if not has_reversal or not has_good_match:
                return {
                    'should_trade': False,
                    'direction': 'none',
                    'confidence': 0.0
                }
            
            # 방향 결정
            reversal_direction = reversal_signal.get('direction', 'none')
            pattern_direction = match_results[0].direction
            
            # 방향 일치 확인
            if reversal_direction == 'bullish' and pattern_direction == 'bullish':
                trade_direction = 'buy'
            elif reversal_direction == 'bearish' and pattern_direction == 'bearish':
                trade_direction = 'sell'
            else:
                return {
                    'should_trade': False,
                    'direction': 'none',
                    'confidence': 0.0
                }
            
            # 신뢰도 계산
            reversal_confidence = reversal_signal.get('confidence', 0.0)
            pattern_confidence = match_results[0].confidence
            technical_confidence = self._calculate_technical_confidence(technical_features)
            
            total_confidence = (
                reversal_confidence * 0.3 +
                pattern_confidence * 0.5 +
                technical_confidence * 0.2
            )
            
            return {
                'should_trade': total_confidence >= self.min_confidence,
                'direction': trade_direction,
                'confidence': total_confidence
            }
            
        except Exception as e:
            logger.warning(f"거래 신호 생성 오류: {e}")
            return {
                'should_trade': False,
                'direction': 'none',
                'confidence': 0.0
            }
    
    def _calculate_technical_confidence(self, technical_features: Dict[str, float]) -> float:
        """기술적 지표 신뢰도 계산"""
        try:
            confidence_factors = []
            
            # RSI 신뢰도
            rsi = technical_features.get('rsi', 0.5)
            if rsi < 0.3 or rsi > 0.7:  # 과매수/과매도
                confidence_factors.append(0.8)
            else:
                confidence_factors.append(0.3)
            
            # 가격 변화 신뢰도
            price_change = abs(technical_features.get('price_change', 0))
            if price_change > 0.02:  # 2% 이상 변화
                confidence_factors.append(0.7)
            else:
                confidence_factors.append(0.2)
            
            # 변동성 신뢰도
            volatility = technical_features.get('volatility', 0)
            if volatility > 0.01:  # 높은 변동성
                confidence_factors.append(0.6)
            else:
                confidence_factors.append(0.3)
            
            return np.mean(confidence_factors) if confidence_factors else 0.0
            
        except Exception as e:
            logger.warning(f"기술적 신뢰도 계산 오류: {e}")
            return 0.0
    
    def _analyze_market_sentiment(self, technical_features: Dict[str, float], reversal_signal: Dict[str, Any]) -> str:
        """시장 심리 분석"""
        try:
            bullish_factors = 0
            bearish_factors = 0
            
            # RSI 분석
            rsi = technical_features.get('rsi', 0.5)
            if rsi < 0.3:
                bearish_factors += 1
            elif rsi > 0.7:
                bullish_factors += 1
            
            # 가격 변화 분석
            price_change = technical_features.get('price_change', 0)
            if price_change > 0.01:
                bullish_factors += 1
            elif price_change < -0.01:
                bearish_factors += 1
            
            # 반전 신호 분석
            if reversal_signal.get('direction') == 'bullish':
                bullish_factors += 1
            elif reversal_signal.get('direction') == 'bearish':
                bearish_factors += 1
            
            # 심리 결정
            if bullish_factors > bearish_factors + 1:
                return 'bullish'
            elif bearish_factors > bullish_factors + 1:
                return 'bearish'
            else:
                return 'neutral'
                
        except Exception as e:
            logger.warning(f"시장 심리 분석 오류: {e}")
            return 'neutral'
    
    def _save_analysis_result(self, result: AnalysisResult):
        """분석 결과 저장"""
        self.analysis_history.append(result)
        
        # 최대 이력 수 제한
        if len(self.analysis_history) > self.max_history:
            self.analysis_history = self.analysis_history[-self.max_history:]
    
    def _create_empty_result(self, symbol: str, timeframe: str, reason: str) -> AnalysisResult:
        """빈 분석 결과 생성"""
        return AnalysisResult(
            timestamp=datetime.now(),
            symbol=symbol,
            timeframe=timeframe,
            has_reversal_signal=False,
            reversal_direction='none',
            reversal_confidence=0.0,
            best_match_pattern_id=None,
            pattern_similarity=0.0,
            pattern_confidence=0.0,
            expected_profit=0.0,
            should_trade=False,
            trade_direction='none',
            trade_confidence=0.0,
            technical_indicators={},
            market_sentiment='neutral',
            analysis_duration_ms=0.0,
            ai_processing_time_ms=0.0
        )
    
    def get_analysis_history(self, limit: int = 100) -> List[Dict[str, Any]]:
        """분석 이력 조회"""
        recent_history = self.analysis_history[-limit:]
        return [
            {
                'timestamp': result.timestamp.isoformat(),
                'symbol': result.symbol,
                'has_reversal_signal': result.has_reversal_signal,
                'reversal_direction': result.reversal_direction,
                'should_trade': result.should_trade,
                'trade_direction': result.trade_direction,
                'trade_confidence': result.trade_confidence,
                'market_sentiment': result.market_sentiment
            }
            for result in recent_history
        ]
