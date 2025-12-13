#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Pine Script 파서 - 기존 파서 통합
"""

import sys
from pathlib import Path

# 기존 파서 모듈 경로 추가
sys.path.append(str(Path(__file__).parent.parent.parent / 'strategy_parser'))

try:
    from pine_script_parser import PineScriptParser as BasePineParser
except ImportError:
    # 기존 파서가 없는 경우 간단한 버전 사용
    BasePineParser = None


class PineScriptParser:
    """Pine Script 파서 래퍼"""
    
    def __init__(self):
        if BasePineParser:
            self.parser = BasePineParser()
        else:
            self.parser = SimplePineParser()
    
    def parse(self, code: str) -> dict:
        """
        Pine Script 코드 파싱
        
        Returns:
            파라미터 정보 딕셔너리
        """
        try:
            parameters = self.parser.parse(code)
            
            # 딕셔너리 형식으로 변환
            result = {}
            if isinstance(parameters, list):
                for param in parameters:
                    if hasattr(param, 'name'):
                        result[param.name] = {
                            'type': param.type,
                            'default': param.default_value,
                            'min': param.min_value if param.min_value is not None else (param.default_value * 0.5 if param.default_value else 1),
                            'max': param.max_value if param.max_value is not None else (param.default_value * 2 if param.default_value else 100),
                            'step': param.step if param.step is not None else (1 if param.type == 'int' else 0.1),
                            'options': param.options,
                            'group': param.group,
                            'title': param.title
                        }
                    elif isinstance(param, dict):
                        name = param.get('name', '')
                        if name:
                            result[name] = {
                                'type': param.get('type', 'float'),
                                'default': param.get('default', 0),
                                'min': param.get('min', param.get('default', 0) * 0.5),
                                'max': param.get('max', param.get('default', 0) * 2),
                                'step': param.get('step', 0.1 if param.get('type') == 'float' else 1),
                                'options': param.get('options', []),
                                'group': param.get('group'),
                                'title': param.get('title')
                            }
            elif isinstance(parameters, dict):
                result = parameters
            
            return result
        except Exception as e:
            print(f"파서 오류: {e}")
            return {}


class SimplePineParser:
    """간단한 Pine Script 파서 (기존 파서가 없는 경우)"""
    
    def __init__(self):
        import re
        self.re = re
    
    def parse(self, code: str) -> list:
        """간단한 파싱"""
        import re
        parameters = []
        
        # input.int 패턴 (더 유연한 패턴)
        int_patterns = [
            r'(\w+)\s*=\s*input\.int\(([^)]+)\)',
            r'input\.int\(([^)]+)\)',
            r'(\w+)\s*=\s*input\(int,?\s*([^)]+)\)'
        ]
        
        for pattern in int_patterns:
            for match in re.finditer(pattern, code, re.IGNORECASE):
                if len(match.groups()) >= 2:
                    name = match.group(1) if match.group(1) else 'param'
                    args = match.group(2)
                else:
                    args = match.group(1)
                    # 이름 추출 시도
                    name_match = re.search(r'(\w+)\s*=', args)
                    name = name_match.group(1) if name_match else 'param'
                
                # 기본값 추출 (첫 번째 숫자)
                default_match = re.search(r'(\d+)', args)
                default = int(default_match.group(1)) if default_match else 20
                
                # min, max, step 추출
                min_val = self._extract_value(args, 'minval')
                max_val = self._extract_value(args, 'maxval')
                step = self._extract_value(args, 'step')
                
                if not min_val:
                    min_val = max(1, int(default * 0.5))
                if not max_val:
                    max_val = int(default * 2)
                if not step:
                    step = 1
                
                parameters.append({
                    'name': name,
                    'type': 'int',
                    'default': default,
                    'min': min_val,
                    'max': max_val,
                    'step': step
                })
        
        # input.float 패턴
        float_patterns = [
            r'(\w+)\s*=\s*input\.float\(([^)]+)\)',
            r'input\.float\(([^)]+)\)',
            r'(\w+)\s*=\s*input\(float,?\s*([^)]+)\)'
        ]
        
        for pattern in float_patterns:
            for match in re.finditer(pattern, code, re.IGNORECASE):
                if len(match.groups()) >= 2:
                    name = match.group(1) if match.group(1) else 'param'
                    args = match.group(2)
                else:
                    args = match.group(1)
                    name_match = re.search(r'(\w+)\s*=', args)
                    name = name_match.group(1) if name_match else 'param'
                
                # 기본값 추출 (소수점 포함)
                default_match = re.search(r'(\d+\.?\d*)', args)
                default = float(default_match.group(1)) if default_match else 2.0
                
                min_val = self._extract_value(args, 'minval')
                max_val = self._extract_value(args, 'maxval')
                step = self._extract_value(args, 'step')
                
                if not min_val:
                    min_val = default * 0.5
                if not max_val:
                    max_val = default * 2.0
                if not step:
                    step = 0.1
                
                parameters.append({
                    'name': name,
                    'type': 'float',
                    'default': default,
                    'min': min_val,
                    'max': max_val,
                    'step': step
                })
        
        # input.string 패턴 (옵션 리스트 포함)
        string_patterns = [
            r'(\w+)\s*=\s*input\.string\(([^)]+)\)',
            r'input\.string\(([^)]+)\)'
        ]
        
        for pattern in string_patterns:
            for match in re.finditer(pattern, code, re.IGNORECASE):
                if len(match.groups()) >= 2:
                    name = match.group(1) if match.group(1) else 'param'
                    args = match.group(2)
                else:
                    args = match.group(1)
                    name_match = re.search(r'(\w+)\s*=', args)
                    name = name_match.group(1) if name_match else 'param'
                
                # 기본값 추출 (따옴표 안의 문자열)
                default_match = re.search(r'["\']([^"\']+)["\']', args)
                default = default_match.group(1) if default_match else ''
                
                # 옵션 리스트 추출
                options_match = re.search(r'options\s*=\s*\[([^\]]+)\]', args)
                options = []
                if options_match:
                    options_str = options_match.group(1)
                    # 각 옵션 추출
                    option_matches = re.findall(r'["\']([^"\']+)["\']', options_str)
                    options = option_matches
                
                parameters.append({
                    'name': name,
                    'type': 'string',
                    'default': default,
                    'options': options,
                    'min': None,
                    'max': None,
                    'step': None
                })
        
        # input.bool 패턴
        bool_patterns = [
            r'(\w+)\s*=\s*input\.bool\(([^)]+)\)',
            r'input\.bool\(([^)]+)\)'
        ]
        
        for pattern in bool_patterns:
            for match in re.finditer(pattern, code, re.IGNORECASE):
                if len(match.groups()) >= 2:
                    name = match.group(1) if match.group(1) else 'param'
                    args = match.group(2)
                else:
                    args = match.group(1)
                    name_match = re.search(r'(\w+)\s*=', args)
                    name = name_match.group(1) if name_match else 'param'
                
                # 기본값 추출 (true/false)
                default_match = re.search(r'\b(true|false)\b', args, re.IGNORECASE)
                default = default_match.group(1).lower() == 'true' if default_match else False
                
                parameters.append({
                    'name': name,
                    'type': 'bool',
                    'default': default,
                    'min': None,
                    'max': None,
                    'step': None,
                    'options': None
                })
        
        # input.color 패턴 (최적화 대상이 아니므로 기본값만 저장)
        color_patterns = [
            r'(\w+)\s*=\s*input\.color\(([^)]+)\)',
            r'input\.color\(([^)]+)\)'
        ]
        
        for pattern in color_patterns:
            for match in re.finditer(pattern, code, re.IGNORECASE):
                if len(match.groups()) >= 2:
                    name = match.group(1) if match.group(1) else 'param'
                    args = match.group(2)
                else:
                    args = match.group(1)
                    name_match = re.search(r'(\w+)\s*=', args)
                    name = name_match.group(1) if name_match else 'param'
                
                # 기본값 추출 (color.xxx 형태)
                default_match = re.search(r'color\.(\w+)', args, re.IGNORECASE)
                default = default_match.group(1) if default_match else 'blue'
                
                # color는 최적화 대상이 아니므로 정보만 저장
                parameters.append({
                    'name': name,
                    'type': 'color',
                    'default': default,
                    'min': None,
                    'max': None,
                    'step': None,
                    'options': None
                })
        
        return parameters
    
    def _extract_value(self, text: str, key: str):
        """값 추출"""
        import re
        pattern = rf'{key}\s*=\s*(\d+\.?\d*)'
        match = re.search(pattern, text)
        if match:
            try:
                return float(match.group(1))
            except:
                return None
        return None

