#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MT5 코드 파서
MT5 EA 코드에서 최적화 가능한 파라미터를 추출합니다.
"""

import re
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, field


@dataclass
class MT5ParameterInfo:
    """MT5 파라미터 정보"""
    name: str
    type: str  # int, double, bool, string, enum
    default_value: Any
    min_value: Optional[float] = None
    max_value: Optional[float] = None
    step: Optional[float] = None
    options: List[str] = field(default_factory=list)
    group: Optional[str] = None
    description: Optional[str] = None
    is_optimizable: bool = True


class MT5CodeParser:
    """MT5 코드 파서"""
    
    def __init__(self):
        # MT5 input 패턴
        self.patterns = {
            'input_int': re.compile(r'input\s+int\s+(\w+)\s*=\s*([^;]+);'),
            'input_double': re.compile(r'input\s+double\s+(\w+)\s*=\s*([^;]+);'),
            'input_bool': re.compile(r'input\s+bool\s+(\w+)\s*=\s*([^;]+);'),
            'input_string': re.compile(r'input\s+string\s+(\w+)\s*=\s*"([^"]+)";'),
            'input_enum': re.compile(r'input\s+(\w+)\s+(\w+)\s*=\s*([^;]+);'),
        }
        
        # 주석에서 추가 정보 추출
        self.comment_pattern = re.compile(r'//\s*([^=]+)=([^;]+)')
    
    def parse(self, code: str) -> List[MT5ParameterInfo]:
        """
        MT5 코드를 파싱하여 파라미터 정보 추출
        
        Args:
            code: MT5 코드
            
        Returns:
            파라미터 정보 리스트
        """
        parameters = []
        
        # 각 input 타입별로 파싱
        for input_type, pattern in self.patterns.items():
            matches = pattern.finditer(code)
            for match in matches:
                param = self._parse_input(match, input_type, code)
                if param:
                    parameters.append(param)
        
        return parameters
    
    def _parse_input(self, match: re.Match, input_type: str, code: str) -> Optional[MT5ParameterInfo]:
        """
        input 구문 파싱
        
        Args:
            match: 정규식 매치 객체
            input_type: input 타입
            code: 전체 코드 (주석 정보 추출용)
            
        Returns:
            MT5ParameterInfo 객체 또는 None
        """
        try:
            name = match.group(1)
            default_str = match.group(2) if len(match.groups()) > 1 else match.group(2)
            
            # 기본값 파싱
            default_value = self._parse_default_value(default_str, input_type)
            
            # 주석에서 추가 정보 추출
            line_start = match.start()
            line_end = code.find(';', line_start)
            line = code[line_start:line_end] if line_end != -1 else code[line_start:]
            
            # group 추출
            group_match = re.search(r'group\s*=\s*"([^"]+)"', line)
            group = group_match.group(1) if group_match else None
            
            # description 추출
            desc_match = re.search(r'description\s*=\s*"([^"]+)"', line)
            description = desc_match.group(1) if desc_match else None
            
            # min, max, step 추출 (주석 또는 코드에서)
            min_value = self._extract_value(line, 'min')
            max_value = self._extract_value(line, 'max')
            step = self._extract_value(line, 'step')
            
            # enum 타입의 경우 options 추출
            options = []
            if input_type == 'input_enum':
                enum_name = match.group(2)
                # enum 정의 찾기
                enum_pattern = rf'enum\s+{enum_name}\s*{{([^}}]+)}}'
                enum_match = re.search(enum_pattern, code)
                if enum_match:
                    enum_body = enum_match.group(1)
                    # enum 항목 추출
                    for item in enum_body.split(','):
                        item = item.strip()
                        if '=' in item:
                            item = item.split('=')[0].strip()
                        options.append(item)
            
            # 최적화 가능 여부 판단
            is_optimizable = self._is_optimizable(name, input_type, group)
            
            return MT5ParameterInfo(
                name=name,
                type=input_type.replace('input_', ''),
                default_value=default_value,
                min_value=min_value,
                max_value=max_value,
                step=step,
                options=options,
                group=group,
                description=description,
                is_optimizable=is_optimizable
            )
        except Exception as e:
            print(f"파싱 오류: {match.group(0)} - {e}")
        
        return None
    
    def _parse_default_value(self, value_str: str, input_type: str) -> Any:
        """기본값 문자열 파싱"""
        value_str = value_str.strip()
        
        if input_type == 'input_int':
            # 숫자만 추출
            match = re.search(r'(\d+)', value_str)
            return int(match.group(1)) if match else 0
        elif input_type == 'input_double':
            # 숫자 추출 (소수점 포함)
            match = re.search(r'(\d+\.?\d*)', value_str)
            return float(match.group(1)) if match else 0.0
        elif input_type == 'input_bool':
            return 'true' in value_str.lower() or value_str.strip() == 'true'
        elif input_type == 'input_string':
            # 따옴표 제거
            return value_str.strip('"\'')
        elif input_type == 'input_enum':
            # enum 값 추출
            match = re.search(r'(\w+)', value_str)
            return match.group(1) if match else None
        
        return None
    
    def _extract_value(self, line: str, key: str) -> Optional[float]:
        """라인에서 특정 키의 값 추출"""
        # 주석 형식: // min=10
        comment_pattern = rf'//\s*{key}\s*=\s*(\d+\.?\d*)'
        match = re.search(comment_pattern, line)
        if match:
            return float(match.group(1))
        
        # 코드 형식: min=10
        code_pattern = rf'{key}\s*=\s*(\d+\.?\d*)'
        match = re.search(code_pattern, line)
        if match:
            return float(match.group(1))
        
        return None
    
    def _is_optimizable(self, name: str, input_type: str, group: str) -> bool:
        """파라미터가 최적화 가능한지 판단"""
        # 최적화 불가능한 키워드
        non_optimizable_keywords = [
            'MagicNumber', 'magic',
            'Slippage', 'slippage',
            'Color', 'color',
            'Show', 'show',
            'Display', 'display',
            'Position', 'position',
            'Size', 'size',
            'Font', 'font',
        ]
        
        # 그룹이 UI 관련인 경우
        ui_groups = ['Visual', 'Display', 'Chart', 'UI']
        if group and any(ui in group for ui in ui_groups):
            return False
        
        # 이름에 최적화 불가능한 키워드가 포함된 경우
        if any(keyword in name for keyword in non_optimizable_keywords):
            return False
        
        return True
    
    def get_optimization_ranges(self, parameters: List[MT5ParameterInfo]) -> Dict[str, Dict]:
        """최적화 가능한 파라미터의 범위 추출"""
        ranges = {}
        
        for param in parameters:
            if not param.is_optimizable:
                continue
            
            range_info = {
                'type': param.type,
                'default': param.default_value,
            }
            
            # 범위 설정
            if param.min_value is not None:
                range_info['min'] = param.min_value
            if param.max_value is not None:
                range_info['max'] = param.max_value
            if param.step is not None:
                range_info['step'] = param.step
            
            # bool 타입의 경우
            if param.type == 'bool':
                range_info['options'] = [True, False]
            
            # enum/string 타입의 경우
            if param.options:
                range_info['options'] = param.options
            
            # 기본 범위 설정
            if param.type == 'int' and param.min_value is None:
                if param.default_value:
                    range_info['min'] = max(1, int(param.default_value * 0.5))
                    range_info['max'] = int(param.default_value * 2)
                    range_info['step'] = 1
            
            if param.type == 'double' and param.min_value is None:
                if param.default_value:
                    range_info['min'] = param.default_value * 0.5
                    range_info['max'] = param.default_value * 2.0
                    range_info['step'] = param.default_value * 0.1
            
            ranges[param.name] = range_info
        
        return ranges


def parse_mt5_file(filepath: str) -> Dict[str, Any]:
    """
    MT5 파일을 파싱하여 파라미터 정보 반환
    
    Args:
        filepath: MT5 파일 경로
        
    Returns:
        파싱 결과 딕셔너리
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        code = f.read()
    
    parser = MT5CodeParser()
    parameters = parser.parse(code)
    ranges = parser.get_optimization_ranges(parameters)
    
    return {
        'parameters': [p.__dict__ for p in parameters],
        'optimization_ranges': ranges,
        'total_parameters': len(parameters),
        'optimizable_parameters': len([p for p in parameters if p.is_optimizable])
    }


if __name__ == '__main__':
    # 테스트
    test_code = """
    input int LongBBLength = 15;  // min=10 max=30 step=2
    input double LongBBDev = 2.0;  // min=1.5 max=3.0 step=0.2
    input bool ActiveLong = true;
    input group "=== 손절/익절 설정 ==="
    input double LongTPPerc = 0.02;  // min=0.01 max=0.05 step=0.01
    """
    
    parser = MT5CodeParser()
    params = parser.parse(test_code)
    ranges = parser.get_optimization_ranges(params)
    
    print("파싱된 파라미터:")
    for param in params:
        print(f"  {param.name}: {param.type} = {param.default_value} (최적화: {param.is_optimizable})")
    
    print("\n최적화 범위:")
    for name, range_info in ranges.items():
        print(f"  {name}: {range_info}")

