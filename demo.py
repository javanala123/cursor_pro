#!/usr/bin/env python3
"""
자동매매봇 데모 스크립트
실제 동작을 보여주기 위한 짧은 데모
"""

from trading_bot import TradingBot
import time

def run_demo():
    """자동매매봇 데모 실행"""
    print("🤖 자동매매봇 데모 시작!")
    print("=" * 50)
    
    # 데모용 설정으로 봇 생성
    bot = TradingBot()
    
    # 초기 상태 출력
    print("📊 초기 포트폴리오:")
    bot.print_portfolio_status()
    
    print("\n🔄 자동매매 시뮬레이션 시작... (10초간 실행)")
    print("실제 봇은 설정된 주기마다 매매를 수행합니다.")
    
    # 10초간 매매 사이클 실행
    start_time = time.time()
    cycle_count = 0
    
    while time.time() - start_time < 10:
        cycle_count += 1
        print(f"\n--- 매매 사이클 {cycle_count} ---")
        bot.run_trading_cycle()
        
        # 현재 상태 출력
        print("현재 포트폴리오:")
        current_value = bot.get_portfolio_value()
        initial_value = bot.config['initial_cash']
        profit_loss = current_value - initial_value
        profit_rate = (profit_loss / initial_value) * 100
        
        print(f"💰 총 자산: {current_value:,.0f}원")
        print(f"📈 손익: {profit_loss:+,.0f}원 ({profit_rate:+.2f}%)")
        
        time.sleep(3)  # 3초 대기
    
    print(f"\n🏁 데모 완료! ({cycle_count}회 매매 사이클 실행)")
    print("=" * 50)
    
    # 최종 결과
    final_value = bot.get_portfolio_value()
    initial_value = bot.config['initial_cash']
    total_return = final_value - initial_value
    return_rate = (total_return / initial_value) * 100
    
    print("📋 최종 결과:")
    bot.print_portfolio_status()
    print(f"💡 총 수익률: {return_rate:+.2f}%")
    
    if return_rate > 0:
        print("🎉 수익 발생!")
    elif return_rate < 0:
        print("😔 손실 발생 (시뮬레이션입니다)")
    else:
        print("📊 손익 없음")
    
    print("\n✨ 실제 사용시에는 'python trading_bot.py'로 실행하세요!")

if __name__ == "__main__":
    run_demo()