# TurnOff-Office-Update

macOS에서 Microsoft Office의 백그라운드 자동 업데이트를 끄고 업데이트 오류 배너를 우회하거나, 파일을 복원하고 자동 업데이트를 다시 켜는 스크립트입니다. `turnoff`·`turnon`은 macOS 기본 도구만 사용합니다. Python이나 Homebrew 설치가 필요하지 않으며, 선택 기능인 배너 진단에만 Swift가 필요합니다.

## 실행

### 한 줄로 다운로드하고 실행

Excel·Word·PowerPoint를 완전히 종료한 뒤, 다른 Mac의 터미널에 아래 한 줄을 붙여 넣으세요. 최신 `main` 브랜치의 스크립트를 다운로드하고 **자동 업데이트 차단과 배너 우회용 파일 이동을 한 번에 처리**합니다. Mac 관리자 암호가 필요합니다.

```bash
curl -fsSL https://raw.githubusercontent.com/hungryZoo/TurnOff-Office-Update/main/TurnOff-Office-Update.command -o TurnOff-Office-Update.command && bash TurnOff-Office-Update.command turnoff
```

자동 업데이트를 다시 켜려면 다음 한 줄을 실행하세요. 옮겨 둔 파일도 자동으로 복원합니다.

```bash
curl -fsSL https://raw.githubusercontent.com/hungryZoo/TurnOff-Office-Update/main/TurnOff-Office-Update.command -o TurnOff-Office-Update.command && bash TurnOff-Office-Update.command turnon
```

### 파일을 받아 직접 실행

이 저장소를 다운로드한 뒤, 터미널에서 해당 폴더로 이동해 실행하세요.

```bash
# 자동 업데이트 끄기 + 배너 우회 — 관리자 암호 필요
bash TurnOff-Office-Update.command turnoff

# 옮긴 파일 자동 복원 + 자동 다운로드 및 설치 켜기 — 관리자 암호 필요
bash TurnOff-Office-Update.command turnon

# 상태 확인 — 읽기 전용
bash TurnOff-Office-Update.command status

# 업데이트 오류 배너 진단 — 읽기 전용, Swift 필요
bash TurnOff-Office-Update.command banner-status

# 끄기 작업 미리 보기 — 변경 없음
bash TurnOff-Office-Update.command dry-run

# 최초 실행 전 설정으로 복원 — 관리자 암호 필요
bash TurnOff-Office-Update.command restore
```

Finder에서 `TurnOff-Office-Update.command`를 더블 클릭하면 기본 동작인 `turnoff`를 실행합니다. 터미널에 관리자 암호를 입력할 때 글자가 표시되지 않는 것은 정상입니다.

## 배너 처리와 파일 자동 복원

`turnoff`는 두 업데이트 서비스를 비활성화하고 실행 등록을 해제한 뒤, 다음 에이전트 plist를 관리자 전용 백업 폴더로 이동합니다. 백그라운드 허용을 켜지 않고 Office 시작 시의 업데이트 오류 배너를 우회하는 방식입니다. 열린 Office 앱은 완전히 종료한 뒤 다시 열어 주세요.

```text
원본: /Library/LaunchAgents/com.microsoft.update.agent.plist
백업: /Library/Application Support/TurnOff-Office-Update/com.microsoft.update.agent.plist
```

`turnon`은 백업 파일을 원래 위치로 복원한 뒤 자동 업데이트를 켭니다. `restore`도 파일을 자동 복원하고, 설정과 서비스는 최초 실행 전 상태로 되돌립니다. 별도의 파일 이동 명령은 필요하지 않습니다.

반복 실행 시 이미 이동된 파일을 유지합니다. Office 또는 MAU 재설치로 새 plist가 생겼다면 `turnoff`를 다시 실행하세요. 이전 파일은 `agent-archived-*.plist`로 보존하고 새 파일을 백업하므로, 이후 `turnon`은 새 파일을 복원합니다. `turnon` 실행 시 원본 경로에 설치 파일이 이미 있으면 그 파일을 사용하고 기존 백업도 보존합니다.

이전 안내에 따라 `/Users/Shared/com.microsoft.update.agent.plist.bak`으로 직접 옮긴 파일도 자동 인식합니다. 관리자 소유의 정상적인 에이전트 plist인지 확인한 뒤 관리자 전용 폴더로 옮겨 같은 방식으로 처리합니다. 형식·소유권·권한이 맞지 않거나 경로가 심볼릭 링크이면 설정 변경 전에 중단합니다.

파일 위치와 서비스 설정은 `status`로 확인할 수 있습니다. 추가로 macOS의 승인 상태를 확인하려면 다음 읽기 전용 진단을 사용하세요. 이 선택 기능은 macOS 13 이상과 Xcode 또는 Command Line Tools의 Swift가 필요합니다.

```bash
bash TurnOff-Office-Update.command banner-status
```

`banner-status`는 `SMAppService.statusForLegacyPlist(at:)`를 조회합니다. `2 (requiresApproval)`는 사용자의 백그라운드 실행 승인이 필요한 상태입니다. `turnoff`·`turnon`은 이 진단 없이도 파일 이동과 복원을 수행합니다. 일반 사용자로 조회할 때 관리자 전용 백업의 내용은 표시하지 않습니다.

## 적용 범위

사용자와 시스템 공용 Microsoft AutoUpdate(MAU) 설정에 다음을 기록합니다.

| 설정 | `turnoff` | `turnon` |
| --- | --- | --- |
| `HowToCheck` | `Manual` | `AutomaticDownload` |
| `StartDaemonOnAppLaunch` | `false` | `true` |

아래 두 서비스에 대해 `turnoff`는 `launchctl disable`과 `bootout`을 적용하고, `turnon`은 `launchctl enable`과 필요한 경우 `bootstrap`을 적용합니다.

- 현재 사용자: `com.microsoft.update.agent`
- 시스템 공용: `com.microsoft.autoupdate.helper`

Microsoft 문서상 `Manual`만 설정하면 MAU 자체의 업데이트 확인이 남을 수 있어 서비스 차단도 함께 적용합니다. `StartDaemonOnAppLaunch`는 현재 공식 문서에 없는 추가 호환 설정이며, 이 값 하나에 의존하지 않습니다.

`turnon`은 자동 확인·다운로드·설치를 켭니다. 에이전트 원본과 백업이 모두 없거나 시스템 도우미 plist가 없으면 설정을 변경하기 전에 중단하므로 Office 또는 Microsoft AutoUpdate 설치를 확인하세요.

문서, 로그인 정보, 키체인, 라이선스 서비스와 Office 앱 파일은 변경하지 않습니다. VS Code, Edge, OneDrive의 별도 업데이트 설정도 대상에 포함되지 않습니다.

## 백업과 복원

최초 `turnoff` 또는 `turnon` 실행 시 기존 설정을 다음 위치에 백업합니다. 백업은 해당 Mac에만 저장되며 관리자만 읽을 수 있습니다.

```text
/Library/Application Support/TurnOff-Office-Update/active
```

반복 실행해도 최초 설정 백업을 덮어쓰지 않습니다. `restore`는 배너 우회용 에이전트 plist를 원래 위치로 돌려놓고 두 설정 키와 두 서비스의 이전 상태를 복원하며, 다른 최신 환경설정을 덮어쓰지 않습니다. 복원된 설정 백업은 같은 상위 폴더의 `restored-*` 디렉터리에 보관됩니다. 에이전트 plist 백업은 `active` 밖에 보관하므로 설정 백업을 보관 처리한 뒤에도 유지됩니다.

이미 수동으로 업데이트를 꺼 둔 Mac이라면 그 상태가 최초 백업이 됩니다. 따라서 이 경우 `restore`를 실행해도 자동 업데이트가 켜지지 않습니다.

자동 업데이트를 켜려면 `turnon`을 사용하세요. `turnon`은 최초 백업을 유지하며, 이후 `restore`로 그 백업 상태를 복원할 수 있습니다.

## 사용 전 확인

- 로그인된 일반 Mac 사용자 계정의 터미널에서 실행하세요. root 직접 실행과 원격 SSH 실행은 지원하지 않습니다.
- 시스템 도우미 차단과 에이전트 plist 이동은 Mac의 모든 사용자에게 영향을 줍니다. 사용자 에이전트의 `launchctl` 차단은 실행한 계정에 적용됩니다.
- `turnoff`는 자동 보안 업데이트도 차단합니다. 필요한 업데이트를 직접 관리하고, MAU를 사용하려면 `turnon`으로 켜거나 `restore`로 이전 서비스 상태를 복원하세요.
- Mac App Store 설치본의 업데이트는 App Store가 관리합니다. 이 스크립트는 App Store 설정을 변경하지 않습니다.
- 회사·학교 관리 프로파일의 업데이트 정책이 우선할 수 있습니다.
- Office 또는 MAU를 재설치한 뒤에는 `status`로 차단 상태를 다시 확인하세요.

설정과 복원 범위에 대한 자세한 설명은 [사용방법.txt](./사용방법.txt)를 참고하세요.

## 검증 범위

macOS에서 셸 문법과 읽기 전용 `status`·`dry-run`·`banner-status` 실행을 확인했습니다. 별도의 모의 환경에서 차단·켜기·복원, 반복 실행 시 최초 백업 유지, 변경한 키만 복원, 기존 서비스 상태 복원, 없는 설정 키 복원, 공백이 포함된 경로와 기존 정수형 설정 보존을 확인했습니다. Swift 없이 자동 이동·복원하는 동작, 이전 수동 백업 인식, 재설치 후 파일 보존, 잘못된 백업 거부와 서비스 등록 오류 처리도 모의 환경에서 검증했습니다.

실제 Mac 한 대에서 plist를 수동 이동한 뒤 원본 없음·백업 있음과 `2 (requiresApproval)` → `0 (notRegistered)` 전환을 확인했습니다. 자동 업데이트 서비스가 비활성화된 상태를 유지하면서 Office 업데이트 오류 배너가 나타나지 않는 것도 확인했습니다. 모든 macOS·Office·MAU 버전에서 같은 결과를 보장하지는 않습니다.

## 참고

- [Microsoft AutoUpdate 공식 환경설정 문서](https://learn.microsoft.com/en-us/microsoft-365-apps/mac/mau-preferences)
- [Apple SMAppService.statusForLegacyPlist(at:) 문서](https://developer.apple.com/documentation/servicemanagement/smappservice/statusforlegacyplist(at:))
- [Apple requiresApproval 문서](https://developer.apple.com/documentation/servicemanagement/smappservice/status-swift.enum/requiresapproval)
- 로컬 도움말: `launchctl help disable`, `launchctl help bootout`, `launchctl help enable`, `launchctl help bootstrap`
