#!/usr/bin/env python3
"""
자동매매봇 (Automated Trading Bot)
간단한 주식 자동매매 시스템
"""

import time
import logging
import json
from datetime import datetime
from typing import Dict, Optional, List
import requests


class TradingBot:
    """자동매매봇 메인 클래스"""
    
    def __init__(self, config_file: str = "config.json"):
        self.config = self.load_config(config_file)
        self.setup_logging()
        self.portfolio = {"cash": self.config.get("initial_cash", 100000), "stocks": {}}
        self.trading_active = False
        
    def load_config(self, config_file: str) -> Dict:
        """설정 파일 로드"""
        try:
            with open(config_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except FileNotFoundError:
            logging.warning(f"설정 파일 {config_file}를 찾을 수 없습니다. 기본 설정을 사용합니다.")
            return {
                "initial_cash": 100000,
                "watchlist": ["AAPL", "GOOGL", "MSFT"],
                "trading_interval": 60,
                "max_position_size": 0.1,
                "stop_loss_percent": 0.05,
                "take_profit_percent": 0.1
            }
    
    def setup_logging(self):
        """로깅 설정"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('trading_bot.log', encoding='utf-8'),
                logging.StreamHandler()
            ]
        )
        
    def get_stock_price(self, symbol: str) -> Optional[float]:
        """주식 가격 조회 (시뮬레이션용)"""
        # 실제 구현에서는 API를 통해 실시간 가격을 가져옴
        # 여기서는 시뮬레이션을 위한 랜덤 가격 생성
        import random
        base_prices = {"AAPL": 150, "GOOGL": 2500, "MSFT": 300}
        base_price = base_prices.get(symbol, 100)
        # ±5% 범위의 랜덤 가격 변동
        variation = random.uniform(-0.05, 0.05)
        return round(base_price * (1 + variation), 2)
    
    def calculate_sma(self, prices: List[float], period: int) -> Optional[float]:
        """단순 이동평균 계산"""
        if len(prices) < period:
            return None
        return sum(prices[-period:]) / period
    
    def analyze_signal(self, symbol: str, prices: List[float]) -> str:
        """매매 신호 분석"""
        if len(prices) < 20:
            return "HOLD"
        
        # 단순한 이동평균 기반 전략
        sma_5 = self.calculate_sma(prices, 5)
        sma_20 = self.calculate_sma(prices, 20)
        
        if sma_5 and sma_20:
            if sma_5 > sma_20 * 1.02:  # 5일선이 20일선보다 2% 이상 위에 있으면
                return "BUY"
            elif sma_5 < sma_20 * 0.98:  # 5일선이 20일선보다 2% 이상 아래에 있으면
                return "SELL"
        
        return "HOLD"
    
    def execute_buy(self, symbol: str, price: float, amount: float) -> bool:
        """매수 실행"""
        total_cost = price * amount
        if self.portfolio["cash"] >= total_cost:
            self.portfolio["cash"] -= total_cost
            if symbol not in self.portfolio["stocks"]:
                self.portfolio["stocks"][symbol] = 0
            self.portfolio["stocks"][symbol] += amount
            
            logging.info(f"매수 실행: {symbol} {amount}주 @ {price}원 (총 {total_cost}원)")
            return True
        else:
            logging.warning(f"매수 실패: 잔고 부족 ({symbol})")
            return False
    
    def execute_sell(self, symbol: str, price: float, amount: float) -> bool:
        """매도 실행"""
        if symbol in self.portfolio["stocks"] and self.portfolio["stocks"][symbol] >= amount:
            self.portfolio["stocks"][symbol] -= amount
            if self.portfolio["stocks"][symbol] == 0:
                del self.portfolio["stocks"][symbol]
            
            total_revenue = price * amount
            self.portfolio["cash"] += total_revenue
            
            logging.info(f"매도 실행: {symbol} {amount}주 @ {price}원 (총 {total_revenue}원)")
            return True
        else:
            logging.warning(f"매도 실패: 보유 주식 부족 ({symbol})")
            return False
    
    def get_portfolio_value(self) -> float:
        """포트폴리오 총 가치 계산"""
        total_value = self.portfolio["cash"]
        for symbol, amount in self.portfolio["stocks"].items():
            price = self.get_stock_price(symbol)
            if price:
                total_value += price * amount
        return total_value
    
    def print_portfolio_status(self):
        """포트폴리오 현황 출력"""
        print("\n=== 포트폴리오 현황 ===")
        print(f"현금: {self.portfolio['cash']:,.0f}원")
        
        if self.portfolio["stocks"]:
            print("보유 주식:")
            for symbol, amount in self.portfolio["stocks"].items():
                price = self.get_stock_price(symbol)
                if price:
                    value = price * amount
                    print(f"  {symbol}: {amount}주 @ {price}원 = {value:,.0f}원")
        
        total_value = self.get_portfolio_value()
        print(f"총 자산: {total_value:,.0f}원")
        print("="*25)
    
    def run_trading_cycle(self):
        """한 번의 매매 사이클 실행"""
        watchlist = self.config.get("watchlist", [])
        price_history = getattr(self, 'price_history', {})
        
        for symbol in watchlist:
            price = self.get_stock_price(symbol)
            if price is None:
                continue
            
            # 가격 히스토리 업데이트
            if symbol not in price_history:
                price_history[symbol] = []
            price_history[symbol].append(price)
            
            # 최근 30개 가격만 유지
            if len(price_history[symbol]) > 30:
                price_history[symbol] = price_history[symbol][-30:]
            
            # 매매 신호 분석
            signal = self.analyze_signal(symbol, price_history[symbol])
            
            # 매매 실행
            if signal == "BUY":
                max_position = self.config.get("max_position_size", 0.1)
                max_investment = self.portfolio["cash"] * max_position
                amount = int(max_investment / price)
                if amount > 0:
                    self.execute_buy(symbol, price, amount)
            
            elif signal == "SELL" and symbol in self.portfolio["stocks"]:
                amount = self.portfolio["stocks"][symbol]
                if amount > 0:
                    self.execute_sell(symbol, price, amount)
        
        self.price_history = price_history
    
    def start_trading(self):
        """자동매매 시작"""
        self.trading_active = True
        logging.info("자동매매봇이 시작되었습니다.")
        
        try:
            while self.trading_active:
                self.run_trading_cycle()
                self.print_portfolio_status()
                
                # 설정된 간격만큼 대기
                interval = self.config.get("trading_interval", 60)
                time.sleep(interval)
                
        except KeyboardInterrupt:
            logging.info("사용자에 의해 자동매매가 중단되었습니다.")
        except Exception as e:
            logging.error(f"자동매매 중 오류 발생: {e}")
        finally:
            self.stop_trading()
    
    def stop_trading(self):
        """자동매매 중단"""
        self.trading_active = False
        logging.info("자동매매봇이 중단되었습니다.")
        self.print_portfolio_status()


if __name__ == "__main__":
    bot = TradingBot()
    print("자동매매봇을 시작합니다...")
    print("중단하려면 Ctrl+C를 누르세요.")
    bot.start_trading()