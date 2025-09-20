"""
AI Pattern Trading System - Main Backend Application
진짜 AI 기반 패턴 거래 시스템의 메인 서버
"""

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import uvicorn
import asyncio
import json
import psutil
import gc
import os
from datetime import datetime
from typing import List, Dict, Any
import logging

# AI 모듈들
from ai_modules.pattern_extractor import PatternExtractor
from ai_modules.pattern_matcher import PatternMatcher
from ai_modules.real_time_analyzer import RealTimeAnalyzer
from trading.trade_executor import TradeExecutor
from data.data_manager import DataManager

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/trading_bot.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# 에러 로깅을 위한 별도 핸들러
error_handler = logging.FileHandler('logs/error.log', encoding='utf-8')
error_handler.setLevel(logging.ERROR)
error_handler.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))
logger.addHandler(error_handler)

# FastAPI 앱 생성
app = FastAPI(
    title="AI Pattern Trading System",
    description="진짜 AI 기반 패턴 거래 시스템",
    version="1.0.0"
)

# CORS 설정 (프론트엔드와 통신)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://127.0.0.1:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 전역 변수들
pattern_extractor = None
pattern_matcher = None
real_time_analyzer = None
trade_executor = None
data_manager = None
active_connections: List[WebSocket] = []

@app.on_event("startup")
async def startup_event():
    """서버 시작 시 AI 모듈들 초기화"""
    global pattern_extractor, pattern_matcher, real_time_analyzer, trade_executor, data_manager
    
    logger.info("🚀 AI Pattern Trading System 시작 중...")
    
    try:
        # 데이터 매니저 초기화
        data_manager = DataManager()
        await data_manager.initialize()
        
        # AI 모듈들 초기화
        pattern_extractor = PatternExtractor(data_manager)
        pattern_matcher = PatternMatcher()
        real_time_analyzer = RealTimeAnalyzer(pattern_matcher)
        trade_executor = TradeExecutor()
        
        # 5-10년 과거 데이터에서 성공 패턴 추출
        logger.info("📊 과거 데이터에서 성공 패턴 추출 중...")
        await pattern_extractor.extract_successful_patterns()
        
        logger.info("✅ AI 시스템 초기화 완료!")
        
    except Exception as e:
        logger.error(f"❌ 초기화 실패: {e}")
        raise

@app.on_event("shutdown")
async def shutdown_event():
    """서버 종료 시 정리 작업"""
    logger.info("🛑 AI Pattern Trading System 종료 중...")
    
    try:
        # 모든 WebSocket 연결 종료
        for connection in manager.active_connections:
            try:
                await connection.close()
            except Exception as e:
                logger.warning(f"⚠️ 연결 종료 중 오류: {e}")
        
        # AI 모듈들 정리
        if real_time_analyzer:
            try:
                await real_time_analyzer.cleanup()
            except Exception as e:
                logger.warning(f"⚠️ 실시간 분석기 정리 중 오류: {e}")
        
        if trade_executor:
            try:
                await trade_executor.cleanup()
            except Exception as e:
                logger.warning(f"⚠️ 거래 실행기 정리 중 오류: {e}")
        
        if data_manager:
            try:
                await data_manager.cleanup()
            except Exception as e:
                logger.warning(f"⚠️ 데이터 매니저 정리 중 오류: {e}")
        
        # 연결 상태 초기화
        manager.active_connections.clear()
        manager.connection_health.clear()
        
        logger.info("✅ 종료 완료")
        
    except Exception as e:
        logger.error(f"❌ 종료 중 오류: {e}")

# WebSocket 연결 관리
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []
        self.connection_health: Dict[WebSocket, datetime] = {}
        self.max_retry_attempts = 3
        self.retry_delay = 5  # seconds

    async def connect(self, websocket: WebSocket):
        try:
            await websocket.accept()
            self.active_connections.append(websocket)
            self.connection_health[websocket] = datetime.now()
            logger.info(f"🔌 WebSocket 연결됨. 총 연결 수: {len(self.active_connections)}")
        except Exception as e:
            logger.error(f"❌ WebSocket 연결 실패: {e}")

    def disconnect(self, websocket: WebSocket):
        try:
            if websocket in self.active_connections:
                self.active_connections.remove(websocket)
            if websocket in self.connection_health:
                del self.connection_health[websocket]
            logger.info(f"🔌 WebSocket 연결 해제됨. 총 연결 수: {len(self.active_connections)}")
        except Exception as e:
            logger.error(f"❌ WebSocket 연결 해제 중 오류: {e}")

    async def broadcast(self, message: dict):
        """모든 연결된 클라이언트에게 메시지 전송"""
        disconnected_connections = []
        
        for connection in self.active_connections:
            try:
                await connection.send_text(json.dumps(message))
                # 연결 상태 업데이트
                self.connection_health[connection] = datetime.now()
            except Exception as e:
                logger.warning(f"⚠️ 메시지 전송 실패: {e}")
                disconnected_connections.append(connection)
        
        # 끊어진 연결들 정리
        for connection in disconnected_connections:
            self.disconnect(connection)

    async def check_connection_health(self):
        """연결 상태 체크 및 정리"""
        current_time = datetime.now()
        unhealthy_connections = []
        
        for connection, last_seen in self.connection_health.items():
            # 30초 이상 응답이 없으면 비정상 연결로 간주
            if (current_time - last_seen).seconds > 30:
                unhealthy_connections.append(connection)
        
        for connection in unhealthy_connections:
            logger.warning(f"⚠️ 비정상 연결 감지, 제거 중: {connection}")
            self.disconnect(connection)

    async def get_connection_stats(self):
        """연결 통계 반환"""
        return {
            "total_connections": len(self.active_connections),
            "healthy_connections": len(self.connection_health),
            "connection_details": [
                {
                    "last_seen": last_seen.isoformat(),
                    "is_healthy": (datetime.now() - last_seen).seconds < 30
                }
                for last_seen in self.connection_health.values()
            ]
        }

manager = ConnectionManager()

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """실시간 데이터 전송을 위한 WebSocket 엔드포인트"""
    await manager.connect(websocket)
    
    try:
        while True:
            try:
                # 클라이언트로부터 메시지 수신 (타임아웃 설정)
                data = await asyncio.wait_for(websocket.receive_text(), timeout=30.0)
                message = json.loads(data)
                
                # 메시지 타입에 따른 처리
                if message.get("type") == "start_analysis":
                    await start_real_time_analysis()
                elif message.get("type") == "stop_analysis":
                    await stop_real_time_analysis()
                elif message.get("type") == "get_patterns":
                    await send_pattern_info()
                elif message.get("type") == "ping":
                    # 연결 상태 확인용 핑 메시지
                    await websocket.send_text(json.dumps({"type": "pong", "timestamp": datetime.now().isoformat()}))
                
            except asyncio.TimeoutError:
                # 타임아웃 시 핑 메시지 전송
                await websocket.send_text(json.dumps({"type": "ping", "timestamp": datetime.now().isoformat()}))
                
    except WebSocketDisconnect:
        logger.info("🔌 클라이언트가 연결을 종료했습니다.")
        manager.disconnect(websocket)
    except Exception as e:
        logger.error(f"❌ WebSocket 오류: {e}")
        manager.disconnect(websocket)
    finally:
        # 연결 정리
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
    """실시간 분석 메인 루프"""
    analysis_active = True
    consecutive_errors = 0
    max_consecutive_errors = 5
    
    while analysis_active:
        try:
            # 연결 상태 체크
            await manager.check_connection_health()
            
            # 현재 시장 데이터 가져오기
            current_data = await data_manager.get_current_market_data()
            
            # AI 패턴 분석
            analysis_result = await real_time_analyzer.analyze_patterns(current_data)
            
            # 거래 신호 생성
            if analysis_result.get("should_trade"):
                trade_signal = await trade_executor.generate_trade_signal(analysis_result)
                
                # WebSocket으로 실시간 결과 전송
                await manager.broadcast({
                    "type": "analysis_result",
                    "timestamp": datetime.now().isoformat(),
                    "data": analysis_result,
                    "trade_signal": trade_signal
                })
            
            # 연결 상태 정보 전송
            if len(manager.active_connections) > 0:
                stats = await manager.get_connection_stats()
                await manager.broadcast({
                    "type": "connection_stats",
                    "timestamp": datetime.now().isoformat(),
                    "stats": stats
                })
            
            # 에러 카운터 리셋
            consecutive_errors = 0
            
            # 1초마다 분석
            await asyncio.sleep(1)
            
        except Exception as e:
            consecutive_errors += 1
            logger.error(f"❌ 실시간 분석 오류 ({consecutive_errors}/{max_consecutive_errors}): {e}")
            
            # 연속 에러가 너무 많으면 분석 중지
            if consecutive_errors >= max_consecutive_errors:
                logger.error("❌ 연속 에러가 너무 많아 분석을 중지합니다.")
                analysis_active = False
                break
            
            # 에러 발생 시 대기 시간 증가
            await asyncio.sleep(min(5 * consecutive_errors, 30))

async def send_pattern_info():
    """저장된 패턴 정보 전송"""
    if pattern_extractor:
        patterns = pattern_extractor.get_extracted_patterns()
        await manager.broadcast({
            "type": "pattern_info",
            "patterns": patterns
        })

# REST API 엔드포인트들
@app.get("/")
async def root():
    """서버 상태 확인"""
    return {
        "message": "AI Pattern Trading System",
        "status": "running",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/api/patterns")
async def get_patterns():
    """추출된 패턴 목록 조회"""
    if pattern_extractor:
        return {
            "patterns": pattern_extractor.get_extracted_patterns(),
            "total_count": len(pattern_extractor.get_extracted_patterns())
        }
    return {"patterns": [], "total_count": 0}

@app.get("/api/analysis/current")
async def get_current_analysis():
    """현재 분석 결과 조회"""
    if real_time_analyzer:
        current_data = await data_manager.get_current_market_data()
        result = await real_time_analyzer.analyze_patterns(current_data)
        return result
    return {"error": "분석기가 초기화되지 않음"}

@app.post("/api/trading/start")
async def start_trading():
    """자동 거래 시작"""
    if trade_executor:
        await trade_executor.start_auto_trading()
        return {"message": "자동 거래 시작됨"}
    return {"error": "거래 실행기가 초기화되지 않음"}

@app.post("/api/trading/stop")
async def stop_trading():
    """자동 거래 중지"""
    if trade_executor:
        await trade_executor.stop_auto_trading()
        return {"message": "자동 거래 중지됨"}
    return {"error": "거래 실행기가 초기화되지 않음"}

@app.get("/api/trading/status")
async def get_trading_status():
    """거래 상태 조회"""
    if trade_executor:
        return await trade_executor.get_trading_status()
    return {"status": "not_initialized"}

@app.get("/api/connections/status")
async def get_connection_status():
    """연결 상태 조회"""
    stats = await manager.get_connection_stats()
    return {
        "connection_stats": stats,
        "server_status": "running",
        "timestamp": datetime.now().isoformat()
    }

@app.post("/api/connections/cleanup")
async def cleanup_connections():
    """비정상 연결 정리"""
    await manager.check_connection_health()
    stats = await manager.get_connection_stats()
    return {
        "message": "연결 정리 완료",
        "stats": stats,
        "timestamp": datetime.now().isoformat()
    }

@app.get("/api/system/memory")
async def get_memory_status():
    """메모리 사용량 조회"""
    try:
        process = psutil.Process()
        memory_info = process.memory_info()
        
        return {
            "memory_usage": {
                "rss": memory_info.rss,  # 실제 메모리 사용량 (bytes)
                "vms": memory_info.vms,  # 가상 메모리 사용량 (bytes)
                "percent": process.memory_percent(),  # 메모리 사용률 (%)
                "available": psutil.virtual_memory().available,  # 사용 가능한 메모리
                "total": psutil.virtual_memory().total  # 총 메모리
            },
            "gc_stats": {
                "counts": gc.get_count(),
                "thresholds": gc.get_threshold()
            },
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"❌ 메모리 상태 조회 오류: {e}")
        return {"error": str(e)}

@app.post("/api/system/gc")
async def force_garbage_collection():
    """강제 가비지 컬렉션 실행"""
    try:
        # 가비지 컬렉션 실행
        collected = gc.collect()
        
        # 메모리 상태 조회
        process = psutil.Process()
        memory_info = process.memory_info()
        
        return {
            "message": f"가비지 컬렉션 완료. {collected}개 객체 정리됨",
            "memory_after_gc": {
                "rss": memory_info.rss,
                "percent": process.memory_percent()
            },
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"❌ 가비지 컬렉션 오류: {e}")
        return {"error": str(e)}

@app.get("/api/system/health")
async def get_system_health():
    """시스템 전체 상태 조회"""
    try:
        # 메모리 상태
        process = psutil.Process()
        memory_info = process.memory_info()
        
        # CPU 사용률
        cpu_percent = psutil.cpu_percent(interval=1)
        
        # 연결 상태
        connection_stats = await manager.get_connection_stats()
        
        # 디스크 사용률
        disk_usage = psutil.disk_usage('/')
        
        return {
            "system_health": {
                "status": "healthy" if memory_info.percent < 80 and cpu_percent < 80 else "warning",
                "memory": {
                    "used_percent": memory_info.percent,
                    "used_mb": round(memory_info.rss / 1024 / 1024, 2),
                    "available_mb": round(psutil.virtual_memory().available / 1024 / 1024, 2)
                },
                "cpu": {
                    "usage_percent": cpu_percent,
                    "count": psutil.cpu_count()
                },
                "disk": {
                    "used_percent": round(disk_usage.used / disk_usage.total * 100, 2),
                    "free_gb": round(disk_usage.free / 1024 / 1024 / 1024, 2),
                    "total_gb": round(disk_usage.total / 1024 / 1024 / 1024, 2)
                },
                "connections": connection_stats
            },
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"❌ 시스템 상태 조회 오류: {e}")
        return {"error": str(e), "status": "error"}

@app.get("/api/logs/errors")
async def get_error_logs():
    """최근 에러 로그 조회"""
    try:
        error_log_path = "logs/error.log"
        if not os.path.exists(error_log_path):
            return {"errors": [], "message": "에러 로그 파일이 없습니다."}
        
        with open(error_log_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
            # 최근 50개 에러만 반환
            recent_errors = lines[-50:] if len(lines) > 50 else lines
        
        return {
            "errors": [line.strip() for line in recent_errors if line.strip()],
            "total_count": len(recent_errors),
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"❌ 에러 로그 조회 오류: {e}")
        return {"error": str(e)}

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
