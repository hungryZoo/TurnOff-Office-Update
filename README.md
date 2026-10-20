# TurnOff-Office-Update

## 개요

macOS에서 Microsoft Office의 백그라운드 자동 업데이트를 끄고, Office 실행 시 나타나는 업데이트 오류 배너를 우회하는 스크립트입니다. 다시 켤 때는 옮긴 파일도 자동으로 복원합니다.

macOS 기본 도구만 사용하므로 Python, Homebrew, Swift를 설치하지 않아도 업데이트 끄기와 복원을 실행할 수 있습니다.

## 실행

Excel·Word·PowerPoint를 완전히 종료한 뒤 터미널에서 실행하세요. 최신 `main` 브랜치의 스크립트를 다운로드하며, Mac 관리자 암호가 필요합니다. 암호를 입력할 때 글자가 표시되지 않는 것은 정상입니다.

### 업데이트끄기

자동 업데이트 차단과 배너 우회용 파일 이동을 한 번에 처리합니다. 실행 후 Office를 다시 열어 주세요.

```bash
curl -fsSL https://raw.githubusercontent.com/hungryZoo/TurnOff-Office-Update/main/TurnOff-Office-Update.command -o TurnOff-Office-Update.command && bash TurnOff-Office-Update.command turnoff
```

### 업데이트복원

옮긴 파일을 원래 위치로 자동 복원하고, 자동 업데이트 확인·다운로드·설치를 다시 켭니다.

```bash
curl -fsSL https://raw.githubusercontent.com/hungryZoo/TurnOff-Office-Update/main/TurnOff-Office-Update.command -o TurnOff-Office-Update.command && bash TurnOff-Office-Update.command turnon
```

## 원리

사용자와 시스템 공용 Microsoft AutoUpdate(MAU) 설정을 다음과 같이 변경합니다.

| 설정 | `turnoff` | `turnon` |
| --- | --- | --- |
| `HowToCheck` | `Manual` | `AutomaticDownload` |
| `StartDaemonOnAppLaunch` | `false` | `true` |

`turnoff`는 현재 사용자의 `com.microsoft.update.agent`와 시스템 공용 `com.microsoft.autoupdate.helper`를 `launchctl disable`로 비활성화하고, `bootout`으로 실행 등록을 해제합니다. `turnon`은 `enable`과 필요한 경우 `bootstrap`으로 서비스를 다시 등록합니다.

`Manual` 설정만으로는 MAU 자체의 업데이트 확인이 남을 수 있어 서비스 차단도 함께 적용합니다. `StartDaemonOnAppLaunch`는 현재 Microsoft 공식 문서에 없는 추가 호환 설정이며, 이 값 하나에 의존하지 않습니다.

배너 우회를 위해 에이전트 plist를 다음 위치로 이동합니다. `turnon`과 `restore`는 이 파일을 자동 복원합니다.

```text
원본: /Library/LaunchAgents/com.microsoft.update.agent.plist
백업: /Library/Application Support/TurnOff-Office-Update/com.microsoft.update.agent.plist
```

반복 실행하면 이미 이동된 파일을 유지합니다. 재설치로 새 plist가 생기면 이전 백업을 `agent-archived-*.plist`로 보존하고 새 파일을 백업합니다. 복원 시 원본 경로에 설치 파일이 이미 있으면 그 파일을 사용하고 기존 백업도 보존합니다. 이전 방식의 `/Users/Shared/com.microsoft.update.agent.plist.bak`도 자동 인식합니다.

최초 설정은 `/Library/Application Support/TurnOff-Office-Update/active`에 백업하며 반복 실행해도 덮어쓰지 않습니다. `turnon`은 자동 업데이트를 켜고, `restore`는 파일을 복원한 뒤 설정과 서비스를 최초 실행 전 상태로 되돌립니다. 처음부터 업데이트가 꺼져 있었다면 `restore` 후에도 꺼진 상태입니다.

`status`로 설정과 파일 위치를, `dry-run`으로 끄기 작업을 미리 확인할 수 있습니다. 선택 진단인 `banner-status`는 macOS의 `SMAppService` 승인 상태를 조회하며, 이 기능에만 macOS 13 이상과 Xcode 또는 Command Line Tools의 Swift가 필요합니다.

## 사용전주의사항

- 로그인된 일반 Mac 사용자 계정의 터미널에서 실행하세요. root 직접 실행과 원격 SSH 실행은 지원하지 않습니다.
- 자동 보안 업데이트도 차단되므로 필요한 업데이트는 직접 관리해야 합니다.
- 시스템 도우미 차단과 에이전트 plist 이동은 Mac의 모든 사용자에게 영향을 줍니다.
- Mac App Store 설치본의 업데이트는 App Store가 관리하며, 회사·학교 관리 프로파일의 정책이 로컬 설정보다 우선할 수 있습니다.
- Office 또는 MAU를 재설치한 뒤에는 상태를 확인하고 필요하면 `turnoff`를 다시 실행하세요.
- 에이전트 원본과 백업이 모두 없거나 시스템 도우미 plist가 없으면 `turnon`은 중단합니다. 백업의 형식·소유권·권한이 잘못되거나 경로가 심볼릭 링크여도 처리를 중단합니다.
- 실제 Mac에서 plist 이동 후 배너가 사라지는 것을 확인했으나, 모든 macOS·Office·MAU 버전에서 같은 결과를 보장하지는 않습니다.

## 참고

- [자세한 사용방법](./사용방법.txt)
- [Microsoft AutoUpdate 공식 환경설정 문서](https://learn.microsoft.com/en-us/microsoft-365-apps/mac/mau-preferences)
- [Apple SMAppService.statusForLegacyPlist(at:) 문서](https://developer.apple.com/documentation/servicemanagement/smappservice/statusforlegacyplist(at:))
- [Apple requiresApproval 문서](https://developer.apple.com/documentation/servicemanagement/smappservice/status-swift.enum/requiresapproval)
- 로컬 도움말: `launchctl help disable`, `launchctl help bootout`, `launchctl help enable`, `launchctl help bootstrap`
