#!/bin/bash
#######################################################################################################
# Description: IBM Connections 5.5 Install Easy Script
#
# Author: 2014 by Enio Basso ( http://ebasso.net )
#
# Version V1 20140627.01 - Connections 45
# Version V1 20151112.01 - Connections 50
# Version V1 20160211.01 - Connections 55
# Version V1 20160623.01 - Connections 55CR1 - jdk7
#
# Next Versions
# Version VX 2013XXXX.01 - Support for Connections
#######################################################################################################
# ------------ Script Variables   -------------------------------------
HOSTNAME=`hostname`
#S_HOSTNAME=`hostname -s`

SCRIPT_NAME=$0
CMD=$1
PARAM1=$2
PARAM2=$3
PARAM3=$4

SCRIPT_PWD=`dirname $0`;
if [ "x$SCRIPT_PWD" = "x." ]; then
   SCRIPT_PWD=`pwd`
fi

# -------------------------------------- Default Values -----------------------------------------------
. ./Connections55Deploy.properties
. ./helperfunctions.fnc

unset http_proxy
unset https_proxy

IBM_ROOT="/opt/IBM"
WAS_ND_VERSION="WAS85"

BIN_DIR="/opt/IBM/Binarios"
IIM_BIN_DIR="$BIN_DIR/iim"
WAS_ND_BIN_DIR="$BIN_DIR/was855"
WAS_ND_FIX_BIN_DIR="$BIN_DIR/was855fix"
WAS_SUP_BIN_DIR="$BIN_DIR/was855sup"
WAS_SUP_FIX_BIN_DIR="$BIN_DIR/was855supfix"
JDK_BIN_DIR="$BIN_DIR/jdk7"
CON_BIN_DIR="$BIN_DIR/c55"
CON_FIX_BIN_DIR="$BIN_DIR/c55fix"
FEB_BIN_DIR="$BIN_DIR/c55/feb"
COG_BIN_DIR="$BIN_DIR/c55/cognos"

IIM_BIN_FILE="agent.installer.linux.gtk.x86_64_1.8.4001.20160217_1716.zip"
JDK_BIN_FILE="7.1.3.10_0001-WS-IBMWASJAVA-Linux.zip"
JDK_NAME="1.7.1_64"

WAS_BIN_01="WAS_ND_V8.5.5_1_OF_3.zip"
WAS_BIN_02="WAS_ND_V8.5.5_2_OF_3.zip"
WAS_BIN_03="WAS_ND_V8.5.5_3_OF_3.zip"
WAS_BIN_04="WAS_V8.5.5_SUPPL_1_OF_3.zip"
WAS_BIN_05="WAS_V8.5.5_SUPPL_2_OF_3.zip"
WAS_BIN_06="WAS_V8.5.5_SUPPL_3_OF_3.zip"

WAS_FIX_BIN_01="8.5.5-WS-WAS-FP0000008-part1.zip"
WAS_FIX_BIN_02="8.5.5-WS-WAS-FP0000008-part2.zip"
WAS_FIX_BIN_03="8.5.5-WS-WASSupplements-FP0000008-part1.zip"
WAS_FIX_BIN_04="8.5.5-WS-WASSupplements-FP0000008-part2.zip"

CON_BIN_01="IBM_Connections_5.5_lin.tar"

FEB_BIN_01="IBM_ConnectionsSurvey_5.5_lin.tar"

CCM_BIN_01="5.2.1-P8CPE-LINUX.BIN"
CCM_BIN_02="5.2.1.2-P8CPE-LINUX-FP002.BIN"
CCM_BIN_03="5.2.1.2-P8CPE-CLIENT-LINUX-FP002.BIN"
CCM_BIN_04="IBM_CONTENT_NAVIGATOR-2.0.3-LINUX.bin"
CCM_BIN_05="IBM_CONTENT_NAVIGATOR-2.0.3.5-FP005-LINUX.bin"

COG_BIN_01="bi_svr_10.2.2_l86_ml.tar.gz"
COG_BIN_02="bi_trfrm_10.2.2_l86_ml.tar.gz"
COG_BIN_03="5.5.0.0-IC-CR1-CognosWizard-LO88785-Linux.tar"
#"IBM_Cognos_Wizard_5.5_lin.tar"

CON_FIX_BIN_01="5.5.0.0-IC-Multi-UPDI-20160628.zip"
CON_FIX_BIN_02="5.5.0.0-IC-Multi-CR01-LO88602.zip"

set_deploy_environment_production()
{
  DP_DMGR_CELLNAME=connectionsCell
  DP_DMGR_NODENAME=cnx11Node
  DP_DMGR_HOSTNAME=cnx11.company.com

  DP_NODENAME=$HOSTNAME"Node"
  DP_HOSTNAME="$HOSTNAME.$DNS_DOMAIN_NAME"

  COGNOS_NODENAME="cnx12Node"
  COGNOS_HOSTNAME="cnx12.company.com"

  DB_HOST_COGNOS="proddb2-cognos.company.com"
  DB_PORT_COGNOS="50000"
  DB_HOST_METRICS="proddb2-metrics.company.com"
  DB_PORT_METRICS="50000"

  LDAP_SERVER="ldap01srv.company.com"
  LDAP_ALIAS="aplic_ldap"
  LDAP_REPO="LDAP_PROD"
  LDAP_REALM="ou=users,o=company,c=us"

  REPO_TYPE="production"
  REPO_URL="http://myreposerver.company.com"
  CON_RSP_FILE="responsefiles/instalaC55_production.rsp"
  CONFIX_RSP_FILE="responsefiles/instalaC55CR1_production.rsp"
  FEBSERVER_RSP_FILE="responsefiles/instalaFeb_production.rsp"
  COGNOS_RSP_FILE="responsefiles/instalaCog55_production.rsp"

  IIM_INST_URL="$REPO_URL/installation"
  WAS_INST_URL="$REPO_URL/was/8.5.5"

  CON_INST_URL="$REPO_URL/connections/5.5/app"
  CCM_INST_URL="$REPO_URL/connections/5.5/app/filenet"
  COG_INST_URL="$REPO_URL/connections/5.5/app/cognos"
  CON_FIX_INST_URL="$REPO_URL/connections/5.5/CR1"
  FEB_INST_URL="$REPO_URL/connections/5.5/app/feb"

}

# ------------ WAS Functions   -------------------------------------
#function Usage ()
show_usage ()
{
  echo ""
  echo "Usage: $0 { CMD }  "
  echo ""
  echo "Where CMD"
  echo "  sanity_check             - Check the environment before install "
  echo "  tuning_os                - Tuning Operating System, you must restart server after changes "
  echo ""
  echo "  download_was85                              - Download IIM, WAS 8.5 ND, WAS Fixes"
  echo "  download_connections55                      - Download Connections Files"
  echo "  download_connections55_fixes                - Download Connections Files Fixes"
  echo "  download_was85_sup                          - Download IHS, Plugin, Wct"
  echo "  extract_was85                               - Extract IIM, WAS 8.5 ND, WAS Fixes"
  echo "  extract_connections55                       - Extract Connections Files"
  echo "  extract_connections55_fixes                 - Extract Connections Files Fixes"
  echo "  extract_was85_sup                           - Extract IHS, Plugin, Wct"
  echo ""
  echo "  install_was85                               - Install WAS Software"
  echo "  install_dmgr                                - Install Dmgr"
  echo "  install_wasnode                             - Install Was Node"
  echo "  install_wasnode_feb                         - Install Was Node for Forms"
  echo "  install_ihsnode                             - Install HTTP Server Node"
  echo "  install_plgnode                             - Install Plugin, Wct"
  echo ""
  echo "Install Connections"
  echo "  install_connections55                 - Install IBM Connections 5.5"
  echo "  install_connections55_fixes           - Install IBM Connections 5.5"
  echo "  install_febserver                     - Install IBM Connections 5.5"
  echo ""
  echo "Install Cognos"
  echo "  install_db2client                     - Install DB2 Client"
  echo "  configure_db2client                   - Configure DB2 Client"
  echo "  install_wasnode_cognos                - Install WAS node - Cognos"
  echo "  start_server1                         - Start Server1"
  echo "  download_cognos                     - Download Cognos Files"
  echo "  extract _cognos                     - Extract Cognos Files"
  echo "  install_cognos                        - Install Cognos"
#  echo ""
  echo "# -------- Debug Options --------"
  echo ""
  echo "  sanity_check"
  echo "  tuning_os"
  echo "  download_was85                              - Download All Software "
  echo "    download_installation_manager                - Download IBM Installation Manager"
  echo "    download_was_nd                              - Download WAS 8.5.5"
  echo "    download_was_nd_fixes                        - Download WAS 8.5.5.7 FIX"
  echo "    download_jdk7                                - Download Java 7"
  echo "  download_connections55                       - Download Connections Files"
  echo "  download_connections55_fixes                       - Download Connections Files"
  echo "  download_feb                                - Download Forms"
  echo "  extract_was85                               - Extract All Software to Shared Area"
  echo "    extract_installation_manager                 - Extract IBM Installation Manager"
  echo "    extract_was_nd                               - Extract WAS 8.5.5"
  echo "    extract_was_nd_fixes                         - Extract WAS 8.5.5.7 FIX"
  echo "    extract_jdk7                                 - Extract Java 7"
  echo "  extract_connections55                       - Extract Connections Files"
  echo "  extract_connections55_fixes                 - Extract Connections Files"
  echo "  extract_feb                                 - Extract Forms"
  echo "  install_was85                                  - Install WAS Software"
  echo "    install_installation_manager                 - Install/update IBM Installation Manager"
  echo "    install_was_nd"
  echo "    install_was_nd_fixes"
  echo "    install_jdk7"
  echo "  configure_dmgr_profile"
  echo "  configure_node_profile"
  echo "  configure_node_profile_cognos"
  echo "  configure_jdk7"
  echo "  cleanup_deploy "
  echo "  cleanup_binarios "
  echo "  cleanup_was_profile "
  echo "  start_dmgr                            - Start Dmgr"
  echo "  stop_dmgr                             - Stop  Dmgr"
  echo "  configure_dmgr_service                - Configure dmgr as service on linux"
  echo "  configure_node_service                - Configure nodeagent as service on linux"
  echo "  config_db2jdbcV10_5                    - Configure DB2 Jdbc"
  echo "  backup_pre_connections                 "
  echo "  configure_plgwct                      - Configure Plugin for IHS"
  echo "  configure_webserver_on_dmgr           - Configure webserver on DMGR"
  echo "  install_connections55_updateInstaller - Install connections 55 cr1 update installer"
  echo "  wsadmin scripts"
  echo "    ws_import_ldap_cert                         - retrieve ssl for LDAP"
  echo "    ws_config_ldap                              - config LDAP"
  echo "    ws_config_dmgr_jvm                          - config DMGR Jvm"
  return 0
}


###########################################################   Main Script ##############################################################
init_script_environment
get_system_architecture

#set_deploy_environment_desenv
set_deploy_environment_homologacao
#set_deploy_environment_production

case "$CMD" in
  sanity_check)
	  sanity_check
  ;;
 tuning_os)
    tuning_os_linux_x86
    echo "Voce deve reinicar o SO para que as alteracoes sejam efetivadas"
 ;;
 install_was85)
    echo "Install IBM WebSphere Application Server ..."
    install_installation_manager
    echo "IBM Installation Manager  [Installed]"
    install_was_nd
    echo "IBM WAS 8.5               [Installed]"
    install_was_nd_fixes
    echo "IBM WAS 8.5 FIX           [Installed]"
    install_jdk7
    echo "IBM Java 7                [Installed]"
    config_db2jdbcV10_5
    echo "DB2 JDBC Drivers        [Configured]"
 ;;
 install_dmgr)   # DMGR Profile
    echo "Install DMGR Server ..."
    $0 install_was85
    check_errmsg_and_exit "install_dmgr: [ERROR]"
    configure_dmgr_profile
    echo "WAS Profile             [Configured]"
    stop_server "dmgr" "$WAS_USERNAME" "$WAS_PASSWORD" "Dmgr01"
    start_server "dmgr" "Dmgr01"
    configure_jdk7
    echo "Java 7                  [Configured]"
    ws_import_ldap_cert
    echo "retrieve ssl for LDAP   [Configured]"
    ws_config_ldap
    echo "config LDAP             [Configured]"
    stop_server "dmgr" "$WAS_USERNAME" "$WAS_PASSWORD" "Dmgr01"
    start_server "dmgr" "Dmgr01"
    ws_config_dmgr_jvm
    echo "tuning_jvm             [Configured]"
    stop_server "dmgr" "$WAS_USERNAME" "$WAS_PASSWORD" "Dmgr01"
    start_server "dmgr" "Dmgr01"
 ;;
 install_wasnode)    # Node Profile
    echo "Install Was Node ..."
    $0 install_was85
    check_errmsg_and_exit "install_wasnode: [ERROR]"
    configure_node_profile
    echo "WAS Profile             [Configured]"
 ;;
 install_wasnode_cognos)    # Cognos Profile
    echo "Install Cognos Node ..."
    install_installation_manager
    echo "IBM Installation Manager  [Installed]"
    install_was_nd
    echo "IBM WAS 8.5               [Installed]"
    install_was_nd_fixes
    echo "IBM WAS 8.5 FIX           [Installed]"
    install_jdk7
    echo "IBM Java 7                [Installed]"
    configure_node_profile_cognos
    echo "WAS Profile             [Configured]"
 ;;
 install_wasnode_feb)
    echo "Install Febserver Node ..."
    $0 install_was85
    check_errmsg_and_exit "install_wasnode_feb: [ERROR]"
    configure_node_profile_feb
    echo "WAS Profile             [Configured]"
    federate_node
    echo "Federate Node           [Configured]"
 ;;
 install_ihsnode)
    echo "Install HTTP Server ..."
    install_installation_manager
    echo "IBM Installation Manager  [Installed]"
    install_ihs
    echo "IBM HTTP Server           [Installed]"
    install_plgwct
    echo "IBM Websphere Plg and Wct [Installed]"
 ;;
 install_plgnode)
    echo "Install HTTP Server ..."
    install_installation_manager
    echo "IBM Installation Manager  [Installed]"
    install_plgwct
    echo "IBM Websphere Plg and Wct [Installed]"
 ;;
 install_db2client)
    install_db2client
    echo "IBM DB2 client        [Installed]"
 ;;
 configure_db2client)
    configure_db2client
    echo "IBM DB2 client        [Configured]"
 ;;
 backup_pre_connections)
    backup_pre_connections
 ;;
 install_connections55)
    install_connections55
    echo "IBM Connections         [Installed]"
  ;;
  install_connections55_fixes)
     install_connections55_updateInstaller
     echo "Update updateInstaller  [Installed]"
     install_connections55_fixes
     echo "IBM Connections Fixes   [Installed]"
  ;;
  install_febserver)
    install_febserver
    echo "IBM FebServer         [Installed]"
  ;;
 install_connections55_updateInstaller)
    install_connections55_updateInstaller
 ;;
 federate_node)
      federate_node
      echo "Federate Node           [Federado]"
  ;;
 install_cognos)
    install_cognos
    echo "IBM Cognos              [Installed]"
  ;;
 start_server1)
      start_server1
      echo "IBM start_server1       [Iniciado]"
  ;;
# -------- Debug Options --------
 download_installation_manager)
      download_installation_manager
 ;;
 download_was_nd)
      download_was_nd
 ;;
 download_was_nd_fixes)
      download_was_nd_fixes
 ;;
 download_jdk7)
      download_jdk7
 ;;
 download_was85)
      download_installation_manager
      download_was_nd
      download_was_nd_fixes
      download_jdk7
 ;;
 download_was85_sup)
      download_installation_manager
      download_was_sup
      download_was_sup_fixes
 ;;
 download_connections55)
      download_connections55
 ;;
 download_connections55_fixes)
      download_connections55_fixes
 ;;
 download_feb)
      download_feb
 ;;
 download_cognos)
      download_cognos
 ;;
 extract_cognos)
      extract_cognos
 ;;
 extract_installation_manager)
      extract_installation_manager
 ;;
 extract_was_nd)
      extract_was_nd
 ;;
 extract_was_nd_fixes)
      extract_was_nd_fixes
 ;;
 extract_jdk7)
      extract_jdk7
 ;;
 extract_was85)
      extract_installation_manager
      extract_was_nd
      extract_was_nd_fixes
      extract_jdk7
 ;;
 extract_was85_sup)
      extract_installation_manager
      extract_was_sup
      extract_was_sup_fixes
 ;;
 extract_connections55)
      extract_connections55
 ;;
 extract_connections55_fixes)
      extract_connections55_fixes
 ;;
 extract_feb)
      extract_feb
 ;;
 install_installation_manager)
      install_installation_manager
 ;;
 install_was_nd)
      install_was_nd
 ;;
 install_was_nd_fixes)
     install_was_nd_fixes
 ;;
 install_jdk7)
     install_jdk7
 ;;
 configure_dmgr_profile)
      configure_dmgr_profile
 ;;
 configure_node_profile)
     configure_node_profile
 ;;
 configure_node_profile_cognos)
     configure_node_profile_cognos
 ;;
 configure_jdk7)
    configure_jdk7
  ;;
 cleanup_deploy)
      cleanup_deploy
 ;;
 cleanup_binarios)
      cleanup_binarios
 ;;
 cleanup_was_profile)
      cleanup_was_profile
 ;;
 configure_dmgr_service)
      configure_was_service "configure_dmgr_service" "dmgr"
 ;;
 configure_node_service)
      configure_was_service "configure_node_service" "nodeagent"
 ;;
 start_dmgr)
      start_server "dmgr" "Dmgr01"
 ;;
 stop_dmgr)
      stop_server "dmgr" "$WAS_USERNAME" "$WAS_PASSWORD" "Dmgr01"
 ;;
 start_node)
      start_server "nodeagent" "AppSrv01"
 ;;
 stop_node)
      stop_server "nodeagent" "$WAS_USERNAME" "$WAS_PASSWORD" "AppSrv01"
 ;;
 config_db2jdbcV10_5)
      config_db2jdbcV10_5
 ;;
 testa_db2client)
      testa_db2client
 ;;
 configure_plgwct)
    configure_plgwct
 ;;
 configure_webserver_on_dmgr)
    configure_webserver_on_dmgr
;;
 ws_import_ldap_cert)
      ws_import_ldap_cert
 ;;
 ws_config_ldap)
      ws_config_ldap
 ;;
 ws_config_dmgr_jvm)
      ws_config_dmgr_jvm
 ;;
 *)
      show_usage
      exit 1
 ;;
esac
exit 0
