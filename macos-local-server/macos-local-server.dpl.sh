#:title:        Divine deployment: macos-local-server
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.12.16
#:revremark:    Fix syntax error
#:created_at:   2019.06.30

D_DPL_NAME='macos-local-server'
D_DPL_DESC='macOS web-dev server (httpd, php, mariadb, dnsmasq)'
D_DPL_PRIORITY=4096
D_DPL_FLAGS=!ir
D_DPL_WARNING='Make sure you know what you are doing'
D_DPL_OS=( macos )


##
## Primaries
##

d_dpl_check()
{
  [ "$D__OS_PKGMGR" = brew ] || return 3
  d__stash -- ready || return 3
  D_MLTSK_MAIN=( \
    bottles \
    configs \
    resolvers \
    landings \
    sites_dir \
    sites_link \
    cert \
    cert_link \
    set_up \
  )
  d__mltsk_check
}
d_dpl_install() { d__mltsk_install; }
d_dpl_remove()  { d__mltsk_remove;  }


##
## Task 'bottles' (pkg-queue)
##

d_bottles_check()
{
  D_QUEUE_MAIN=( openldap libiconv httpd php mariadb dnsmasq )
  D_QUEUE_FLAGS=( 'md' 'md' 'md' 'md' 'md' 'md' )
  d__queue_split
  d__pkg_queue_check
}
d_bottles_install() { d__pkg_queue_install; }
d_bottles_post_install()
{
  [ "$D__TASK_INSTALL_CODE" -eq 0 ] || D_ADDST_MLTSK_HALT=true
  return 0
}
d_bottles_remove()  { d__pkg_queue_remove;  }


##
## Task 'configs' (link-queue)
##
d_configs_check()
{
  local min=${#D_QUEUE_MAIN[@]}
  if d__stash -s -- has php_etc_dir; then
    PHP_ETC_DIR="$( d__stash -s -- get php_etc_dir )"
  else
    PHP_ETC_DIR="$( \
      $( which php ) --ini \
        | head -1 \
        | awk -F': ' '{print $2}' \
    )"
  fi
  if ! [ -d "$PHP_ETC_DIR" ]; then
    d__notify -lx -- 'Failed to extract path to php.ini directory'
    D_ADDST_MLTSK_IRRELEVANT=true
    return 3
  fi
  D_QUEUE_MAIN+=( \
    dnsmasq.conf \
    httpd-ssl.conf \
    httpd-vhosts.conf \
    httpd.conf \
    php.ini \
  )
  D_QUEUE_ASSETS[$min+0]="$D__DPL_ASSET_DIR/dnsmasq/dnsmasq.conf"
  D_QUEUE_ASSETS[$min+1]="$D__DPL_ASSET_DIR/httpd/extra/httpd-ssl.conf"
  D_QUEUE_ASSETS[$min+2]="$D__DPL_ASSET_DIR/httpd/extra/httpd-vhosts.conf"
  D_QUEUE_ASSETS[$min+3]="$D__DPL_ASSET_DIR/httpd/httpd.conf"
  D_QUEUE_ASSETS[$min+4]="$D__DPL_ASSET_DIR/php/php.ini"
  D_QUEUE_TARGETS[$min+0]="/usr/local/etc/dnsmasq.conf"
  D_QUEUE_TARGETS[$min+1]="/usr/local/etc/httpd/extra/httpd-ssl.conf"
  D_QUEUE_TARGETS[$min+2]="/usr/local/etc/httpd/extra/httpd-vhosts.conf"
  D_QUEUE_TARGETS[$min+3]="/usr/local/etc/httpd/httpd.conf"
  D_QUEUE_TARGETS[$min+4]="$PHP_ETC_DIR/php.ini"
  d__queue_split
  d_link_item_post_install()
  {
    if [ "$D__ITEM_NAME" = php.ini -a "$D__ITEM_INSTALL_CODE" -eq 0 ]; then
      if ! d__stash -s -- set php_etc_dir "$PHP_ETC_DIR"; then
        d__notify -lx -- "Failed to record PHP etc directory: '$PHP_ETC_DIR'"
      fi
    fi
    return 0
  }
  d_link_item_post_remove()
  {
    if [ "$D__ITEM_NAME" = php.ini -a "$D__ITEM_REMOVE_CODE" -eq 0 ]; then
      if ! d__stash -s -- unset php_etc_dir; then
        d__notify -lx -- "Failed to record PHP etc directory: '$PHP_ETC_DIR'"
      fi
    fi
    return 0
  }
  d__link_queue_check
}
d_configs_install()  { d__link_queue_install;  }
d_configs_post_install()
{
  [ "$D__TASK_INSTALL_CODE" -eq 0 ] || D_ADDST_MLTSK_HALT=true
  return 0
}
d_configs_remove()   { d__link_queue_remove;   }


##
## Task 'resolvers' (copy-queue)
##

d_resolvers_check()
{
  local min=${#D_QUEUE_MAIN[@]} ii=0 resolver_filepath resolver_filename
  $D__ENABLE_NULLGLOB
  for resolver_filepath in "$D__DPL_ASSET_DIR/resolvers/"*; do
    resolver_filename="$( basename -- "$resolver_filepath" )"
    if [[ $resolver_filename =~ ^[a-z]+$ ]]; then
      D_QUEUE_MAIN[$min+$ii]="$resolver_filename"
      D_QUEUE_ASSETS[$min+$ii]="$resolver_filepath"
      D_QUEUE_TARGETS[$min+$ii]="/etc/resolver/$resolver_filename"
      ((++ii))
    fi
  done
  $D__RESTORE_NULLGLOB
  (($ii)) && D_ADDST_COPY_QUEUE_EXACT=true
  d__queue_split
  d__copy_queue_check
}
d_resolvers_install()  { d__copy_queue_install;  }
d_resolvers_post_install()
{
  [ "$D__TASK_INSTALL_CODE" -eq 0 ] || D_ADDST_MLTSK_HALT=true
  return 0
}
d_resolvers_remove()   { d__copy_queue_remove;   }


##
## Task 'landings' (copy-queue)
##
d_landings_check()
{
  local min=${#D_QUEUE_MAIN[@]}
  D_QUEUE_MAIN+=( \
    index-macos.html \
    index-brew.html \
  )
  D_QUEUE_ASSETS[$min+0]="$D__DPL_DIR/landings/index-macos.html"
  D_QUEUE_ASSETS[$min+1]="$D__DPL_DIR/landings/index-brew.html"
  D_QUEUE_TARGETS[$min+0]="/Library/WebServer/Documents/index.html"
  D_QUEUE_TARGETS[$min+1]='/usr/local/var/www/index.html'
  d__queue_split
  D_ADDST_COPY_QUEUE_EXACT=true
  d__copy_queue_check
}
d_landings_install()  { d__copy_queue_install;  }
d_landings_post_install()
{
  [ "$D__TASK_INSTALL_CODE" -eq 0 ] || D_ADDST_MLTSK_HALT=true
  return 0
}
d_landings_remove()   { d__copy_queue_remove;   }


##
## Task 'sites_dir' (custom)
##
d_sites_dir_check()
{
  # Compose directory path; perform check
  local sites_dir="$HOME/Sites"
  if [ -d "$sites_dir" ]; then
    if [ "$D__REQ_ROUTINE" = install ]; then
      d__notify -ls -- "Already exists: $sites_dir"
      return 3
    fi
    d__stash -s -- has sites_dir_created && return 1 || return 7
  elif [ -e "$sites_dir" ]; then
    if [ "$D__REQ_ROUTINE" = remove ]; then
      d__notify -l! -- "Existing non-directory: $sites_dir"
    else
      d__notify -lx -- "Existing non-directory: $sites_dir"
      D_ADDST_MLTSK_IRRELEVANT=true
      return 3
    fi
  else
    if [ "$D__REQ_ROUTINE" = remove ]; then
      d__notify -ls -- "Already not exists: $sites_dir"
      return 3
    fi
    d__stash -s -- has sites_dir_created && return 6 || return 2
  fi
}
d_sites_dir_install()
{
  # Compose directory path; make directory
  local sites_dir="$HOME/Sites"
  if mkdir -p -m 0700 -- "$sites_dir" &>/dev/null; then
    d__stash -- set sites_dir_created
    return 0
  else
    d__notify -lx -- "Failed to create directory: $sites_dir"
    return 1
  fi
}
d_sites_dir_post_install()
{
  [ "$D__TASK_INSTALL_CODE" -eq 0 ] || D_ADDST_MLTSK_HALT=true
  return 0
}
d_sites_dir_remove()
{
  # Compose directory path
  local sites_dir="$HOME/Sites"

  # If not empty, prompt user
  if [ -n "$( ls -Aq -- "$sites_dir" 2>/dev/null )" ]; then
    d__prompt -xp 'Erase?' -- \
      "This will ${BOLD}completely erase$NORMAL non-empty directory at:" \
      -i- "$BOLD$RED$REVERSE $sites_dir $NORMAL"
    case $? in
      1)  return 2;;
      *)  :;;
    esac
  fi

  # Proceed to removal
  if rm -rf -- "$sites_dir" &>/dev/null; then
    d__stash -s -- unset sites_dir_created
    return 0
  else
    return 1
  fi
}


##
## Task 'sites_link' (link-queue)
##
d_sites_link_check()
{
  local min=${#D_QUEUE_MAIN[@]}
  D_QUEUE_MAIN[$min+0]='~/Sites'
  D_QUEUE_ASSETS[$min+0]="$HOME/Sites"
  D_QUEUE_TARGETS[$min+0]='/usr/local/sites'
  d__queue_split
  d__link_queue_check
}
d_sites_link_install()  { d__link_queue_install;  }
d_sites_link_post_install()
{
  [ "$D__TASK_INSTALL_CODE" -eq 0 ] || D_ADDST_MLTSK_HALT=true
  return 0
}
d_sites_link_remove()   { d__link_queue_remove;   }


##
## Task 'cert' (custom)
##
d_cert_check()
{
  d__stash -s -- has certificates_set_up && return 1 || return 2
}
d_cert_install()
{
  # Switch context; warn about sudo operations
  d__context -- notch
  d__context -- push 'Setting up local self-signed certificates'
  d__notify -u! -- 'Upcoming commands require sudo privelege'

  ## Generate root certificate (and password-less private key), which will be 
  #. trusted by the OS and used to sign any number of certificates for locally 
  #. hosted domains.
  #
  if ! openssl req -x509 -new -newkey rsa:2048 -nodes -sha256 -days 730 \
    -keyout "$D__DPL_ASSET_DIR/ceritficates/rootCA.key" \
    -out "$D__DPL_ASSET_DIR/ceritficates/rootCA.pem" \
    -subj '/C=US/ST=Firmament/L=Pantheon/O=Divine.dotfiles/OU=Deployment macos-local-server/CN=com.divine-dotfiles.macos-local-server'
  then
    d__fail -- 'Failed to create root certificate'
    return 1
  fi

  ## A relatively uncommon common name (CN) is used for the root certificate to 
  #. prevent clobbering of actual certificates. As a precaution, delete 
  #. pre-existing certificate with that CN, if any exists, from the system 
  #. keychain.
  #
  sudo security delete-certificate \
    -c 'com.divine-dotfiles.macos-local-server' \
    '/Library/Keychains/System.keychain'
  # Add root certificate as trusted to system keychain
  if ! sudo security add-trusted-cert \
    -d -r trustRoot \
    -k '/Library/Keychains/System.keychain' \
    "$D__DPL_ASSET_DIR/ceritficates/rootCA.pem"
  then
    d__fail -- 'Failed to trust root certificate'
    return 1
  fi

  ## Create a child certificate signing request with no domains attached to it 
  #. yet; the attachments will come at the signing phase.
  #
  if ! openssl req -new -newkey rsa:2048 -nodes -sha256 \
    -keyout "$D__DPL_ASSET_DIR/ceritficates/server.key" \
    -out "$D__DPL_ASSET_DIR/ceritficates/server.csr" \
    -subj '/C=US/ST=Firmament/L=Pantheon/O=Divine.dotfiles/OU=Deployment macos-local-server/CN=Local test sites'
  then
    d__fail -- 'Failed to create certificate signing request'
    return 1
  fi
  
  ## Sign the certificate, attaching extension file, which forces usage of 
  #. x509v3. The extension file contains usage directives (which might be 
  #. required by some browsers) and certified domains via subjectAltName (SAN).
  #
  ## Known issues:
  #
  ## Browsers do not support top level wildcards, hence *.divine.test instead 
  #. of more logical *.test.
  #
  ## Current Safari 13.0.4 has an apparent bug that invalidates wildcards 
  #. specifically on .test domains, rendering the resulting certificate 
  #. unusable on macOS currently.
  #
  ## Firefox needs 'security.enterprise_roots.enabled' set to 'true' in 
  #. 'about:config' page.
  #
  if ! openssl x509 -req -sha256 -days 730 \
    -in "$D__DPL_ASSET_DIR/ceritficates/server.csr" \
    -CA "$D__DPL_ASSET_DIR/ceritficates/rootCA.pem" \
    -CAkey "$D__DPL_ASSET_DIR/ceritficates/rootCA.key" \
    -CAcreateserial \
    -extfile "$D__DPL_ASSET_DIR/ceritficates/v3.ext" \
    -out "$D__DPL_ASSET_DIR/ceritficates/server.crt"
  then
    d__fail -- 'Failed to sign certificate signing request'
    return 1
  fi

  d__stash -s -- set certificates_set_up
}
d_cert_post_install()
{
  [ "$D__TASK_INSTALL_CODE" -eq 0 ] || D_ADDST_MLTSK_HALT=true
  return 0
}
d_cert_remove()
{
  rm -f -- "$D__DPL_ASSET_DIR/ceritficates/server.crt"
  rm -f -- "$D__DPL_ASSET_DIR/ceritficates/server.csr"
  rm -f -- "$D__DPL_ASSET_DIR/ceritficates/server.key"
  sudo security delete-certificate \
    -c 'com.divine-dotfiles.macos-local-server' \
    '/Library/Keychains/System.keychain'
  rm -f -- "$D__DPL_ASSET_DIR/ceritficates/rootCA.pem"
  rm -f -- "$D__DPL_ASSET_DIR/ceritficates/rootCA.srl"
  rm -f -- "$D__DPL_ASSET_DIR/ceritficates/rootCA.key"
  d__stash -s -- unset certificates_set_up
}


##
## Task 'cert_link' (link-queue)
##
d_cert_link_check()
{
  local min=${#D_QUEUE_MAIN[@]}
  D_QUEUE_MAIN[$min+0]='server.crt'
  D_QUEUE_MAIN[$min+1]='server.key'
  D_QUEUE_ASSETS[$min+0]='/usr/local/etc/httpd/server.crt'
  D_QUEUE_ASSETS[$min+1]='/usr/local/etc/httpd/server.key'
  D_QUEUE_TARGETS[$min+0]="$D__DPL_ASSET_DIR/certificates/server.crt"
  D_QUEUE_TARGETS[$min+1]="$D__DPL_ASSET_DIR/certificates/server.key"
  d__link_queue_check
}
d_cert_link_install()  { d__link_queue_install;  }
d_cert_link_post_install()
{
  [ "$D__TASK_INSTALL_CODE" -eq 0 ] || D_ADDST_MLTSK_HALT=true
  return 0
}
d_cert_link_remove()   { d__link_queue_remove;   }


##
## Task 'set_up' (custom)
##

d_set_up_check()
{
  d__stash -s -- has server_set_up && return 1 || return 2
}
d_set_up_install()
{
  d__prompt -x -- 'About to shut down built-in httpd and launch services for' \
    'Homebrew httpd, mariadb, and dnsmasq'
  case $? in
    1)  return 2;;
    *)  :;;
  esac
  d__context -- notch
  d__context -- push 'Setting up local macOS development server'
  d__notify -u! -- 'Upcoming commands might require sudo privelege'
  if d__cmd ---- sudo apachectl stop \
    &&  d__cmd ---- sudo launchctl unload -w \
          /System/Library/LaunchDaemons/org.apache.httpd.plist \
    &&  d__cmd ---- sudo brew services start httpd \
    &&  d__cmd ---- brew services start mariadb \
    &&  d__cmd ---- /usr/local/bin/mysql_secure_installation \
    &&  d__cmd ---- sudo brew services start dnsmasq
  then
    d__stash -s -- set server_set_up
    d__context -- lop
    return 0
  else
    return 1
  fi
}
d_set_up_post_install()
{
  if [ "$D__TASK_INSTALL_CODE" -ne 0 ]; then
    d__notify -lx -- 'One of the server set-up commands failed' \
      -n- 'Please, fix the problem and re-try'
    return 0
  fi
  if sudo apachectl configtest; then
    sudo apachectl -k restart
  else
    d__notify -lx -- 'httpd configuration check failed'
    d__notify -l! -- 'Please restart httpd manually with:' \
      -i- '$ sudo apachectl -k restart'
  fi
  D_ADDST_HELP+=('Reboot is required to finilize installation')
  return 0
}
d_set_up_remove()
{
  d__prompt -x -- 'About to shut down services for Homebrew httpd, mariadb,' \
    'and dnsmasq and launch built-in httpd'
  case $? in
    1)  return 2;;
    *)  :;;
  esac
  d__context -- notch
  d__context -- push 'Dismantling local macOS development server'
  d__notify -u! -- 'Upcoming commands might require sudo privelege'
  if d__cmd ---- sudo brew services stop dnsmasq \
    && d__cmd ---- brew services stop mariadb \
    && d__cmd ---- sudo brew services stop httpd \
    && d__cmd ---- sudo launchctl load -w \
      /System/Library/LaunchDaemons/org.apache.httpd.plist
  then
    d__stash -s -- unset server_set_up
    d__context -- lop
    return 0
  else
    return 1
  fi
}
d_set_up_post_remove()
{
  if [ "$D__TASK_REMOVE_CODE" -ne 0 ]; then
    d__notify -lx -- 'One of the server dismantling commands failed' \
      -n- 'Please, fix the problem and re-try'
    D_ADDST_MLTSK_HALT=true
    return 0
  fi
  if sudo apachectl configtest; then
    sudo apachectl -k restart
  else
    d__notify -lx -- 'httpd configuration check failed'
    d__notify -l! -- 'Please restart httpd manually with:' \
      -i- '$ sudo apachectl -k restart'
  fi
  D_ADDST_HELP+=('Reboot is required to finilize removal')
  return 0
}