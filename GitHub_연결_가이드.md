# GitHub 연결 및 CodeRabbit 설정 가이드

## 🚀 GitHub 저장소 생성 및 연결

### 1. **GitHub에서 새 저장소 생성**

#### A. GitHub.com 접속
1. https://github.com 접속
2. 로그인 후 우측 상단 "+" 클릭
3. "New repository" 선택

#### B. 저장소 설정
```
Repository name: ut-bot-trading-system
Description: UT Bot AI 트레이딩 시스템 with CodeRabbit 자동 리뷰
Visibility: Private (또는 Public)
Initialize: 체크 해제 (이미 로컬에 파일이 있음)
```

#### C. 저장소 생성
- "Create repository" 클릭

### 2. **로컬 저장소와 GitHub 연결**

#### A. GitHub 저장소 URL 복사
```
HTTPS: https://github.com/yourusername/ut-bot-trading-system.git
SSH: git@github.com:yourusername/ut-bot-trading-system.git
```

#### B. 로컬에서 원격 저장소 연결
```bash
# 현재 폴더에서 실행
git remote add origin https://github.com/yourusername/ut-bot-trading-system.git
git branch -M main
git push -u origin main
```

### 3. **CodeRabbit 설치**

#### A. GitHub Marketplace에서 CodeRabbit 설치
1. GitHub 저장소 → Settings
2. 왼쪽 메뉴에서 "Integrations & services"
3. "Browse all integrations" 클릭
4. "CodeRabbit" 검색
5. "Install" 클릭

#### B. 권한 설정
```
Repository access: "Selected repositories"
Select repositories: "ut-bot-trading-system" 선택
Permissions: "Read and write" 선택
Install 클릭
```

### 4. **CodeRabbit 테스트**

#### A. 테스트 브랜치 생성
```bash
git checkout -b feature/coderabbit-test
```

#### B. 작은 변경사항 만들기
- `UT_Bot_EA_Perfect.mq5` 파일에 주석 추가
- 또는 새로운 테스트 파일 생성

#### C. 커밋 및 Push
```bash
git add .
git commit -m "CodeRabbit 테스트를 위한 변경사항"
git push origin feature/coderabbit-test
```

#### D. Pull Request 생성
1. GitHub 저장소 페이지에서 "Compare & pull request" 클릭
2. 제목: "CodeRabbit 자동 리뷰 테스트"
3. 설명: "CodeRabbit 설정 및 자동 리뷰 기능 테스트"
4. "Create pull request" 클릭

### 5. **CodeRabbit 리뷰 결과 확인**

#### A. 자동 리뷰 시작
- Pull Request 생성 후 1-2분 내에 CodeRabbit이 자동으로 리뷰 시작
- 댓글로 개선사항 제안

#### B. 리뷰 결과 확인
```
Pull Request 페이지에서:
1. "Files changed" 탭에서 CodeRabbit 댓글 확인
2. 제안사항 클릭하여 자세히 보기
3. "Apply suggestion" 버튼으로 자동 수정
4. 수정 후 커밋
```

### 6. **지속적인 사용법**

#### A. 일반적인 개발 워크플로우
```bash
# 1. 코드 수정
# 2. 커밋
git add .
git commit -m "개선사항 설명"

# 3. Push
git push origin main

# 4. Pull Request 생성 (GitHub에서)
# 5. CodeRabbit 자동 리뷰 확인
# 6. 제안사항 적용
# 7. Merge
```

#### B. 브랜치 전략
```bash
# 메인 브랜치
main: 안정적인 프로덕션 코드

# 개발 브랜치
develop: 개발 중인 기능들

# 기능 브랜치
feature/improve-ut-bot: UT Bot 개선
feature/add-new-strategy: 새 전략 추가
feature/optimize-backtest: 백테스트 최적화

# 수정 브랜치
hotfix/critical-bug: 긴급 버그 수정
```

### 7. **CodeRabbit 고급 설정**

#### A. `.coderabbit.yml` 파일 커스터마이징
```yaml
# 현재 설정된 내용 확인
# 필요에 따라 수정 가능
```

#### B. 자동 승인 조건 설정
```yaml
auto_approve:
  small_changes: true
  comment_only_changes: true
  documentation_changes: true
```

#### C. 리뷰 강도 조정
```yaml
intensity: "thorough"  # light, balanced, thorough
```

### 8. **문제 해결**

#### A. CodeRabbit이 작동하지 않는 경우
1. GitHub App 설치 확인
2. 권한 설정 확인
3. `.coderabbit.yml` 파일 문법 확인
4. Pull Request가 올바르게 생성되었는지 확인

#### B. 리뷰가 너무 많거나 적은 경우
```yaml
# .coderabbit.yml에서 조정
intensity: "light"  # 또는 "balanced", "thorough"
```

### 9. **성공 확인 체크리스트**

```
□ GitHub 저장소 생성 완료
□ 로컬 저장소와 GitHub 연결 완료
□ CodeRabbit 앱 설치 완료
□ .coderabbit.yml 파일 설정 완료
□ 테스트 Pull Request 생성 완료
□ CodeRabbit 자동 리뷰 확인 완료
□ 제안사항 적용 테스트 완료
```

### 10. **다음 단계**

#### A. 정기적인 사용
- **매번 Pull Request 생성** 시 자동 리뷰
- **코드 품질** 자동 관리
- **버그 예방** 효과

#### B. 팀 협업
- **일관된 코드 품질** 유지
- **자동화된 리뷰** 프로세스
- **학습 효과** 증대

---

**🎉 축하합니다!** 이제 UT Bot 트레이딩 시스템에서 CodeRabbit을 사용하여 자동 코드 리뷰를 받을 수 있습니다!
