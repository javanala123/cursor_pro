#!/usr/bin/env python3
import re

def fix_function_indent():
    # 파일 읽기
    with open('EMA_MultiCross_Fixed_v9.pine', 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # 함수 정의 들여쓰기 제거
    new_lines = []
    for line in lines:
        # 함수 정의 패턴: 공백 + 함수이름(파라미터) + =>
        match = re.match(r'^\s+(\w+\([^)]*\)\s*=>\s*)$', line)
        if match:
            # 들여쓰기 제거
            new_lines.append(match.group(1) + '\n')
        else:
            new_lines.append(line)

    # 파일 쓰기
    with open('EMA_MultiCross_Fixed_v9.pine', 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

    print('함수 정의 들여쓰기 수정 완료')

if __name__ == '__main__':
    fix_function_indent()
