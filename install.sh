#!/bin/bash
# Author: Jrohy
# Github: https://github.com/Jrohy/python3-install

INSTALL_VERSION=""

OPENSSL_VERSION="1.1.1d"

LATEST=0

NO_PIP=0

ORIGIN_PATH=$(pwd)

# cancel centos alias
[[ -f /etc/redhat-release ]] && unalias -a

#######color code########
RED="31m"
GREEN="32m"
YELLOW="33m"
BLUE="36m"
FUCHSIA="35m"

colorEcho(){
    COLOR=$1
    echo -e "\033[${COLOR}${@:2}\033[0m"
}

#######get params#########
while [[ $# > 0 ]];do
    KEY="$1"
    case $KEY in
        --nopip)
        NO_PIP=1
        colorEcho $BLUE "only install python3..\n"
        ;;
        --latest)
        LATEST=1
        ;;
        -v|--version)
        INSTALL_VERSION="$2"
        echo -e "prepare install python $(colorEcho ${BLUE} $INSTALL_VERSION)..\n"
        shift
        ;;
        *)
                # unknown option
        ;;
    esac
    shift # past argument or value
done
#############################

checkSys() {
    # check root user
    [ $(id -u) != "0" ] && { colorEcho ${RED} "Error: You must be root to run this script"; exit 1; }

    # check os
    if [[ -e /etc/redhat-release ]];then
        if [[ $(cat /etc/redhat-release | grep Fedora) ]];then
            OS='Fedora'
            PACKAGE_MANAGER='dnf'
        elif [[ $(cat /etc/redhat-release |grep "CentOS Linux release 8") ]];then
            OS='CentOS8'
            PACKAGE_MANAGER='dnf'
        else
            OS='CentOS'
            PACKAGE_MANAGER='yum'
        fi
    elif [[ $(cat /etc/issue | grep Debian) ]];then
        OS='Debian'
        PACKAGE_MANAGER='apt-get'
    elif [[ $(cat /etc/issue | grep Ubuntu) ]];then
        OS='Ubuntu'
        PACKAGE_MANAGER='apt-get'
    elif [[ $(cat /etc/issue | grep Raspbian) ]];then
        OS='Raspbian'
        PACKAGE_MANAGER='apt-get'
    else
        colorEcho ${RED} "Not support OS, Please reinstall OS and retry!"
        exit 1
    fi
}

commonDependent(){
    [[ $PACKAGE_MANAGER == 'apt-get' ]] && ${PACKAGE_MANAGER} update -y
    ${PACKAGE_MANAGER} install wget -y
}

compileDependent(){
    if [[ ${OS} =~ 'CentOS' || ${OS} == 'Fedora' ]];then
        ${PACKAGE_MANAGER} groupinstall -y "Development tools"
        ${PACKAGE_MANAGER} install -y tk-devel xz-devel gdbm-devel sqlite-devel bzip2-devel readline-devel zlib-devel openssl-devel libffi-devel
    else
        ${PACKAGE_MANAGER} install -y build-essential
        ${PACKAGE_MANAGER} install -y uuid-dev tk-dev liblzma-dev libgdbm-dev libsqlite3-dev libbz2-dev libreadline-dev zlib1g-dev libncursesw5-dev libssl-dev libffi-dev
    fi
}

downloadPackage(){
    cd $ORIGIN_PATH
    [[ $LATEST == 1 ]] && INSTALL_VERSION=`curl -s https://www.python.org/|grep "downloads/release/"|egrep -o "Python [[:digit:]]+\.[[:digit:]]+\.[[:digit:]]"|sed s/"Python "//g`
    wget https://www.python.org/ftp/python/$INSTALL_VERSION/Python-$INSTALL_VERSION.tgz
    if [[ $? != 0 ]];then
        colorEcho ${RED} "Fail download Python-$INSTALL_VERSION.tgz version python!"
        exit 1
    fi
    tar xzvf Python-$INSTALL_VERSION.tgz
    cd Python-$INSTALL_VERSION
}

updateOpenSSL(){
    cd $ORIGIN_PATH
    local VERSION=$1
    wget https://www.openssl.org/source/openssl-$VERSION.tar.gz
    tar xzvf openssl-$VERSION.tar.gz
    cd openssl-$VERSION
    ./config --prefix=/usr/local/openssl shared zlib
    make && make install
    mv -f /usr/bin/openssl /usr/bin/openssl.old
    mv -f /usr/include/openssl /usr/include/openssl.old
    ln -s /usr/local/openssl/bin/openssl /usr/bin/openssl
    ln -s /usr/local/openssl/include/openssl /usr/include/openssl
    echo "/usr/local/openssl/lib">>/etc/ld.so.conf
    ldconfig

    cd $ORIGIN_PATH && rm -rf openssl-$VERSION*
}

# compile install python3
compileInstall(){
    compileDependent

    LOCAL_SSL_VERSION=$(openssl version|awk '{print $2}'|tr -cd '[0-9]')

    if [ $LOCAL_SSL_VERSION -gt 101 ];then
        downloadPackage
        ./configure
        make && make install
    else
        updateOpenSSL $OPENSSL_VERSION
        echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/openssl/lib" >> $HOME/.bashrc
        source $HOME/.bashrc
        downloadPackage
        ./configure --with-openssl=/usr/local/openssl
        make && make install
    fi

    cd $ORIGIN_PATH && rm -rf Python-$INSTALL_VERSION*
}

#online install python3
webInstall(){
    if [[ ${OS} =~ 'CentOS' || ${OS} == 'Fedora' ]];then
        if ! type python3 >/dev/null 2>&1;then
            if [[ ${OS} == 'CentOS' ]];then
                ${PACKAGE_MANAGER} install epel-release -y
                ${PACKAGE_MANAGER} install https://centos7.iuscommunity.org/ius-release.rpm -y
                ${PACKAGE_MANAGER} install python36u -y
                [[ ! -e /bin/python3 ]] && ln -s /bin/python3.6 /bin/python3
            elif [[ ${OS} == 'CentOS8' ]];then
                ${PACKAGE_MANAGER} install python3 -y
            fi
        fi
    else
        if ! type python3 >/dev/null 2>&1;then
            ${PACKAGE_MANAGER} install python3 -y
        fi
        ${PACKAGE_MANAGER} install python3-distutils -y >/dev/null 2>&1
    fi
}

main(){
    checkSys

    commonDependent
    
    if [[ $LATEST == 1 || $INSTALL_VERSION ]];then
        compileInstall
    else
        webInstall
    fi
    # install latest pip
    [[ $NO_PIP == 0 ]] && python3 <(curl -sL https://bootstrap.pypa.io/get-pip.py)
}

main