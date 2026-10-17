# TurnOff-Office-Update

macOS에서 Microsoft Office의 백그라운드 자동 업데이트를 끄고, 최초 실행 전 설정으로 복원하는 스크립트입니다. macOS 기본 도구만 사용하며 Python이나 Homebrew 설치가 필요하지 않습니다.

## 실행

이 저장소를 다운로드한 뒤, 터미널에서 해당 폴더로 이동해 실행하세요.

```bash
# 자동 업데이트 끄기 — 관리자 암호 필요
bash TurnOff-Office-Update.command disable

# 상태 확인 — 읽기 전용
bash TurnOff-Office-Update.command status

# 적용할 작업 미리 보기 — 변경 없음
bash TurnOff-Office-Update.command dry-run

# 최초 실행 전 설정으로 복원 — 관리자 암호 필요
bash TurnOff-Office-Update.command restore
```

Finder에서 `TurnOff-Office-Update.command`를 더블 클릭하면 기본 동작인 `disable`을 실행합니다. 터미널에 관리자 암호를 입력할 때 글자가 표시되지 않는 것은 정상입니다.

## 적용 범위

사용자와 시스템 공용 Microsoft AutoUpdate(MAU) 설정에 다음을 기록합니다.

| 설정 | 적용 값 |
| --- | --- |
| `HowToCheck` | `Manual` |
| `StartDaemonOnAppLaunch` | `false` |

이어서 아래 두 서비스를 `launchctl disable`로 비활성화하고, 등록되어 있으면 `bootout`으로 내립니다.

- 현재 사용자: `com.microsoft.update.agent`
- 시스템 공용: `com.microsoft.autoupdate.helper`

Microsoft 문서상 `Manual`만 설정하면 MAU 자체의 업데이트 확인이 남을 수 있어 서비스 차단도 함께 적용합니다. `StartDaemonOnAppLaunch`는 현재 공식 문서에 없는 추가 호환 설정이며, 이 값 하나에 의존하지 않습니다.

문서, 로그인 정보, 키체인, 라이선스 서비스와 Office 앱 파일은 변경하지 않습니다. VS Code, Edge, OneDrive의 별도 업데이트 설정도 대상에 포함되지 않습니다.

## 백업과 복원

최초 `disable` 실행 시 기존 설정을 다음 위치에 백업합니다. 백업은 해당 Mac에만 저장되며 관리자만 읽을 수 있습니다.

```text
/Library/Application Support/TurnOff-Office-Update/active
```

반복 실행해도 최초 백업을 덮어쓰지 않습니다. `restore`는 두 설정 키와 두 서비스의 이전 상태를 복원하며 다른 최신 환경설정을 덮어쓰지 않습니다. 복원된 백업은 같은 상위 폴더의 `restored-*` 디렉터리에 보관됩니다.

이미 수동으로 업데이트를 꺼 둔 Mac이라면 그 상태가 최초 백업이 됩니다. 따라서 이 경우 `restore`를 실행해도 자동 업데이트가 켜지지 않습니다.

## 사용 전 확인

- 로그인된 일반 Mac 사용자 계정의 터미널에서 실행하세요. root 직접 실행과 원격 SSH 실행은 지원하지 않습니다.
- 시스템 도우미 차단은 Mac의 모든 사용자에게 영향을 줍니다. 사용자 에이전트 차단은 실행한 계정에 적용됩니다.
- 자동 보안 업데이트도 차단됩니다. 필요한 업데이트를 직접 관리하고, MAU로 수동 업데이트하기 전에는 서비스를 복원하세요.
- Mac App Store 설치본의 업데이트는 App Store가 관리합니다. 이 스크립트는 App Store 설정을 변경하지 않습니다.
- 회사·학교 관리 프로파일의 업데이트 정책이 우선할 수 있습니다.
- Office 또는 MAU를 재설치한 뒤에는 `status`로 차단 상태를 다시 확인하세요.

설정과 복원 범위에 대한 자세한 설명은 [사용방법.txt](./사용방법.txt)를 참고하세요.

## 검증 범위

macOS에서 셸 문법과 읽기 전용 `status`·`dry-run` 실행을 확인했습니다. 별도의 모의 환경에서 차단, 반복 차단 시 최초 백업 유지, 변경한 키만 복원, 기존 서비스 상태 복원, 없는 설정 키 복원, 공백이 포함된 경로와 기존 정수형 설정 보존을 확인했습니다. 모든 macOS·MAU 버전에 대한 실기기 검증을 의미하지는 않습니다.

## 참고

- [Microsoft AutoUpdate 공식 환경설정 문서](https://learn.microsoft.com/en-us/microsoft-365-apps/mac/mau-preferences)
- 로컬 도움말: `launchctl help disable`, `launchctl help bootout`
