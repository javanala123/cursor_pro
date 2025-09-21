#!/usr/bin/env python3
"""
자동매매봇 테스트 스크립트
"""

from trading_bot import TradingBot
import time

def test_trading_bot():
    """자동매매봇 기본 기능 테스트"""
    print("=== 자동매매봇 테스트 시작 ===\n")
    
    # 봇 초기화
    bot = TradingBot()
    
    # 1. 설정 로드 테스트
    print("1. 설정 로드 테스트:")
    print(f"   초기 자금: {bot.config['initial_cash']:,}원")
    print(f"   감시 종목: {bot.config['watchlist']}")
    print(f"   매매 주기: {bot.config['trading_interval']}초\n")
    
    # 2. 주식 가격 조회 테스트
    print("2. 주식 가격 조회 테스트:")
    for symbol in ["AAPL", "GOOGL", "MSFT"]:
        price = bot.get_stock_price(symbol)
        print(f"   {symbol}: {price}원")
    print()
    
    # 3. 포트폴리오 상태 테스트
    print("3. 초기 포트폴리오 상태:")
    bot.print_portfolio_status()
    
    # 4. 매수 테스트
    print("4. 매수 테스트:")
    test_price = bot.get_stock_price("AAPL")
    test_amount = 10
    success = bot.execute_buy("AAPL", test_price, test_amount)
    print(f"   매수 결과: {'성공' if success else '실패'}")
    bot.print_portfolio_status()
    
    # 5. 매도 테스트
    print("5. 매도 테스트:")
    if "AAPL" in bot.portfolio["stocks"]:
        sell_amount = bot.portfolio["stocks"]["AAPL"]
        sell_price = bot.get_stock_price("AAPL")
        success = bot.execute_sell("AAPL", sell_price, sell_amount)
        print(f"   매도 결과: {'성공' if success else '실패'}")
        bot.print_portfolio_status()
    
    # 6. 단축된 자동매매 사이클 테스트 (3회)
    print("6. 자동매매 사이클 테스트 (3회):")
    for i in range(3):
        print(f"   사이클 {i+1}:")
        bot.run_trading_cycle()
        bot.print_portfolio_status()
        time.sleep(2)  # 짧은 대기
    
    print("=== 자동매매봇 테스트 완료 ===")

if __name__ == "__main__":
    test_trading_bot()