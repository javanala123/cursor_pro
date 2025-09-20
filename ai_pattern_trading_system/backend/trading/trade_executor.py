"""
거래 실행기 - 실제 거래 주문 실행 및 관리
"""

import asyncio
import ccxt
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
import logging
from dataclasses import dataclass
import json

logger = logging.getLogger(__name__)

@dataclass
class TradeOrder:
    """거래 주문 데이터"""
    order_id: str
    symbol: str
    side: str  # 'buy' or 'sell'
    amount: float
    price: float
    order_type: str  # 'market', 'limit'
    status: str  # 'pending', 'filled', 'cancelled'
    created_at: datetime
    filled_at: Optional[datetime] = None
    profit_loss: Optional[float] = None

@dataclass
class TradePosition:
    """포지션 데이터"""
    symbol: str
    side: str
    amount: float
    entry_price: float
    current_price: float
    unrealized_pnl: float
    created_at: datetime

class TradeExecutor:
    """거래 실행기"""
    
    def __init__(self):
        self.exchanges = {
            'binance': ccxt.binance({
                'apiKey': '',  # 실제 API 키 필요
                'secret': '',  # 실제 시크릿 키 필요
                'sandbox': True,  # 테스트 모드
                'enableRateLimit': True,
            })
        }
        
        # 거래 설정
        self.max_position_size = 0.1  # 최대 포지션 크기 (10%)
        self.stop_loss_pct = 0.02  # 손절매 2%
        self.take_profit_pct = 0.04  # 익절매 4%
        self.max_daily_trades = 10  # 일일 최대 거래 수
        
        # 거래 상태
        self.is_auto_trading = False
        self.active_orders: List[TradeOrder] = []
        self.active_positions: List[TradePosition] = []
        self.daily_trade_count = 0
        self.last_trade_date = None
        
        # 거래 통계
        self.total_trades = 0
        self.winning_trades = 0
        self.losing_trades = 0
        self.total_profit = 0.0
        self.max_drawdown = 0.0
    
    async def start_auto_trading(self):
        """자동 거래 시작"""
        self.is_auto_trading = True
        logger.info("🚀 자동 거래 시작")
        
        # 거래 모니터링 루프 시작
        asyncio.create_task(self._monitor_positions())
    
    async def stop_auto_trading(self):
        """자동 거래 중지"""
        self.is_auto_trading = False
        logger.info("⏹️ 자동 거래 중지")
        
        # 모든 미체결 주문 취소
        await self._cancel_all_orders()
    
    async def generate_trade_signal(self, analysis_result: Dict[str, Any]) -> Dict[str, Any]:
        """거래 신호 생성"""
        try:
            if not self.is_auto_trading:
                return {'should_trade': False, 'reason': '자동 거래 비활성화'}
            
            # 일일 거래 수 제한 확인
            if self._is_daily_limit_reached():
                return {'should_trade': False, 'reason': '일일 거래 수 제한'}
            
            # 분석 결과 확인
            should_trade = analysis_result.get('should_trade', False)
            trade_direction = analysis_result.get('trade_direction', 'none')
            trade_confidence = analysis_result.get('trade_confidence', 0.0)
            
            if not should_trade or trade_direction == 'none':
                return {'should_trade': False, 'reason': '거래 신호 없음'}
            
            # 신뢰도 확인
            if trade_confidence < 0.8:
                return {'should_trade': False, 'reason': f'신뢰도 부족: {trade_confidence:.2f}'}
            
            # 거래 실행
            symbol = analysis_result.get('symbol', 'BTC/USDT')
            trade_result = await self._execute_trade(symbol, trade_direction, trade_confidence)
            
            return trade_result
            
        except Exception as e:
            logger.error(f"거래 신호 생성 오류: {e}")
            return {'should_trade': False, 'reason': f'오류: {str(e)}'}
    
    async def _execute_trade(self, symbol: str, direction: str, confidence: float) -> Dict[str, Any]:
        """실제 거래 실행"""
        try:
            # 포지션 크기 계산
            position_size = self._calculate_position_size(symbol, confidence)
            
            if position_size <= 0:
                return {'should_trade': False, 'reason': '포지션 크기 계산 오류'}
            
            # 현재 가격 가져오기
            current_price = await self._get_current_price(symbol)
            if not current_price:
                return {'should_trade': False, 'reason': '현재 가격 조회 실패'}
            
            # 주문 생성
            order = TradeOrder(
                order_id=f"{symbol}_{direction}_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
                symbol=symbol,
                side=direction,
                amount=position_size,
                price=current_price,
                order_type='market',
                status='pending',
                created_at=datetime.now()
            )
            
            # 실제 거래 실행 (테스트 모드에서는 시뮬레이션)
            if self.exchanges['binance'].sandbox:
                # 시뮬레이션 거래
                order.status = 'filled'
                order.filled_at = datetime.now()
                
                # 포지션 생성
                position = TradePosition(
                    symbol=symbol,
                    side=direction,
                    amount=position_size,
                    entry_price=current_price,
                    current_price=current_price,
                    unrealized_pnl=0.0,
                    created_at=datetime.now()
                )
                
                self.active_orders.append(order)
                self.active_positions.append(position)
                self.daily_trade_count += 1
                self.last_trade_date = datetime.now().date()
                self.total_trades += 1
                
                logger.info(f"✅ 시뮬레이션 거래 실행: {symbol} {direction} {position_size} @ {current_price}")
                
                return {
                    'should_trade': True,
                    'order_id': order.order_id,
                    'symbol': symbol,
                    'side': direction,
                    'amount': position_size,
                    'price': current_price,
                    'status': 'filled'
                }
            else:
                # 실제 거래 실행
                exchange = self.exchanges['binance']
                binance_symbol = symbol.replace('/', '')
                
                if direction == 'buy':
                    order_result = await exchange.create_market_buy_order(
                        binance_symbol, position_size
                    )
                else:
                    order_result = await exchange.create_market_sell_order(
                        binance_symbol, position_size
                    )
                
                order.status = 'filled'
                order.filled_at = datetime.now()
                order.order_id = order_result['id']
                
                self.active_orders.append(order)
                self.daily_trade_count += 1
                self.last_trade_date = datetime.now().date()
                self.total_trades += 1
                
                logger.info(f"✅ 실제 거래 실행: {symbol} {direction} {position_size}")
                
                return {
                    'should_trade': True,
                    'order_id': order.order_id,
                    'symbol': symbol,
                    'side': direction,
                    'amount': position_size,
                    'price': current_price,
                    'status': 'filled'
                }
                
        except Exception as e:
            logger.error(f"거래 실행 오류: {e}")
            return {'should_trade': False, 'reason': f'거래 실행 실패: {str(e)}'}
    
    def _calculate_position_size(self, symbol: str, confidence: float) -> float:
        """포지션 크기 계산"""
        try:
            # 기본 포지션 크기
            base_size = self.max_position_size
            
            # 신뢰도에 따른 조정
            confidence_multiplier = min(confidence, 1.0)
            
            # 최종 포지션 크기
            position_size = base_size * confidence_multiplier
            
            # 최소/최대 제한
            position_size = max(0.001, min(position_size, self.max_position_size))
            
            return position_size
            
        except Exception as e:
            logger.error(f"포지션 크기 계산 오류: {e}")
            return 0.0
    
    async def _get_current_price(self, symbol: str) -> Optional[float]:
        """현재 가격 조회"""
        try:
            exchange = self.exchanges['binance']
            binance_symbol = symbol.replace('/', '')
            
            ticker = await exchange.fetch_ticker(binance_symbol)
            return ticker['last']
            
        except Exception as e:
            logger.error(f"현재 가격 조회 오류: {e}")
            return None
    
    def _is_daily_limit_reached(self) -> bool:
        """일일 거래 수 제한 확인"""
        current_date = datetime.now().date()
        
        # 날짜가 바뀌면 카운트 리셋
        if self.last_trade_date != current_date:
            self.daily_trade_count = 0
            self.last_trade_date = current_date
        
        return self.daily_trade_count >= self.max_daily_trades
    
    async def _monitor_positions(self):
        """포지션 모니터링"""
        while self.is_auto_trading:
            try:
                # 활성 포지션 업데이트
                await self._update_positions()
                
                # 손절/익절 확인
                await self._check_stop_loss_take_profit()
                
                # 1초마다 모니터링
                await asyncio.sleep(1)
                
            except Exception as e:
                logger.error(f"포지션 모니터링 오류: {e}")
                await asyncio.sleep(5)
    
    async def _update_positions(self):
        """포지션 업데이트"""
        try:
            for position in self.active_positions:
                # 현재 가격 조회
                current_price = await self._get_current_price(position.symbol)
                if current_price:
                    position.current_price = current_price
                    
                    # 미실현 손익 계산
                    if position.side == 'buy':
                        position.unrealized_pnl = (current_price - position.entry_price) * position.amount
                    else:
                        position.unrealized_pnl = (position.entry_price - current_price) * position.amount
                    
        except Exception as e:
            logger.error(f"포지션 업데이트 오류: {e}")
    
    async def _check_stop_loss_take_profit(self):
        """손절/익절 확인"""
        try:
            positions_to_close = []
            
            for position in self.active_positions:
                # 수익률 계산
                if position.side == 'buy':
                    profit_rate = (position.current_price - position.entry_price) / position.entry_price
                else:
                    profit_rate = (position.entry_price - position.current_price) / position.entry_price
                
                # 손절매 확인
                if profit_rate <= -self.stop_loss_pct:
                    positions_to_close.append((position, 'stop_loss'))
                    logger.info(f"🛑 손절매 신호: {position.symbol} {position.side}")
                
                # 익절매 확인
                elif profit_rate >= self.take_profit_pct:
                    positions_to_close.append((position, 'take_profit'))
                    logger.info(f"💰 익절매 신호: {position.symbol} {position.side}")
            
            # 포지션 청산
            for position, reason in positions_to_close:
                await self._close_position(position, reason)
                
        except Exception as e:
            logger.error(f"손절/익절 확인 오류: {e}")
    
    async def _close_position(self, position: TradePosition, reason: str):
        """포지션 청산"""
        try:
            # 청산 주문 생성
            close_side = 'sell' if position.side == 'buy' else 'buy'
            
            order = TradeOrder(
                order_id=f"close_{position.symbol}_{close_side}_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
                symbol=position.symbol,
                side=close_side,
                amount=position.amount,
                price=position.current_price,
                order_type='market',
                status='filled',
                created_at=datetime.now(),
                filled_at=datetime.now(),
                profit_loss=position.unrealized_pnl
            )
            
            # 거래 통계 업데이트
            if position.unrealized_pnl > 0:
                self.winning_trades += 1
            else:
                self.losing_trades += 1
            
            self.total_profit += position.unrealized_pnl
            
            # 포지션 제거
            self.active_positions.remove(position)
            self.active_orders.append(order)
            
            logger.info(f"✅ 포지션 청산: {position.symbol} {reason} P&L: {position.unrealized_pnl:.2f}")
            
        except Exception as e:
            logger.error(f"포지션 청산 오류: {e}")
    
    async def _cancel_all_orders(self):
        """모든 미체결 주문 취소"""
        try:
            for order in self.active_orders:
                if order.status == 'pending':
                    # 실제 거래소에서 주문 취소
                    if not self.exchanges['binance'].sandbox:
                        exchange = self.exchanges['binance']
                        await exchange.cancel_order(order.order_id, order.symbol)
                    
                    order.status = 'cancelled'
                    logger.info(f"❌ 주문 취소: {order.order_id}")
            
        except Exception as e:
            logger.error(f"주문 취소 오류: {e}")
    
    async def get_trading_status(self) -> Dict[str, Any]:
        """거래 상태 조회"""
        try:
            # 수익률 계산
            win_rate = (self.winning_trades / self.total_trades * 100) if self.total_trades > 0 else 0
            
            # 평균 수익 계산
            avg_profit = self.total_profit / self.total_trades if self.total_trades > 0 else 0
            
            return {
                'is_auto_trading': self.is_auto_trading,
                'active_positions': len(self.active_positions),
                'active_orders': len([o for o in self.active_orders if o.status == 'pending']),
                'daily_trade_count': self.daily_trade_count,
                'max_daily_trades': self.max_daily_trades,
                'total_trades': self.total_trades,
                'winning_trades': self.winning_trades,
                'losing_trades': self.losing_trades,
                'win_rate': win_rate,
                'total_profit': self.total_profit,
                'avg_profit': avg_profit,
                'max_drawdown': self.max_drawdown,
                'positions': [
                    {
                        'symbol': pos.symbol,
                        'side': pos.side,
                        'amount': pos.amount,
                        'entry_price': pos.entry_price,
                        'current_price': pos.current_price,
                        'unrealized_pnl': pos.unrealized_pnl,
                        'created_at': pos.created_at.isoformat()
                    }
                    for pos in self.active_positions
                ]
            }
            
        except Exception as e:
            logger.error(f"거래 상태 조회 오류: {e}")
            return {'error': str(e)}
    
    def get_trade_history(self, limit: int = 100) -> List[Dict[str, Any]]:
        """거래 이력 조회"""
        try:
            # 최근 거래만 반환
            recent_orders = self.active_orders[-limit:]
            
            return [
                {
                    'order_id': order.order_id,
                    'symbol': order.symbol,
                    'side': order.side,
                    'amount': order.amount,
                    'price': order.price,
                    'status': order.status,
                    'created_at': order.created_at.isoformat(),
                    'filled_at': order.filled_at.isoformat() if order.filled_at else None,
                    'profit_loss': order.profit_loss
                }
                for order in recent_orders
            ]
            
        except Exception as e:
            logger.error(f"거래 이력 조회 오류: {e}")
            return []
