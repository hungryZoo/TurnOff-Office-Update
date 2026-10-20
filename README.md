# TurnOff-Office-Update

macOS에서 Microsoft Office의 백그라운드 자동 업데이트를 끄거나 켜고, 최초 실행 전 설정으로 복원하는 스크립트입니다. 업데이트 설정 변경에는 macOS 기본 도구를 사용하며 Python이나 Homebrew 설치가 필요하지 않습니다. 선택 기능인 배너 진단에는 Swift가 필요합니다.

## 실행

### 한 줄로 다운로드하고 실행

다른 Mac의 터미널에 아래 한 줄을 붙여 넣으면 최신 `main` 브랜치의 스크립트를 다운로드하고 `turnoff`를 실행합니다. Mac 관리자 암호가 필요합니다.

```bash
curl -fsSL https://raw.githubusercontent.com/hungryZoo/TurnOff-Office-Update/main/TurnOff-Office-Update.command -o TurnOff-Office-Update.command && bash TurnOff-Office-Update.command turnoff
```

자동 업데이트를 다시 켜려면 다음 한 줄을 실행하세요.

```bash
curl -fsSL https://raw.githubusercontent.com/hungryZoo/TurnOff-Office-Update/main/TurnOff-Office-Update.command -o TurnOff-Office-Update.command && bash TurnOff-Office-Update.command turnon
```

### 파일을 받아 직접 실행

이 저장소를 다운로드한 뒤, 터미널에서 해당 폴더로 이동해 실행하세요.

```bash
# 자동 업데이트 끄기 — 관리자 암호 필요
bash TurnOff-Office-Update.command turnoff

# 자동 다운로드 및 설치 켜기 — 관리자 암호 필요
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

## Office 실행 시 업데이트 오류 배너가 뜨는 경우

백그라운드 허용을 꺼 둔 상태에서 “Microsoft 자동 업데이트를 백그라운드에서 실행하도록 허용합니다” 배너가 뜨면 다음 진단을 실행하세요. 이 명령은 파일이나 설정을 변경하지 않습니다. macOS 13 이상과 Xcode 또는 Command Line Tools의 Swift가 필요하며, 일반적인 `turnoff`·`turnon`에는 Swift가 필요하지 않습니다.

```bash
bash TurnOff-Office-Update.command banner-status
```

이 명령은 `/Library/LaunchAgents/com.microsoft.update.agent.plist`의 존재 여부와 `SMAppService.statusForLegacyPlist(at:)` 상태를 조회합니다. `2 (requiresApproval)`는 사용자의 백그라운드 실행 승인이 필요한 상태입니다. 이 상태에서 plist를 LaunchAgents 밖으로 옮기는 방법을 배너 우회 후보로 안내합니다. Office 버전별 효과는 직접 확인해야 합니다.

원본 파일이 있고 상태가 `2`이며 아래 백업 경로가 비어 있는 경우에만 진행하세요. 자동 업데이트는 `turnoff`로 끈 상태를 유지하고, Excel·Word·PowerPoint를 완전히 종료한 뒤 직접 실행하세요.

```bash
sudo /bin/mv -n "/Library/LaunchAgents/com.microsoft.update.agent.plist" "/Users/Shared/com.microsoft.update.agent.plist.bak"
```

`-n`은 기존 파일을 덮어쓰지 않습니다. 다시 `banner-status`를 실행해 **원본 없음 / 백업 있음**을 확인한 뒤 Office를 다시 열어 배너가 사라졌는지 확인하세요. 이동 후에도 상태 값은 직접 확인하며, 특정 값으로 바뀐다고 가정하지 않습니다. 파일 이동 명령은 자동 업데이트 설정이나 백그라운드 허용을 켜지 않습니다. 시스템 공용 파일이므로 다른 Mac 사용자에게도 영향을 줍니다.

되돌리려면 Office를 완전히 종료하고 다음을 실행하세요.

```bash
sudo /bin/mv -n "/Users/Shared/com.microsoft.update.agent.plist.bak" "/Library/LaunchAgents/com.microsoft.update.agent.plist"
```

다시 `banner-status`로 **원본 있음 / 백업 없음**을 확인하세요. 원본과 백업이 모두 있다면 재설치 등으로 파일이 새로 생겼을 수 있으므로 덮어쓰지 말고 두 파일을 먼저 확인하세요.

이 수동 백업은 아래의 최초 설정 백업과 별개입니다. `turnon`이나 `restore` 전에 파일을 원래 위치로 되돌려야 합니다. 스크립트는 백업을 자동으로 이동하거나 삭제하지 않으며, 원본이 없고 백업만 있으면 설정 변경 전에 중단하고 복원 명령을 안내합니다. Office 또는 MAU가 해당 plist를 다시 설치하면 배너가 재발할 수 있습니다.

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

`turnon`은 자동 확인·다운로드·설치를 켭니다. MAU 서비스 파일이 없으면 설정을 변경하기 전에 중단하므로 Office 또는 Microsoft AutoUpdate 설치를 확인하세요.

문서, 로그인 정보, 키체인, 라이선스 서비스와 Office 앱 파일은 변경하지 않습니다. VS Code, Edge, OneDrive의 별도 업데이트 설정도 대상에 포함되지 않습니다.

## 백업과 복원

최초 `turnoff` 또는 `turnon` 실행 시 기존 설정을 다음 위치에 백업합니다. 백업은 해당 Mac에만 저장되며 관리자만 읽을 수 있습니다.

```text
/Library/Application Support/TurnOff-Office-Update/active
```

반복 실행해도 최초 백업을 덮어쓰지 않습니다. `restore`는 두 설정 키와 두 서비스의 이전 상태를 복원하며 다른 최신 환경설정을 덮어쓰지 않습니다. 복원된 백업은 같은 상위 폴더의 `restored-*` 디렉터리에 보관됩니다.

이미 수동으로 업데이트를 꺼 둔 Mac이라면 그 상태가 최초 백업이 됩니다. 따라서 이 경우 `restore`를 실행해도 자동 업데이트가 켜지지 않습니다.

자동 업데이트를 켜려면 `turnon`을 사용하세요. `turnon`은 최초 백업을 유지하며, 이후 `restore`로 그 백업 상태를 복원할 수 있습니다.

## 사용 전 확인

- 로그인된 일반 Mac 사용자 계정의 터미널에서 실행하세요. root 직접 실행과 원격 SSH 실행은 지원하지 않습니다.
- 시스템 도우미 차단은 Mac의 모든 사용자에게 영향을 줍니다. 사용자 에이전트 차단은 실행한 계정에 적용됩니다.
- `turnoff`는 자동 보안 업데이트도 차단합니다. 필요한 업데이트를 직접 관리하고, MAU를 사용하려면 `turnon`으로 켜거나 `restore`로 이전 서비스 상태를 복원하세요.
- Mac App Store 설치본의 업데이트는 App Store가 관리합니다. 이 스크립트는 App Store 설정을 변경하지 않습니다.
- 회사·학교 관리 프로파일의 업데이트 정책이 우선할 수 있습니다.
- Office 또는 MAU를 재설치한 뒤에는 `status`로 차단 상태를 다시 확인하세요.

설정과 복원 범위에 대한 자세한 설명은 [사용방법.txt](./사용방법.txt)를 참고하세요.

## 검증 범위

macOS에서 셸 문법과 읽기 전용 `status`·`dry-run`·`banner-status` 실행을 확인했습니다. 별도의 모의 환경에서 차단·켜기·복원, 반복 실행 시 최초 백업 유지, 변경한 키만 복원, 기존 서비스 상태 복원, 없는 설정 키 복원, 공백이 포함된 경로와 기존 정수형 설정 보존을 확인했습니다. 배너 진단의 상태별 안내, Swift 조회 실패 처리, plist 이동 후 `turnon`·`restore`가 설정 변경 전에 중단하는 동작도 모의 환경에서 확인했습니다.

실제 Mac 한 대에서 plist를 수동 이동한 뒤 원본 없음·백업 있음과 `2 (requiresApproval)` → `0 (notRegistered)` 전환을 확인했습니다. 자동 업데이트 서비스가 비활성화된 상태를 유지하면서 Office 업데이트 오류 배너가 나타나지 않는 것도 확인했습니다. 모든 macOS·Office·MAU 버전에서 같은 결과를 보장하지는 않습니다.

## 참고

- [Microsoft AutoUpdate 공식 환경설정 문서](https://learn.microsoft.com/en-us/microsoft-365-apps/mac/mau-preferences)
- [Apple SMAppService.statusForLegacyPlist(at:) 문서](https://developer.apple.com/documentation/servicemanagement/smappservice/statusforlegacyplist(at:))
- [Apple requiresApproval 문서](https://developer.apple.com/documentation/servicemanagement/smappservice/status-swift.enum/requiresapproval)
- 로컬 도움말: `launchctl help disable`, `launchctl help bootout`, `launchctl help enable`, `launchctl help bootstrap`
