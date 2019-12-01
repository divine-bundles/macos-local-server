#:title:        Divine deployment: macos-local-server
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.12.01
#:revremark:    Initial commit
#:created_at:   2019.06.30

D_DPL_NAME='macos-local-server'
D_DPL_DESC='macOS web-dev server (httpd, php, mariadb, dnsmasq)'
D_DPL_PRIORITY=4096
D_DPL_FLAGS=!ir
D_DPL_WARNING='Make sure you know what you are doing'
D_DPL_OS=( macos )

d_dpl_check()
{
  # Relevant for macOS only
  [ "$D__OS_FAMILY" = macos ] || return 3

  # Otherwise, checking is not implemented
  return 0
}

d_dpl_install()
{
  # Make sure, Homebrew is installed
  [ "$D__OS_PKGMGR" = brew ] || { printf >&2 'Homebrew missing\n'; return 1; }

  # Installed XCode command line tools, if haven't already
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Installing XCode command line tools${NORMAL}"
  xcode-select --install

  # Install support libraries
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Installing support libraries${NORMAL}"
  d__os_pkgmgr check openldap || d__os_pkgmgr install openldap
  d__os_pkgmgr check libiconv || d__os_pkgmgr install libiconv

  # Stop and unload built-in Apache
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Stopping and unloading built-in Apache${NORMAL}"
  sudo apachectl stop
  sudo launchctl unload -w /System/Library/LaunchDaemons/org.apache.httpd.plist 2>/dev/null

  # Install Homebrew httpd
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Installing Homebrew httpd${NORMAL}"
  d__os_pkgmgr check httpd || d__os_pkgmgr install httpd
  sudo brew services start httpd

  # Storage variables
  local todo item real_path symlink_path backup_path

  # Link httpd config
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Linking httpd config${NORMAL}"
  # Gather files to link
  todo=( \
    'httpd/httpd.conf' \
    'httpd/extra/httpd-ssl.conf' \
    'httpd/extra/httpd-vhosts.conf' \
  )
  # Link each one
  for item in "${todo[@]}"; do
    real_path="$D__DPL_ASSET_DIR/$item"
    symlink_path="/usr/local/etc/$item"
    backup_path="$D_FMWK_DIR_BACKUPS/$D_DPL_NAME/$item"
    dln -f -- "$real_path" "$symlink_path" "$backup_path" || {
      printf >&2 '%s\n' "Failed to link $item"
      return 1
    }
  done

  # Install Homebrew php
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Installing Homebrew php${NORMAL}"
  d__os_pkgmgr check php || d__os_pkgmgr install php

  # Link php config
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Linking php config${NORMAL}"
  real_path="$D__DPL_ASSET_DIR/php/php.ini"
  symlink_path="$( $( which php ) --ini | head -1 | awk -F': ' '{print $2}' )"
  [ -d "$symlink_path" -a -r "$symlink_path"] || {
    printf >&2 '%s\n' "Failed to locate php.ini directory"
    return 1
  }
  symlink_path+="/php.ini"
  backup_path="$D_FMWK_DIR_BACKUPS/$D_DPL_NAME/php/php.ini"
  dln -f -- "$real_path" "$symlink_path" "$backup_path" || {
    printf >&2 '%s\n' "Failed to link php.ini"
    return 1
  }

  # Install Homebrew mariadb
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Installing Homebrew mariadb${NORMAL}"
  d__os_pkgmgr check mariadb || d__os_pkgmgr install mariadb
  brew services start mariadb
  /usr/local/bin/mysql_secure_installation

  # Install Homebrew dnsmasq
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Installing Homebrew dnsmasq${NORMAL}"
  d__os_pkgmgr check dnsmasq || d__os_pkgmgr install dnsmasq

  # Link dnsmasq config
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Linking dnsmasq config${NORMAL}"
  real_path="$D__DPL_ASSET_DIR/dnsmasq/dnsmasq.conf"
  symlink_path='/usr/local/etc/dnsmasq.conf'
  backup_path="$D_FMWK_DIR_BACKUPS/$D_DPL_NAME/dnsmasq/dnsmasq.conf"
  dln -f -- "$real_path" "$symlink_path" "$backup_path" || {
    printf >&2 '%s\n' "Failed to link dnsmasq.conf"
    return 1
  }

  # Make resolver dir and files in it
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Making resolver${NORMAL}"
  sudo mkdir -v /etc/resolver
  todo=( 'no' 'test' )
  for item in "${todo[@]}"; do
    sudo bash -c "echo \"nameserver 127.0.0.1\" >/etc/resolver/$item"
  done

  # Start dnsmasq
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Starting dnsmasq${NORMAL}"
  sudo brew services start dnsmasq

  # Plant SSL certificates
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Planting SSL certificates${NORMAL}"
  cd /usr/local/etc/httpd
  openssl req -x509 -days 365 -new -newkey rsa:4096 -nodes \
    -keyout server.key -out server.crt \
    -subj "/C=US/ST=California/L=Van Nuys/O=IT/CN=www.serpnet.org"

  # Plant custom 'It works!' messages
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Planting custom 'It works!' messages${NORMAL}"
  local html
  html='<html><body><h1>It works! (Homebrew httpd)</h1></body></html>'
  echo "$html" >/usr/local/var/www/index.html
  html='<html><body><h1>It works! (macOS built-in httpd)</h1></body></html>'
  sudo bash -c "echo \"$html\" >/Library/WebServer/Documents/index.html"

  # Check for errors and restart
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Testing and restarting httpd${NORMAL}"
  sudo apachectl configtest && sudo apachectl -k restart || {
    printf >&2 '%s\n' "Failed httpd configuration check"
    printf >&2 '%s\n' "Restart manually with:"
    printf >&2 '%s\n' "  $ sudo apachectl -k restart"
  }

  # Request reboot, because switching httpd's may be unreliable
  D_ADDST_REBOOT+=('Please, reboot your mac to finilize installation')
  return 0
}

d_dpl_remove()
{
  # Make sure, Homebrew is installed
  [ "$D__OS_PKGMGR" = brew ] || { printf >&2 'Homebrew missing\n'; return 1; }

  # Storage variables
  local todo real_path symlink_path backup_path

  # Remove SSL certificates
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Removing SSL certificates${NORMAL}"
  rm -f -- /usr/local/etc/httpd/server.key /usr/local/etc/httpd/server.crt

  # Stop dnsmasq
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Stopping dnsmasq${NORMAL}"
  sudo brew services stop dnsmasq

  # Unmake resolver dir and files in it
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Unmaking resolver${NORMAL}"
  todo=( 'no' 'test' )
  for item in "${todo[@]}"; do
    sudo rm -f "/etc/resolver/$item"
  done
  sudo rmdir /etc/resolver

  # Unlink dnsmasq config
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Unlinking dnsmasq config${NORMAL}"
  real_path="$D__DPL_ASSET_DIR/dnsmasq/dnsmasq.conf"
  symlink_path='/usr/local/etc/dnsmasq.conf'
  backup_path="$D_FMWK_DIR_BACKUPS/$D_DPL_NAME/dnsmasq/dnsmasq.conf"
  dln -rq -- "$real_path" "$symlink_path" "$backup_path" || {
    dln -rq -- "$real_path" "$symlink_path" \
      && cp -n -- "$real_path" "$symlink_path" \
      || printf >&2 '%s\n' "Failed to unlink dnsmasq.conf"
  }

  # Remove Homebrew dnsmasq
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Removing Homebrew dnsmasq${NORMAL}"
  d__os_pkgmgr check dnsmasq && d__os_pkgmgr remove dnsmasq

  # Remove Homebrew mariadb
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Removing Homebrew mariadb${NORMAL}"
  brew services stop mariadb
  d__os_pkgmgr check mariadb && d__os_pkgmgr remove mariadb

  # Unlink php config
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Unlinking php config${NORMAL}"
  real_path="$D__DPL_ASSET_DIR/php/php.ini"
  symlink_path="$( $( which php ) --ini | head -1 | awk -F': ' '{print $2}' )"
  [ -d "$symlink_path" -a -r "$symlink_path"] || {
    printf >&2 '%s\n' "Failed to locate php.ini directory"
    return 1
  }
  symlink_path+="/php.ini"
  backup_path="$D_FMWK_DIR_BACKUPS/$D_DPL_NAME/php/php.ini"
  dln -rq -- "$real_path" "$symlink_path" "$backup_path" || {
    dln -rq -- "$real_path" "$symlink_path" \
      && cp -n -- "$real_path" "$symlink_path" \
      || printf >&2 '%s\n' "Failed to unlink php.ini"
  }

  # Remove Homebrew php
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Removing Homebrew php${NORMAL}"
  d__os_pkgmgr check php && d__os_pkgmgr remove php

  # Unlink httpd config
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Unlinking httpd config${NORMAL}"
  # Gather files to unlink
  todo=( \
    'httpd/httpd.conf' \
    'httpd/extra/httpd-ssl.conf' \
    'httpd/extra/httpd-vhosts.conf' \
  )
  # Unlink each one
  for item in "${todo[@]}"; do
    real_path="$D__DPL_ASSET_DIR/$item"
    symlink_path="/usr/local/etc/$item"
    backup_path="$D_FMWK_DIR_BACKUPS/$D_DPL_NAME/$item"
    dln -rq -- "$real_path" "$symlink_path" "$backup_path" || {
      dln -rq -- "$real_path" "$symlink_path" \
        && cp -n -- "$real_path" "$symlink_path" \
        || printf >&2 '%s\n' "Failed to unlink $item"
    }
  done

  # Remove Homebrew httpd
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Removing Homebrew httpd${NORMAL}"
  sudo brew services stop httpd
  d__os_pkgmgr check httpd && d__os_pkgmgr remove httpd

  # Load and start built-in Apache
  printf '%s %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    "${BOLD}Loading and starting built-in Apache${NORMAL}"
  sudo launchctl load -w \
    /System/Library/LaunchDaemons/org.apache.httpd.plist 2>/dev/null
  sudo apachectl -k restart

  # Remove support libraries
  printf '%s\n' \
    "${BOLD}${GREEN}==>${NORMAL} ${BOLD}Removing support libraries${NORMAL}"
  d__os_pkgmgr check libiconv && d__os_pkgmgr remove libiconv
  d__os_pkgmgr check openldap && d__os_pkgmgr remove openldap

  # Request reboot, because switching httpd's may be unreliable
  D_ADDST_REBOOT+=('Please, reboot your mac to finilize removal')
  return 0
}