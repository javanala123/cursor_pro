#!/usr/bin/env python3
"""
MCP 서버 연결 테스트 스크립트
개선된 연결 관리 시스템을 테스트합니다.
"""

import asyncio
import aiohttp
import json
import time
from datetime import datetime

class MCPConnectionTester:
    def __init__(self, base_url="http://localhost:8000"):
        self.base_url = base_url
        self.session = None
        
    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        return self
        
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()
    
    async def test_server_health(self):
        """서버 상태 테스트"""
        print("🔍 서버 상태 테스트 중...")
        try:
            async with self.session.get(f"{self.base_url}/") as response:
                if response.status == 200:
                    data = await response.json()
                    print(f"✅ 서버 상태: {data['status']}")
                    return True
                else:
                    print(f"❌ 서버 응답 오류: {response.status}")
                    return False
        except Exception as e:
            print(f"❌ 서버 연결 실패: {e}")
            return False
    
    async def test_system_health(self):
        """시스템 상태 테스트"""
        print("🔍 시스템 상태 테스트 중...")
        try:
            async with self.session.get(f"{self.base_url}/api/system/health") as response:
                if response.status == 200:
                    data = await response.json()
                    health = data['system_health']
                    print(f"✅ 시스템 상태: {health['status']}")
                    print(f"   메모리 사용률: {health['memory']['used_percent']:.1f}%")
                    print(f"   CPU 사용률: {health['cpu']['usage_percent']:.1f}%")
                    print(f"   연결 수: {health['connections']['total_connections']}")
                    return True
                else:
                    print(f"❌ 시스템 상태 조회 실패: {response.status}")
                    return False
        except Exception as e:
            print(f"❌ 시스템 상태 조회 오류: {e}")
            return False
    
    async def test_connection_cleanup(self):
        """연결 정리 테스트"""
        print("🔍 연결 정리 테스트 중...")
        try:
            async with self.session.post(f"{self.base_url}/api/connections/cleanup") as response:
                if response.status == 200:
                    data = await response.json()
                    print(f"✅ 연결 정리 완료: {data['message']}")
                    return True
                else:
                    print(f"❌ 연결 정리 실패: {response.status}")
                    return False
        except Exception as e:
            print(f"❌ 연결 정리 오류: {e}")
            return False
    
    async def test_memory_management(self):
        """메모리 관리 테스트"""
        print("🔍 메모리 관리 테스트 중...")
        try:
            # 메모리 상태 조회
            async with self.session.get(f"{self.base_url}/api/system/memory") as response:
                if response.status == 200:
                    data = await response.json()
                    memory = data['memory_usage']
                    print(f"✅ 메모리 사용률: {memory['percent']:.1f}%")
                    print(f"   사용 중인 메모리: {memory['rss'] / 1024 / 1024:.1f} MB")
                    
                    # 가비지 컬렉션 실행
                    async with self.session.post(f"{self.base_url}/api/system/gc") as gc_response:
                        if gc_response.status == 200:
                            gc_data = await gc_response.json()
                            print(f"✅ 가비지 컬렉션 완료: {gc_data['message']}")
                            return True
                        else:
                            print(f"❌ 가비지 컬렉션 실패: {gc_response.status}")
                            return False
                else:
                    print(f"❌ 메모리 상태 조회 실패: {response.status}")
                    return False
        except Exception as e:
            print(f"❌ 메모리 관리 테스트 오류: {e}")
            return False
    
    async def test_error_logs(self):
        """에러 로그 테스트"""
        print("🔍 에러 로그 테스트 중...")
        try:
            async with self.session.get(f"{self.base_url}/api/logs/errors") as response:
                if response.status == 200:
                    data = await response.json()
                    print(f"✅ 에러 로그 조회 완료: {data['total_count']}개 에러")
                    if data['errors']:
                        print("   최근 에러들:")
                        for error in data['errors'][-3:]:  # 최근 3개만 표시
                            print(f"   - {error}")
                    return True
                else:
                    print(f"❌ 에러 로그 조회 실패: {response.status}")
                    return False
        except Exception as e:
            print(f"❌ 에러 로그 테스트 오류: {e}")
            return False
    
    async def run_all_tests(self):
        """모든 테스트 실행"""
        print("🚀 MCP 서버 연결 테스트 시작")
        print("=" * 50)
        
        tests = [
            ("서버 상태", self.test_server_health),
            ("시스템 상태", self.test_system_health),
            ("연결 정리", self.test_connection_cleanup),
            ("메모리 관리", self.test_memory_management),
            ("에러 로그", self.test_error_logs)
        ]
        
        results = []
        for test_name, test_func in tests:
            print(f"\n📋 {test_name} 테스트")
            print("-" * 30)
            try:
                result = await test_func()
                results.append((test_name, result))
            except Exception as e:
                print(f"❌ {test_name} 테스트 중 예외 발생: {e}")
                results.append((test_name, False))
            
            # 테스트 간 잠시 대기
            await asyncio.sleep(1)
        
        # 결과 요약
        print("\n" + "=" * 50)
        print("📊 테스트 결과 요약")
        print("=" * 50)
        
        passed = 0
        total = len(results)
        
        for test_name, result in results:
            status = "✅ 통과" if result else "❌ 실패"
            print(f"{test_name}: {status}")
            if result:
                passed += 1
        
        print(f"\n총 {total}개 테스트 중 {passed}개 통과 ({passed/total*100:.1f}%)")
        
        if passed == total:
            print("🎉 모든 테스트가 성공적으로 완료되었습니다!")
        else:
            print("⚠️ 일부 테스트가 실패했습니다. 로그를 확인해주세요.")

async def main():
    """메인 함수"""
    async with MCPConnectionTester() as tester:
        await tester.run_all_tests()

if __name__ == "__main__":
    print("MCP 서버 연결 테스트 도구")
    print("서버가 실행 중인지 확인하고 테스트를 시작합니다...")
    print("서버 주소: http://localhost:8000")
    print()
    
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n⏹️ 테스트가 중단되었습니다.")
    except Exception as e:
        print(f"\n❌ 테스트 실행 중 오류 발생: {e}")
