#!/bin/bash
# macOS built-in tools only. Default action: turn off Microsoft AutoUpdate.
# Usage: bash TurnOff-Office-Update.command [turnoff|turnon|restore|status|dry-run]
set -euo pipefail

ACTION="${1:-turnoff}"
PREF_DOMAIN='com.microsoft.autoupdate2'
SYSTEM_PREF='/Library/Preferences/com.microsoft.autoupdate2.plist'
SYSTEM_DOMAIN='/Library/Preferences/com.microsoft.autoupdate2'
AGENT='com.microsoft.update.agent'
HELPER='com.microsoft.autoupdate.helper'
AGENT_PLIST="/Library/LaunchAgents/$AGENT.plist"
HELPER_PLIST="/Library/LaunchDaemons/$HELPER.plist"
STATE_ROOT='/Library/Application Support/TurnOff-Office-Update'
STATE="$STATE_ROOT/active"

say() { printf '%s\n' "$*"; }
die() { say "오류: $*" >&2; exit 1; }

case "$ACTION" in
    turnoff|turnon|restore|status|dry-run) ;;
    -h|--help|help)
        say '사용법: bash TurnOff-Office-Update.command [turnoff|turnon|restore|status|dry-run]'
        say 'turnoff: 자동 업데이트 끄기 (기본값, 최초 설정 백업)'
        say 'turnon: 자동 다운로드 및 설치 켜기 (최초 설정 백업)'
        say 'restore: 이 스크립트 최초 실행 전의 설정으로 복원'
        say 'status: 현재 설정과 서비스 상태 확인 (읽기 전용)'
        say 'dry-run: turnoff 작업 표시 (변경 없음)'
        exit 0 ;;
    *) die "알 수 없는 동작: $ACTION. --help를 참고하세요." ;;
esac
[ "$(/usr/bin/uname -s)" = Darwin ] || die 'macOS에서만 실행할 수 있습니다.'
PLUTIL_HELP="$(/usr/bin/plutil -help)"
case "$PLUTIL_HELP" in
    *'-type keypath'*) ;;
    *) die '필요한 plutil 기능이 없는 macOS 버전입니다. 최신 macOS에서 실행해 주세요.' ;;
esac

if [ "$EUID" -eq 0 ]; then
    TARGET_USER="${SUDO_USER:-}"
    TARGET_UID="${SUDO_UID:-}"
    [ -n "$TARGET_USER" ] && [ -n "$TARGET_UID" ] ||
        die '일반 사용자 계정의 터미널에서 실행해 주세요. root 직접 실행은 지원하지 않습니다.'
else
    TARGET_USER="$(/usr/bin/id -un)"
    TARGET_UID="$(/usr/bin/id -u)"
fi
case "$TARGET_UID" in ''|*[!0-9]*|0) die '대상 사용자 UID가 올바르지 않습니다.' ;; esac
[ "$(/usr/bin/id -u "$TARGET_USER")" = "$TARGET_UID" ] || die '사용자와 UID가 일치하지 않습니다.'
TARGET_HOME="$(/usr/bin/dscl . -read "/Users/$TARGET_USER" NFSHomeDirectory | /usr/bin/sed 's/^NFSHomeDirectory: //')"
[ -d "$TARGET_HOME" ] || die '사용자 홈 폴더를 찾을 수 없습니다.'
USER_PREF="$TARGET_HOME/Library/Preferences/$PREF_DOMAIN.plist"
GUI_DOMAIN="gui/$TARGET_UID"

user_command() {
    if [ "$EUID" -eq 0 ]; then
        /bin/launchctl asuser "$TARGET_UID" /usr/bin/sudo -H -u "$TARGET_USER" "$@"
    else
        "$@"
    fi
}

pref_command() {
    local scope="$1"
    shift
    if [ "$scope" = user ]; then
        user_command /usr/bin/defaults "$@"
    else
        /usr/bin/defaults "$@"
    fi
}

loaded() { /bin/launchctl print "$1" >/dev/null 2>&1; }

# An explicit launchctl override wins; otherwise use the service plist default.
disabled() {
    local domain="$1" label="$2" plist="$3" value
    value="$(/bin/launchctl print-disabled "$domain" | /usr/bin/awk -v label="\"$label\"" '$1 == label {gsub(/[;,]/,"",$3); print $3}')"
    case "$value" in
        disabled) return 0 ;;
        enabled) return 1 ;;
    esac
    value="$(/usr/bin/plutil -extract Disabled raw -o - "$plist" 2>/dev/null || true)"
    [ "$value" = true ]
}

status() {
    local scope domain key value flag running
    for scope in user system; do
        if [ "$scope" = user ]; then domain="$PREF_DOMAIN"; else domain="$SYSTEM_DOMAIN"; fi
        for key in HowToCheck StartDaemonOnAppLaunch; do
            value="$(pref_command "$scope" read "$domain" "$key" 2>/dev/null || true)"
            say "$scope: $key = ${value:-미설정}"
        done
    done
    for scope in agent helper; do
        if [ "$scope" = agent ]; then
            domain="$GUI_DOMAIN"; key="$AGENT"; value="$AGENT_PLIST"
        else
            domain=system; key="$HELPER"; value="$HELPER_PLIST"
        fi
        flag=enabled; running=unloaded
        if disabled "$domain" "$key" "$value"; then flag=disabled; fi
        if loaded "$domain/$key"; then running=loaded; fi
        say "$domain/$key: $flag, $running"
    done
}

if [ "$ACTION" = status ]; then status; exit 0; fi
if [ "$ACTION" = dry-run ]; then
    say "대상 사용자: $TARGET_USER (UID $TARGET_UID)"
    say '사용자 및 시스템 MAU 설정: HowToCheck=Manual, StartDaemonOnAppLaunch=false'
    say "서비스 차단 및 등록 해제: $GUI_DOMAIN/$AGENT, system/$HELPER"
    say "최초 설정 백업: $STATE"
    say '문서, 계정, 키체인, 라이선스, VS Code 설정은 변경하지 않습니다.'
    say '변경 사항을 적용하지 않았습니다.'
    exit 0
fi

if [ "$EUID" -ne 0 ]; then
    /bin/launchctl print "$GUI_DOMAIN" >/dev/null 2>&1 || die '로그인된 Mac 사용자 계정의 터미널에서 실행해 주세요.'
    SELF="$(cd "$(/usr/bin/dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(/usr/bin/basename "${BASH_SOURCE[0]}")"
    say '시스템 업데이트 도우미를 변경하려면 Mac 관리자 암호가 필요합니다.'
    say '터미널에 암호를 입력할 때 글자가 표시되지 않는 것은 정상입니다.'
    # Feed the script through stdin; root need not open a script in Documents/Downloads.
    exec /usr/bin/sudo /bin/bash -s -- "$ACTION" < "$SELF"
fi

trap 'say "작업 중 오류가 발생했습니다. 일부 설정이 적용됐을 수 있습니다. 백업이 있으면 restore로 복원할 수 있습니다." >&2' ERR

snapshot_preferences() {
    local scope="$1" file="$2" key type
    if [ -f "$file" ]; then
        /bin/cp "$file" "$STATE/$scope.plist"
        /usr/bin/plutil -lint "$STATE/$scope.plist" >/dev/null
        for key in HowToCheck StartDaemonOnAppLaunch; do
            type="$(/usr/bin/plutil -type "$key" "$STATE/$scope.plist" 2>/dev/null || true)"
            case "$type" in
                string|bool|integer|float) ;;
                *)
                    if /usr/bin/plutil -extract "$key" xml1 -o - "$STATE/$scope.plist" >/dev/null 2>&1; then
                        die "복원을 지원하지 않는 기존 설정 형식: $scope/$key ($type)"
                    fi ;;
            esac
        done
    else
        /usr/bin/touch "$STATE/$scope.absent"
    fi
}

save_baseline() {
    if [ -e "$STATE" ]; then
        [ -f "$STATE/ready" ] || die "불완전한 백업이 있습니다. 확인이 필요합니다: $STATE"
        [ "$(/bin/cat "$STATE/uid")" = "$TARGET_UID" ] || die '다른 사용자가 저장한 백업입니다. 최초 실행 계정에서 복원해 주세요.'
        say '이전 백업을 유지합니다. 최초 실행 전 설정을 덮어쓰지 않습니다.'
        return
    fi
    [ ! -L "$STATE_ROOT" ] || die '백업 경로가 심볼릭 링크입니다.'
    umask 077
    /bin/mkdir -p "$STATE"
    /bin/chmod 700 "$STATE_ROOT" "$STATE"
    say "$TARGET_UID" > "$STATE/uid"
    snapshot_preferences user "$USER_PREF"
    snapshot_preferences system "$SYSTEM_PREF"
    if disabled "$GUI_DOMAIN" "$AGENT" "$AGENT_PLIST"; then say disabled; else say enabled; fi > "$STATE/agent-state"
    if disabled system "$HELPER" "$HELPER_PLIST"; then say disabled; else say enabled; fi > "$STATE/helper-state"
    if loaded "$GUI_DOMAIN/$AGENT"; then say yes; else say no; fi > "$STATE/agent-loaded"
    if loaded "system/$HELPER"; then say yes; else say no; fi > "$STATE/helper-loaded"
    /usr/bin/touch "$STATE/ready"
    say "최초 설정 백업 완료: $STATE"
}

unload_if_loaded() {
    if loaded "$1"; then /bin/launchctl bootout "$1"; fi
}

enable_service() {
    local domain="$1" label="$2" plist="$3"
    /bin/launchctl enable "$domain/$label"
    if ! loaded "$domain/$label"; then
        /bin/launchctl bootstrap "$domain" "$plist"
    fi
    if disabled "$domain" "$label" "$plist"; then
        die "서비스 비활성화가 해제되지 않았습니다: $domain/$label"
    fi
    loaded "$domain/$label" || die "서비스가 등록되지 않았습니다: $domain/$label"
}

restore_preferences() {
    local scope="$1" domain="$2" current="$3" key type value option
    for key in HowToCheck StartDaemonOnAppLaunch; do
        if [ -f "$STATE/$scope.plist" ] && /usr/bin/plutil -extract "$key" xml1 -o - "$STATE/$scope.plist" >/dev/null 2>&1; then
            type="$(/usr/bin/plutil -type "$key" "$STATE/$scope.plist")"
            value="$(/usr/bin/plutil -extract "$key" raw -o - "$STATE/$scope.plist")"
            case "$type" in
                string) option=-string ;; bool) option=-bool ;;
                integer) option=-int ;; float) option=-float ;;
                *) die "지원하지 않는 백업 형식: $type" ;;
            esac
            pref_command "$scope" write "$domain" "$key" "$option" "$value"
        elif [ -f "$current" ] && /usr/bin/plutil -extract "$key" xml1 -o - "$current" >/dev/null 2>&1; then
            pref_command "$scope" delete "$domain" "$key"
        fi
    done
}

restore_service() {
    local kind="$1" domain="$2" label="$3" plist="$4" previous
    previous="$(/bin/cat "$STATE/$kind-state")"
    if [ "$previous" = disabled ]; then
        /bin/launchctl disable "$domain/$label"
        unload_if_loaded "$domain/$label"
    elif [ "$previous" = enabled ]; then
        /bin/launchctl enable "$domain/$label"
        if [ "$(/bin/cat "$STATE/$kind-loaded")" = yes ]; then
            if ! loaded "$domain/$label"; then
                [ -f "$plist" ] || die "서비스 파일을 찾을 수 없습니다: $plist"
                /bin/launchctl bootstrap "$domain" "$plist"
            fi
        else
            unload_if_loaded "$domain/$label"
        fi
    else
        die '백업된 서비스 상태가 올바르지 않습니다.'
    fi
}

if [ "$ACTION" = turnoff ]; then
    save_baseline
    user_command /usr/bin/defaults write "$PREF_DOMAIN" HowToCheck -string Manual
    user_command /usr/bin/defaults write "$PREF_DOMAIN" StartDaemonOnAppLaunch -bool false
    /usr/bin/defaults write "$SYSTEM_DOMAIN" HowToCheck -string Manual
    /usr/bin/defaults write "$SYSTEM_DOMAIN" StartDaemonOnAppLaunch -bool false
    /bin/launchctl disable "$GUI_DOMAIN/$AGENT"
    unload_if_loaded "$GUI_DOMAIN/$AGENT"
    /bin/launchctl disable "system/$HELPER"
    unload_if_loaded "system/$HELPER"
    [ "$(user_command /usr/bin/defaults read "$PREF_DOMAIN" HowToCheck)" = Manual ]
    [ "$(user_command /usr/bin/defaults read "$PREF_DOMAIN" StartDaemonOnAppLaunch)" = 0 ]
    [ "$(/usr/bin/defaults read "$SYSTEM_DOMAIN" HowToCheck)" = Manual ]
    [ "$(/usr/bin/defaults read "$SYSTEM_DOMAIN" StartDaemonOnAppLaunch)" = 0 ]
    disabled "$GUI_DOMAIN" "$AGENT" "$AGENT_PLIST"
    disabled system "$HELPER" "$HELPER_PLIST"
    if loaded "$GUI_DOMAIN/$AGENT" || loaded "system/$HELPER"; then
        die '업데이트 서비스의 실행 등록이 해제되지 않았습니다.'
    fi
    say 'Office 백그라운드 자동 업데이트 차단을 적용하고 확인했습니다.'
elif [ "$ACTION" = turnon ]; then
    [ -f "$AGENT_PLIST" ] || die "MAU 서비스 파일이 없습니다. Office 또는 Microsoft AutoUpdate 설치를 확인하세요: $AGENT_PLIST"
    [ -f "$HELPER_PLIST" ] || die "MAU 서비스 파일이 없습니다. Office 또는 Microsoft AutoUpdate 설치를 확인하세요: $HELPER_PLIST"
    save_baseline
    user_command /usr/bin/defaults write "$PREF_DOMAIN" HowToCheck -string AutomaticDownload
    user_command /usr/bin/defaults write "$PREF_DOMAIN" StartDaemonOnAppLaunch -bool true
    /usr/bin/defaults write "$SYSTEM_DOMAIN" HowToCheck -string AutomaticDownload
    /usr/bin/defaults write "$SYSTEM_DOMAIN" StartDaemonOnAppLaunch -bool true
    enable_service system "$HELPER" "$HELPER_PLIST"
    enable_service "$GUI_DOMAIN" "$AGENT" "$AGENT_PLIST"
    [ "$(user_command /usr/bin/defaults read "$PREF_DOMAIN" HowToCheck)" = AutomaticDownload ]
    [ "$(user_command /usr/bin/defaults read "$PREF_DOMAIN" StartDaemonOnAppLaunch)" = 1 ]
    [ "$(/usr/bin/defaults read "$SYSTEM_DOMAIN" HowToCheck)" = AutomaticDownload ]
    [ "$(/usr/bin/defaults read "$SYSTEM_DOMAIN" StartDaemonOnAppLaunch)" = 1 ]
    say 'Office 자동 다운로드 및 설치를 켜고 서비스 등록을 확인했습니다.'
else
    [ -f "$STATE/ready" ] || die '이 스크립트가 저장한 최초 설정 백업이 없습니다.'
    [ "$(/bin/cat "$STATE/uid")" = "$TARGET_UID" ] || die '최초 실행 사용자 계정에서 복원해 주세요.'
    restore_preferences user "$PREF_DOMAIN" "$USER_PREF"
    restore_preferences system "$SYSTEM_DOMAIN" "$SYSTEM_PREF"
    restore_service agent "$GUI_DOMAIN" "$AGENT" "$AGENT_PLIST"
    restore_service helper system "$HELPER" "$HELPER_PLIST"
    ARCHIVE="$STATE_ROOT/restored-$(/bin/date +%Y%m%d-%H%M%S)-$(/usr/bin/uuidgen)"
    /bin/mv "$STATE" "$ARCHIVE"
    say "최초 실행 전 설정으로 복원했습니다. 백업 보관 위치: $ARCHIVE"
fi
say ''
status
