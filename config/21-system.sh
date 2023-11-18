# 30-system

### hosts ###

GetPackageOriginalFile filesystem '/etc/hosts' > /dev/null
AddHostsEntry '127.0.0.1' localhost.localdomain localhost

### hostname ###

SetHostname --dns

### vconsole ###

CreateFile '/etc/vconsole.conf' > /dev/null
SetVConsoleConf KEYMAP 'us'

### timezone ###

SetTimezone 'America/Toronto'

### hwclock ###

AdjustHardwareClock

### locale gen ###

GetPackageOriginalFile glibc '/etc/locale.gen' > /dev/null
AddLocale 'en_CA.UTF-8'
AddLocale 'en_GB.UTF-8'
AddLocale 'en_US.UTF-8'
AddLocale 'fr_CA.UTF-8'
AddLocale 'fr_FR.UTF-8'
AddLocale 'is_IS.UTF-8'
AddLocale 'ja_JP.UTF-8'
AddLocale 'ro_RO.UTF-8'
AddLocale 'ru_RU.UTF-8'
AddLocale 'en_DK.UTF-8' # for ISO timestamps
# TODO run locale-gen

### locale.conf ###

CreateFile '/etc/locale.conf' > /dev/null
SetLocaleConf LANG              'en_US.UTF-8'
SetLocaleConf LANGUAGE          'en_US.UTF-8'
SetLocaleConf LC_CTYPE          'en_US.UTF-8'
SetLocaleConf LC_NUMERIC        'en_US.UTF-8'
SetLocaleConf LC_TIME           'en_US.UTF-8'
SetLocaleConf LC_COLLATE        'en_US.UTF-8'
SetLocaleConf LC_MONETARY       'en_US.UTF-8'
SetLocaleConf LC_MESSAGES       'en_US.UTF-8'
SetLocaleConf LC_PAPER          'en_US.UTF-8'
SetLocaleConf LC_NAME           'en_US.UTF-8'
SetLocaleConf LC_ADDRESS        'en_US.UTF-8'
SetLocaleConf LC_TELEPHONE      'en_US.UTF-8'
SetLocaleConf LC_MEASUREMENT    'en_US.UTF-8'
SetLocaleConf LC_IDENTIFICATION 'en_US.UTF-8'

### services ###

EnableService getty@tty1.service
EnableService remote-fs.target
EnableService --global p11-kit-server.socket
EnableService NetworkManager.service

### users ###

# TODO AddUser root \
#   --password 'changeme'

# TODO AddUser victor \
#   --password 'changeme' \
#   --uid 1000 \
#   --gid users \
#   --shell '/bin/zsh' \
#   --groups 'wheel'
