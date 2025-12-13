#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
바탕화면 바로가기 생성 스크립트
"""

import os
import sys
from pathlib import Path
import win32com.client


def create_shortcut():
    """바탕화면에 바로가기 생성"""
    try:
        # 현재 스크립트의 디렉토리
        current_dir = Path(__file__).parent.absolute()
        main_script = current_dir / 'main.py'
        
        # Python 실행 파일 경로
        python_exe = sys.executable
        
        # 바탕화면 경로
        desktop = Path.home() / 'Desktop'
        
        # 바로가기 생성
        shell = win32com.client.Dispatch("WScript.Shell")
        shortcut = shell.CreateShortCut(str(desktop / "백테스트 프로그램.lnk"))
        shortcut.Targetpath = python_exe
        shortcut.Arguments = f'"{main_script}"'
        shortcut.WorkingDirectory = str(current_dir)
        shortcut.IconLocation = python_exe  # Python 아이콘 사용
        shortcut.Description = "백테스트 GUI 프로그램"
        shortcut.save()
        
        print(f"바로가기가 생성되었습니다: {desktop / '백테스트 프로그램.lnk'}")
        return True
        
    except Exception as e:
        print(f"바로가기 생성 실패: {e}")
        print("\n대안: 수동으로 바로가기를 생성하세요.")
        print(f"1. 바탕화면에서 우클릭 > 새로 만들기 > 바로가기")
        print(f"2. 대상: {python_exe}")
        print(f"3. 인수: \"{main_script}\"")
        print(f"4. 시작 위치: {current_dir}")
        return False


if __name__ == '__main__':
    try:
        import win32com.client
        create_shortcut()
    except ImportError:
        print("pywin32 패키지가 필요합니다.")
        print("설치: pip install pywin32")
        sys.exit(1)

