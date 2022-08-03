#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

public_file=/www/server/panel/install/public.sh
public_file_Check=$(cat ${public_file} 2>/dev/null)

NODE_URL='http://download.bt.cn';
download_Url=$NODE_URL

mkdir -p /www/server
run_path="/root"
Is_64bit=`getconf LONG_BIT`
Centos6Check=$(cat /etc/redhat-release|grep ' 6.'|grep -i centos)
Centos7Check=$(cat /etc/redhat-release|grep ' 7.'|grep -i centos)
Centos8Check=$(cat /etc/redhat-release|grep ' 8.'|grep -i centos)
CentosStream8Check=$(cat /etc/redhat-release |grep -i "Centos Stream"|grep 8)
sysType=$(uname -a|grep x86_64)

opensslVersion="1.0.2r"
curlVersion="7.70.0"
freetypeVersion="2.9.1"
pcreVersion="8.43"

if [ -f "/etc/redhat-release" ] && [ $(cat /etc/os-release|grep PLATFORM_ID|grep -oE "el8|an8") ];then
	rpm_path="centos8"
fi

if [ "${Centos8Check}" ] || [ "${CentosStream8Check}" ]; then
	rpm_path="centos8"
elif [ "${Centos7Check}" ]; then
	rpm_path="centos7"
elif [ "${Centos6Check}" ]; then
	rpm_path="centos6"
fi

if [ -z "${rpm_path}" ] || [ "${Is_64bit}" == "32" ] || [ -z "${sysType}" ]; then
	wget -O lib.sh ${download_Url}/install/0/lib.sh && sh lib.sh
	exit;
fi

Install_Sendmail()
{ 
	yum install postfix mysql-libs -y
	if [ "${centos_version}" != '' ];then
		systemctl start postfix
		systemctl enable postfix	
	else
		service postfix start
		chkconfig --level 2345 postfix on
	fi
}

Install_Curl()
{
	if [ ! -f "/usr/local/curl/bin/curl" ];then
		wget ${download_Url}/rpm/${rpm_path}/${Is_64bit}/bt-curl-${curlVersion}.rpm
		yum install bt-curl-${curlVersion}.rpm -y
		rm -f bt-curl-${curlVersion}.rpm
	fi
}

Install_Openssl()
{
	if [ ! -f "/usr/local/openssl/bin/openssl" ];then
		wget ${download_Url}/rpm/${rpm_path}/${Is_64bit}/bt-openssl102.rpm
		yum install bt-openssl102.rpm -y
		rm -f bt-openssl102.rpm
	fi	
}
Install_Pcre(){
	Cur_Pcre_Ver=`pcre-config --version|grep '^8.' 2>&1`
	if [ "$Cur_Pcre_Ver" == "" ];then
		wget -O pcre-${pcreVersion}.tar.gz ${download_Url}/src/pcre-${pcreVersion}.tar.gz -T 5
		tar zxf pcre-${pcreVersion}.tar.gz
		rm -f pcre-${pcreVersion}.tar.gz
		cd pcre-${pcreVersion}
		if [ "$Is_64bit" == "64" ];then
			./configure --prefix=/usr --docdir=/usr/share/doc/pcre-${pcreVersion} --libdir=/usr/lib64 --enable-unicode-properties --enable-pcre16 --enable-pcre32 --enable-pcregrep-libz --enable-pcregrep-libbz2 --enable-pcretest-libreadline --disable-static --enable-utf8  
		else
			./configure --prefix=/usr --docdir=/usr/share/doc/pcre-${pcreVersion} --enable-unicode-properties --enable-pcre16 --enable-pcre32 --enable-pcregrep-libz --enable-pcregrep-libbz2 --enable-pcretest-libreadline --disable-static --enable-utf8
		fi
		make -j${cpuCore}
		make install
		cd ..
		rm -rf pcre-${pcreVersion}
	fi
}
Install_Libiconv()
{
	if [ -d '/usr/local/libiconv' ];then
		return
	fi
	cd ${run_path}
	if [ ! -f "libiconv-1.14.tar.gz" ];then
		wget -O libiconv-1.14.tar.gz ${download_Url}/src/libiconv-1.14.tar.gz -T 5
	fi
	mkdir /patch
	wget -O /patch/libiconv-glibc-2.16.patch ${download_Url}/src/patch/libiconv-glibc-2.16.patch -T 5
	tar zxf libiconv-1.14.tar.gz
	cd libiconv-1.14
    patch -p0 < /patch/libiconv-glibc-2.16.patch
    ./configure --prefix=/usr/local/libiconv --enable-static
    make -j${cpuCore}
    make install
    cd ${run_path}
    rm -rf libiconv-1.14
	rm -f libiconv-1.14.tar.gz
	echo -e "Install_Libiconv" >> /www/server/lib.pl
}
Install_Libmcrypt()
{
	if [ -f '/usr/local/lib/libmcrypt.so' ];then
		return;
	fi
	cd ${run_path}
	wget ${download_Url}/rpm/${rpm_path}/${Is_64bit}/bt-libmcrypt-2.5.8.rpm
	rpm -ivh bt-libmcrypt-2.5.8.rpm --force --nodeps
	rm -f bt-libmcrypt-2.5.8.rpm
	ln -s /usr/local/lib/libltdl.so.3 /usr/lib/libltdl.so.3
	echo -e "Install_Libmcrypt" >> /www/server/lib.pl
}
Install_Mcrypt()
{
	if [ -f '/usr/bin/mcrypt' ] || [ -f '/usr/local/bin/mcrypt' ];then
		return;
	fi
	cd ${run_path}
	wget ${download_Url}/rpm/${rpm_path}/${Is_64bit}/bt-mcrypt-2.6.8.rpm 
	rpm -ivh bt-mcrypt-2.6.8.rpm --force --nodeps 
	rm -f bt-mcrypt-2.6.8.rpm
	echo -e "Install_Mcrypt" >> /www/server/lib.pl
}
Install_Mhash()
{
	if [ -f '/usr/local/lib/libmhash.so' ];then
		return;
	fi
	cd ${run_path}
	if [ ! -f "mhash-0.9.9.9.rpm" ];then
		wget ${download_Url}/rpm/${rpm_path}/${Is_64bit}/bt-mhash-0.9.9.9.rpm
	fi
	rpm -ivh bt-mhash-0.9.9.9.rpm --force --nodeps
	rm -f bt-mhash-0.9.9.9.rpm
	echo -e "Install_Mhash" >> /www/server/lib.pl
}

Install_Yumlib(){
	sed -i "s#SELINUX=enforcing#SELINUX=disabled#" /etc/selinux/config
	rpm -e --nodeps mariadb-libs-*
	
	if [ "${rpm_path}" == "centos8" ];then
		yum config-manager --set-enabled PowerTools
		yum config-manager --set-enabled powertools
	fi
	Maipo7Check=$(cat /etc/redhat-release|grep ' 7.')
	OracleLinuxCheck=$(cat /etc/os-release|grep "Oracle Linux")
	if [ "${Maipo7Check}" ] && [ "${OracleLinuxCheck}" ];then
		yum-config-manager --enable ol7_developer_EPEL	
	fi

	mv /etc/yum.repos.d/epel.repo /etc/yum.repos.d/epel.repo.backup
	rm -f /var/run/yum.pid
	Packs="make cmake gcc gcc-c++ gcc-g77 flex bison file libtool libtool-libs autoconf kernel-devel patch wget libjpeg libjpeg-devel libpng libpng-devel libpng10 libpng10-devel gd gd-devel libxml2 libxml2-devel zlib zlib-devel glib2 glib2-devel tar bzip2 bzip2-devel libevent libevent-devel ncurses ncurses-devel curl curl-devel libcurl libcurl-devel e2fsprogs e2fsprogs-devel krb5 krb5-devel libidn libidn-devel openssl openssl-devel vim-minimal gettext gettext-devel ncurses-devel gmp-devel pspell-devel libcap diffutils ca-certificates net-tools libc-client-devel psmisc libXpm-devel c-ares-devel libicu-devel libxslt libxslt-devel zip unzip glibc.i686 libstdc++.so.6 cairo-devel bison-devel ncurses-devel libaio-devel perl perl-devel perl-Data-Dumper lsof pcre pcre-devel vixie-cron crontabs expat-devel readline-devel oniguruma-devel libwebp-devel libvpx-devel"
	yum install ${Packs} -y
	for yumPack in ${Packs};
	do
		rpmPack=$(rpm -q ${yumPack})
		packCheck=$(echo $rpmPack|grep not)
		if [ "${packCheck}" ]; then
			yum install ${yumPack} -y
		fi
	done
	mv /etc/yum.repos.d/epel.repo.backup /etc/yum.repos.d/epel.repo
	yum install epel-release -y
	echo "true" > /etc/bt_lib.lock
}
Install_Lib()
{
	if [ -f "/www/server/nginx/sbin/nginx" ] || [ -f "/www/server/apache/bin/httpd" ] || [ -f "/www/server/mysql/bin/mysql" ]; then
		return
	fi
	lockFile="/etc/bt_lib.lock"
	if [ -f "${lockFile}" ]; then
		return
	fi
	Install_Yumlib
	Install_Sendmail
	Run_User="www"
	groupadd ${Run_User}
	useradd -s /sbin/nologin -g ${Run_User} ${Run_User}

}

Install_Lib
Install_Openssl
Install_Pcre
Install_Curl
Install_Mhash
Install_Libmcrypt
Install_Mcrypt	
Install_Libiconv

