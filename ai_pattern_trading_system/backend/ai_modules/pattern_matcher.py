"""
패턴 매칭기 - 실시간 차트와 성공 패턴 비교
진짜 AI 기반으로 유사도 90% 이상일 때만 매칭
"""

import numpy as np
from typing import List, Dict, Any, Tuple, Optional
import logging
from dataclasses import dataclass
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.preprocessing import StandardScaler
import cv2

logger = logging.getLogger(__name__)

@dataclass
class MatchResult:
    """패턴 매칭 결과"""
    pattern_id: str
    similarity_score: float
    confidence: float
    expected_profit: float
    pattern_type: str
    direction: str
    technical_similarity: float
    image_similarity: float
    is_match: bool

class PatternMatcher:
    """패턴 매칭기 - 진짜 AI 기반"""
    
    def __init__(self):
        self.similarity_threshold = 0.9  # 90% 이상 유사도
        self.confidence_threshold = 0.8  # 80% 이상 신뢰도
        self.scaler = StandardScaler()
        
    def match_patterns(
        self, 
        current_data: np.ndarray, 
        current_image_features: np.ndarray,
        current_technical_features: Dict[str, float],
        successful_patterns: List[Any]
    ) -> List[MatchResult]:
        """현재 데이터와 성공 패턴들 매칭"""
        
        if not successful_patterns:
            return []
        
        match_results = []
        
        for pattern in successful_patterns:
            try:
                # 1. 가격 곡선 유사도 계산
                price_similarity = self._calculate_price_similarity(
                    current_data, pattern.price_points
                )
                
                # 2. 이미지 특징 유사도 계산
                image_similarity = self._calculate_image_similarity(
                    current_image_features, pattern.image_features
                )
                
                # 3. 기술적 특징 유사도 계산
                technical_similarity = self._calculate_technical_similarity(
                    current_technical_features, pattern.technical_features
                )
                
                # 4. 종합 유사도 계산 (가중 평균)
                total_similarity = (
                    price_similarity * 0.4 +      # 가격 곡선 40%
                    image_similarity * 0.3 +      # 이미지 특징 30%
                    technical_similarity * 0.3    # 기술적 특징 30%
                )
                
                # 5. 신뢰도 계산
                confidence = self._calculate_confidence(
                    total_similarity, 
                    pattern.success_rate, 
                    pattern.confidence_score
                )
                
                # 6. 매칭 여부 결정
                is_match = (
                    total_similarity >= self.similarity_threshold and
                    confidence >= self.confidence_threshold
                )
                
                # 결과 생성
                result = MatchResult(
                    pattern_id=pattern.pattern_id,
                    similarity_score=total_similarity,
                    confidence=confidence,
                    expected_profit=pattern.profit_pips,
                    pattern_type=pattern.pattern_type,
                    direction=pattern.direction,
                    technical_similarity=technical_similarity,
                    image_similarity=image_similarity,
                    is_match=is_match
                )
                
                match_results.append(result)
                
            except Exception as e:
                logger.warning(f"패턴 매칭 오류 {pattern.pattern_id}: {e}")
                continue
        
        # 유사도 순으로 정렬
        match_results.sort(key=lambda x: x.similarity_score, reverse=True)
        
        return match_results
    
    def _calculate_price_similarity(self, current_data: np.ndarray, pattern_data: np.ndarray) -> float:
        """가격 곡선 유사도 계산 - DTW (Dynamic Time Warping) 사용"""
        try:
            # 데이터 길이 맞추기
            min_length = min(len(current_data), len(pattern_data))
            if min_length < 10:
                return 0.0
            
            current_normalized = current_data[:min_length]
            pattern_normalized = pattern_data[:min_length]
            
            # DTW 거리 계산
            dtw_distance = self._dtw_distance(current_normalized, pattern_normalized)
            
            # 거리를 유사도로 변환 (0-1 범위)
            max_distance = min_length * 2  # 최대 가능한 거리
            similarity = max(0, 1 - (dtw_distance / max_distance))
            
            return similarity
            
        except Exception as e:
            logger.warning(f"가격 유사도 계산 오류: {e}")
            return 0.0
    
    def _dtw_distance(self, seq1: np.ndarray, seq2: np.ndarray) -> float:
        """Dynamic Time Warping 거리 계산"""
        n, m = len(seq1), len(seq2)
        
        # DTW 매트릭스 초기화
        dtw_matrix = np.full((n + 1, m + 1), np.inf)
        dtw_matrix[0, 0] = 0
        
        # DTW 계산
        for i in range(1, n + 1):
            for j in range(1, m + 1):
                cost = abs(seq1[i-1] - seq2[j-1])
                dtw_matrix[i, j] = cost + min(
                    dtw_matrix[i-1, j],      # 삽입
                    dtw_matrix[i, j-1],      # 삭제
                    dtw_matrix[i-1, j-1]     # 대체
                )
        
        return dtw_matrix[n, m]
    
    def _calculate_image_similarity(self, current_features: np.ndarray, pattern_features: np.ndarray) -> float:
        """이미지 특징 유사도 계산 - 코사인 유사도 사용"""
        try:
            if len(current_features) == 0 or len(pattern_features) == 0:
                return 0.0
            
            # 특징 벡터 길이 맞추기
            min_length = min(len(current_features), len(pattern_features))
            current_vec = current_features[:min_length].reshape(1, -1)
            pattern_vec = pattern_features[:min_length].reshape(1, -1)
            
            # 코사인 유사도 계산
            similarity = cosine_similarity(current_vec, pattern_vec)[0][0]
            
            return max(0, similarity)  # 음수 방지
            
        except Exception as e:
            logger.warning(f"이미지 유사도 계산 오류: {e}")
            return 0.0
    
    def _calculate_technical_similarity(self, current_features: Dict[str, float], pattern_features: Dict[str, float]) -> float:
        """기술적 특징 유사도 계산"""
        try:
            # 공통 키만 사용
            common_keys = set(current_features.keys()) & set(pattern_features.keys())
            if not common_keys:
                return 0.0
            
            current_values = []
            pattern_values = []
            
            for key in common_keys:
                current_values.append(current_features[key])
                pattern_values.append(pattern_features[key])
            
            # 배열로 변환
            current_array = np.array(current_values).reshape(1, -1)
            pattern_array = np.array(pattern_values).reshape(1, -1)
            
            # 정규화
            current_normalized = self.scaler.fit_transform(current_array)
            pattern_normalized = self.scaler.fit_transform(pattern_array)
            
            # 코사인 유사도 계산
            similarity = cosine_similarity(current_normalized, pattern_normalized)[0][0]
            
            return max(0, similarity)
            
        except Exception as e:
            logger.warning(f"기술적 유사도 계산 오류: {e}")
            return 0.0
    
    def _calculate_confidence(
        self, 
        similarity: float, 
        pattern_success_rate: float, 
        pattern_confidence: float
    ) -> float:
        """종합 신뢰도 계산"""
        try:
            # 가중 평균으로 신뢰도 계산
            confidence = (
                similarity * 0.5 +           # 유사도 50%
                pattern_success_rate * 0.3 +  # 패턴 성공률 30%
                pattern_confidence * 0.2      # 패턴 신뢰도 20%
            )
            
            return min(1.0, max(0.0, confidence))
            
        except Exception as e:
            logger.warning(f"신뢰도 계산 오류: {e}")
            return 0.0
    
    def find_best_match(self, match_results: List[MatchResult]) -> Optional[MatchResult]:
        """가장 좋은 매칭 결과 반환"""
        if not match_results:
            return None
        
        # 매칭된 결과만 필터링
        matched_results = [r for r in match_results if r.is_match]
        
        if not matched_results:
            return None
        
        # 신뢰도 순으로 정렬
        matched_results.sort(key=lambda x: x.confidence, reverse=True)
        
        return matched_results[0]
    
    def get_match_statistics(self, match_results: List[MatchResult]) -> Dict[str, Any]:
        """매칭 통계 정보 반환"""
        if not match_results:
            return {
                'total_patterns': 0,
                'matched_patterns': 0,
                'match_rate': 0.0,
                'avg_similarity': 0.0,
                'avg_confidence': 0.0
            }
        
        matched_results = [r for r in match_results if r.is_match]
        
        return {
            'total_patterns': len(match_results),
            'matched_patterns': len(matched_results),
            'match_rate': len(matched_results) / len(match_results),
            'avg_similarity': np.mean([r.similarity_score for r in match_results]),
            'avg_confidence': np.mean([r.confidence for r in match_results]),
            'best_similarity': max([r.similarity_score for r in match_results]) if match_results else 0.0,
            'best_confidence': max([r.confidence for r in match_results]) if match_results else 0.0
        }
