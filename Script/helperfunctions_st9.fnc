
sametime_hosts_production () {
  log_info "sametime_hosts_production: - Start"

  local NOW=$(date +"%Y-%m-%d-%H-%M-%S")

  cp /etc/hosts /etc/hosts_$NOW
  echo "" > /etc/hosts

cat << EOD > /etc/hosts
#
# hosts         This file describes a number of hostname-to-address
#               mappings for the TCP/IP subsystem.  It is mostly
#               used at boot time, when no name servers are running.
#               On small systems, this file can be used instead of a
#               "named" name server.
# Syntax:
#
# IP-Address  Full-Qualified-Hostname  Short-Hostname
#

127.0.0.1       localhost


#  LDAP Server
192.168.78.230 	ldap01srv.company.com
# DB2 Server
192.168.87.139	stdb2.company.com            stdb2                # DB2 Server

EOD


  log_info "sametime_hosts_production : end"
  return 0
}


######################################################
#  Install Sametime 9.0 System Console
######################################################
install_stsc9 () {
  log_debug "install_stsc9 : start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")
  local filenameIn="$STSC_RESPONSE_FILE"
  local filenameOut="$SCRIPT_LOGS_DIR/installSTSC_$lNow.rsp"

  if is_product_installed "STSC90" ; then
     log_info "-- Already installed"
     return 1

  fi
  log_debug "install_stsc9 : starting install"

  if [ ! -x "$IBM_IM_ROOT/eclipse/tools/imcl" ] ; then
     errmsg_and_exit "install_stsc9: imcl not available or executable permission: [$IBM_IM_ROOT/eclipse/tools/imcl]"
  fi

  if [ ! -f "$IBM_IM_ROOT/eclipse/tools/imutilsc" ] ; then
     errmsg_and_exit "imutilsc not available: [$IBM_IM_ROOT/eclipse/tools/imutilsc]"
  fi

  WAS_ENCODED_PASSWORD="`$IBM_IM_ROOT/eclipse/tools/imutilsc encryptString $WAS_PASSWORD`"
  DB_ENCODED_PASSWORD="`$IBM_IM_ROOT/eclipse/tools/imutilsc encryptString $DB_PASSWORD`"

  local c01="s,@@WAS_ENCODED_PASSWORD@@,$WAS_ENCODED_PASSWORD,"
  local c02="s,@@WAS_USERNAME@@,$WAS_USERNAME,"
  local c03="s,@@DB_ENCODED_PASSWORD@@,$DB_ENCODED_PASSWORD,"
  sed -e "$c01" -e "$c02" -e "$c03" $filenameIn > $filenameOut

  echo "$IBM_IM_ROOT/eclipse/tools/imcl -acceptLicense -sVP -log $SCRIPT_LOGS_DIR/stsc_install_log_$lNow.log input $filenameOut ">> $SCRIPT_LOG_FILE 2>&1

  $IBM_IM_ROOT/eclipse/tools/imcl -acceptLicense -sVP -log $SCRIPT_LOGS_DIR/stsc_install_log_$lNow.log input $filenameOut >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_stsc9: [ERROR]"

  log_debug "install_stsc9 : end"
  return 0
}

######################################################
#  Install Sametime 9.0 Proxy Server
######################################################
install_stpr9 () {
  log_debug "install_stpr9 : start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")
  local filenameIn="$STPR_RESPONSE_FILE"
  local filenameOut="$SCRIPT_LOGS_DIR/installSTPR_$lNow.rsp"
  local MY_REPOSITORY="$SCRIPT_TEMP_DIR/SametimeProxyServer/STProxy/repository.config"

  if is_product_installed "STPR90" ; then
     log_info "-- Already installed"
     return 1

  fi
  log_debug "install_stpr9 : starting install"

  mkdir -p $IBM_ROOT/STTempDir/Transfer
  check_errmsg_and_exit "install_stpr9: [ERROR] Creating ST Proxy Transfer Directory"


  if [ ! -x "$IBM_IM_ROOT/eclipse/tools/imcl" ] ; then
     errmsg_and_exit "install_stpr9: imcl not available or executable permission: [$IBM_IM_ROOT/eclipse/tools/imcl]"
  fi

  if [ ! -f "$IBM_IM_ROOT/eclipse/tools/imutilsc" ] ; then
     errmsg_and_exit "imutilsc not available: [$IBM_IM_ROOT/eclipse/tools/imutilsc]"
  fi

  WAS_ENCODED_PASSWORD="`$IBM_IM_ROOT/eclipse/tools/imutilsc encryptString $WAS_PASSWORD`"


  local c01="s,@@WAS_ENCODED_PASSWORD@@,$WAS_ENCODED_PASSWORD,"
  local c02="s,@@WAS_USERNAME@@,$WAS_USERNAME,"
  local c03="s,@@SAMETIME_DEPNAME@@,$STPR_DEPNAME,"
  local c04="s,@@SSC_HOSTNAME@@,$SSC_HOSTNAME,"
  local c05="s,@@MY_REPOSITORY@@,$MY_REPOSITORY,"
  sed -e "$c01" -e "$c02" -e "$c03" -e "$c04" -e "$c05" $filenameIn > $filenameOut


  echo "$IBM_IM_ROOT/eclipse/tools/imcl -acceptLicense -sVP -log $SCRIPT_LOGS_DIR/stpr_install_log_$lNow.log input $filenameOut ">> $SCRIPT_LOG_FILE 2>&1

  $IBM_IM_ROOT/eclipse/tools/imcl -acceptLicense -sVP -log $SCRIPT_LOGS_DIR/stpr_install_log_$lNow.log input $filenameOut >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_stpr9: [ERROR]"

  log_debug "install_stpr9 : end"
  return 0
}

######################################################
#  Install Sametime 9.0 WAS Proxy for Meeting
######################################################
install_st_mtproxy9 () {
  log_debug " install_st_mtproxy9 : start"
  echo "IBM WAS Proxy Server ... "
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")
  local filenameIn="$PKG_RESPONSE_FILE"
  local filenameOut="$SCRIPT_LOGS_DIR/installSTWASPROXY_$lNow.rsp"
  local MY_REPOSITORY="$SCRIPT_TEMP_DIR/SametimeMeetingServer/STMeetings/repository.config"

  mkdir -p $IBM_ROOT/STTempDir/Capture
  check_errmsg_and_exit "install_st_mtproxy9: [ERROR] Creating ST Meeting Capture Directory"

  mkdir -p $IBM_ROOT/STTempDir/DocShare
  check_errmsg_and_exit "install_st_mtproxy9: [ERROR] Creating ST Meeting DocShare Directory"

  if [ ! -x "$IBM_IM_ROOT/eclipse/tools/imcl" ] ; then
     errmsg_and_exit " install_st_mtproxy9: imcl not available or executable permission: [$IBM_IM_ROOT/eclipse/tools/imcl]"
  fi

  if [ ! -f "$IBM_IM_ROOT/eclipse/tools/imutilsc" ] ; then
     errmsg_and_exit "imutilsc not available: [$IBM_IM_ROOT/eclipse/tools/imutilsc]"
  fi

  WAS_ENCODED_PASSWORD="`$IBM_IM_ROOT/eclipse/tools/imutilsc encryptString $WAS_PASSWORD`"


  local c01="s,@@WAS_ENCODED_PASSWORD@@,$WAS_ENCODED_PASSWORD,"
  local c02="s,@@WAS_USERNAME@@,$WAS_USERNAME,"
  local c03="s,@@SAMETIME_DEPNAME@@,$SAMETIME_DEPNAME,"
  local c04="s,@@SSC_HOSTNAME@@,$SSC_HOSTNAME,"
  local c05="s,@@MY_REPOSITORY@@,$MY_REPOSITORY,"
  sed -e "$c01" -e "$c02" -e "$c03" -e "$c04" -e "$c05" $filenameIn > $filenameOut

  echo "$IBM_IM_ROOT/eclipse/tools/imcl -acceptLicense -sVP -log $SCRIPT_LOGS_DIR/stmm_install_log_$lNow.log input $filenameOut ">> $SCRIPT_LOG_FILE 2>&1

  $IBM_IM_ROOT/eclipse/tools/imcl -acceptLicense -sVP -log $SCRIPT_LOGS_DIR/stmm_install_log_$lNow.log input $filenameOut >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit " install_st_mtproxy9: [ERROR]"

  echo "IBM ST 9.0 WAS Proxy Server  [Installed]"
  log_debug " install_st_mtproxy9 : end"
  return 0
}

######################################################
#  Install Sametime 9.0 System Console
######################################################
install_stmm9 () {
  log_debug "install_stmm9 : start"
  echo "IBM Sametime Media Server ... "
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")
  local filenameIn="$PKG_RESPONSE_FILE"
  local filenameOut="$SCRIPT_LOGS_DIR/installSTMM_$lNow.rsp"
  local MY_REPOSITORY="$SCRIPT_TEMP_DIR/SametimeMediaManager/IAV/repository.config"

  if is_product_installed "STMM90" ; then
     log_info "-- Already installed"
     return 1

  fi
  log_debug "install_stmm9 : starting install"

  if [ ! -x "$IBM_IM_ROOT/eclipse/tools/imcl" ] ; then
     errmsg_and_exit "install_stmm9: imcl not available or executable permission: [$IBM_IM_ROOT/eclipse/tools/imcl]"
  fi

  if [ ! -f "$IBM_IM_ROOT/eclipse/tools/imutilsc" ] ; then
     errmsg_and_exit "imutilsc not available: [$IBM_IM_ROOT/eclipse/tools/imutilsc]"
  fi

  WAS_ENCODED_PASSWORD="`$IBM_IM_ROOT/eclipse/tools/imutilsc encryptString $WAS_PASSWORD`"


  local c01="s,@@WAS_ENCODED_PASSWORD@@,$WAS_ENCODED_PASSWORD,"
  local c02="s,@@WAS_USERNAME@@,$WAS_USERNAME,"
  local c03="s,@@SAMETIME_DEPNAME@@,$SAMETIME_DEPNAME,"
  local c04="s,@@SSC_HOSTNAME@@,$SSC_HOSTNAME,"
  local c05="s,@@MY_REPOSITORY@@,$MY_REPOSITORY,"
  sed -e "$c01" -e "$c02" -e "$c03" -e "$c04" -e "$c05" $filenameIn > $filenameOut

  echo "$IBM_IM_ROOT/eclipse/tools/imcl -acceptLicense -sVP -log $SCRIPT_LOGS_DIR/stmm_install_log_$lNow.log input $filenameOut ">> $SCRIPT_LOG_FILE 2>&1

  $IBM_IM_ROOT/eclipse/tools/imcl -acceptLicense -sVP -log $SCRIPT_LOGS_DIR/stmm_install_log_$lNow.log input $filenameOut >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_stmm9: [ERROR]"

  echo "IBM ST 9.0 Media Server Component  [Installed]"
  log_debug "install_stmm9 : end"
  return 0
}

######################################################
#  Install Sametime 9.0 MCU Server
######################################################
install_stmcu9 () {
  log_debug "install_stmcu9 : start"
  local NOW=$(date +"%Y-%m-%d-%H-%M-%S")
  local filename="$SCRIPT_TEMP_DIR/SametimeVideoMCU.zip"



  if is_product_installed "stmcu90" ; then
     log_info "-- Already installed"
     return 1

  fi
  log_debug "install_stmcu9 : starting install"

  local MCU_INSTALLER_DIR="$SCRIPT_TEMP_DIR/SametimeVideoMCU"

  echo "Downloading .... SametimeVideoMCU.zip"
  wget -q $MCU_INSTALLER_URL -O $filename  >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_stmcu9: [ERROR] Retrieve File"

  echo "Extracting .... SametimeVideoMCU.zip"
  unzip -o $filename -d $SCRIPT_TEMP_DIR  >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_stmcu9: [ERROR] on extract"

  cp $MCU_INSTALLER_DIR/console.properties $MCU_INSTALLER_DIR/console.properties_$NOW

  local MCU_RESPONSE_FILE="$MCU_INSTALLER_DIR/console.properties"

  echo "# console.properties"             >  $MCU_RESPONSE_FILE
  echo "ACCEPT_LICENSE=true"              >> $MCU_RESPONSE_FILE
  echo "SSCHostName=$SSC_HOSTNAME"        >> $MCU_RESPONSE_FILE
  echo "SSCSSLEnabled=true"               >> $MCU_RESPONSE_FILE
  echo "SSCHTTPSPort=9443"                >> $MCU_RESPONSE_FILE
  echo "depName=$MCU_DEPNAME"             >> $MCU_RESPONSE_FILE
  echo "localHostName=$MCU_HOSTNAME"      >> $MCU_RESPONSE_FILE
  echo "SSCUserName=$WAS_USERNAME"        >> $MCU_RESPONSE_FILE
  echo "SSCPassword=$WAS_PASSWORD"        >> $MCU_RESPONSE_FILE
  echo "JAVA_HOME=/usr"                   >> $MCU_RESPONSE_FILE

  cd $MCU_INSTALLER_DIR

  ./installvideomcu_SLES11.sh  >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_stmcu9: [ERROR] on installvideomcu_SLES11"

  log_debug "install_stmcu9 : end"
  return 0
}

######################################################
#  Install Sametime 9.0 D9 Server
######################################################
install_domino9 () {
  log_debug "install_domino9 : start"
  local NOW=$(date +"%Y-%m-%d-%H-%M-%S")
  local filename="$SCRIPT_TEMP_DIR/DOMINO_SERVER.tar"
  local DOMINO_RESPONSE_FILE="$SCRIPT_RSP_DIR/installDomino9.rsp"


  #if is_product_installed "domino9" ; then
  #   log_info "-- Already installed"
  #   return 1
  #
  #fi
  #log_debug "install_domino9 : starting install"

  local D9_INSTALLER_DIR="$SCRIPT_TEMP_DIR/D9"

  echo "Criando grupo sametime .... "
  groupadd sametime >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_domino9: [ERROR] Create Group"

  echo "Criando usuario sametime .... "
  useradd -m -g sametime -d /opt/ibm/sametimedata sametime >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_domino9: [ERROR] Create User"

  mkdir -p $D9_INSTALLER_DIR  >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_domino9: [ERROR]"

  echo "Downloading .... DOMINO_SERVER.tar"
  wget -q $D9_INSTALLER_URL -O $filename  >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_domino9: [ERROR] Retrieve File"

  echo "Extracting .... DOMINO_SERVER.tar"
  tar -xvf $filename -C $D9_INSTALLER_DIR  >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_domino9: [ERROR] on extract"

  echo "Installing .... "
  $D9_INSTALLER_DIR/linux/domino/install -options "$DOMINO_RESPONSE_FILE" -silent >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_domino9: [ERROR] on Domino Server"

  log_debug "install_domino9 : end"
  return 0
}

######################################################
#  Install Sametime 9.0 D9FIX Server
######################################################
install_domino9_fixes () {
  log_debug "install_domino9_fixes : start"
  local NOW=$(date +"%Y-%m-%d-%H-%M-%S")
  local filename="$SCRIPT_TEMP_DIR/DS9.0.1_FPK1_FOR_LNX_ON_INTEL32_E.tar"

  #if is_product_installed "domino9" ; then
  #   log_info "-- Already installed"
  #   return 1
  #
  #fi
  #log_debug "install_domino9_fixes : starting install"

  local D9FIX_INSTALLER_DIR="$SCRIPT_TEMP_DIR/D9FIX"

  mkdir -p $D9FIX_INSTALLER_DIR  >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_domino9_fixes: [ERROR]"

  echo "Downloading .... DS9.0.1_FPK1_FOR_LNX_ON_INTEL32_E.tar"
  wget -q $D9FIX_INSTALLER_URL -O $filename  >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_domino9_fixes: [ERROR] Retrieve File"

  echo "Extracting .... DS9.0.1_FPK1_FOR_LNX_ON_INTEL32_E.tar"
  tar -xvf $filename -C $D9FIX_INSTALLER_DIR  >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_domino9_fixes: [ERROR] on extract"

  export NUI_NOTESDIR=/opt/ibm/domino

  echo "Installing .... "
  $D9FIX_INSTALLER_DIR/linux/domino/install -script $D9FIX_INSTALLER_DIR/linux/domino/script.dat >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_domino9_fixes: [ERROR] on Domino Server"

  log_debug "install_domino9_fixes : end"
  return 0
}

######################################################
#  Install Sametime 9.0 Community Server
######################################################
install_stcom9 () {
  log_debug "install_stcom9 : start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")
  local filename="$SCRIPT_TEMP_DIR/STD_SERVER_UNIX.tar"
  local filenameOut="$SCRIPT_LOGS_DIR/installSTCO_$lNow.rsp"

  #if is_product_installed "domino9" ; then
  #   log_info "-- Already installed"
  #   return 1
  #
  #fi
  #log_debug "install_stcom9 : starting install"

  local STCO_INSTALLER_DIR="$SCRIPT_TEMP_DIR/STCO"

  mkdir -p $STCO_INSTALLER_DIR  >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_stcom9: [ERROR]"

  echo "Downloading .... STD_SERVER_UNIX.tar"
  wget -q $STCO_INSTALLER_URL -O $filename  >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_stcom9: [ERROR] Retrieve File"

  echo "Extracting .... STD_SERVER_UNIX.tar"
  tar -xvf $filename -C $STCO_INSTALLER_DIR  >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_stcom9: [ERROR] on extract"

  echo "#  ./setuplinux.bin -silent -options installSTCO_$lNow.rsp"    > $filenameOut
  echo "-V SAMETIME_LOCALE=\"en\""                                     >> $filenameOut
  echo "-V licenseAccepted=\"true\""                                   >> $filenameOut
  echo "-V UNIX_DataDir=\"/opt/ibm/sametimedata\""                     >> $filenameOut
  echo "-V UNIX_UserName=\"sametime\""                                 >> $filenameOut
  echo "-V UNIX_GroupName=\"sametime\""                                >> $filenameOut
  echo "-V UNIX_ServerName=\"$STCO_HOSTNAME\""                         >> $filenameOut
  echo "-V UPGRADE_SAMETIME=\"true\""                                  >> $filenameOut
  echo "-V USE_SAMETIME_SYSTEM_CONSOLE=\"true\""                       >> $filenameOut
  echo "-V SSC_DEPLOYMENT_PLAN_NAME=\"$SAMETIME_DEPNAME\""             >> $filenameOut
  echo "-V SSC_ADMIN_USERNAME=\"$WAS_USERNAME\""                       >> $filenameOut
  echo "-V SSC_ADMIN_PASSWORD=\"$WAS_PASSWORD\""                       >> $filenameOut
  echo "-V SSC_HOSTNAME=\"$SSC_HOSTNAME\""                             >> $filenameOut
  echo "-V SSC_USE_SSL=\"true\""                                       >> $filenameOut
  echo "-V SSC_PORT=\"9443\""                                          >> $filenameOut
  echo "-V SAMETIME_SERVER_HOSTNAME=\"$STCO_HOSTNAME\""                >> $filenameOut

  echo "Installing .... "
  $STCO_INSTALLER_DIR/SametimeStandardServer/Server/setuplinux.bin -silent -options $filenameOut -is:log /tmp/installlog.txt >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_stcom9: [ERROR] on Domino Server"

  log_debug "install_stcom9 : end"
  return 0
}

######################################################
#  Download Sametime 9.0 Advanced Server
######################################################
download_stadv9 () {
  log_debug "download_stadv9 : start"

  local installerUrl="$REPOSITORY_URL/sametime/9.0/app/SametimeAdvancedServer.zip"
  local filename01="$SCRIPT_TEMP_DIR/SametimeAdvancedServer.zip"

  echo "Downloading .... $installerUrl"
  wget -q $installerUrl -O $filename01  >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "download_stadv9: [ERROR] Retrieve File "

  echo "Extracting .... "
  unzip -o $filename01 -d $SCRIPT_TEMP_DIR  >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "download_installation_manager: [ERROR] on extract"

  log_debug "download_stadv9 : end"
  return 0
}

######################################################
#  Install Sametime 9.0 Advanced Server
######################################################
install_stadv9 () {
  log_debug "install_stadv9 : start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")

  local MY_REPOSITORY="$SCRIPT_TEMP_DIR/SametimeAdvancedServer/STAdvanced/repository.config"
  local filenameIn="responsefiles/install_stadv9.rsp"
  local filenameOut="$SCRIPT_LOGS_DIR/installSTADV_$lNow.rsp"

  if is_product_installed "stadv90" ; then
     log_info "-- Already installed"
     return 1

  fi
  log_debug "install_stadv9 : starting install"

  if [ ! -x "$IBM_IM_ROOT/eclipse/tools/imcl" ] ; then
     errmsg_and_exit "install_stadv9: imcl not available or executable permission: [$IBM_IM_ROOT/eclipse/tools/imcl]"
  fi

  if [ ! -f "$IBM_IM_ROOT/eclipse/tools/imutilsc" ] ; then
     errmsg_and_exit "imutilsc not available: [$IBM_IM_ROOT/eclipse/tools/imutilsc]"
  fi

  WAS_ENCODED_PASSWORD="`$IBM_IM_ROOT/eclipse/tools/imutilsc encryptString $WAS_PASSWORD`"

  local c01="s,@@WAS_ENCODED_PASSWORD@@,$WAS_ENCODED_PASSWORD,"
  local c02="s,@@WAS_USERNAME@@,$WAS_USERNAME,"
  local c03="s,@@STSC_HOSTNAME@@,$SSC_HOSTNAME,"
  local c04="s,@@STADV_DEPNAME@@,$STADV_DEPNAME,"
  local c05="s,@@STADV_HOSTNAME@@,$STADV_HOSTNAME,"
  local c06="s,@@MY_REPOSITORY@@,$MY_REPOSITORY,"

  sed -e "$c01" -e "$c02" -e "$c03" -e "$c04" -e "$c05" -e "$c06" $filenameIn > $filenameOut

  echo "$IBM_IM_ROOT/eclipse/tools/imcl -acceptLicense -sVP -log $SCRIPT_LOGS_DIR/stadv_install_log_$lNow.log input $filenameOut ">> $SCRIPT_LOG_FILE 2>&1

  $IBM_IM_ROOT/eclipse/tools/imcl -acceptLicense -sVP -log $SCRIPT_LOGS_DIR/stadv_install_log_$lNow.log input $filenameOut >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "install_stadv9: [ERROR]"

  log_debug "install_stadv9 : end"
  return 0
}

######################################################
#  Function:  st_configure_node_profile
#  Description:   Run Create a WAS node profile
######################################################
st_configure_node_profile () {
  log_debug "st_configure_node_profile: start"
  local lNow=$(date +"%Y-%m-%d-%H-%M-%S")
  local NODE_RESPONSE_FILE="$SCRIPT_LOGS_DIR/configNode_$DP_NODENAME.rsp"

  if [ -d $APPSERVER_ROOT/profiles/AppSrv01 ]; then
     log_info "-- Already created"
     return 1
  fi

  if [ ! -f $APPSERVER_ROOT"/bin/manageprofiles.sh" ]; then
    errmsg_and_exit "st_configure_node_profile: File [$APPSERVER_ROOT/bin/manageprofiles.sh] not found"
  fi

  echo "create          "                  >  $NODE_RESPONSE_FILE
  echo "profileName=AppSrv01"              >> $NODE_RESPONSE_FILE
  echo "profilePath=$APPSERVER_ROOT/profiles/AppSrv01"         >> $NODE_RESPONSE_FILE
  echo "templatePath=$APPSERVER_ROOT/profileTemplates/managed" >> $NODE_RESPONSE_FILE
  echo "nodeName=$DP_NODENAME"             >> $NODE_RESPONSE_FILE
  echo "hostName=$DP_HOSTNAME"             >> $NODE_RESPONSE_FILE
  echo "dmgrHost=$SSC_HOSTNAME"            >> $NODE_RESPONSE_FILE
  echo "dmgrPort=8703"                     >> $NODE_RESPONSE_FILE
  echo "dmgrAdminUserName=$WAS_USERNAME"   >> $NODE_RESPONSE_FILE
  echo "dmgrAdminPassword=$WAS_PASSWORD"   >> $NODE_RESPONSE_FILE
  echo "personalCertValidityPeriod=15"     >> $NODE_RESPONSE_FILE
  echo "signingCertValidityPeriod=15"      >> $NODE_RESPONSE_FILE

  $APPSERVER_ROOT/bin/manageprofiles.sh -response $NODE_RESPONSE_FILE >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "st_configure_node_profile:  error"

  check_manageprofile_result_log "AppSrv01_create"

  log_debug "st_configure_node_profile:  end"
  return 0
}

download_sametime () {
  log_debug "download_sametime : start"

  local filenameIn="$SCRIPT_TEMP_DIR/$PKG_FILENAME"
  #local localRepository="$SCRIPT_TEMP_DIR/SametimeSystemConsole"

  echo "Downloading .... $PKG_FILENAME"
  wget -q $PKG_INSTALLER_URL -O $filenameIn  >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "download_sametime: [ERROR] Retrieve File "

  echo "Extracting .... $PKG_FILENAME"
  #unzip -o $filenameIn -d $SCRIPT_TEMP_DIR  >> $SCRIPT_LOG_FILE 2>&1
  tar -xvf $filenameIn -C $SCRIPT_TEMP_DIR  >> $SCRIPT_LOG_FILE 2>&1
  check_errmsg_and_exit "download_installation_manager: [ERROR] on extract"

  log_debug "download_sametime : end"
  return 0
}
