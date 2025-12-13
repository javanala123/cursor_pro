#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MT5 코드 파서 - 기존 파서 통합
"""

import sys
from pathlib import Path

# 기존 파서 모듈 경로 추가
sys.path.append(str(Path(__file__).parent.parent.parent / 'strategy_parser'))

try:
    from mt5_code_parser import MT5CodeParser as BaseMT5Parser
except ImportError:
    BaseMT5Parser = None


class MT5CodeParser:
    """MT5 코드 파서 래퍼"""
    
    def __init__(self):
        if BaseMT5Parser:
            self.parser = BaseMT5Parser()
        else:
            self.parser = SimpleMT5Parser()
    
    def parse(self, code: str) -> list:
        """
        MT5 코드 파싱
        
        Returns:
            파라미터 정보 리스트 (딕셔너리)
        """
        parameters = self.parser.parse(code)
        
        # 딕셔너리 형식으로 변환
        result = {}
        for param in parameters:
            if hasattr(param, 'name'):
                result[param.name] = {
                    'type': param.type,
                    'default': param.default_value,
                    'min': param.min_value,
                    'max': param.max_value,
                    'step': param.step,
                    'options': param.options,
                    'group': param.group,
                    'description': param.description
                }
            elif isinstance(param, dict):
                result[param.get('name', '')] = param
        
        return result


class SimpleMT5Parser:
    """간단한 MT5 파서 (기존 파서가 없는 경우)"""
    
    def parse(self, code: str) -> list:
        """간단한 파싱"""
        import re
        parameters = []
        
        # input int 패턴
        int_pattern = r'input\s+int\s+(\w+)\s*=\s*(\d+);'
        for match in re.finditer(int_pattern, code):
            name = match.group(1)
            default = int(match.group(2))
            
            # 주석에서 min, max 추출
            line_start = match.start()
            line_end = code.find('\n', line_start)
            line = code[line_start:line_end] if line_end != -1 else code[line_start:]
            
            min_val = self._extract_value(line, 'min')
            max_val = self._extract_value(line, 'max')
            step = self._extract_value(line, 'step') or 1
            
            parameters.append({
                'name': name,
                'type': 'int',
                'default': default,
                'min': min_val or default * 0.5,
                'max': max_val or default * 2,
                'step': step or 1
            })
        
        # input double 패턴
        double_pattern = r'input\s+double\s+(\w+)\s*=\s*(\d+\.?\d*);'
        for match in re.finditer(double_pattern, code):
            name = match.group(1)
            default = float(match.group(2))
            
            line_start = match.start()
            line_end = code.find('\n', line_start)
            line = code[line_start:line_end] if line_end != -1 else code[line_start:]
            
            min_val = self._extract_value(line, 'min')
            max_val = self._extract_value(line, 'max')
            step = self._extract_value(line, 'step') or 0.1
            
            parameters.append({
                'name': name,
                'type': 'float',
                'default': default,
                'min': min_val or default * 0.5,
                'max': max_val or default * 2,
                'step': step or 0.1
            })
        
        return parameters
    
    def _extract_value(self, text: str, key: str):
        """값 추출"""
        import re
        pattern = rf'//\s*{key}\s*=\s*(\d+\.?\d*)'
        match = re.search(pattern, text)
        if match:
            try:
                return float(match.group(1))
            except:
                return None
        return None

