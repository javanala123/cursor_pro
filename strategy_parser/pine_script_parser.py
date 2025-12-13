#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Pine Script 파서
Pine Script 코드에서 최적화 가능한 파라미터를 추출합니다.
"""

import re
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, field


@dataclass
class ParameterInfo:
    """파라미터 정보"""
    name: str
    type: str  # int, float, bool, string
    default_value: Any
    min_value: Optional[float] = None
    max_value: Optional[float] = None
    step: Optional[float] = None
    options: List[str] = field(default_factory=list)
    group: Optional[str] = None
    title: Optional[str] = None
    tooltip: Optional[str] = None
    is_optimizable: bool = True  # 최적화 가능 여부


class PineScriptParser:
    """Pine Script 코드 파서"""
    
    def __init__(self):
        # Pine Script input 패턴
        self.patterns = {
            'input_int': re.compile(r'input\.int\(([^)]+)\)'),
            'input_float': re.compile(r'input\.float\(([^)]+)\)'),
            'input_bool': re.compile(r'input\.bool\(([^)]+)\)'),
            'input_string': re.compile(r'input\.string\(([^)]+)\)'),
            'input_color': re.compile(r'input\.color\(([^)]+)\)'),
        }
    
    def parse(self, code: str) -> List[ParameterInfo]:
        """
        Pine Script 코드를 파싱하여 파라미터 정보 추출
        
        Args:
            code: Pine Script 코드
            
        Returns:
            파라미터 정보 리스트
        """
        parameters = []
        
        # 각 input 타입별로 파싱
        for input_type, pattern in self.patterns.items():
            matches = pattern.finditer(code)
            for match in matches:
                param = self._parse_input(match.group(1), input_type)
                if param:
                    parameters.append(param)
        
        return parameters
    
    def _parse_input(self, args_str: str, input_type: str) -> Optional[ParameterInfo]:
        """
        input 구문 파싱
        
        Args:
            args_str: input 함수의 인자 문자열
            input_type: input 타입 (input_int, input_float 등)
            
        Returns:
            ParameterInfo 객체 또는 None
        """
        try:
            # 기본값 추출
            default_match = re.search(r'(\d+\.?\d*)', args_str)
            default_value = None
            if default_match:
                if input_type == 'input_int':
                    default_value = int(default_match.group(1))
                elif input_type == 'input_float':
                    default_value = float(default_match.group(1))
                elif input_type == 'input_bool':
                    default_value = args_str.strip().startswith('true')
            
            # 이름 추출 (변수명)
            name_match = re.search(r'(\w+)\s*=', args_str)
            name = name_match.group(1) if name_match else None
            
            # title 추출
            title_match = re.search(r'title\s*=\s*["\']([^"\']+)["\']', args_str)
            title = title_match.group(1) if title_match else name
            
            # group 추출
            group_match = re.search(r'group\s*=\s*["\']([^"\']+)["\']', args_str)
            group = group_match.group(1) if group_match else None
            
            # minval, maxval, step 추출
            min_value = self._extract_value(args_str, 'minval')
            max_value = self._extract_value(args_str, 'maxval')
            step = self._extract_value(args_str, 'step')
            
            # options 추출 (string 타입의 경우)
            options = []
            if input_type == 'input_string':
                options_match = re.search(r'options\s*=\s*\[([^\]]+)\]', args_str)
                if options_match:
                    options = [opt.strip().strip('"\'') 
                              for opt in options_match.group(1).split(',')]
            
            # 최적화 가능 여부 판단
            is_optimizable = self._is_optimizable(name, input_type, group)
            
            if name:
                return ParameterInfo(
                    name=name,
                    type=input_type.replace('input_', ''),
                    default_value=default_value,
                    min_value=min_value,
                    max_value=max_value,
                    step=step,
                    options=options,
                    group=group,
                    title=title,
                    is_optimizable=is_optimizable
                )
        except Exception as e:
            print(f"파싱 오류: {args_str} - {e}")
        
        return None
    
    def _extract_value(self, args_str: str, key: str) -> Optional[float]:
        """인자 문자열에서 특정 키의 값 추출"""
        pattern = rf'{key}\s*=\s*(\d+\.?\d*)'
        match = re.search(pattern, args_str)
        if match:
            return float(match.group(1))
        return None
    
    def _is_optimizable(self, name: str, input_type: str, group: str) -> bool:
        """
        파라미터가 최적화 가능한지 판단
        
        최적화 불가능한 경우:
        - 색상, 표시 관련 파라미터
        - UI 관련 파라미터
        - 고정 설정값
        """
        # 최적화 불가능한 키워드
        non_optimizable_keywords = [
            'color', 'Color', 'COLOR',
            'show', 'Show', 'SHOW',
            'visible', 'Visible', 'VISIBLE',
            'display', 'Display', 'DISPLAY',
            'position', 'Position', 'POSITION',
            'size', 'Size', 'SIZE',
            'text', 'Text', 'TEXT',
        ]
        
        # 그룹이 UI 관련인 경우
        ui_groups = ['대시보드', 'Dashboard', 'Visual', 'Display']
        if group and any(ui in group for ui in ui_groups):
            return False
        
        # 이름에 최적화 불가능한 키워드가 포함된 경우
        if any(keyword in name for keyword in non_optimizable_keywords):
            return False
        
        # bool 타입은 선택적으로 최적화 (필터 활성화/비활성화)
        if input_type == 'input_bool':
            # 필터 관련 bool은 최적화 가능
            filter_keywords = ['enable', 'Enable', 'active', 'Active', 'use', 'Use']
            return any(keyword in name for keyword in filter_keywords)
        
        return True
    
    def get_optimization_ranges(self, parameters: List[ParameterInfo]) -> Dict[str, Dict]:
        """
        최적화 가능한 파라미터의 범위 추출
        
        Args:
            parameters: 파라미터 정보 리스트
            
        Returns:
            최적화 범위 딕셔너리
        """
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
            
            # bool 타입의 경우 options로 처리
            if param.type == 'bool':
                range_info['options'] = [True, False]
            
            # string 타입의 경우 options 사용
            if param.type == 'string' and param.options:
                range_info['options'] = param.options
            
            # 기본 범위 설정 (min/max가 없는 경우)
            if param.type == 'int' and param.min_value is None:
                # 기본값 기준으로 범위 추정
                if param.default_value:
                    range_info['min'] = max(1, int(param.default_value * 0.5))
                    range_info['max'] = int(param.default_value * 2)
                    range_info['step'] = 1
            
            if param.type == 'float' and param.min_value is None:
                # 기본값 기준으로 범위 추정
                if param.default_value:
                    range_info['min'] = param.default_value * 0.5
                    range_info['max'] = param.default_value * 2.0
                    range_info['step'] = param.default_value * 0.1
            
            ranges[param.name] = range_info
        
        return ranges


def parse_pine_script_file(filepath: str) -> Dict[str, Any]:
    """
    Pine Script 파일을 파싱하여 파라미터 정보 반환
    
    Args:
        filepath: Pine Script 파일 경로
        
    Returns:
        파싱 결과 딕셔너리
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        code = f.read()
    
    parser = PineScriptParser()
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
    lbbLengthInput = input.int(15, title="롱 길이", group="볼린저밴드")
    lbbDevInput = input.float(2.0, title="롱 편차", step=0.1, group="볼린저밴드")
    active_long = input.bool(true, "롱 활성화", group='볼린저밴드')
    longTakeProfitPerc = input.float(0.02, title="롱 % ", step=0.01, group="TAKE PROFIT")
    """
    
    parser = PineScriptParser()
    params = parser.parse(test_code)
    ranges = parser.get_optimization_ranges(params)
    
    print("파싱된 파라미터:")
    for param in params:
        print(f"  {param.name}: {param.type} = {param.default_value} (최적화: {param.is_optimizable})")
    
    print("\n최적화 범위:")
    for name, range_info in ranges.items():
        print(f"  {name}: {range_info}")

