#######################################################################################################
# Helper Functions
#######################################################################################################
write_log() {
  local NOW=$(date '+%d/%m/%Y %T')
  local loglevel=$1
  local logmsg=""

  shift
  logmsg=$@
  if [ "$loglevel" != "DEBUG" ]; then
    echo "$logmsg"
  fi
  echo "[$NOW] $loglevel  $logmsg" >> $SCRIPT_LOG_FILE
}

log_info() {
  write_log "INFO" $@
}

log_debug() {
  write_log "DEBUG" $@
}

log_error() {
  write_log "ERROR" $@
}

check_errmsg_and_exit() {
  local error_code=$?
  if [ $error_code -ne 0 ]; then
     log_error $1 "- errcode: [$error_code]"
     cd $SCRIPT_PWD
     exit 1
  fi
}

errmsg_and_exit() {
  log_error $1
  cd $SCRIPT_PWD
  exit 1
}

######################################################
#  Function:  get_system_architecture()
#  Description:   Determine architecture and platform
######################################################
get_system_architecture () {
  log_debug "get_system_architecture: start"
  PLATFORM_NAME="unknown"
  PLATFORM=`/bin/uname`
  UNAME=`/bin/uname -m`

  case $PLATFORM in
    AIX)
		PLATFORM_NAME="AixPPC64"
    ;;
    Linux)
        case $UNAME in
			*86*64*)  PLATFORM_NAME="LinuxX64";;
			#s390*)  PLATFORM_NAME="LinuxS390";;
		esac

		if [ -e /etc/SuSE-release ]; then
		  LINUX_DISTRIBUTION="suse"
		elif [ -e /etc/redhat-release ]; then
		  LINUX_DISTRIBUTION="redhat"
		else
		  LINUX_DISTRIBUTION="unknown"
		fi
    ;;
  esac
  log_debug "get_system_architecture: end"
  return 0
}

######################################################
#  Function:  init_script_environment()
#  Description:
#     - Configure Script Environment
######################################################
init_script_environment () {
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")

  SCRIPT_LOGS_DIR="$SCRIPT_PWD/logs"
  SCRIPT_LOG_FILE="$SCRIPT_PWD/logs/SystemOut.log"
  SCRIPT_TEMP_DIR="$SCRIPT_PWD/temp"
  SCRIPT_RSP_DIR="$SCRIPT_PWD/responsefiles"

  mkdir -p $SCRIPT_LOGS_DIR
  if [ $? -ne 0 ]; then
     echo "init_script_environment: Erro na criacao arquivo de log"
     exit 1
  fi

  if [ -f $SCRIPT_LOG_FILE ]; then
     cp $SCRIPT_LOG_FILE $SCRIPT_LOG_FILE"_"$lNow
  fi

  echo "########################### $0 - Start Log ###########################" > $SCRIPT_LOG_FILE

  mkdir -p $SCRIPT_TEMP_DIR
  check_errmsg_and_exit "init_script_environment: [ERROR] Cannot create $SCRIPT_TEMP_DIR directory"
  mkdir -p $SCRIPT_RSP_DIR
  check_errmsg_and_exit "init_script_environment: [ERROR] Cannot create $SCRIPT_RSP_DIR directory"

  mkdir -p "$IBM_ROOT/CTemp"
  check_errmsg_and_exit "init_script_environment: [ERROR] Cannot create $IBM_ROOT/CTemp directory"

  SHARED_DIR=$IBM_ROOT"/IMShared"
  # IBM Installation Manager Default Home
  IBM_IM_ROOT=$IBM_ROOT"/InstallationManager"
  # WebSphere Default Home
  WEBSPHERE_ROOT=$IBM_ROOT"/WebSphere"
  # WAS Applicaton Server Default Home
  APPSERVER_ROOT=$WEBSPHERE_ROOT"/AppServer"
  # IBM HTTP Server
  IHS_ROOT=$IBM_ROOT"/HTTPServer85"
  PLG_ROOT=$WEBSPHERE_ROOT"/Plugins"
  WCT_ROOT=$WEBSPHERE_ROOT"/Toolbox"


  echo "$lNow" >> $SCRIPT_LOG_FILE
  log_debug "init_script_environment: end"

  return 0
}

######################################################
#  Function:  TunningLinuxX86()
#  Description:
#    - You can check values at http://www-10.lotus.com/ldd/portalwiki.nsf/dx/IBM_WebSphere_Portal_V_8.0_Performance_Tuning_Guide
#    - Change /etc/security/limits.conf for open files
#    - Make the backup of /etc/sysctl.conf
#  Returns:
#		0 - specified product installer successfully
######################################################
tuning_os_linux_x86 () {
  log_debug "tuning_os_linux_x86 : start"

  log_info "tuning_os_linux_x86: - Start"

  log_info "tuning_os_linux_x86: - Configure Open Files"
  local NOW=$(date +"%Y-%m-%d-%H-%M-%S")

  local c01="/\*.*soft.*nofile/d"
  local c02="/\*.*hard.*nofile/d"
  local c03="/root.*soft.*nofile/d"
  local c04="/root.*hard.*nofile/d"
  local c05="/Values defined to IBM Portal/d"

  cp /etc/security/limits.conf /etc/security/limits.conf_$NOW

  sed -e "$c01" -e "$c02" -e "$c03" -e "$c04" -e "$c05" /etc/security/limits.conf_$NOW > /etc/security/limits.conf

  echo "############################################" >> /etc/security/limits.conf
  echo "## Values defined to IBM Portal ##"           >> /etc/security/limits.conf
  echo "############################################" >> /etc/security/limits.conf
  echo "root            soft    nofile   65535"       >> /etc/security/limits.conf
  echo "root            hard    nofile   65535"       >> /etc/security/limits.conf

  log_info "tuning_os_linux_x86: - Configure Open Files at Runtime"
  ulimit -n 65535


  log_info "tuning_os_linux_x86: - Tuning TCPIP "
  cp /etc/sysctl.conf /etc/sysctl.conf_$NOW

  echo "" > /etc/sysctl.conf

cat << EOD > /etc/sysctl.conf
# Disable response to broadcasts.
# You don't want yourself becoming a Smurf amplifier.
net.ipv4.icmp_echo_ignore_broadcasts = 1
# enable route verification on all interfaces
net.ipv4.conf.all.rp_filter = 1
# enable ipV6 forwarding
#net.ipv6.conf.all.forwarding = 1
# increase the number of possible inotify(7) watches
fs.inotify.max_user_watches = 65536
# avoid deleting secondary IPs on deleting the primary IP
net.ipv4.conf.default.promote_secondaries = 1
net.ipv4.conf.all.promote_secondaries = 1
############## Inicio das Configuracoes
net.ipv4.ip_forward = 0
net.ipv4.conf.default.accept_source_route = 0
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_fin_timeout = 15
net.core.netdev_max_backlog = 3000
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_keepalive_time = 1800
net.ipv4.ip_local_port_range = 1024 65000

# disable SYN cookies
# Note: make sure this syncookies=1 item is commented out (it will already exist in this file).
net.ipv4.tcp_syncookies=0

# increase the TCP backlog to increase simultaneous new connection creation abilities
net.ipv4.tcp_max_syn_backlog = 200000
net.core.somaxconn = 200000

# increase and recycle TCP connection blocks for reuse in an optimal manner
net.ipv4.tcp_max_tw_buckets = 2000000

# disable Selective Acknowledgements for 1GBps networking
net.ipv4.tcp_sack = 0
net.ipv4.tcp_dsack = 0
net.ipv4.tcp_timestamps = 0

#increase kernel memory by doubling the default (check your system first!)
#the value of this item will be related to the memory in your system
vm.min_free_kbytes = 393216
vm.swappiness = 0

# manage the TCP network buffer sizings
net.core.netdev_max_backlog = 200000
############## Fim das Configuracoes
EOD

  log_debug "tuning_os_linux_x86 : end"
  return 0
}

cleanup_binarios() {
  rm -fr /opt/IBM/Binarios/
}

cleanup_deploy() {
  rm -fr /var/ibm/InstallationManager/
  rm -fr /opt/IBM/InstallationManager/
  rm -fr /opt/IBM/WebSphere/
  rm -fr /opt/IBM/IMShared/
  rm -fr /opt/IBM/LotusConnections/
  rm -fr /opt/IBM/Connections/
  rm -fr /opt/IBM/db2
  rm -fr /opt/IBM/CTemp
  rm -fr /etc/.ibm/
  rm -fr /opt/.ibm/
  #rm -fr /opt/IBM/Binarios/
  rm -fr $SCRIPT_TEMP_DIR
  rm -fr $SCRIPT_LOGS_DIR
  rm -f /var/.com.zerog.registry.xml
  rm -fr /root/.InstallAnywhere
}

#########################################################
# check if product is installed
########################################################
is_product_installed () {
  log_debug "is_product_installed : start"
  local PRODUCT="$1"

  # No value specified
  if [ "X$PRODUCT" = "X" ]; then
     log_debug "is_product_installed : Product is Null"
     return 1
  fi

  if [ ! -s "/var/ibm/InstallationManager/installed.xml" ]; then
     log_debug "is_product_installed : [/var/ibm/InstallationManager/installed.xml] not found"
     return 1
  fi

  case "$PRODUCT" in
    "IIM")
      PROD_NAME="IBM Installation Manager"
      PKG_ID="com.ibm.cic.agent"
    ;;
    "WAS85")
      PROD_NAME="IBM WebSphere Application Server V8.5"
      PKG_ID="com.ibm.websphere.ND.v85"
    ;;
    "PORTAL80")
      PROD_NAME="IBM WebSphere Portal Server"
      PKG_ID="com.ibm.websphere.PORTAL.SERVER.v80"
    ;;
    "IHS85")
      PROD_NAME="IBM HTTP Server V8.5"
      PKG_ID="com.ibm.websphere.IHS.v85"
    ;;
    "IHSPLG85")
      PROD_NAME="Web Server Plug-ins for IBM WebSphere Application Server"
      PKG_ID="com.ibm.websphere.PLG.v85"
    ;;
    "STSC90")
      PROD_NAME="IBM&#xAE; Sametime&#xAE; Server Platform"
      PKG_ID="com.ibm.lotus.sametime.systemconsoleserver"
    ;;
    "STPR90")
      PROD_NAME="IBM&#xAE; Sametime&#xAE; Server Platform"
      PKG_ID="com.ibm.lotus.sametime.proxyserver"
    ;;
    "STMT90")
      PROD_NAME="IBM&#xAE; Sametime&#xAE; Server Platform"
      PKG_ID="com.ibm.lotus.sametime.meetingserver"
    ;;
    "STMM90")
      PROD_NAME="IBM&#xAE; Sametime&#xAE; Server Platform"
      PKG_ID="com.ibm.lotus.sametime.mediaserver"
    ;;

    *)
     log_debug "is_product_installed : [$PRODUCT] not valid"
      return 1
    ;;
  esac

  PROD_ROOT=`egrep "location id" /var/ibm/InstallationManager/installed.xml | grep "$PROD_NAME" | sed "s,.*path='\([^']*\)'.*,\1,"`
  if [ "X$PROD_ROOT" = "X" ]; then
     log_debug "is_product_installed : [$PROD_ROOT] no location"
     return 1
  fi

  PROD_VERSION=`egrep "package kind='offering" /var/ibm/InstallationManager/installed.xml | grep "$PKG_ID" | sed "s,.*version='\([^']*\)'.*,\1,"`
  if [ "X$PROD_VERSION" = "X" ]; then
     log_debug "is_product_installed : [$PROD_VERSION] no version"
     return 1
  fi

  log_debug "is_product_installed : end"
  return 0
}

verify_checksum() {
  log_debug "verify_checksum: start"
  local filename=$1
  local sum=`sha256sum $filename | cut -f1 -d" "`

  log_debug "verify_checksum: for file $filename"

  case "$sum" in
    "c1cab8bf2c4c2d15f350fc4c7a564c248acc3227a5705406f9d94e6e0f108555")
        #agent.installer.linux.gtk.x86_64_1.8.4001.20160217_1716.zip
        log_debug "verify_checksum: valid"
    ;;
    "b1333962ba4b25c8632c7e4c82b472350337e99febac8f70ffbd551ca3905e83")
        #  WAS_ND_V8.5.5_1_OF_3.zip
        log_debug "verify_checksum: valid"
    ;;
    "440b7ed82089d43b1d45c1e908bf0a1951fed98f2542b6d37c8b5e7274c6b1c9")
        #WAS_ND_V8.5.5_2_OF_3.zip
        log_debug "verify_checksum: valid"
    ;;
    "b73ae070656bed6399a113c2db9fb0abaf5505b0d41c564bf2a58ce0b1e0dcd2")
        #WAS_ND_V8.5.5_3_OF_3.zip
        log_debug "verify_checksum: valid"
    ;;
    "d63c59de4a5548e3d26e71fefb76193d41ac7585bc450c1e504287e0a6f746c9")
        #  WAS_V8.5.5_SUPPL_1_OF_3.zip
        log_debug "verify_checksum: valid"
    ;;
    "ac00e7ab43cc528fe7f3ccd69aeb6564a2e738e7bc6e30e71fd2e0d4bd64f39e")
        #WAS_V8.5.5_SUPPL_2_OF_3.zip
        log_debug "verify_checksum: valid"
    ;;
    "94e3d9b70b139ad5fa0578da6857b295c5d2370c1b6ecb544c1e5757406fec90")
        #WAS_V8.5.5_SUPPL_3_OF_3.zip
        log_debug "verify_checksum: valid"
    ;;
    "ffd63ca69e1496f416e483e7ba7089a2b94b5538255b7eb037b672084f4870dc")
        #8.5.5-WS-WAS-FP0000008-part1.zip
        log_debug "verify_checksum: valid"cd
    ;;
    "14469a107c33083b5885dfeef010fe5fcb4b0815eb4ab3dadc5c47bbad6c4871")
        #8.5.5-WS-WAS-FP0000008-part2.zip
        log_debug "verify_checksum: valid"
    ;;
    "fe17129ab2bb7b253c3ee3baa24b516b1034f603b18320f4b7ac7605e38c43ed")
        #8.5.5-WS-WASSupplements-FP0000008-part1.zip
        log_debug "verify_checksum: valid"cd
    ;;
    "98689c3ae576e67f13cee567864b4e95543b6658d9a3c0a08b2f1adce9d94b6a")
        #8.5.5-WS-WASSupplements-FP0000008-part2.zip
        log_debug "verify_checksum: valid"
    ;;
    "628fded0398fbbfec9af6e45118d236d15778b59db3441a8cc7736dcc8e384df")
        #7.1.3.10_0001-WS-IBMWASJAVA-Linux.zip
        log_debug "verify_checksum: valid"
    ;;
    "6a775827550ebf4bacfce0426bbc22db8e427f56d8a50ee9ca469385a7e88867")
        #IBM_Connections_5.5_lin.tar
        log_debug "verify_checksum: valid"
    ;;
    "78091d65768221fa492df20c89ce4d3a08592f6acc4995efb09db05be07a4b48")
        #IBM_Cognos_Wizard_5.5_lin.tar
        log_debug "verify_checksum: valid"
    ;;
    "451d5cada94b8ce5a8a32888aa71e41c50b975eb7db75118c27db1e4d27213d5")
        #IBM_ConnectionsSurvey_5.5_lin.tar
        log_debug "verify_checksum: valid"
    ;;
    "1e2d01114c3ae9a143f1423ea8d5f0cd089ef879403ed606f719ddc8a4cf9488")
        #5.2.1-P8CPE-CLIENT-LINUX.BIN
        log_debug "verify_checksum: valid"
    ;;
    "456b7d36cde1cf174f8893999b034f49ac2b0558b96e8160a8197fcf916c3e3d")
        #5.2.1-P8CPE-LINUX.BIN
        log_debug "verify_checksum: valid"
    ;;
    "6ba6a75ebaea4a6035df63ab4018b38fdff968acf7155d96785acefc233328af")
        #5.2.1.2-P8CPE-CLIENT-LINUX-FP002.BIN
        log_debug "verify_checksum: valid"
    ;;
    "95627a790b7f28196bc22fd11ce0dacfd49af03591b24935ca875532eaeb65d1")
        #5.2.1.2-P8CPE-LINUX-FP002.BIN
        log_debug "verify_checksum: valid"
    ;;
    "b4f58d8933e2283610802aa7645c10e9c950b0e92a254954dcf306d672bda8e3")
        #IBM_CONTENT_NAVIGATOR-2.0.3-LINUX.bin
        log_debug "verify_checksum: valid"
    ;;
    "3c3887a38cdd86f83d4d31274746d4d6de65bc8aa0d8484458dc44676db5a07d")
        #IBM_CONTENT_NAVIGATOR-2.0.3.5-FP005-LINUX.bin
        log_debug "verify_checksum: valid"
    ;;
    "a394e5f4c8065f64f5237998da44fbd4dcc7ef8bd7b5ef0d6167c010cce5e230")
        #bi_svr_10.2.2_l86_ml.tar.gz
        log_debug "verify_checksum: valid"
    ;;
    "5337a0a54038439518f088a0039a0ca7d5696aba1bfeaa733bcd18e049036dff")
        #bi_trfrm_10.2.2_l86_ml.tar.gz
        log_debug "verify_checksum: valid"
    ;;
    "5337a0a54038439518f088a0039a0ca7d5696aba1bfeaa733bcd18e049036dff")
        #bi_trfrm_10.2.2_l86_ml.tar.gz
        log_debug "verify_checksum: valid"
    ;;
    "ea0509c83fc355cd91b606478e6b02c138f7727dbc5b98208c84f57054055237") #5.5.0.0-IC-CR1-CognosWizard-LO88785-Linux.tar
      log_debug "verify_checksum: valid"
    ;;
    "346cc594fab01a21fa0ef3c609f80833200010f59d2984663e8ef892c11a92f4") #  5.5.0.0-IC-Multi-CR01-LO88602.zip
      log_debug "verify_checksum: valid"
    ;;
    "7da651c20fec2592fd0955c042b28b40a8b4e6fe2caa362d4d0b658567a47ddd") #  5.5.0.0-IC-Multi-UPDI-20160628.zip
      log_debug "verify_checksum: valid"
    ;;
    "8a140e10e2c9103d7c88faeecaf92252b4d277d27cfe6934b72d7061c1f1e935") #  5.5.0.0_CR1-IC-Search-IFLO89575.jar
      log_debug "verify_checksum: valid"
    ;;
    "081877883a642a4b16bd94a3cc1e21b609798ce28bd56c4c1184cd8eeeee5810") #  IC5.5.0.0_CR1-IC-Multi-IFLO89638.jar
      log_debug "verify_checksum: valid"
    ;;
    "9d16f56e5e193071f82de955a0a71240fdabda2e69dc06dde766d24ef57acf27") #  v10.5fp7_linuxx64_client.tar.gz
      log_debug "verify_checksum: valid"
    ;;
    "81fb26227b4ca16f59f78784cb61dd74ab145eef43267b53d5dce4a99908ce89") #  v10.5fp7_linuxx64_client.tar.gz
      log_debug "verify_checksum: valid"
    ;;
    #"")
    #    #
    #    log_debug "verify_checksum: valid"
    #;;
    *)
        log_debug "verify_checksum: not valid"
        return 1
    ;;
  esac

  log_debug "verify_checksum: end"
  return 0
}

extract_installation_manager() {
  log_debug "extract_installation_manager:  start"

  extract_checksum "extract_installation_manager" $IIM_BIN_DIR $IIM_BIN_FILE

  log_info "extract_installation_manager:  success"
  log_debug "extract_installation_manager:  end"
  return 0
}

extract_checksum() {
  log_debug "extract_checksum:  start"
  local fncname=$1
  local currentDirectory=$2
  local filename=$3

  verify_checksum "$currentDirectory/$filename"
  check_errmsg_and_exit "$fncname: [ERROR] Checksum Error $currentDirectory/$filename"

  case "$filename" in
    *zip*)
     unzip -o $currentDirectory/$filename -d $currentDirectory  >> $SCRIPT_LOG_FILE 2>&1
      ;;
    *tar.gz*)
       tar -xzvf $currentDirectory/$filename -C $currentDirectory  >> $SCRIPT_LOG_FILE 2>&1
       ;;
    *tgz*)
       tar -xzvf $currentDirectory/$filename -C $currentDirectory  >> $SCRIPT_LOG_FILE 2>&1
     ;;
     *tar*)
      tar -xvf $currentDirectory/$filename -C $currentDirectory  >> $SCRIPT_LOG_FILE 2>&1
       ;;
  esac
  check_errmsg_and_exit "$fncname: [ERROR] on extract $currentDirectory/$filename"

  log_info "$fncname: extract $filename success"
  log_debug "extract_checksum:  end"
  return 0
}

extract_was_nd() {
  log_debug "extract_was_nd:  start"

  extract_checksum "extract_was_nd" $WAS_ND_BIN_DIR $WAS_BIN_01
  extract_checksum "extract_was_nd" $WAS_ND_BIN_DIR $WAS_BIN_02
  extract_checksum "extract_was_nd" $WAS_ND_BIN_DIR $WAS_BIN_03

  log_info "extract_was_nd:  success"
  log_debug "extract_was_nd:  end"
  return 0
}

extract_was_nd_fixes() {
  log_debug "extract_was_nd_fixes:  start"

  extract_checksum "extract_was_nd_fixes" $WAS_ND_FIX_BIN_DIR $WAS_FIX_BIN_01
  extract_checksum "extract_was_nd_fixes" $WAS_ND_FIX_BIN_DIR $WAS_FIX_BIN_02

  log_info "extract_was_nd_fixes:  success"
  log_debug "extract_was_nd_fixes:  end"
  return 0
}



extract_jdk7() {
  log_debug "extract_jdk7:  start"

  extract_checksum "extract_jdk7" $JDK_BIN_DIR $JDK_BIN_FILE

  log_info "extract_jdk7:  success"
  log_debug "extract_jdk7:  end"
  return 0
}

extract_was_sup() {
  log_debug "extract_was_sup:  start"

  extract_checksum "extract_was_sup" $WAS_SUP_BIN_DIR $WAS_BIN_04
  extract_checksum "extract_was_sup" $WAS_SUP_BIN_DIR $WAS_BIN_05
  extract_checksum "extract_was_sup" $WAS_SUP_BIN_DIR $WAS_BIN_06

  log_info "extract_was_sup:  success"
  log_debug "extract_was_sup:  end"
  return 0
}

extract_was_sup_fixes() {
  log_debug "extract_was_sup_fixes:  start"

  extract_checksum "extract_was_sup_fixes" $WAS_SUP_FIX_BIN_DIR $WAS_FIX_BIN_03
  extract_checksum "extract_was_sup_fixes" $WAS_SUP_FIX_BIN_DIR $WAS_FIX_BIN_04

  log_info "extract_was_sup_fixes:  success"
  log_debug "extract_was_sup_fixes:  end"
  return 0
}

######################################################
#  Install IBM Installation Manager
######################################################
install_installation_manager () {
  log_debug "install_installation_manager : start"

  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")

  if is_product_installed "IIM" ; then
     log_info "-- Already installed"
     return 1
  fi

  if [ ! -x "$IIM_BIN_DIR/tools/imcl" ] ; then
     errmsg_and_exit "imcl not available or executable permission: [$IIM_BIN_DIR/tools/imcl]"
  fi

  local shellCmd="$IIM_BIN_DIR/tools/imcl install com.ibm.cic.agent -acceptLicense -installationDirectory $IBM_IM_ROOT -repositories $IIM_BIN_DIR -log $SCRIPT_LOGS_DIR/iim_install_log_info_$lNow.log"
  echo $shellCmd >> $SCRIPT_LOG_FILE
  $shellCmd    >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_installation_manager [ERROR]"

  log_info "install_installation_manager:  success"
  log_debug "install_installation_manager : end"
  return 0
}

######################################################
#  Install WebSphere Application Server Network Deployment
######################################################
install_was_nd () {
  log_debug "install_was_nd : start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")
  local filenameOut="$SCRIPT_LOGS_DIR/installWAS855_$lNow.rsp"

  if is_product_installed "$WAS_ND_VERSION" ; then
     log_info "-- Already installed"
     return 1
  fi
  log_debug "install_was_nd : starting install"

  if [ ! -x "$IBM_IM_ROOT/eclipse/tools/imcl" ] ; then
     errmsg_and_exit "install_was_nd: imcl not available or executable permission: [$IBM_IM_ROOT/eclipse/tools/imcl]"
  fi

  if [ ! -f "$WAS_ND_BIN_DIR/disk1/diskTag.inf" ] ; then
     errmsg_and_exit "install_was_nd: install files not available: [$WAS_ND_BIN_DIR/disk1/diskTag.inf]"
  fi

  if [ ! -f "$WAS_ND_BIN_DIR/disk2/diskTag.inf" ] ; then
     errmsg_and_exit "install_was_nd: install files not available: [$WAS_ND_BIN_DIR/disk2/diskTag.inf]"
  fi
  if [ ! -f "$WAS_ND_BIN_DIR/disk3/diskTag.inf" ] ; then
     errmsg_and_exit "install_was_nd: install files not available: [$WAS_ND_BIN_DIR/disk3/diskTag.inf]"
  fi

cat << EOFWASND > $filenameOut
<?xml version="1.0" encoding="UTF-8"?>
<agent-input acceptLicense='true'>
<server>
<repository location='$WAS_ND_BIN_DIR'/>
</server>
<profile id='IBM WebSphere Application Server V8.5' installLocation='$APPSERVER_ROOT'>
<data key='eclipseLocation' value='$APPSERVER_ROOT'/>
<data key='user.import.profile' value='false'/>
<data key='cic.selector.os' value='linux'/>
<data key='cic.selector.arch' value='x86'/>
<data key='cic.selector.ws' value='gtk'/>
<data key='cic.selector.nl' value='en'/>
</profile>
<install modify='false'>
<offering id='com.ibm.websphere.ND.v85' profile='IBM WebSphere Application Server V8.5' features='core.feature,ejbdeploy,thinclient,embeddablecontainer,com.ibm.sdk.6_64bit' installFixes='none'/>
</install>
<preference name='com.ibm.cic.common.core.preferences.eclipseCache' value='$SHARED_DIR'/>
<preference name='com.ibm.cic.common.core.preferences.connectTimeout' value='30'/>
<preference name='com.ibm.cic.common.core.preferences.readTimeout' value='45'/>
<preference name='com.ibm.cic.common.core.preferences.downloadAutoRetryCount' value='0'/>
<preference name='offering.service.repositories.areUsed' value='false'/>
<preference name='com.ibm.cic.common.core.preferences.ssl.nonsecureMode' value='false'/>
<preference name='com.ibm.cic.common.core.preferences.http.disablePreemptiveAuthentication' value='false'/>
<preference name='http.ntlm.auth.kind' value='NTLM'/>
<preference name='http.ntlm.auth.enableIntegrated.win32' value='true'/>
<preference name='com.ibm.cic.common.core.preferences.preserveDownloadedArtifacts' value='true'/>
<preference name='com.ibm.cic.common.core.preferences.keepFetchedFiles' value='false'/>
<preference name='PassportAdvantageIsEnabled' value='false'/>
<preference name='com.ibm.cic.common.core.preferences.searchForUpdates' value='false'/>
<preference name='com.ibm.cic.agent.ui.displayInternalVersion' value='false'/>
<preference name='com.ibm.cic.common.sharedUI.showErrorLog' value='true'/>
<preference name='com.ibm.cic.common.sharedUI.showWarningLog' value='true'/>
<preference name='com.ibm.cic.common.sharedUI.showNoteLog' value='true'/>
</agent-input>
EOFWASND


  local shellCmd="$IBM_IM_ROOT/eclipse/tools/imcl -acceptLicense -sVP -log $SCRIPT_LOGS_DIR/was_install_log_info_$lNow.log input $filenameOut"
  echo $shellCmd >> $SCRIPT_LOG_FILE
  $shellCmd    >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_was_nd: [ERROR] on install"

  log_info "install_was_nd:  success"
  log_debug "install_was_nd : end"
  return 0
}

######################################################
#  Install WAS ND Fixes
######################################################
install_was_nd_fixes () {
  log_debug "install_was_nd_fixes : start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")
  local filenameIn="$WAS_ND_FIX_RSP_FILE"
  local filenameOut="$SCRIPT_LOGS_DIR/installWAS855Fixes_$lNow.rsp"

  #if is_product_installed "$WAS_ND_FIX_VERSION" ; then
  #   log_info "-- Already installed"
  #   return 1
  #
  #fi
  log_debug "install_was_nd_fixes : starting install"

  if [ ! -x "$IBM_IM_ROOT/eclipse/tools/imcl" ] ; then
     errmsg_and_exit "install_was_nd_fixes: imcl not available or executable permission: [$IBM_IM_ROOT/eclipse/tools/imcl]"
  fi

cat << EOFWASFIXES > $filenameOut
<?xml version='1.0' encoding='UTF-8'?>
<agent-input>
  <variables>
    <variable name='sharedLocation' value='$SHARED_DIR'/>
  </variables>
  <server>
    <repository location='$WAS_ND_FIX_BIN_DIR'/>
  </server>
  <profile id='IBM WebSphere Application Server V8.5' installLocation='$APPSERVER_ROOT'>
    <data key='cic.selector.arch' value='x86'/>
  </profile>
  <install>
    <offering profile='IBM WebSphere Application Server V8.5' id='com.ibm.websphere.ND.v85' features='com.ibm.sdk.6_64bit,core.feature,ejbdeploy,embeddablecontainer,thinclient'/>
  </install>
  <preference name='com.ibm.cic.common.core.preferences.eclipseCache' value='${sharedLocation}'/>
  <preference name='offering.service.repositories.areUsed' value='false'/>
</agent-input>
EOFWASFIXES

  local shellCmd="$IBM_IM_ROOT/eclipse/tools/imcl -acceptLicense -sVP -log $SCRIPT_LOGS_DIR/was_fixes_install_log_info_$lNow.log input $filenameOut"
  echo $shellCmd >> $SCRIPT_LOG_FILE
  $shellCmd    >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_was_nd_fixes: [ERROR]"

  log_info "install_was_nd_fixes:  success"
  log_debug "install_was_nd_fixes : end"
  return 0
}

######################################################
#  Install Jdk 7
######################################################
install_jdk7 () {
  log_debug "install_jdk7 : start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")
  local filenameOut="$SCRIPT_LOGS_DIR/installJdk7_$lNow.rsp"

  log_debug "install_jdk7 : starting install"

  if [ ! -x "$IBM_IM_ROOT/eclipse/tools/imcl" ] ; then
     errmsg_and_exit "install_jdk7: imcl not available or executable permission: [$IBM_IM_ROOT/eclipse/tools/imcl]"
  fi

cat << EOFJDK7 > $filenameOut
<?xml version='1.0' encoding='UTF-8'?>
<agent-input>
  <variables>
    <variable name='sharedLocation' value='$SHARED_DIR'/>
  </variables>
  <server>
    <repository location='$JDK_BIN_DIR'/>
  </server>
  <profile id='IBM WebSphere Application Server V8.5' installLocation='$APPSERVER_ROOT'>
    <data key='cic.selector.arch' value='x86'/>
  </profile>
  <install>
    <offering profile='IBM WebSphere Application Server V8.5' id='com.ibm.websphere.IBMJAVA.v71' version='7.1.3010.20151112_0058' features='com.ibm.sdk.7.1'/>
  </install>
  <preference name='com.ibm.cic.common.core.preferences.eclipseCache' value='${sharedLocation}'/>
  <preference name='offering.service.repositories.areUsed' value='false'/>
</agent-input>
EOFJDK7

  local shellCmd="$IBM_IM_ROOT/eclipse/tools/imcl -acceptLicense -sVP -log $SCRIPT_LOGS_DIR/jdk_install_log_info_$lNow.log input $filenameOut"
  echo $shellCmd >> $SCRIPT_LOG_FILE
  $shellCmd    >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_jdk7: [ERROR]"

  log_info "install_jdk7:  success"
  log_debug "install_jdk7 : end"
  return 0
}

install_ihs () {
  log_debug "install_ihs : start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")
  local filenameOut="$SCRIPT_LOGS_DIR/installIHS_$lNow.rsp"

  log_debug "install_ihs : starting install"

  if [ ! -x "$IBM_IM_ROOT/eclipse/tools/imcl" ] ; then
     errmsg_and_exit "install_ihs: imcl not available or executable permission: [$IBM_IM_ROOT/eclipse/tools/imcl]"
  fi

cat << EOFIHS > $filenameOut
<?xml version='1.0' encoding='UTF-8'?>
<agent-input>
  <server>
    <repository location='$WAS_SUP_BIN_DIR'/>
    <repository location='$WAS_SUP_FIX_BIN_DIR'/>
  </server>
  <profile id='IBM HTTP Server V8.5' installLocation='$IHS_ROOT'>
    <data key='cic.selector.arch' value='x86'/>
    <data key='user.ihs.http.server.service.name' value='none'/>
    <data key='user.ihs.httpPort' value='80'/>
    <data key='user.ihs.installHttpService' value='false'/>
  </profile>
  <install>
    <offering profile='IBM HTTP Server V8.5' id='com.ibm.websphere.IHS.v85' version='8.5.5008.20151112_0939' features='core.feature,arch.64bit'/>
  </install>
  <preference name='com.ibm.cic.common.core.preferences.eclipseCache' value='$SHARED_DIR'/>
  <preference name='offering.service.repositories.areUsed' value='false'/>
</agent-input>
EOFIHS

  local shellCmd="$IBM_IM_ROOT/eclipse/tools/imcl -acceptLicense -sVP -log $SCRIPT_LOGS_DIR/ihs_install_log_info_$lNow.log input $filenameOut"
  echo $shellCmd >> $SCRIPT_LOG_FILE
  $shellCmd    >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_ihs: [ERROR]"

  log_info "install_ihs:  success"
  log_debug "install_ihs : end"
  return 0
}

install_plgwct () {
  log_debug "install_plgwct : start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")
  local filenameOut="$SCRIPT_LOGS_DIR/installPlgWct_$lNow.rsp"

  log_debug "install_plgwct : starting install"

  if [ ! -x "$IBM_IM_ROOT/eclipse/tools/imcl" ] ; then
     errmsg_and_exit "install_plgwct: imcl not available or executable permission: [$IBM_IM_ROOT/eclipse/tools/imcl]"
  fi

cat << EOFIHS > $filenameOut
<?xml version='1.0' encoding='UTF-8'?>
<agent-input>
  <server>
    <repository location='$WAS_SUP_BIN_DIR'/>
    <repository location='$WAS_SUP_FIX_BIN_DIR'/>
  </server>
  <profile id='Web Server Plug-ins for IBM WebSphere Application Server V8.5' installLocation='$PLG_ROOT'>
    <data key='cic.selector.arch' value='x86'/>
  </profile>
  <install>
    <!-- Web Server Plug-ins for IBM WebSphere Application Server 8.5.5.8 -->
    <offering profile='Web Server Plug-ins for IBM WebSphere Application Server V8.5' id='com.ibm.websphere.PLG.v85' version='8.5.5008.20151112_0939' features='core.feature,com.ibm.jre.6_64bit'/>
  </install>
  <profile id='WebSphere Customization Toolbox V8.5' installLocation='$WCT_ROOT'>
    <data key='cic.selector.arch' value='x86'/>
  </profile>
  <install>
    <!-- WebSphere Customization Toolbox  8.5.5.0 -->
    <offering profile='WebSphere Customization Toolbox V8.5' id='com.ibm.websphere.WCT.v85' version='8.5.5000.20130514_1044' features='core.feature,pct'/>
  </install>
  <preference name='com.ibm.cic.common.core.preferences.eclipseCache' value='$SHARED_DIR'/>
  <preference name='offering.service.repositories.areUsed' value='false'/>
</agent-input>
EOFIHS

  local shellCmd="$IBM_IM_ROOT/eclipse/tools/imcl -acceptLicense -sVP -log $SCRIPT_LOGS_DIR/PlgWct_install_log_info_$lNow.log input $filenameOut"
  echo $shellCmd >> $SCRIPT_LOG_FILE
  $shellCmd    >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_plgwct: [ERROR]"

  log_info "install_plgwct:  success"
  log_debug "install_plgwct : end"
  return 0
}

configure_was_profile () {
  log_debug "configure_was_profile: start"
  local profileName=$1
  local nodeRspFile=$2

  if [ -d $APPSERVER_ROOT/profiles/$profileName ]; then
     log_info "-- Already created"
     return 1
  fi

  if [ ! -f $APPSERVER_ROOT"/bin/manageprofiles.sh" ]; then
    errmsg_and_exit "configure_was_profile: File [$APPSERVER_ROOT/bin/manageprofiles.sh] not found"
  fi
  local shellCmd="$APPSERVER_ROOT/bin/manageprofiles.sh -response $nodeRspFile"

  echo $shellCmd >> $SCRIPT_LOG_FILE
  $shellCmd    >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "configure_was_profile:  error"

  check_manageprofile_result_log $profileName"_create"

  log_info "configure_was_profile:  success"
  log_debug "configure_was_profile:  end"
  return 0
}

######################################################
#  Function:  configure_dmgr_profile
#  Description:   Run Create a DMGR profile
######################################################
configure_dmgr_profile () {
  log_debug "configure_dmgr_profile: start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")
  local DMGR_RSP_FILE="$SCRIPT_LOGS_DIR/configDMGR_$lNow.rsp"

  echo "create          "                  >  $DMGR_RSP_FILE
  echo "profileName=Dmgr01"                >> $DMGR_RSP_FILE
  echo "profilePath=$APPSERVER_ROOT/profiles/Dmgr01"              >> $DMGR_RSP_FILE
  echo "templatePath=$APPSERVER_ROOT/profileTemplates/management" >> $DMGR_RSP_FILE
  echo "nodeName=$DP_DMGR_NODENAME"        >> $DMGR_RSP_FILE
  echo "cellName=$DP_DMGR_CELLNAME"        >> $DMGR_RSP_FILE
  echo "hostName=$DP_DMGR_HOSTNAME"        >> $DMGR_RSP_FILE
  echo "enableAdminSecurity=true"          >> $DMGR_RSP_FILE
  echo "adminUserName=$WAS_USERNAME"       >> $DMGR_RSP_FILE
  echo "adminPassword=$WAS_PASSWORD"       >> $DMGR_RSP_FILE
  echo "serverType=DEPLOYMENT_MANAGER"     >> $DMGR_RSP_FILE
  echo "isDefault"                         >> $DMGR_RSP_FILE
  echo "personalCertValidityPeriod=15"     >> $DMGR_RSP_FILE
  echo "signingCertValidityPeriod=15"      >> $DMGR_RSP_FILE

  configure_was_profile "Dmgr01" $DMGR_RSP_FILE

  log_info "configure_dmgr_profile:  success"
  log_debug "configure_dmgr_profile:  end"
  return 0
}

configure_node_profile () {
  log_debug "configure_node_profile: start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")
  local NODE_RSP_FILE="$SCRIPT_LOGS_DIR/configNode_$DP_NODENAME.rsp"

  log_info "nodeName=$DP_NODENAME"
  log_info "hostName=$DP_HOSTNAME"

  echo "create          "                  >  $NODE_RSP_FILE
  echo "profileName=AppSrv01"              >> $NODE_RSP_FILE
  echo "profilePath=$APPSERVER_ROOT/profiles/AppSrv01"         >> $NODE_RSP_FILE
  echo "templatePath=$APPSERVER_ROOT/profileTemplates/managed" >> $NODE_RSP_FILE
  echo "nodeName=$DP_NODENAME"             >> $NODE_RSP_FILE
  echo "hostName=$DP_HOSTNAME"             >> $NODE_RSP_FILE
  echo "dmgrHost=$DP_DMGR_HOSTNAME"        >> $NODE_RSP_FILE
  echo "dmgrPort=8879"                     >> $NODE_RSP_FILE
  echo "dmgrAdminUserName=$WAS_USERNAME"   >> $NODE_RSP_FILE
  echo "dmgrAdminPassword=$WAS_PASSWORD"   >> $NODE_RSP_FILE
  echo "personalCertValidityPeriod=15"     >> $NODE_RSP_FILE
  echo "signingCertValidityPeriod=15"      >> $NODE_RSP_FILE

  configure_was_profile "AppSrv01" $NODE_RSP_FILE

  log_info "configure_node_profile:  success"
  log_debug "configure_node_profile:  end"
  return 0
}

configure_node_profile_cognos () {
  log_debug "configure_node_profile_cognos: start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")
  local NODE_RSP_FILE="$SCRIPT_LOGS_DIR/configNode_$DP_NODENAME.rsp"

  echo "create          "                  >  $NODE_RSP_FILE
  echo "profileName=AppSrv01"              >> $NODE_RSP_FILE
  echo "profilePath=$APPSERVER_ROOT/profiles/AppSrv01"         >> $NODE_RSP_FILE
  echo "templatePath=$APPSERVER_ROOT/profileTemplates/default" >> $NODE_RSP_FILE
  echo "nodeName=$COGNOS_NODENAME"             >> $NODE_RSP_FILE
  echo "hostName=$COGNOS_HOSTNAME"             >> $NODE_RSP_FILE
  echo "adminUserName=$WAS_USERNAME"       >> $NODE_RSP_FILE
  echo "adminPassword=$WAS_PASSWORD"       >> $NODE_RSP_FILE
  echo "enableAdminSecurity=true"          >> $NODE_RSP_FILE
  echo "personalCertValidityPeriod=15"     >> $NODE_RSP_FILE
  echo "signingCertValidityPeriod=15"      >> $NODE_RSP_FILE

  configure_was_profile "AppSrv01" $NODE_RSP_FILE

  log_info "configure_node_profile_cognos:  success"
  log_debug "configure_node_profile_cognos:  end"
  return 0
}

configure_node_profile_feb () {
  log_debug "configure_node_profile_feb: start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")
  local NODE_RSP_FILE="$SCRIPT_LOGS_DIR/configNode_$DP_NODENAME.rsp"

  echo "create          "                  >  $NODE_RSP_FILE
  echo "profileName=AppSrv01"              >> $NODE_RSP_FILE
  echo "profilePath=$APPSERVER_ROOT/profiles/AppSrv01"         >> $NODE_RSP_FILE
  echo "templatePath=$APPSERVER_ROOT/profileTemplates/default" >> $NODE_RSP_FILE
  echo "nodeName=$DP_NODENAME"             >> $NODE_RSP_FILE
  echo "hostName=$DP_HOSTNAME"             >> $NODE_RSP_FILE
  echo "adminUserName=$WAS_USERNAME"       >> $NODE_RSP_FILE
  echo "adminPassword=$WAS_PASSWORD"       >> $NODE_RSP_FILE
  echo "enableAdminSecurity=true"          >> $NODE_RSP_FILE
  echo "personalCertValidityPeriod=15"     >> $NODE_RSP_FILE
  echo "signingCertValidityPeriod=15"      >> $NODE_RSP_FILE
  echo "serverName=febserver"              >> $NODE_RSP_FILE

  configure_was_profile "AppSrv01" $NODE_RSP_FILE

  log_info "configure_node_profile_feb:  success"
  log_debug "configure_node_profile_feb:  end"
  return 0
}

######################################################
#  Function:    check_manageprofile_result_log
#  Description:   check for manageprofile.sh result
#  Returns:
#               0 - specified file exist
######################################################
check_manageprofile_result_log() {
  local logFileName=$1
  log_debug "check_manageprofile_result_log : start"

  local logFile=$APPSERVER_ROOT"/logs/manageprofiles/$logFileName.log"

  if [ ! -f $logFile ]; then
     errmsg_and_exit "check_manageprofile_result_log:  log file not exist $logFile"
  fi

  if [ "X`tail $logFile | grep "INSTCONFSUCCESS"`" = "X" ] ; then
     errmsg_and_exit "check_manageprofile_result_log:  FAILED"
  fi

  log_debug "check_manageprofile_result_log : end"
  return 0
}

######################################################
#  Function:  cleanup_was_profile
#  Description:   Cleanup Was Profile
######################################################
cleanup_was_profile () {
  log_debug "cleanup_was_profile: start"

  if [ ! -f $APPSERVER_ROOT"/bin/manageprofiles.sh" ]; then
    errmsg_and_exit "cleanup_was_profile: File [$APPSERVER_ROOT/bin/manageprofiles.sh] not found"
  fi

  $APPSERVER_ROOT/bin/manageprofiles.sh -deleteAll >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "cleanup_was_profile:  error"

  rm -fr $APPSERVER_ROOT/profiles/Dmgr01 >> $SCRIPT_LOG_FILE 2>&1
  rm -fr $APPSERVER_ROOT/profiles/AppSrv01 >> $SCRIPT_LOG_FILE 2>&1

  log_debug "cleanup_was_profile:  end"
  return 0
}

configure_jdk7 () {
  log_debug "configure_jdk7: start"

  if [ ! -f $APPSERVER_ROOT"/bin/managesdk.sh" ]; then
    errmsg_and_exit "configure_jdk7: File [$APPSERVER_ROOT/bin/managesdk.sh] not found"
  fi

  $APPSERVER_ROOT/bin/managesdk.sh -enableProfileAll -sdkname $JDK_NAME -user $WAS_USERNAME -password $WAS_PASSWORD >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "configure_jdk7:  error"

  log_debug "configure_jdk7:  end"
  return 0
}

######################################################
#  Configure db2 jdbc for connections
######################################################
config_db2jdbcV10_5 () {
  log_debug "config_db2jdbcV10_5 : start"
  local NOW=$(date +"%Y-%m-%d-%H-%M-%S")

  local DB2JARPATH="/opt/IBM/db2/V10.5/java"
  mkdir -p $DB2JARPATH
  check_errmsg_and_exit "config_db2jdbcV10_5: [ERROR]"

  cp $SCRIPT_PWD/db2jdbc/V10.5/db2jcc.jar $DB2JARPATH/db2jcc.jar  >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "config_db2jdbcV10_5: [ERROR] Retrieve File - db2jcc.jar"
  cp $SCRIPT_PWD/db2jdbc/V10.5/db2jcc4.jar $DB2JARPATH/db2jcc4.jar  >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "config_db2jdbcV10_5: [ERROR] Retrieve File - db2jcc4.jar"
  cp $SCRIPT_PWD/db2jdbc/V10.5/db2jcc_license_cu.jar $DB2JARPATH/db2jcc_license_cu.jar  >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "config_db2jdbcV10_5: [ERROR] Retrieve File - db2jcc_license_cu.jar"

  log_debug "config_db2jdbcV10_5 : end"
  return 0
}

download_checksum() {
  log_debug "download_checksum:  start"
  local fncname=$1
  local currentDirectory=$2
  local filename=$3
  local url=$4

  mkdir -p $currentDirectory >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "$fncname: [ERROR] on mkdir"

  cd $currentDirectory >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "fncname: [ERROR] on cd"

  wget -q $url/$filename -O $currentDirectory/$filename  >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "$fncname: [ERROR] Retrieve File $url"

  verify_checksum "$currentDirectory/$filename"
  check_errmsg_and_exit "$fncname: [ERROR] Checksum Error on file $currentDirectory/$filename"
  log_info "$fncname:  $filename: OK"
  log_debug "download_checksum: end"
  return 0;
}

download_installation_manager() {
  log_debug "download_installation_manager:  start"

  download_checksum "download_installation_manager" $IIM_BIN_DIR $IIM_BIN_FILE $IIM_INST_URL

  log_info "download_installation_manager:  success"
  log_debug "download_installation_manager:  end"
  return 0
}

download_was_nd() {
  log_debug "download_was_nd:  start"

  download_checksum "download_was_nd" $WAS_ND_BIN_DIR $WAS_BIN_01 $WAS_INST_URL
  download_checksum "download_was_nd" $WAS_ND_BIN_DIR $WAS_BIN_02 $WAS_INST_URL
  download_checksum "download_was_nd" $WAS_ND_BIN_DIR $WAS_BIN_03 $WAS_INST_URL

  log_info "download_was_nd:  success"
  log_debug "download_was_nd:  end"
  return 0
}

download_was_nd_fixes() {
  log_debug "download_was_nd_fixes:  start"

  download_checksum "download_was_nd_fixes" $WAS_ND_FIX_BIN_DIR $WAS_FIX_BIN_01 $WAS_INST_URL
  download_checksum "download_was_nd_fixes" $WAS_ND_FIX_BIN_DIR $WAS_FIX_BIN_02 $WAS_INST_URL

  log_info "download_was_nd_fixes:  success"
  log_debug "download_was_nd_fixes:  end"
  return 0
}

download_was_sup() {
  log_debug "download_was_sup:  start"

  download_checksum "download_was_sup" $WAS_SUP_BIN_DIR $WAS_BIN_04 $WAS_INST_URL
  download_checksum "download_was_sup" $WAS_SUP_BIN_DIR $WAS_BIN_05 $WAS_INST_URL
  download_checksum "download_was_sup" $WAS_SUP_BIN_DIR $WAS_BIN_06 $WAS_INST_URL

  log_info "download_was_sup:  success"
  log_debug "download_was_sup:  end"
  return 0
}

download_was_sup_fixes() {
  log_debug "download_was_sup_fixes:  start"

  download_checksum "download_was_sup_fixes" $WAS_SUP_FIX_BIN_DIR $WAS_FIX_BIN_03 $WAS_INST_URL
  download_checksum "download_was_sup_fixes" $WAS_SUP_FIX_BIN_DIR $WAS_FIX_BIN_04 $WAS_INST_URL

  log_info "download_was_sup_fixes:  success"
  log_debug "download_was_sup_fixes:  end"
  return 0
}

download_jdk7() {
  log_debug "download_jdk7:  start"

  download_checksum "download_jdk7" $JDK_BIN_DIR $JDK_BIN_FILE $WAS_INST_URL

  log_info "download_jdk7:  success"
  log_debug "download_jdk7:  end"
  return 0
}

download_connections55 () {
  log_debug "download_connections55 : start"
  local currentDirectory="$CON_BIN_DIR"

  # Download and Extract Connections Installer
  download_checksum "download_connections55" $currentDirectory $CON_BIN_01 $CON_INST_URL
  # Arquivos do CCM
  download_checksum "download_connections55" $currentDirectory $CCM_BIN_01 $CCM_INST_URL
  download_checksum "download_connections55" $currentDirectory $CCM_BIN_02 $CCM_INST_URL
  download_checksum "download_connections55" $currentDirectory $CCM_BIN_03 $CCM_INST_URL
  download_checksum "download_connections55" $currentDirectory $CCM_BIN_04 $CCM_INST_URL
  download_checksum "download_connections55" $currentDirectory $CCM_BIN_05 $CCM_INST_URL

  log_debug "download_connections55 : end"
  return 0
}

download_connections55_fixes () {
  log_debug "download_connections55_fixes : start"
  local currentDirectory="$CON_FIX_BIN_DIR"

  mkdir -p $currentDirectory >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "download_connections55_fixes: [ERROR] on mkdir"

  cd $currentDirectory >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "download_connections55_fixes: [ERROR] on cd"

  download_checksum "download_connections55_fixes" $currentDirectory $CON_FIX_BIN_01 $CON_FIX_INST_URL
  download_checksum "download_connections55_fixes" $currentDirectory $CON_FIX_BIN_02 $CON_FIX_INST_URL

  log_debug "download_connections55_fixes : end"
  return 0
}

download_cognos () {
  log_debug "download_cognos : start"
  local currentDirectory="$COG_BIN_DIR"

  download_checksum "download_cognos" $currentDirectory"/bisvr" $COG_BIN_01 $COG_INST_URL
  download_checksum "download_cognos" $currentDirectory"/bitrf" $COG_BIN_02 $COG_INST_URL
  download_checksum "download_cognos" $currentDirectory $COG_BIN_03 $COG_INST_URL

  local db2file="v10.5fp7_linuxx64_client.tar.gz"

  download_checksum "download_cognos" $currentDirectory $db2file "$REPO_URL/db2/"

  log_debug "download_cognos : end"
  return 0
}

download_feb () {
  log_debug "download_feb : start"
  local currentDirectory="$FEB_BIN_DIR"

  download_checksum "download_feb" $currentDirectory $FEB_BIN_01 $FEB_INST_URL

  log_debug "download_feb : end"
  return 0
}

extract_feb () {
  log_debug "extract_feb : start"
  local currentDirectory="$FEB_BIN_DIR"

  extract_checksum "extract_feb" $currentDirectory $FEB_BIN_01

  log_debug "extract_feb : end"
  return 0
}

extract_cognos () {
  log_debug "extract_cognos : start"
  local currentDirectory="$COG_BIN_DIR"

  extract_checksum "extract_cognos" "$currentDirectory/bisvr" $COG_BIN_01
  extract_checksum "extract_cognos" "$currentDirectory/bitrf" $COG_BIN_02
  extract_checksum "extract_cognos" $currentDirectory $COG_BIN_03
  local db2file="v10.5fp7_linuxx64_client.tar.gz"
  extract_checksum "extract_cognos" $currentDirectory $db2file

  log_debug "extract_cognos : end"
  return 0
}

extract_connections55 () {
  log_debug "extract_connections55 : start"
  local currentDirectory="$CON_BIN_DIR"

  extract_checksum "extract_connections55" $currentDirectory $CON_BIN_01

  log_debug "extract_connections55 : end"
  return 0
}

extract_connections55_fixes () {
  log_debug "extract_connections55_fixes : start"
  local currentDirectory="$CON_FIX_BIN_DIR"

  extract_checksum "extract_connections55_fixes" $currentDirectory $CON_FIX_BIN_01
  extract_checksum "extract_connections55_fixes" $currentDirectory $CON_FIX_BIN_02

  log_debug "extract_connections55_fixes : end"
  return 0
}

backup_pre_connections () {
  log_debug "backup_pre_connections : start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")
  cd /opt/IBM/

  cp -Rv IMShared IMShared_$lNow
  cp -Rv InstallationManager InstallationManager_$lNow
  cp -Rv WebSphere WebSphere_$lNow
  cp /var/ibm/InstallationManager/installed.xml /var/ibm/InstallationManager/installed.xml_$lNow
  cp /var/ibm/InstallationManager/installRegistry.xml /var/ibm/InstallationManager/installRegistry.xml_$lNow
  cp /var/ibm/InstallationManager/.settings/com.ibm.cic.agent.core.prefs /var/ibm/InstallationManager/.settings/com.ibm.cic.agent.core.prefs_$lNow

  sed -i -- 's/RepositoryIsOpen=true/RepositoryIsOpen=false/g' /var/ibm/InstallationManager/.settings/com.ibm.cic.agent.core.prefs

  log_debug "backup_pre_connections : end"
  return 0
}

######################################################
#  Install Connections 55
######################################################
install_connections55 () {
  log_debug "install_connections55 : start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")

  cp /var/ibm/InstallationManager/installed.xml /var/ibm/InstallationManager/installed.xml_$lNow
  cp /var/ibm/InstallationManager/installRegistry.xml /var/ibm/InstallationManager/installRegistry.xml_$lNow
  cp /var/ibm/InstallationManager/.settings/com.ibm.cic.agent.core.prefs /var/ibm/InstallationManager/.settings/com.ibm.cic.agent.core.prefs_$lNow

  sed -i -- 's/RepositoryIsOpen=true/RepositoryIsOpen=false/g' /var/ibm/InstallationManager/.settings/com.ibm.cic.agent.core.prefs

  local filenameIn="$CON_RSP_FILE"
  local filenameOut="$SCRIPT_LOGS_DIR/installC55_$lNow.rsp"

  WAS_ENCODED_PASSWORD="`$IBM_IM_ROOT/eclipse/tools/imutilsc encryptString $WAS_PASSWORD`"
  DB_ENCODED_PASSWORD="`$IBM_IM_ROOT/eclipse/tools/imutilsc encryptString $DB_PASSWORD`"
  CCM_ENCODED_PASSWORD="`$IBM_IM_ROOT/eclipse/tools/imutilsc encryptString $CCM_PASSWORD`"

  local c01="s,@@WAS_ENCODED_PASSWORD@@,$WAS_ENCODED_PASSWORD,"
  local c02="s,@@DB_ENCODED_PASSWORD@@,$DB_ENCODED_PASSWORD,"
  local c03="s,@@CCM_ENCODED_PASSWORD@@,$CCM_ENCODED_PASSWORD,"
  local c04="s,@@WAS_USERNAME@@,$WAS_USERNAME,"
  sed -e "$c01" -e "$c02" -e "$c03" -e "$c04" $filenameIn > $filenameOut

  if [ ! -x "$IBM_IM_ROOT/eclipse/tools/imcl" ] ; then
     errmsg_and_exit "install_connections55: imcl not available or executable permission: [$IBM_IM_ROOT/eclipse/tools/imcl]"
  fi

  local shellCmd="$IBM_IM_ROOT/eclipse/tools/imcl -acceptLicense -sVP -log $SCRIPT_LOGS_DIR/c55_install_log_info_$lNow.log input $filenameOut"
  echo $shellCmd >> $SCRIPT_LOG_FILE
  $shellCmd    >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_connections55: [ERROR]"

  log_debug "install_connections55 : end"
  return 0
}

install_connections55_updateInstaller () {
  log_debug "install_connections55_updateInstaller : start"

  local shellCmd="tar -xvf $CON_FIX_BIN_DIR/5.5.0.0-IC-Multi-UPDI-20160628/AIX-Linux/UpdateInstaller.tar -C $IBM_ROOT/Connections"
  echo $shellCmd >> $SCRIPT_LOG_FILE
  $shellCmd    >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_connections55_updateInstaller: [ERROR] Extract - UpdateInstaller.tar"

  log_debug "install_connections55_updateInstaller : end"
  return 0
}

install_connections55_fixes () {
  log_debug "install_connections55_fixes : start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")

  cp /var/ibm/InstallationManager/installed.xml /var/ibm/InstallationManager/installed.xml_$lNow
  cp /var/ibm/InstallationManager/installRegistry.xml /var/ibm/InstallationManager/installRegistry.xml_$lNow
  cp /var/ibm/InstallationManager/.settings/com.ibm.cic.agent.core.prefs /var/ibm/InstallationManager/.settings/com.ibm.cic.agent.core.prefs_$lNow

  sed -i -- 's/RepositoryIsOpen=true/RepositoryIsOpen=false/g' /var/ibm/InstallationManager/.settings/com.ibm.cic.agent.core.prefs

  #local filename="$SCRIPT_TEMP_DIR/IBM_Connections_55_Lin.tar"
  local filenameIn="$CONFIX_RSP_FILE"
  local filenameOut="$SCRIPT_LOGS_DIR/installC55fix_$lNow.rsp"

  WAS_ENCODED_PASSWORD="`$IBM_IM_ROOT/eclipse/tools/imutilsc encryptString $WAS_PASSWORD`"
  DB_ENCODED_PASSWORD="`$IBM_IM_ROOT/eclipse/tools/imutilsc encryptString $DB_PASSWORD`"
  CCM_ENCODED_PASSWORD="`$IBM_IM_ROOT/eclipse/tools/imutilsc encryptString $CCM_PASSWORD`"

  local c01="s,@@WAS_ENCODED_PASSWORD@@,$WAS_ENCODED_PASSWORD,"
  local c02="s,@@DB_ENCODED_PASSWORD@@,$DB_ENCODED_PASSWORD,"
  local c03="s,@@CCM_ENCODED_PASSWORD@@,$CCM_ENCODED_PASSWORD,"
  local c04="s,@@WAS_USERNAME@@,$WAS_USERNAME,"
  sed -e "$c01" -e "$c02" -e "$c03" -e "$c04" $filenameIn > $filenameOut

  if [ ! -x "$IBM_IM_ROOT/eclipse/tools/imcl" ] ; then
     errmsg_and_exit "install_connections55_fixes: imcl not available or executable permission: [$IBM_IM_ROOT/eclipse/tools/imcl]"
  fi

  local shellCmd="$IBM_IM_ROOT/eclipse/tools/imcl -acceptLicense -sVP -log $SCRIPT_LOGS_DIR/c55fix_install_log_info_$lNow.log input $filenameOut"
  echo $shellCmd >> $SCRIPT_LOG_FILE
  $shellCmd    >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_connections55_fixes: [ERROR]"

  log_debug "install_connections55_fixes : end"
  return 0
}

install_febserver () {
  log_debug "install_febserver : start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")

  cp /var/ibm/InstallationManager/installed.xml /var/ibm/InstallationManager/installed.xml_$lNow
  cp /var/ibm/InstallationManager/installRegistry.xml /var/ibm/InstallationManager/installRegistry.xml_$lNow
  cp /var/ibm/InstallationManager/.settings/com.ibm.cic.agent.core.prefs /var/ibm/InstallationManager/.settings/com.ibm.cic.agent.core.prefs_$lNow

  sed -i -- 's/RepositoryIsOpen=true/RepositoryIsOpen=false/g' /var/ibm/InstallationManager/.settings/com.ibm.cic.agent.core.prefs

  local filenameIn="$FEBSERVER_RSP_FILE"
  local filenameOut="$SCRIPT_LOGS_DIR/instalaFeb_$lNow.rsp"

  WAS_ENCODED_PASSWORD="`$IBM_IM_ROOT/eclipse/tools/imutilsc encryptString $WAS_PASSWORD`"
  DB_ENCODED_PASSWORD="`$IBM_IM_ROOT/eclipse/tools/imutilsc encryptString $DB_PASSWORD`"

  local c01="s,@@WAS_ENCODED_PASSWORD@@,$WAS_ENCODED_PASSWORD,"
  local c02="s,@@DB_ENCODED_PASSWORD@@,$DB_ENCODED_PASSWORD,"
  local c03="s,@@WAS_USERNAME@@,$WAS_USERNAME,"
  sed -e "$c01" -e "$c02" -e "$c03" $filenameIn > $filenameOut

  if [ ! -x "$IBM_IM_ROOT/eclipse/tools/imcl" ] ; then
     errmsg_and_exit "install_febserver: imcl not available or executable permission: [$IBM_IM_ROOT/eclipse/tools/imcl]"
  fi

  local shellCmd="$IBM_IM_ROOT/eclipse/tools/imcl -acceptLicense -sVP -log $SCRIPT_LOGS_DIR/febserver_install_log_info_$lNow.log input $filenameOut"
  echo $shellCmd >> $SCRIPT_LOG_FILE
  $shellCmd    >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_febserver: [ERROR]"

  log_debug "install_febserver : end"
  return 0
}

install_cognos () {
  log_debug "install_cognos : start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")

  cp /var/ibm/InstallationManager/installed.xml /var/ibm/InstallationManager/installed.xml_$lNow
  cp /var/ibm/InstallationManager/installRegistry.xml /var/ibm/InstallationManager/installRegistry.xml_$lNow
  cp /var/ibm/InstallationManager/.settings/com.ibm.cic.agent.core.prefs /var/ibm/InstallationManager/.settings/com.ibm.cic.agent.core.prefs_$lNow

  sed -i -- 's/RepositoryIsOpen=true/RepositoryIsOpen=false/g' /var/ibm/InstallationManager/.settings/com.ibm.cic.agent.core.prefs

  local filenameIn="$COGNOS_RSP_FILE"
  local filenameOut="$SCRIPT_LOGS_DIR/instalaCognos_$lNow.rsp"

  WAS_ENCODED_PASSWORD="`$IBM_IM_ROOT/eclipse/tools/imutilsc encryptString $WAS_PASSWORD`"
  DB_ENCODED_PASSWORD="`$IBM_IM_ROOT/eclipse/tools/imutilsc encryptString $DB_PASSWORD`"
  COGNOS_ENCODED_PASSWORD="`$IBM_IM_ROOT/eclipse/tools/imutilsc encryptString $COGNOS_PASSWORD`"

  local c01="s,@@WAS_ENCODED_PASSWORD@@,$WAS_ENCODED_PASSWORD,"
  local c02="s,@@DB_ENCODED_PASSWORD@@,$DB_ENCODED_PASSWORD,"
  local c03="s,@@WAS_USERNAME@@,$WAS_USERNAME,"
  local c04="s,@@COGNOS_ENCODED_PASSWORD@@,$COGNOS_ENCODED_PASSWORD,"
  sed -e "$c01" -e "$c02" -e "$c03" -e "$c04" $filenameIn > $filenameOut

  if [ ! -x "$IBM_IM_ROOT/eclipse/tools/imcl" ] ; then
     errmsg_and_exit "install_cognos: imcl not available or executable permission: [$IBM_IM_ROOT/eclipse/tools/imcl]"
  fi

  local shellCmd="$IBM_IM_ROOT/eclipse/tools/imcl -acceptLicense -sVP -log $SCRIPT_LOGS_DIR/cognos_install_log_info_$lNow.log input $filenameOut"
  echo $shellCmd >> $SCRIPT_LOG_FILE
  $shellCmd    >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_cognos: [ERROR]"

  log_debug "install_cognos : end"
  return 0
}




######################################################
#  Function:  start_server
#  Description:   start server
#  Returns:
#		0 - specified stop was server successfully
######################################################
start_server () {
  log_debug "start_server: start"
  local serverType=$1
  local profileName=$2
  local shellFile=""
  local pidFile=""
  local shellCmd=""

  case $serverType in
    dmgr)
      shellFile="$APPSERVER_ROOT/profiles/$profileName/bin/startManager.sh"
      pidFile="$APPSERVER_ROOT/profiles/$profileName/logs/dmgr/dmgr.pid"
      shellCmd=$shellFile
    ;;
    nodeagent)
      shellFile="$APPSERVER_ROOT/profiles/$profileName/bin/startNode.sh"
      pidFile="$APPSERVER_ROOT/profiles/$profileName/logs/nodeagent/nodeagent.pid"
      shellCmd=$shellFile
    ;;
    *)
      shellFile="$APPSERVER_ROOT/profiles/$profileName/bin/startServer.sh"
      pidFile="$APPSERVER_ROOT/profiles/$profileName/logs/$serverType/$serverType.pid"
      shellCmd="$shellFile $serverType"
    ;;
  esac

  log_info $lblStarting" "$serverType

  if [ ! -f "$shellFile" ] ; then
     errmsg_and_exit "start_server: $serverType - File [$shellFile] not found"
  fi

  local _PID_FILE=$pidFile
  if [ -f ${_PID_FILE} ]; then
     local _PID_WAS=`cat ${_PID_FILE}`
     ps -e | grep -v grep | grep $_PID_WAS > /dev/null
     if [ $? -eq 0  ]; then
        log_info $lblAlreadyStarted
        log_info $lblDotOk
        return 0
     fi
  fi

  log_debug "start_server $serverType: starting server"

  $shellCmd >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "start_server: $serverType [ERROR]"
  sleep 20

  log_info "-- Server Started"
  log_debug "start_server: end"
  return 0
}

######################################################
#  Function:  stop_server
#  Description:   Executa a parada do WAS
#  Returns:
#		0 - specified stop was server successfully
######################################################
stop_server () {
  log_debug "stop_server : start"

  local serverType=$1
  local shellUserName=$2
  local shellPassword=$3
  local profileName=$4
  local shellFile=""
  local pidFile=""
  local shellCmd=""

  case $serverType in
    dmgr)
      shellFile="$APPSERVER_ROOT/profiles/$profileName/bin/stopManager.sh"
      pidFile="$APPSERVER_ROOT/profiles/$profileName/logs/dmgr/dmgr.pid"
      shellCmd=$shellFile
      shellUserName=$WAS_USERNAME
      shellPassword=$WAS_PASSWORD
    ;;
    nodeagent)
      shellFile="$APPSERVER_ROOT/profiles/$profileName/bin/stopNode.sh"
      pidFile="$APPSERVER_ROOT/profiles/$profileName/logs/nodeagent/nodeagent.pid"
      shellCmd=$shellFile
      shellUserName=$WAS_USERNAME
      shellPassword=$WAS_PASSWORD
    ;;
    *)
      shellFile="$APPSERVER_ROOT/profiles/$profileName/bin/stopServer.sh"
      pidFile="$APPSERVER_ROOT/profiles/$profileName/logs/$serverType/$serverType.pid"
      shellCmd="$shellFile $serverType"
    ;;
  esac

  log_info $lblStopping" "$serverType

  if [ ! -f "$shellFile" ] ; then
     errmsg_and_exit "stop_server: $serverType - File [$shellFile] not found"
  fi

  local _PID_FILE=$pidFile
  if [ ! -f ${_PID_FILE} ]; then
     log_info $lblAlreadyStoppedNoPidFile
     return 0
  fi

  local _PID_WAS=`cat ${_PID_FILE}`
  ps -e | grep -v grep | grep $_PID_WAS > /dev/null
  if [ $? -ne 0  ]; then
     log_info $lblAlreadyStoppedNoPidNumber
     return 0
  fi

  log_debug "stop_server : stopping server $serverType"

  #if [ "SECURITY_ENABLED" = "no" ]; then
  #   $shellCmd >> $SCRIPT_LOG_FILE 2>&1
  #else
     $shellCmd -username $shellUserName -password $shellPassword >> $SCRIPT_LOG_FILE 2>&1
  #fi
  check_errmsg_and_exit "stop_server: $serverType [ERROR]"

  log_info "-- Server Stopped"
  log_debug "stop_server : end"
  return 0
}

stop_cognos () {
  log_debug "stop_cognos: start"

  stop_server "cognos_server" "$WAS_USERNAME" "$WAS_PASSWORD" "AppSrv01"

  stop_server "server1" "$WAS_USERNAME" "$WAS_PASSWORD" "AppSrv01"

  date

  echo " Espere por 1 minuto pelo menos"
  log_debug "stop_cognos:  end"
  return 0
}

start_server1 () {
  log_debug "start_server1: start"

  start_server "server1" "AppSrv01"

  log_debug "start_server1:  end"
  return 0
}

federate_node () {
  log_debug "federate_node: start"

  if [ ! -f "$APPSERVER_ROOT/profiles/AppSrv01/bin/addNode.sh" ]; then
    errmsg_and_exit "federate_node: File [$APPSERVER_ROOT/profiles/AppSrv01/bin/addNode.sh] not found"
  fi

  # -includebuses was removed at portal 8
  $APPSERVER_ROOT/profiles/AppSrv01/bin/addNode.sh $DP_DMGR_HOSTNAME 8879 -username $WAS_USERNAME -password $WAS_PASSWORD -includeapps   >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "federate_node:  error"

  local logFile="$APPSERVER_ROOT/profiles/AppSrv01/logs/AddNode.log"

  if [ ! -f $logFile ]; then
     errmsg_and_exit "federate_node:  log file not exist $logFile"
  fi

  if [ "X`tail $logFile | grep "successfully federated"`" = "X" ] ; then
     errmsg_and_exit "federate_node:  FAILED"
  fi

  log_debug "federate_node: end"
  return 0
}

install_db2client () {
  log_debug "install_db2client : start"
  local NOW=$(date +"%Y-%m-%d-%H-%M-%S")

  local db2file="v10.5fp7_linuxx64_client.tar.gz"
  local currentDirectory="$COG_BIN_DIR"

  rm -fr /opt/IBM/db2/
  check_errmsg_and_exit "install_db2client: [ERROR] on installingcd "

  echo "Installing DB .... start"
  $currentDirectory/client/db2_install -b /opt/IBM/db2/V10.5 >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_db2client: [ERROR] on installing "

  echo "Criando grupo lcuser .... "
  cat /etc/group | grep "lcuser" > /dev/null
  if [ $? -eq 1  ]; then
    groupadd lcuser >> $SCRIPT_LOG_FILE 2>&1
    check_errmsg_and_exit "install_db2client: [ERROR] Create Group"
  fi
  echo "  Grupo lcuser já existe"


  echo "Criando usuario lcuser .... "
  cat /etc/passwd | grep "lcuser" > /dev/null
  if [ $? -eq 1  ]; then
    useradd -m -g lcuser -d /home/lcuser lcuser >> $SCRIPT_LOG_FILE 2>&1
    check_errmsg_and_exit "install_db2client: [ERROR] Create User"
  fi
  echo "Usuário lcuser já existe"


  echo "lcuser:$DB_PASSWORD" |chpasswd >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_db2client: [ERROR] Change pasword"

  log_debug "install_db2client : end"
  return 0
}

configure_db2client () {
  log_debug "configure_db2client : start"
  local NOW=$(date +"%Y-%m-%d-%H-%M-%S")

  /opt/IBM/db2/V10.5/instance/db2icrt -s client -a server -u lcuser lcuser >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "configure_db2client: [ERROR] db2icrt"

  echo "db2 catalog tcpip node cgnnode remote $DB_HOST_COGNOS server $DB_PORT_COGNOS " > /home/lcuser/configdb2.sh
  echo "db2 terminate" >> /home/lcuser/configdb2.sh
  echo "db2 list node directory" >> /home/lcuser/configdb2.sh
  echo "db2 catalog tcpip node mtsnode remote $DB_HOST_METRICS server $DB_PORT_METRICS " >> /home/lcuser/configdb2.sh
  echo "db2 terminate" >> /home/lcuser/configdb2.sh
  echo "db2 list node directory" >> /home/lcuser/configdb2.sh
  echo "db2 catalog db metrics at node mtsnode" >> /home/lcuser/configdb2.sh
  echo "db2 terminate" >> /home/lcuser/configdb2.sh
  echo "db2 list db directory" >> /home/lcuser/configdb2.sh
  echo "db2 connect to metrics user lcuser" >> /home/lcuser/configdb2.sh
  echo "db2 terminate" >> /home/lcuser/configdb2.sh
  echo "db2 catalog db cognos  at node cgnnode" >> /home/lcuser/configdb2.sh
  echo "db2 terminate" >> /home/lcuser/configdb2.sh
  echo "db2 connect to cognos user lcuser" >> /home/lcuser/configdb2.sh
  echo "db2 list db directory" >> /home/lcuser/configdb2.sh
  echo "db2 terminate" >> /home/lcuser/configdb2.sh

  chmod a+x /home/lcuser/configdb2.sh

  echo "# Configured by ScriptS @ Connections Migration" >> /root/.profile
  echo "# The following three lines have been added by IBM DB2 instance utilities." >> /root/.profile
  echo "if [ -f /home/lcuser/sqllib/db2profile ]; then" >> /root/.profile
  echo "    . /home/lcuser/sqllib/db2profile" >> /root/.profile
  echo "fi" >> /root/.profile
  echo "" >> /root/.profile
  echo "" >> /root/.profile
  echo "export PATH=$PATH:/opt/IBM/db2/V10.5/bin" >> /root/.profile
  echo "export LD_LIBRARY_PATH=/opt/IBM/db2/V10.5/lib32" >> /root/.profile
  echo "export DB2DIR=/opt/IBM/db2/V10.5" >> /root/.profile

  log_debug "configure_db2client : end"
  return 0
}

configure_was_service() {
  log_debug "configure_was_service:  start"
  local fncname=$1
  local serverType=$2

  if [ ! -f "$APPSERVER_ROOT/bin/wasservice.sh" ]; then
    errmsg_and_exit "$fncname: File [$APPSERVER_ROOT/bin/wasservice.sh] not found"
  fi

  cd $APPSERVER_ROOT/bin

  case $serverType in
    dmgr)
      ./wasservice.sh -add Dmgr -serverName dmgr -profilePath $APPSERVER_ROOT/profiles/Dmgr01 -stopArgs "-username $WAS_USERNAME -password $WAS_PASSWORD" >> $SCRIPT_LOG_FILE 2>&1
      check_errmsg_and_exit "$fncname: [ERROR] on wasservice"
    ;;
    nodeagent)
      ./wasservice.sh -add Node -serverName nodeagent -profilePath $APPSERVER_ROOT/profiles/AppSrv01  -stopArgs "-username $WAS_USERNAME -password $WAS_PASSWORD" >> $SCRIPT_LOG_FILE 2>&1
      check_errmsg_and_exit "$fncname: [ERROR] on wasservice"
     ;;
  esac

  chkconfig --levels 2345 --add $SERVICE_NAME"_was.init" on
  check_errmsg_and_exit "$fncname: [ERROR] on chkconfig "

  log_info "$fncname success"
  log_debug "configure_was_service:  end"
  return 0
}


configure_plgwct () {
  log_debug "configure_plgwct: start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")
  local filenameOut="$SCRIPT_LOGS_DIR/plgwct_$lNow.rsp"

cat << EOFPLGWCT > $filenameOut
configType=remote
enableAdminServerSupport=true
enableUserAndPass=true
enableWinService=false
ihsAdminCreateUserAndGroup=true
ihsAdminPassword=$IHSADMIN_PASSWORD
ihsAdminPort=8085
ihsAdminUnixUserGroup=ihsadmins
ihsAdminUnixUserID=ihsadmin
mapWebServerToApplications=true
wasMachineHostname=$HOSTNAME.$DNS_DOMAIN_NAME
webServerConfigFile1=$IHS_ROOT/conf/httpd.conf
webServerSelected=icd hs
webServerDefinition=$HOSTNAME
webServerHostName=$HOSTNAME.$DNS_DOMAIN_NAME
webServerInstallArch=64
webServerPortNumber=80
EOFPLGWCT

  if [ ! -f "$WCT_ROOT/WCT/wctcmd.sh" ]; then
    errmsg_and_exit "configure_plgwct: File [$WCT_ROOT/WCT/wctcmd.sh] not found"
  fi

  if [ ! -f "$filenameOut" ]; then
    errmsg_and_exit "ws_admin_run: File [$filenameOut] not found"
  fi

  local shellCmd="$WCT_ROOT/WCT/wctcmd.sh -tool pct -createDefinition -defLocName $PLG_ROOT -defLocPathname $PLG_ROOT -response $filenameOut"
  $shellCmd    >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "configure_plgwct:  error"

  log_info "configure_plgwct: success "
  log_debug "configure_plgwct: end"
  return 0
}

configure_webserver_on_dmgr() {
  log_debug "configure_webserver_on_dmgr : start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")

  if [ ! -f "$APPSERVER_ROOT/profiles/Dmgr01/bin/wsadmin.sh" ]; then
    errmsg_and_exit "configure_webserver_on_dmgr: File [$APPSERVER_ROOT/profiles/Dmgr01/bin/wsadmin.sh] not found"
  fi

  local httpServer="dxl1scb00107"
  local nodeName=$httpServer"Node"
  local shellCmd="$APPSERVER_ROOT/profiles/Dmgr01/bin/wsadmin.sh"
  shellCmd="$shellCmd -username $WAS_USERNAME -password $WAS_PASSWORD -f $APPSERVER_ROOT/bin/configureWebserverDefinition.jacl"
  shellCmd="$shellCmd  $httpServer IHS $IHS_ROOT $IHS_ROOT/conf/httpd.conf 80 MAP_ALL $PLG_ROOT unmanaged $nodeName $httpServer.$DNS_DOMAIN_NAME linux 8085 ihsadmin $IHSADMIN_PASSWORD"
  echo $shellCmd >> $SCRIPT_LOG_FILE
  $shellCmd    >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "configure_webserver_on_dmgr: $httpServer [ERROR]"

  #/opt/IBM/WebSphere/AppServer/profiles/Dmgr01/bin/wsadmin.sh -username wsadmin -password gecin22 \
  # -f /opt/IBM/WebSphere/AppServer/bin/configureWebserverDefinition.jacl dxl1scb00107 IHS /opt/IBM/HTTPServer85 \
  # /opt/IBM/HTTPServer85/conf/httpd.conf 80 MAP_ALL /opt/IBM/WebSphere/Plugins unmanaged \
  # dxl1scb00107Node dxl1scb00107.company.com linux 8085 ihsadmin gecin22

  log_info "configure_webserver_on_dmgr:  success"
  log_debug "configure_webserver_on_dmgr: end"
  return 0
}

ws_admin_run () {
  log_debug "ws_admin_run: start"
  local filenameOut=$1

  if [ ! -f "$APPSERVER_ROOT/profiles/Dmgr01/bin/wsadmin.sh" ]; then
    errmsg_and_exit "ws_admin_run: File [$APPSERVER_ROOT/profiles/Dmgr01/bin/wsadmin.sh] not found"
  fi

  if [ ! -f "$filenameOut" ]; then
    errmsg_and_exit "ws_admin_run: File [$filenameOut] not found"
  fi

  local shellCmd="$APPSERVER_ROOT/profiles/Dmgr01/bin/wsadmin.sh -lang jython -port 8879 -username $WAS_USERNAME -password $WAS_PASSWORD -f $filenameOut"
  $shellCmd    >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "ws_admin_run:  error"

  log_debug "ws_admin_run: end"
  return 0;
}

ws_import_ldap_cert () {
  log_debug "ws_import_ldap_cert: start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")
  local filenameOut="$SCRIPT_LOGS_DIR/import_ldap_cert_$lNow.py"

cat << EOFIMPORTLDAPSSL > $filenameOut
cellID=AdminControl.getCell()
#Add SSL Signer Certificate for AD to Cell Default Trust Store
AdminTask.retrieveSignerFromPort('[-keyStoreName CellDefaultTrustStore -keyStoreScope (cell):'+cellID+' -host $LDAP_SERVER -port 636 -certificateAlias $LDAP_ALIAS -sslConfigName CellDefaultSSLSettings -sslConfigScopeName (cell):'+cellID+' ]')

#Save and Synchronise
AdminConfig.save()
AdminNodeManagement.syncActiveNodes()
EOFIMPORTLDAPSSL

  ws_admin_run $filenameOut

  log_info "ws_import_ldap_cert: success"
  log_debug "ws_import_ldap_cert: end"
  return 0;
}

ws_config_ldap () {
  log_debug "ws_config_ldap: start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")
  local filenameOut="$SCRIPT_LOGS_DIR/config_ldap_$lNow.py"

cat << EOFCONFIGLDAP > $filenameOut
#Create LDAP Repository
AdminTask.createIdMgrLDAPRepository('[-default true -id $LDAP_REPO -adapterClassName com.ibm.ws.wim.adapter.ldap.LdapAdapter -ldapServerType IDS -sslConfiguration -certificateMapMode exactdn -supportChangeLog none -certificateFilter -loginProperties uid]')
#Add LDAP Server
AdminTask.addIdMgrLDAPServer('[-id $LDAP_REPO -host $LDAP_SERVER -bindDN $LDAP_BIND_USER -bindPassword $LDAP_BIND_PASS -referal ignore -sslEnabled true -ldapServerType IDS -sslConfiguration -certificateMapMode exactdn -certificateFilter -authentication simple -port 636]')

AdminTask.addIdMgrRepositoryBaseEntry('[-id $LDAP_REPO -name $LDAP_REALM -nameInRepository $LDAP_REALM]')
AdminTask.addIdMgrRealmBaseEntry('[-name defaultWIMFileBasedRealm -baseEntry $LDAP_REALM]')

#Tuning
AdminTask.updateIdMgrLDAPRepository('[-id $LDAP_REPO -searchTimeLimit 30000 -searchCountLimit 100]')
AdminTask.updateIdMgrLDAPServer('[-id $LDAP_REPO -host $LDAP_SERVER -connectTimeout 20]')
AdminTask.updateIdMgrLDAPServer('[-id $LDAP_REPO -host $LDAP_SERVER -connectionPool true]')
AdminTask.setIdMgrLDAPContextPool('[-id $LDAP_REPO -enabled true -initPoolSize 1 -maxPoolSize 20 -prefPoolSize 3 -poolTimeOut 120]')
AdminTask.setIdMgrLDAPAttrCache('[-id $LDAP_REPO -enabled true -cacheSize 40000 -cacheDistPolicy none -cacheTimeOut 1200]')
AdminTask.setIdMgrLDAPSearchResultCache('[-id $LDAP_REPO -enabled true -cacheSize 40000 -cacheDistPolicy none -cacheTimeOut 1200]')
#Update Group objects for TDS
AdminTask.updateIdMgrLDAPEntityType('[-id $LDAP_REPO -name Group -objectClasses groupOfUniqueNames -searchBases -searchFilter ]')
AdminTask.addIdMgrLDAPGroupMemberAttr('[-id $LDAP_REPO -name uniquemember -objectClass groupOfUniqueNames -scope direct]')
#Enable dynamic groups
AdminTask.deleteIdMgrLDAPGroupMemberAttr('[-id $LDAP_REPO -name member]')
AdminTask.setIdMgrLDAPGroupConfig('[-id $LDAP_REPO -name ibm-allGroups -scope direct]')

#Save and Synchronise
AdminConfig.save()
AdminNodeManagement.syncActiveNodes()
EOFCONFIGLDAP

  ws_admin_run $filenameOut

  log_info "ws_config_ldap: success"
  log_debug "ws_config_ldap: end"
  return 0;
}

ws_config_security () {
  log_debug "ws_config_security: start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")
  local filenameOut="$SCRIPT_LOGS_DIR/config_ldap_$lNow.py"

cat << EOFCONFIGSEC > $filenameOut
#Configure Applicaton Security
AdminTask.configureAdminWIMUserRegistry('[-verifyRegistry true ]')

#Configure SSO

#Save and Synchronise
AdminConfig.save()
AdminNodeManagement.syncActiveNodes()
EOFCONFIGSEC

  ws_admin_run $filenameOut

  log_info "ws_config_security: success"
  log_debug "ws_config_security: end"
  return 0;
}

ws_config_dmgr_jvm () {
  log_debug "ws_config_dmgr_jvm: start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")
  local filenameOut="$SCRIPT_LOGS_DIR/config_dmgr_jvm_$lNow.py"

cat << EOFCONFIGJVM > $filenameOut
#Configure Applicaton Security
AdminTask.setJVMProperties('[-nodeName $DP_DMGR_NODENAME -serverName dmgr -verboseModeGarbageCollection true -initialHeapSize 2048 -maximumHeapSize 2048 ]')
#Save and Synchronise
AdminConfig.save()
EOFCONFIGJVM

  ws_admin_run $filenameOut

  log_info "ws_config_dmgr_jvm: success"
  log_debug "ws_config_dmgr_jvm: end"
  return 0;
}
