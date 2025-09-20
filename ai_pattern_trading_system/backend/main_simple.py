"""
AI Pattern Trading System - 간단한 버전
기본 웹 서버만 실행하여 테스트
"""

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import uvicorn
import asyncio
import json
from datetime import datetime
from typing import List, Dict, Any
import logging

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# FastAPI 앱 생성
app = FastAPI(
    title="AI Pattern Trading System - Simple",
    description="간단한 AI 패턴 거래 시스템",
    version="1.0.0"
)

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://127.0.0.1:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 전역 변수들
active_connections: List[WebSocket] = []
is_auto_trading = False
trading_stats = {
    "total_trades": 0,
    "winning_trades": 0,
    "losing_trades": 0,
    "total_profit": 0.0,
    "win_rate": 0.0,
    "active_positions": 0,
    "daily_trade_count": 0,
    "max_daily_trades": 10
}

# WebSocket 연결 관리
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        logger.info(f"🔌 WebSocket 연결됨. 총 연결 수: {len(self.active_connections)}")

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)
        logger.info(f"🔌 WebSocket 연결 해제됨. 총 연결 수: {len(self.active_connections)}")

    async def broadcast(self, message: dict):
        """모든 연결된 클라이언트에게 메시지 전송"""
        for connection in self.active_connections:
            try:
                await connection.send_text(json.dumps(message))
            except:
                # 연결이 끊어진 경우 제거
                self.disconnect(connection)

manager = ConnectionManager()

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """실시간 데이터 전송을 위한 WebSocket 엔드포인트"""
    await manager.connect(websocket)
    
    try:
        while True:
            # 클라이언트로부터 메시지 수신
            data = await websocket.receive_text()
            message = json.loads(data)
            
            # 메시지 타입에 따른 처리
            if message.get("type") == "start_analysis":
                await start_real_time_analysis()
            elif message.get("type") == "stop_analysis":
                await stop_real_time_analysis()
            elif message.get("type") == "get_patterns":
                await send_pattern_info()
                
    except WebSocketDisconnect:
        manager.disconnect(websocket)

async def start_real_time_analysis():
    """실시간 분석 시작"""
    logger.info("🔍 실시간 AI 분석 시작")
    
    # 실시간 분석 루프 시작
    asyncio.create_task(real_time_analysis_loop())

async def stop_real_time_analysis():
    """실시간 분석 중지"""
    logger.info("⏹️ 실시간 AI 분석 중지")

async def real_time_analysis_loop():
    """실시간 분석 메인 루프 (시뮬레이션)"""
    import random
    
    while True:
        try:
            # 시뮬레이션 데이터 생성
            analysis_result = {
                "timestamp": datetime.now().isoformat(),
                "symbol": "BTC/USDT",
                "timeframe": "1h",
                "has_reversal_signal": random.random() > 0.7,
                "reversal_direction": random.choice(["bullish", "bearish", "none"]),
                "reversal_confidence": round(random.uniform(0.6, 0.95), 2),
                "pattern_similarity": round(random.uniform(0.7, 0.95), 2),
                "pattern_confidence": round(random.uniform(0.7, 0.95), 2),
                "expected_profit": round(random.uniform(20, 100), 2),
                "should_trade": random.random() > 0.8,
                "trade_direction": random.choice(["buy", "sell", "none"]),
                "trade_confidence": round(random.uniform(0.7, 0.95), 2),
                "market_sentiment": random.choice(["bullish", "bearish", "neutral"]),
                "technical_indicators": {
                    "rsi": round(random.uniform(30, 70), 2),
                    "macd": round(random.uniform(-0.01, 0.01), 4),
                    "adx": round(random.uniform(20, 50), 2),
                    "bb_position": round(random.uniform(0.2, 0.8), 2)
                }
            }
            
            # WebSocket으로 실시간 결과 전송
            await manager.broadcast({
                "type": "analysis_result",
                "timestamp": datetime.now().isoformat(),
                "data": analysis_result
            })
            
            # 3초마다 분석
            await asyncio.sleep(3)
            
        except Exception as e:
            logger.error(f"❌ 실시간 분석 오류: {e}")
            await asyncio.sleep(5)

async def send_pattern_info():
    """저장된 패턴 정보 전송 (시뮬레이션)"""
    patterns = [
        {
            "pattern_id": "pattern_1",
            "symbol": "BTC/USDT",
            "timeframe": "1h",
            "direction": "bullish",
            "profit_pips": 75.5,
            "success_rate": 0.85,
            "confidence_score": 0.92,
            "created_at": datetime.now().isoformat()
        },
        {
            "pattern_id": "pattern_2",
            "symbol": "ETH/USDT",
            "timeframe": "4h",
            "direction": "bearish",
            "profit_pips": 120.3,
            "success_rate": 0.78,
            "confidence_score": 0.88,
            "created_at": datetime.now().isoformat()
        }
    ]
    
    await manager.broadcast({
        "type": "pattern_info",
        "patterns": patterns
    })

# REST API 엔드포인트들
@app.get("/")
async def root():
    """서버 상태 확인"""
    return {
        "message": "AI Pattern Trading System - Simple Version",
        "status": "running",
        "timestamp": datetime.now().isoformat(),
        "version": "1.0.0"
    }

@app.get("/api/patterns")
async def get_patterns():
    """추출된 패턴 목록 조회 (시뮬레이션)"""
    patterns = [
        {
            "pattern_id": "pattern_1",
            "symbol": "BTC/USDT",
            "timeframe": "1h",
            "direction": "bullish",
            "profit_pips": 75.5,
            "success_rate": 0.85,
            "confidence_score": 0.92
        },
        {
            "pattern_id": "pattern_2",
            "symbol": "ETH/USDT",
            "timeframe": "4h",
            "direction": "bearish",
            "profit_pips": 120.3,
            "success_rate": 0.78,
            "confidence_score": 0.88
        }
    ]
    
    return {
        "patterns": patterns,
        "total_count": len(patterns)
    }

@app.get("/api/analysis/current")
async def get_current_analysis():
    """현재 분석 결과 조회 (시뮬레이션)"""
    import random
    
    return {
        "timestamp": datetime.now().isoformat(),
        "symbol": "BTC/USDT",
        "has_reversal_signal": random.random() > 0.7,
        "reversal_direction": random.choice(["bullish", "bearish", "none"]),
        "reversal_confidence": round(random.uniform(0.6, 0.95), 2),
        "pattern_similarity": round(random.uniform(0.7, 0.95), 2),
        "pattern_confidence": round(random.uniform(0.7, 0.95), 2),
        "expected_profit": round(random.uniform(20, 100), 2),
        "should_trade": random.random() > 0.8,
        "trade_direction": random.choice(["buy", "sell", "none"]),
        "trade_confidence": round(random.uniform(0.7, 0.95), 2),
        "market_sentiment": random.choice(["bullish", "bearish", "neutral"])
    }

@app.post("/api/trading/start")
async def start_trading():
    """자동 거래 시작 (시뮬레이션)"""
    global is_auto_trading
    is_auto_trading = True
    return {"message": "자동 거래 시작됨 (시뮬레이션 모드)"}

@app.post("/api/trading/stop")
async def stop_trading():
    """자동 거래 중지"""
    global is_auto_trading
    is_auto_trading = False
    return {"message": "자동 거래 중지됨"}

@app.get("/api/trading/status")
async def get_trading_status():
    """거래 상태 조회"""
    return {
        "is_auto_trading": is_auto_trading,
        "active_positions": trading_stats["active_positions"],
        "active_orders": 0,
        "daily_trade_count": trading_stats["daily_trade_count"],
        "max_daily_trades": trading_stats["max_daily_trades"],
        "total_trades": trading_stats["total_trades"],
        "winning_trades": trading_stats["winning_trades"],
        "losing_trades": trading_stats["losing_trades"],
        "win_rate": trading_stats["win_rate"],
        "total_profit": trading_stats["total_profit"],
        "avg_profit": trading_stats["total_profit"] / max(trading_stats["total_trades"], 1),
        "max_drawdown": 0.0,
        "positions": []
    }

if __name__ == "__main__":
    print("🚀 AI Pattern Trading System - Simple Version 시작!")
    print("📊 웹 인터페이스: http://localhost:3000")
    print("🔧 API 문서: http://localhost:8000/docs")
    print("⚠️  시뮬레이션 모드로 실행 중")
    
    uvicorn.run(
        "main_simple:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
