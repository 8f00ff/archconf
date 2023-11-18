#!/bin/bash
# 01-helpers-systemd.sh

#
# SystemdService [--global] <enable|disable|mask> SERVICE...
#
# Enables, disables or masks a service.
#

function SystemdService() {
  local scope scope_type state service=()
  
  if [ "$1" == '--global' ]; then
    scope='global'
    unit_type='user'
    shift 1
  else
    scope='system'
    unit_type='system'
  fi
  
  [[ $# -lt 2 ]] && FatalError "Expected 2 or more arguments, got $#."
  
  state="$1"
  shift 1
  
  if [ "${state}" != 'enable' ] && [ "${state}" != 'disable' ] && [ "${state}" != 'mask' ]; then
    FatalError "Expected enable, disable or mask, got ${state}."
  fi
  
  service=($@)
  
  local systemd_unit_path="$(systemd-path | grep "systemd-${unit_type}-unit" | cut -d ':' -f 2 | tr -d ' ')"
  [ ! -d "$systemd_unit_path" ] && FatalError "Invalid systemd unit path, found ${systemd_unit_path}"
  
  mount --onlyonce -rm -o bind "${systemd_unit_path}" "${output_dir}/files/${systemd_unit_path}"
  
  systemctl --quiet --root="${output_dir}/files" --${scope} ${state} ${service[@]}
  
  umount -fq "${output_dir}/files${systemd_unit_path}"
  
  rmdir -p "${output_dir}/files${systemd_unit_path}" &>/dev/null || true
}

#
# EnableService [--global] SERVICE...
#
# Enables services to be started on system boot
#

function EnableService() {
  local is_global
  if [ "$1" == '--global' ]; then
    is_global=1
    shift 1
  fi
  [[ $# -lt 1 ]] && FatalError "Expected 1 or more argument, got $#."
  local service=($@)
  SystemdService ${is_global:+--global} enable ${service[@]}
}

#
# DisableService [--user] SERVICE...
#
# Disables services to be started on system boot
#

function DisableService() {
  local is_global
  [ "$1" == '--global' ] && (is_global=1 && shift 1)
  [[ $# -lt 1 ]] && FatalError "Expected 1 or more argument, got $#."
  local service=($@)
  SystemdService ${is_global:+--global} disable ${service[@]}
}


#
# MaskService [--user] SERVICE...
#
# Masks services to be started on system boot
#

function MaskService() {
  local is_global
  [[ $# -lt 1 ]] && FatalError "Expected 1 or more argument, got $#."
  [ "$1" == '--global' ] && (is_global=1 && shift 1)
  local service=($@)
  SystemdService ${is_global:+--global} mask ${service[@]}
}
