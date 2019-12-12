#:title:        Divine deployment: macos-local-server
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2019.12.12
#:revremark:    Force manager-only versions of bottles
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
  D_QUEUE_FLAGS=( 'm' 'm' 'm' 'm' 'm' 'm' )
  d__queue_split
  d__pkg_queue_check
}
d_bottles_install() { d__pkg_queue_install; }
d_bottles_post_install()
{ [ "$D__QUEUE_CHECK_CODE" -eq 0 ] || D_ADDST_MLTSK_HALT=true; }
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
    d__notify -l! -- 'Failed to extract path to php.ini directory'
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
  }
  d_link_item_post_remove()
  {
    if [ "$D__ITEM_NAME" = php.ini -a "$D__ITEM_REMOVE_CODE" -eq 0 ]; then
      if ! d__stash -s -- unset php_etc_dir; then
        d__notify -lx -- "Failed to record PHP etc directory: '$PHP_ETC_DIR'"
      fi
    fi
  }
  d__link_queue_check
}
d_configs_install()  { d__link_queue_install;  }
d_configs_post_install()
{ [ "$D__QUEUE_CHECK_CODE" -eq 0 ] || D_ADDST_MLTSK_HALT=true; }
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
{ [ "$D__QUEUE_CHECK_CODE" -eq 0 ] || D_ADDST_MLTSK_HALT=true; }
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
  d__copy_queue_check
}
d_landings_install()  { d__copy_queue_install;  }
d_landings_remove()   { d__copy_queue_remove;   }


##
## Task 'set_up' (custom)
##

d_set_up_check()
{
  d__stash -s -- has server_set_up && return 5 || return 9
}
d_set_up_install()
{
  d__context -- notch
  d__context -- push 'Setting up local macOS development server'
  d__notify -u! -- 'Upcoming commands might require sudo privelege'
  if d__cmd ---- xcode-select --install \
    &&  d__cmd ---- sudo apachectl stop \
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