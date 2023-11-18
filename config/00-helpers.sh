# 00-helpers.sh

#
# aug COMMAND
#
# Runs augtool commands on currect config files.
#

aug() {
  AconfNeedProgram augtool augeas n # Install augeas now, if needed.
  augtool --root="${output_dir}/files" "$(printf '%s\n' "$@")" > /dev/null
}

#
# AddHostsEntry IP CANONICAL [ALIAS...]
#
# Adds an entry to hosts file.
#

function AddHostsEntry() {
  [[ $# -lt 2 ]] && (echo "Expected 2 or more arguments, got $#." && exit 1)
  local ip="$1" canonical="$2"
  shift 2
  local alias=($@)
  
  local aug_cmd="$(printf '%s\n%s' \
    "set /files/etc/hosts/01/ipaddr ${ip}" \
    "set /files/etc/hosts/01/canonical ${canonical}"
  )"
  
  for i in $(seq ${#alias[@]}); do
    local j="${alias[$(($i - 1))]}"
    aug_cmd="$(
      printf '%s\n%s' "$aug_cmd" "set /files/etc/hosts/01/alias[${i}] ${j}"
    )"
  done
  
  aug $aug_cmd
}

#
# SetHostname <--dns|CANONICAL [ALIAS...]>
#
# Sets local system hostname.
#
# --dns tries to determine the hostname from DNS.
#

function SetHostname() {
  AconfNeedProgram dig bind n # Install dig now, if needed
  
  local from_dns=0 canonical='' alias=()
  
  if [[ "$1" == "--dns" ]]; then
    from_dns=1
    shift 1
  fi
  
  if [ "${from_dns}" -ne 1 ]; then
    [[ $# -lt 1 ]] && (echo "Expected 1 or more arguments, got $#." && exit 1)
    local canonical="$1"
    shift 1
    local alias=($@)
  else
    local local_ip="$(ip route get 1 | tr -s ' ' | cut -d ' ' -f7)"
    local hostnames="$(dig +short -x "${local_ip}" | sed 's/.$//')"
    local canonical="$(printf "${hostnames}" | awk '{print length, $0}' | sort -nr | head -1 | cut -d ' ' -f 2)"
    local alias=($(printf "${hostnames}" | (grep -ve "^${canonical}$" || true) | cut -d ' ' -f 2))
  fi
  
  # hostname
  echo "${canonical}" > "$(CreateFile '/etc/hostname')"
  
  # hosts
  AddHostsEntry '127.0.1.1' "${canonical}" ${alias[@]}
}

#
# SetTimezone TIMEZONE
#
# Sets system timezone.
#

function SetTimezone() {
  [[ $# -ne 1 ]] && FatalError "Expected 1 argument, got $#."
  local timezone="$1"
  [ ! -f "/usr/share/zoneinfo/${timezone}" ] && FatalError "Invalid timezone ${timezone}."
  
  CreateLink '/etc/localtime' "/usr/share/zoneinfo/${timezone}"
}

#
# SetVConsoleConf SETTING VALUE
#
# Configures the virtual console.
#

function SetVConsoleConf() {
  [[ $# -ne 2 ]] && FatalError "Expected 2 arguments, got $#."
  local setting="$1" value="$2"
  
  CreateFile --no-clobber '/etc/vconsole.conf' > /dev/null
  aug "set /files/etc/vconsole.conf/${setting} ${value}"
}

#
# AdjustHardwareClock [-f|--force]
#
# Sets the Hardware Clock from the System Clock.
#

function AdjustHardwareClock() {
  local force=0 file="$(CreateFile '/etc/adjtime')"
  
  if [[ $# -gt 0 ]] && ([ "$1" == '-f' ] || [ "$1" == '--force' ]); then
    force=1
  fi
  
  if [ -f '/etc/adjtime' ] && [ "${force}" -ne 1 ]; then
    cat '/etc/adjtime' > "${file}"
  else
    RemoveFile '/etc/adjtime'
    hwclock --systohc --adjfile "${file}"
  fi
}

#
# AddLocale LOCALE...
#
# Adds locales to generate.
#

AddLocale() {
  [[ $# -ne 1 ]] && FatalError "Expected 1 argument, got $#."
  local locale=($@) file="$(GetPackageOriginalFile --no-clobber glibc /etc/locale.gen)"
  for i in $(seq ${#locale[@]}); do
    local j="${locale[$(($i - 1))]}"
    ! grep -e "${j}" "${file}" &> /dev/null && FatalError "Unsupported locale ${j}"
    sed -i 's/^[ #]*\('"${j}"'\)/\1/g' "${file}"
  done
}

#
# SetLocaleConf SETTING LOCALE...
#
# Configures system-wide locale settings.
# Possible settings:
#   LANG, LANGUAGE, LC_CTYPE, LC_NUMERIC, LC_TIME, LC_COLLATE,
#   LC_MONETARY, LC_MESSAGES, LC_PAPER, LC_NAME, LC_ADDRESS,
#   LC_TELEPHONE, LC_MEASUREMENT, LC_IDENTIFICATION
#

SetLocaleConf() {
  [[ $# -ne 2 ]] && FatalError "Expected 2 arguments, got $#."
  local setting="$1" locale="$2"
  
  CreateFile --no-clobber '/etc/locale.conf' > /dev/null
  aug "set /files/etc/locale.conf/${setting} ${locale}"
}
