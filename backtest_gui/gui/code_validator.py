#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
코드 검증기 - Pine Script 및 MT5 코드 문법 검사
"""

import re
from typing import List, Dict, Tuple
from dataclasses import dataclass


@dataclass
class CodeError:
    """코드 에러 정보"""
    line: int
    column: int
    message: str
    severity: str  # 'error', 'warning'
    code: str = ''  # 에러가 발생한 코드 라인


class CodeValidator:
    """코드 검증기"""
    
    def __init__(self, language='pine'):
        self.language = language
    
    def validate(self, code: str) -> List[CodeError]:
        """
        코드 검증
        
        Args:
            code: 검증할 코드
            
        Returns:
            에러 리스트
        """
        errors = []
        
        if self.language == 'pine':
            errors.extend(self._validate_pine(code))
        else:  # MT5
            errors.extend(self._validate_mt5(code))
        
        return errors
    
    def _validate_pine(self, code: str) -> List[CodeError]:
        """Pine Script 코드 검증"""
        errors = []
        lines = code.split('\n')
        
        # 기본 검사
        if not code.strip():
            return errors
        
        # @version 확인
        has_version = False
        for i, line in enumerate(lines):
            if '@version' in line.lower():
                has_version = True
                break
        
        if not has_version:
            errors.append(CodeError(
                line=1,
                column=1,
                message="Pine Script 버전이 지정되지 않았습니다. //@version=5 추가 권장",
                severity='warning'
            ))
        
        # strategy 또는 study 확인
        has_strategy = False
        for i, line in enumerate(lines):
            if 'strategy(' in line.lower() or 'study(' in line.lower() or 'indicator(' in line.lower():
                has_strategy = True
                break
        
        if not has_strategy:
            errors.append(CodeError(
                line=1,
                column=1,
                message="strategy(), study(), 또는 indicator() 선언이 없습니다.",
                severity='warning'
            ))
        
        # 괄호 매칭 검사
        open_parens = code.count('(')
        close_parens = code.count(')')
        if open_parens != close_parens:
            errors.append(CodeError(
                line=1,
                column=1,
                message=f"괄호 불일치: 열린 괄호 {open_parens}개, 닫힌 괄호 {close_parens}개",
                severity='error'
            ))
        
        open_braces = code.count('{')
        close_braces = code.count('}')
        if open_braces != close_braces:
            errors.append(CodeError(
                line=1,
                column=1,
                message=f"중괄호 불일치: 열린 중괄호 {open_braces}개, 닫힌 중괄호 {close_braces}개",
                severity='error'
            ))
        
        # 기본 문법 검사
        for i, line in enumerate(lines, 1):
            stripped = line.strip()
            
            # 빈 줄은 건너뛰기
            if not stripped or stripped.startswith('//'):
                continue
            
            # input 구문 검사
            if 'input.' in stripped and '(' in stripped and ')' not in stripped:
                errors.append(CodeError(
                    line=i,
                    column=stripped.find('input.') + 1,
                    message="input 구문이 완성되지 않았습니다 (닫는 괄호 없음)",
                    severity='error',
                    code=stripped
                ))
            
            # 변수 할당 검사
            if '=' in stripped:
                parts = stripped.split('=')
                if len(parts) == 2:
                    left = parts[0].strip()
                    right = parts[1].strip()
                    if not left or not right:
                        errors.append(CodeError(
                            line=i,
                            column=stripped.find('=') + 1,
                            message="변수 할당이 완성되지 않았습니다",
                            severity='error',
                            code=stripped
                        ))
        
        return errors
    
    def _validate_mt5(self, code: str) -> List[CodeError]:
        """MT5 코드 검증"""
        errors = []
        lines = code.split('\n')
        
        if not code.strip():
            return errors
        
        # 괄호 매칭 검사
        open_parens = code.count('(')
        close_parens = code.count(')')
        if open_parens != close_parens:
            errors.append(CodeError(
                line=1,
                column=1,
                message=f"괄호 불일치: 열린 괄호 {open_parens}개, 닫힌 괄호 {close_parens}개",
                severity='error'
            ))
        
        open_braces = code.count('{')
        close_braces = code.count('}')
        if open_braces != close_braces:
            errors.append(CodeError(
                line=1,
                column=1,
                message=f"중괄호 불일치: 열린 중괄호 {open_braces}개, 닫힌 중괄호 {close_braces}개",
                severity='error'
            ))
        
        # 세미콜론 검사 (선택적)
        for i, line in enumerate(lines, 1):
            stripped = line.strip()
            
            if not stripped or stripped.startswith('//') or stripped.startswith('/*'):
                continue
            
            # 함수 선언이나 제어문이 아닌 경우 세미콜론 확인
            if (stripped and 
                not stripped.endswith(';') and 
                not stripped.endswith('{') and 
                not stripped.endswith('}') and
                'if' not in stripped and
                'for' not in stripped and
                'while' not in stripped and
                'switch' not in stripped and
                'case' not in stripped and
                'default' not in stripped and
                'return' not in stripped and
                'break' not in stripped and
                'continue' not in stripped):
                # input 구문은 세미콜론 필요
                if 'input' in stripped.lower():
                    errors.append(CodeError(
                        line=i,
                        column=len(stripped),
                        message="input 구문 끝에 세미콜론(;)이 필요합니다",
                        severity='error',
                        code=stripped
                    ))
        
        return errors
    
    def get_error_summary(self, errors: List[CodeError]) -> str:
        """에러 요약 문자열 생성"""
        if not errors:
            return "에러 없음"
        
        error_count = len([e for e in errors if e.severity == 'error'])
        warning_count = len([e for e in errors if e.severity == 'warning'])
        
        summary = f"에러 {error_count}개, 경고 {warning_count}개"
        return summary

