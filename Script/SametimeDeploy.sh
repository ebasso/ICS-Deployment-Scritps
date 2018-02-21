#!/bin/bash
#######################################################################################################
# Description: IBM Portal 8 Install Easy Script
#
# Author: 2014 by Enio Basso ( http://ebasso.net )
#
# Version V1 20140610.01 - Sametime 9.0
#
#
# Next Versions
# Version VX 2013XXXX.01 - Support for Portal 8.0.0.1CF7 and WAS 8.5.5
#######################################################################################################

# -------------------------------------- Default Values -----------------------------------------------
. ./SametimeDeploy.properties
. ./helperfunctions.fnc

#IIM_INSTALLER_URL="$REPOSITORY_URL/installation/1.6.2/app/InstalMgr1.6.2_LNX_X86_64_WAS_8.5.5.zip"
#IIM_INSTALLER_URL="$REPOSITORY_URL/installation/1.7.3/agent.installer.linux.gtk.x86_64_1.7.3000.20140521_1925.zip"
IIM_INSTALLER_URL="$REPOSITORY_URL/installation/agent.installer.linux.gtk.x86_64_1.8.3000.20150606_0047.zip"
WAS_ND_RESPONSE_FILE="responsefiles/installSTWAS85_$REPOSITORY_TYPE.rsp"
WAS_ND_FIXES_RESPONSE_FILE="responsefiles/installSTWAS85Fixes_$REPOSITORY_TYPE.rsp"
WAS_855_FIXES_RESPONSE_FILE="responsefiles/updateSTWAS855_Fixes_$REPOSITORY_TYPE.rsp"

IBM_ROOT="/opt/IBM"
WAS_ND_VERSION="WAS85"

MCU_INSTALLER_URL="$REPOSITORY_URL/sametime/9.0/app/SametimeVideoMCU.zip"
D9_INSTALLER_URL="$REPOSITORY_URL/sametime/9.0/9.0.0.1/SametimeCommunityServer/DOMINO_SERVER_9.0.1_LINUX_XS_32_EN.tar"
D9FIX_INSTALLER_URL="$REPOSITORY_URL/sametime/9.0/9.0.0.1/SametimeCommunityServer/DS9.0.1_FPK1_FOR_LNX_ON_INTEL32_E.tar"
STCO_INSTALLER_URL="$REPOSITORY_URL/sametime/9.0/9.0.0.1/SametimeCommunityServer/STD_SERVER_UNIX.tar"
STSC_INSTALLER_URL="$REPOSITORY_URL/sametime/9.0/9.0.0.1/SametimeSystemConsole.tgz"
STPR_INSTALLER_URL="$REPOSITORY_URL/sametime/9.0/9.0.0.1/SametimeProxyServer.tgz"
STMT_INSTALLER_URL="$REPOSITORY_URL/sametime/9.0/9.0.0.1/SametimeMeetingServer.tgz"
STMM_INSTALLER_URL="$REPOSITORY_URL/sametime/9.0/9.0.0.1/SametimeMediaManager.tgz"
ST_MTPROXY_INSTALLER_URL="$REPOSITORY_URL/sametime/9.0/9.0.0.1/SametimeMeetingWindows/SametimeMeetingServer.zip"

unset http_proxy
unset https_proxy

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

# ------------ WAS Functions   -------------------------------------
#function Usage ()
show_usage ()
{
  echo ""
  echo "Usage: $0 { CMD }  "
  echo ""
  echo "Where CMD"
  echo "  sanity_check             - Check the environment before install "
  echo "  sametime_hosts_production  - Sametime hosts em production "
  echo "  tuning_os                - Tuning Operating System, you must restart server after changes "
  echo ""
  echo "  install_was85                  - Install WAS 8.5 and Fixes on Server"
  echo "  install_"$REP_PREFIX"console901       - Install Sametime System Console"
  echo "  install_domino9                - Install Domino and Fix on Server"
  echo "  install_"$REP_PREFIX"comser90x        - Install Sametime Community Server"
  echo "  install_"$REP_PREFIX"pr90x            - Install Sametime Proxy Server"
  echo "  install_"$REP_PREFIX"sip90x           - Install Sametime Media Server"
  echo "  install_"$REP_PREFIX"vmgr90x          - Install Sametime VMGR Server"
  echo "  install_"$REP_PREFIX"mcu90x           - Install Sametime MCU Server"
  echo "  install_"$REP_PREFIX"adv90x           - Install Sametime Advanced Server"
  echo "  install_"$REP_PREFIX"mprx00x          - Install Sametime Proxy Server Externo"
  echo "  install_"$REP_PREFIX"was90x           - Install WAS HTTP Proxy Server"
  echo ""
  echo "  Update Versions"
  echo "    download_installation_manager                - Download IBM Installation Manager"
  echo "    install_installation_manager                 - Install/update IBM Installation Manager"
  echo ""
  echo "    download_was855fixes                         - Download WAS 8.5.5 fixes"
  echo "    update_was855_fixes                 - Install/update IBM Installation Manager"
  echo ""
  echo "  Examples:"
  echo ""
  echo "   $0 install_was85"
  echo "   $0 install_"$REP_PREFIX"console901"
  echo ""
  echo ""
#  echo "# -------- Debug Options --------"
#  echo ""
#  echo "  sanity_check"
#  echo "  tuning_os"
#  echo "  cleanup_deploy "
  return 0
}


###########################################################   Main Script ##############################################################
init_script_environment
get_system_architecture


case "$CMD" in
   sanity_check)
 	sanity_check
   ;;
   sametime_hosts_production)
 	sametime_hosts_production
   ;;
   tuning_os)
        tuning_os_linux_x86
        echo "Voce deve reinicar o SO para que as alteracoes sejam efetivadas"
   ;;
   install_was85)
        echo "IBM WebSphere Application Server ..."
        download_installation_manager
        install_installation_manager
        tuning_installation_manager
        echo "IBM Installation Manager  [Installed]"
        install_was_nd
        echo "IBM WAS 8.5               [Installed]"
        install_was_nd_fixes
        echo "IBM WAS 8.5 Fixes         [Installed]"
   ;;
   install_stconsole901)
        echo "IBM Sametime System Console ..."
        PKG_INSTALLER_URL="$STSC_INSTALLER_URL"
        PKG_FILENAME="SametimeSystemConsole.tgz"
        download_sametime
        STSC_RESPONSE_FILE="responsefiles/install_stconsole901.rsp"
        install_stsc9
        echo "IBM ST 9.0 System Console [Installed]"
   ;;
   install_stpr901)
        echo "IBM Sametime Proxy Server ..."
        PKG_INSTALLER_URL="$STPR_INSTALLER_URL"
        PKG_FILENAME="SametimeProxyServer.tgz"
        STPR_RESPONSE_FILE="responsefiles/install_Xvmlstpr9NN.rsp"
        STPR_DEPNAME="dp_stpr901"
        download_sametime
        echo "IBM ST 9.0 Proxy Server ... Instalando"
        install_stpr9
        echo "IBM ST 9.0 Proxy Server   [Installed]"
   ;;
   install_stpr902)
        echo "IBM Sametime Proxy Server ..."
        PKG_INSTALLER_URL="$STPR_INSTALLER_URL"
        PKG_FILENAME="SametimeProxyServer.tgz"
        STPR_RESPONSE_FILE="responsefiles/install_Xvmlstpr9NN.rsp"
        STPR_DEPNAME="dp_stpr902"
        download_sametime
        echo "IBM ST 9.0 Proxy Server ... Instalando"
        install_stpr9
        echo "IBM ST 9.0 Proxy Server   [Installed]"
   ;;

#   install_stmeetser901)
#        echo "IBM Sametime Meeting Server ..."
#        download_installation_manager
#        install_installation_manager
#        tuning_installation_manager
#        echo "IBM Installation Manager  [Installed]"
#        install_was_nd
#        echo "IBM WAS 8.5               [Installed]"
#        install_was_nd_fixes
#        echo "IBM WAS 8.5 Fixes         [Installed]"
#        STMT_RESPONSE_FILE="responsefiles/install_stmeetser901.rsp"
#        install_stmt9
#        echo "IBM ST 9.0 Meeting Server [Installed]"
#   ;;
   install_stsip901)
        echo "IBM Sametime SIP Server ..."
        PKG_INSTALLER_URL="$STMM_INSTALLER_URL"
        PKG_FILENAME="SametimeMediaManager.tgz"
        PKG_RESPONSE_FILE="responsefiles/install_Xvmlstsip9NN.rsp"
        SAMETIME_DEPNAME="dp_stsip901"
        download_sametime
        install_stmm9

   ;;
   install_stsip902)
        echo "IBM Sametime SIP Server ..."
        PKG_INSTALLER_URL="$STMM_INSTALLER_URL"
        PKG_FILENAME="SametimeMediaManager.tgz"
        PKG_RESPONSE_FILE="responsefiles/install_Xvmlstsip9NN.rsp"
        SAMETIME_DEPNAME="dp_stsip901"
        download_sametime
        install_stmm9

   ;;
   install_stsip903)
        echo "IBM Sametime SIP Server ..."
        PKG_INSTALLER_URL="$STMM_INSTALLER_URL"
        PKG_FILENAME="SametimeMediaManager.tgz"
        PKG_RESPONSE_FILE="responsefiles/install_Xvmlstsip9NN.rsp"
        SAMETIME_DEPNAME="dp_stsip903"
        download_sametime
        install_stmm9

   ;;
   install_stsip904)
        echo "IBM Sametime SIP Server ..."
        PKG_INSTALLER_URL="$STMM_INSTALLER_URL"
        PKG_FILENAME="SametimeMediaManager.tgz"
        PKG_RESPONSE_FILE="responsefiles/install_Xvmlstsip9NN.rsp"
        SAMETIME_DEPNAME="dp_stsip904"
        download_sametime
        install_stmm9

   ;;
   install_stvmgr901)
        echo "IBM Sametime VMGR Server ..."
        PKG_INSTALLER_URL="$STMM_INSTALLER_URL"
        PKG_FILENAME="SametimeMediaManager.tgz"
        PKG_RESPONSE_FILE="responsefiles/install_Xvmlstsip9NN.rsp"
        SAMETIME_DEPNAME="dp_stvmgr901"
        download_sametime
        install_stmm9
        echo "IBM ST 9.0 VMGR Server    [Installed]"
   ;;
   install_stvmgr902)
        echo "IBM Sametime VMGR Server ..."
        PKG_INSTALLER_URL="$STMM_INSTALLER_URL"
        PKG_FILENAME="SametimeMediaManager.tgz"
        PKG_RESPONSE_FILE="responsefiles/install_Xvmlstsip9NN.rsp"
        SAMETIME_DEPNAME="dp_stvmgr902"
        download_sametime
        install_stmm9
        echo "IBM ST 9.0 VMGR Server    [Installed]"
   ;;
   install_stmcu901)
        echo "IBM Sametime MCU Server ..."
        MCU_DEPNAME="dp_stmcu901"
        MCU_HOSTNAME="stmcu901.company.com"
        install_stmcu9
        echo "IBM ST 9.0 VMCU Server    [Installed]"
   ;;
   install_stmcu902)
        echo "IBM Sametime MCU Server ..."
        MCU_DEPNAME="dp_stmcu902"
        MCU_HOSTNAME="stmcu902.company.com"
        install_stmcu9
        echo "IBM ST 9.0 VMCU Server    [Installed]"
   ;;
   install_stcomser901)
        echo "IBM Sametime Community Server ..."
        SAMETIME_DEPNAME="dp_stcomser901"
        STCO_HOSTNAME="stcomser901.company.com"
        install_stcom9
        echo "IBM ST 9.0 Community Svr  [Installed]"
   ;;
   install_stcomser902)
        echo "IBM Sametime Community Server ..."
        SAMETIME_DEPNAME="dp_stcomser902"
        STCO_HOSTNAME="stcomser902.company.com"
        install_stcom9
        echo "IBM ST 9.0 Community Svr  [Installed]"
   ;;

   install_stadv901)
        echo "IBM Sametime Advanced ..."
        STADV_DEPNAME="dp_stadv901"
        STADV_HOSTNAME="stadv901.company.com"
        download_stadv9
        echo "IBM ST 9.0 Advanced Server    [Download]"
        install_stadv9
        echo "IBM ST 9.0 Advanced Server    [Installed]"
   ;;
   install_stwas901)
#        DP_NODENAME="stwas901Node"
#        DP_HOSTNAME="stwas901.company.com"
#        st_configure_node_profile
#        echo "WAS Profile             [Configured]"
        echo "IBM WAS HTTP Proxy Server ..."
        PKG_INSTALLER_URL="$ST_MTPROXY_INSTALLER_URL"
        PKG_FILENAME="SametimeMeetingServer.zip"
        PKG_RESPONSE_FILE="responsefiles/install_Xvmlstwas9NN.rsp"
        SAMETIME_DEPNAME="dp_stwas901"
        download_sametime
        install_st_mtproxy9
   ;;
   install_stwas902)
        echo "IBM WAS HTTP Proxy Server ..."
        PKG_INSTALLER_URL="$ST_MTPROXY_INSTALLER_URL"
        PKG_FILENAME="SametimeMeetingServer.zip"
        PKG_RESPONSE_FILE="responsefiles/install_Xvmlstwas9NN.rsp"
        SAMETIME_DEPNAME="dp_stwas902"
        download_sametime
        install_st_mtproxy9
   ;;

   install_domino9)
        echo "IBM Domino Server ..."
        install_domino9
        echo "IBM Domino 9.0 Server     [Installed]"
        install_domino9_fixes
        echo "IBM Domino 9.0 Fixes      [Installed]"
   ;;


   download_installation_manager)
        download_installation_manager
        install_installation_manager
# -------- Debug Options --------
   cleanup_deploy)
        cleanup_deploy
   ;;
   *)
        show_usage
        exit 1
   ;;
esac
exit 0
