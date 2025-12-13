#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
테스트 기록 관리자 - 백테스트 결과 및 코드 저장/불러오기
"""

import json
import sqlite3
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Optional
from dataclasses import dataclass, asdict
import uuid


@dataclass
class TestRecord:
    """테스트 기록 데이터 클래스"""
    id: str
    timestamp: str
    name: str
    environment: str
    symbol: str
    timeframes: List[str]
    code: str
    parameters: Dict
    results: List[Dict]
    best_result: Optional[Dict] = None
    notes: str = ''
    
    def to_dict(self):
        """딕셔너리로 변환"""
        return asdict(self)
    
    @classmethod
    def from_dict(cls, data: Dict):
        """딕셔너리에서 생성"""
        return cls(**data)


class RecordManager:
    """테스트 기록 관리자"""
    
    def __init__(self, db_path: Optional[Path] = None):
        """
        초기화
        
        Args:
            db_path: 데이터베이스 파일 경로 (None이면 기본 경로 사용)
        """
        if db_path is None:
            base_dir = Path(__file__).parent.parent
            data_dir = base_dir / 'data'
            data_dir.mkdir(exist_ok=True)
            db_path = data_dir / 'test_records.db'
        
        self.db_path = db_path
        self.init_database()
    
    def init_database(self):
        """데이터베이스 초기화"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # 테스트 기록 테이블
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS test_records (
                id TEXT PRIMARY KEY,
                timestamp TEXT NOT NULL,
                name TEXT NOT NULL,
                environment TEXT NOT NULL,
                symbol TEXT NOT NULL,
                timeframes TEXT NOT NULL,
                code TEXT NOT NULL,
                parameters TEXT NOT NULL,
                results TEXT NOT NULL,
                best_result TEXT,
                notes TEXT DEFAULT ''
            )
        ''')
        
        conn.commit()
        conn.close()
    
    def save_record(self, record: TestRecord) -> str:
        """
        테스트 기록 저장
        
        Args:
            record: 테스트 기록
            
        Returns:
            저장된 기록 ID
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # 최고 결과 찾기
        if record.results:
            best = max(record.results, key=lambda x: x.get('metrics', {}).get('total_return', 0))
            record.best_result = best
        
        cursor.execute('''
            INSERT OR REPLACE INTO test_records 
            (id, timestamp, name, environment, symbol, timeframes, code, parameters, results, best_result, notes)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            record.id,
            record.timestamp,
            record.name,
            record.environment,
            record.symbol,
            json.dumps(record.timeframes),
            record.code,
            json.dumps(record.parameters),
            json.dumps(record.results),
            json.dumps(record.best_result) if record.best_result else None,
            record.notes
        ))
        
        conn.commit()
        conn.close()
        
        return record.id
    
    def load_record(self, record_id: str) -> Optional[TestRecord]:
        """
        테스트 기록 불러오기
        
        Args:
            record_id: 기록 ID
            
        Returns:
            테스트 기록 또는 None
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('SELECT * FROM test_records WHERE id = ?', (record_id,))
        row = cursor.fetchone()
        conn.close()
        
        if not row:
            return None
        
        # 컬럼 이름 가져오기
        columns = [desc[0] for desc in cursor.description]
        data = dict(zip(columns, row))
        
        # JSON 필드 파싱
        data['timeframes'] = json.loads(data['timeframes'])
        data['parameters'] = json.loads(data['parameters'])
        data['results'] = json.loads(data['results'])
        if data['best_result']:
            data['best_result'] = json.loads(data['best_result'])
        
        return TestRecord.from_dict(data)
    
    def list_records(self, limit: int = 100, offset: int = 0) -> List[TestRecord]:
        """
        테스트 기록 목록 가져오기
        
        Args:
            limit: 최대 개수
            offset: 시작 위치
            
        Returns:
            테스트 기록 리스트
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT * FROM test_records 
            ORDER BY timestamp DESC 
            LIMIT ? OFFSET ?
        ''', (limit, offset))
        
        rows = cursor.fetchall()
        conn.close()
        
        records = []
        for row in rows:
            columns = [desc[0] for desc in cursor.description]
            data = dict(zip(columns, row))
            
            # JSON 필드 파싱
            data['timeframes'] = json.loads(data['timeframes'])
            data['parameters'] = json.loads(data['parameters'])
            data['results'] = json.loads(data['results'])
            if data['best_result']:
                data['best_result'] = json.loads(data['best_result'])
            
            records.append(TestRecord.from_dict(data))
        
        return records
    
    def delete_record(self, record_id: str) -> bool:
        """
        테스트 기록 삭제
        
        Args:
            record_id: 기록 ID
            
        Returns:
            삭제 성공 여부
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('DELETE FROM test_records WHERE id = ?', (record_id,))
        deleted = cursor.rowcount > 0
        
        conn.commit()
        conn.close()
        
        return deleted
    
    def search_records(self, keyword: str, limit: int = 100) -> List[TestRecord]:
        """
        테스트 기록 검색
        
        Args:
            keyword: 검색 키워드
            limit: 최대 개수
            
        Returns:
            검색된 테스트 기록 리스트
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT * FROM test_records 
            WHERE name LIKE ? OR symbol LIKE ? OR notes LIKE ?
            ORDER BY timestamp DESC 
            LIMIT ?
        ''', (f'%{keyword}%', f'%{keyword}%', f'%{keyword}%', limit))
        
        rows = cursor.fetchall()
        conn.close()
        
        records = []
        for row in rows:
            columns = [desc[0] for desc in cursor.description]
            data = dict(zip(columns, row))
            
            # JSON 필드 파싱
            data['timeframes'] = json.loads(data['timeframes'])
            data['parameters'] = json.loads(data['parameters'])
            data['results'] = json.loads(data['results'])
            if data['best_result']:
                data['best_result'] = json.loads(data['best_result'])
            
            records.append(TestRecord.from_dict(data))
        
        return records
    
    def create_record(self, name: str, environment: str, symbol: str, 
                     timeframes: List[str], code: str, parameters: Dict,
                     results: List[Dict], notes: str = '') -> TestRecord:
        """
        새 테스트 기록 생성
        
        Args:
            name: 기록 이름
            environment: 테스트 환경
            symbol: 심볼
            timeframes: 시간프레임 리스트
            code: 전략 코드
            parameters: 파라미터 딕셔너리
            results: 결과 리스트
            notes: 메모
            
        Returns:
            생성된 테스트 기록
        """
        record = TestRecord(
            id=str(uuid.uuid4()),
            timestamp=datetime.now().isoformat(),
            name=name,
            environment=environment,
            symbol=symbol,
            timeframes=timeframes,
            code=code,
            parameters=parameters,
            results=results,
            notes=notes
        )
        
        return record

