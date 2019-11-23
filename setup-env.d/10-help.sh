#!/bin/sh
# 辅助函数

# --- 日志 ---
info() {
    echo '[INFO] ' "$@"
}

fatal() {
    echo '[ERROR] ' "$@" >&2
    exit 1
}

# --- 检查命令存在 ---
command_exists() {
    command -v "$@" >/dev/null 2>/dev/null &
}

# --- 以root运行 ---
run_as_root() {
    local CMD="$*"
    local user="$(id -un 2>/dev/null || true)"

    sh_c='sh -c'
    if [ "$user" != 'root' ]; then
        if command_exists sudo; then
            sh_c='sudo -E sh -c'
        elif command_exists su; then
            sh_c='su -c'
        else
            cat <<-EOF | fatal -
			Error: this installer needs the ability to run commands as root.
			We are unable to find either "sudo" or "su" available to make this happen.
			EOF
        fi
    fi

    $sh_c "$CMD"
}

# --- 检查IP是否合法 ---
check_ip() {
    IP_REGEX='^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$'
    printf '%s' "$1" | tr -d '\n' | grep -Eq "$IP_REGEX"
}

# --- 向命令参数添加引号 ---
quote() {
    for arg in "$@"; do
        printf '%s\n' "$arg" | sed "s/'/'\\\\''/g;1s/^/'/;\$s/\$/'/"
    done
}

# --- 向带引号的参数添加缩进和换行符 ---
quote_indent() {
    printf ' \\\n'
    for arg in "$@"; do
        printf '\t%s \\\n' "$(quote "$arg")"
    done
}

# --- 转义大部分标点字符，引号、正斜杠和空格除外 ---
escape() {
    printf '%s' "$@" | sed -e 's/\([][!#$%&()*;<=>?\_`{|}]\)/\\\1/g;'
}

# --- 转义双引号 ---
escape_dq() {
    printf '%s' "$@" | sed -e 's/"/\\"/g'
}

# --- 关闭selinux ---
selinux_disable() {
    if command_exists getenforce && [ "$(getenforce)" = "Enabled" ]; then
        run_as_root 'setenforce 0'
        run_as_root "sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config"
        info "Selinux disabled success!"
    fi
}

# --- 关闭防火墙 ---
firewalld_stop() {
    if [ "$(systemctl is-active firewalld)" = "active" ]; then
        run_as_root 'systemctl disable firewalld'
        run_as_root 'systemctl stop firewalld'
        info "Firewall disabled success!"
    fi
}
