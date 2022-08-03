#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
LANG=en_US.UTF-8

public_file=/www/server/panel/install/public.sh

NODE_URL='http://download.bt.cn';
download_Url=$NODE_URL

Root_Path=`cat /var/bt_setupPath.conf`
Setup_Path=$Root_Path/server/apache
run_path='/root'
apache_24='2.4.52'
apache_22_version='2.2.34'
opensslVersion="1.1.1k"
nghttp2Version="1.41.0"
aprVersion="1.6.5"
aprutilVersion="1.6.1"
Centos8Check=$(cat /etc/redhat-release | grep ' 8.' | grep -iE 'centos|Red Hat')
CentosStream8Check=$(cat /etc/redhat-release |grep -i "Centos Stream"|grep 8)

OPENSSL_111_CHECK=$(openssl version|grep 1.1.1)
if [ -z "${OPENSSL_111_CHECK}" ] || [ -f "/usr/local/openssl111/bin/openssl" ];then	
	ENABLE_SSL_PATH="--with-ssl=/usr/local/openssl111"
fi

if [ "${PM}" == "yum" ];then
	ENABLE_HTTP2_PATH="--with-nghttp2=/usr/local/nghttp2"
fi

if [ -z "${cpuCore}" ]; then
	cpuCore="1"
fi

loongarch64Check=$(uname -a|grep loongarch64)
if [ "${loongarch64Check}" ];then
        CONFIGURE_BUILD_TYPE="--build=arm-linux"
fi

System_Lib(){
	if [ "${PM}" == "yum" ] || [ "${PM}" == "dnf" ] ; then
		Pack="gcc gcc-c++ lua lua-devel"
		${PM} install ${Pack} -y
		sleep 1
		pkg-config lua --cflags
		if [ $? -eq 0 ];then
			ENABLE_LUA="--enable-lua"
		fi
	elif [ "${PM}" == "apt-get" ]; then
		Pack="gcc g++ lua5.1 lua5.1-dev lua-cjson lua-socket libnghttp2-dev"
		${PM} install ${Pack} -y
		ENABLE_LUA="--enable-lua"
	fi
}
Service_Add(){
	if [ "${PM}" == "yum" ] || [ "${PM}" == "dnf" ]; then
		chkconfig --add httpd
		chkconfig --level 2345 httpd on
	elif [ "${PM}" == "apt-get" ]; then
		update-rc.d httpd defaults
	fi 
}
Service_Del(){
	if [ "${PM}" == "yum" ] || [ "${PM}" == "dnf" ]; then
		chkconfig --del httpd
		chkconfig --level 2345 httpd off
	elif [ "${PM}" == "apt-get" ]; then
		update-rc.d httpd remove
	fi
}

Mpm_Opt(){
	MemInfo=$(free -g |grep Mem |awk '{print $2}')
	ServerLimit=$((400*(1+${MemInfo})))
	if [ "${ServerLimit}" -gt "20000" ]; then
		ServerLimit="20000"
	fi
	echo "ServerLimit" ${ServerLimit} >> ${Setup_Path}/conf/httpd.conf
	wget -O ${Setup_Path}/conf/extra/httpd-mpm.conf ${download_Url}/conf/httpd-mpm.conf
	sed -i 's/$work/'${ServerLimit}'/g' ${Setup_Path}/conf/extra/httpd-mpm.conf 
}
Install_OpenSSL(){
	opensslCheck=$(/usr/local/openssl111/bin/openssl version|grep 1.1.1)
	if [ -z "${opensslCheck}" ]; then
		cd ${run_path}
		wget ${download_Url}/src/openssl-${opensslVersion}.tar.gz -T 20
		tar -zxf openssl-${opensslVersion}.tar.gz
		rm -f openssl-${opensslVersion}.tar.gz
		cd openssl-${opensslVersion}
		./config --prefix=/usr/local/openssl111 zlib-dynamic ${CONFIGURE_BUILD_TYPE}
		make -j${cpuCore}
		make install
		echo "/usr/local/openssl111/lib" >> /etc/ld.so.conf.d/openssl111.conf
		ldconfig
		cd ..
		rm -rf openssl-${opensslVersion} 
	fi
}
Install_Nghttp2(){
	if [ ! -f "/usr/local/nghttp2/lib/libnghttp2.so" ];then
		wget ${download_Url}/src/nghttp2-${nghttp2Version}.tar.gz
		tar -zxf nghttp2-${nghttp2Version}.tar.gz
		cd nghttp2-${nghttp2Version}
		if [ "${ENABLE_SSL_PATH}" ];then
			export CFLAGS='-I/usr/local/openssl111/include' LIBS='-L/usr/local/openssl111/lib'
		fi
		./configure --prefix=/usr/local/nghttp2 ${CONFIGURE_BUILD_TYPE}
		make -j${cpuCore}
		make install
		cd ..
		rm -rf nghttp2-${nghttp2Version}*

	fi
}
Install_cjson()
{
	if [ ! -f /usr/local/lib/lua/5.1/cjson.so ];then
		wget -O lua-cjson-2.1.0.tar.gz $download_Url/install/src/lua-cjson-2.1.0.tar.gz -T 20
		tar xvf lua-cjson-2.1.0.tar.gz
		rm -f lua-cjson-2.1.0.tar.gz
		cd lua-cjson-2.1.0
		make -j${cpuCore}
		make install
		cd ..
		rm -rf lua-cjson-2.1.0
	fi

	if [ -f /usr/local/lib/lua/5.1/cjson.so ];then
		if [ -d "/usr/lib64/lua/5.1" ];then
			ln -sf /usr/local/lib/lua/5.1/cjson.so /usr/lib64/lua/5.1/cjson.so 
		fi
		if [ -d "/usr/lib/lua/5.1" ];then
			ln -sf /usr/local/lib/lua/5.1/cjson.so /usr/lib/lua/5.1/cjson.so 
		fi
	fi
}
SSL_Check(){
	sslOn=$(cat /www/server/panel/vhost/apache/*.conf|grep "SSLEngine On")
	if [ "${sslOn}" != "" ]; then
		sed -i '/Listen 80/a\Listen 443' ${Setup_Path}/conf/httpd.conf
	fi
}

CheckPHPVersion()
{
	PHPVersion=""
	for phpVer in 52 53 54 55 56 70 71 72 73 74 80;
	do
		if [ -d "/www/server/php/${phpVer}/bin" ]; then
			PHPVersion=${phpVer}
		fi
	done
	if [ "${PHPVersion}" != '' ];then
		sed -i "s#VERSION#$PHPVersion#" ${Setup_Path}/conf/extra/httpd-vhosts.conf
	fi
}

Install_Apache_24()
{
	System_Lib
	Install_cjson
	cd ${run_path}

	Run_User="www"
	wwwUser=$(cat /etc/passwd|grep www)
	if [ -z "${wwwUser}" ];then
		groupadd ${Run_User}
		useradd -s /sbin/nologin -g ${Run_User} ${Run_User}
	fi
	
	if [ "${actionType}" = "install" ]; then
		Uninstall_Apache
		mkdir -p ${Setup_Path}
		rm -rf ${Setup_Path}/*
		rm -f /etc/init.d/httpd
	fi

	cd ${Setup_Path}
	[ -d "src" ] && rm -rf src
	if [ ! -f "${Setup_Path}/src.tar.gz" ];then
		wget -O ${Setup_Path}/src.tar.gz ${download_Url}/src/httpd-${apache_24}.tar.gz -T20
	fi
	tar -zxvf src.tar.gz
	rm -f src.tar.gz
	mv httpd-${apache_24} src
	cd src/srclib
	wget ${download_Url}/src/apr-${aprVersion}.tar.gz
	wget ${download_Url}/src/apr-util-${aprutilVersion}.tar.gz
	
	tar zxf apr-${aprVersion}.tar.gz
	tar zxf apr-util-${aprutilVersion}.tar.gz
	mv apr-${aprVersion} apr
	mv apr-util-${aprutilVersion} apr-util
	cd ..

	name=apache
	i_path=/www/server/panel/install/$name

	i_args=$(cat $i_path/config.pl|xargs)
	i_make_args=""
	for i_name in $i_args
	do
		init_file=$i_path/$i_name/init.sh
		if [ -f $init_file ];then
			bash $init_file
		fi
		args_file=$i_path/$i_name/args.pl
		if [ -f $args_file ];then
			args_string=$(cat $args_file)
			i_make_args="$i_make_args $args_string"
		fi
	done

	cd ${Setup_Path}/src
	./configure --prefix=${Setup_Path} --enable-mods-shared=most --enable-headers --enable-mime-magic --enable-proxy --enable-so --enable-rewrite --enable-ssl --enable-deflate --with-pcre --with-included-apr --with-apr-util --enable-mpms-shared=all --enable-nonportable-atomics=yes --enable-remoteip --enable-http2 ${ENABLE_HTTP2_PATH} ${ENABLE_SSL_PATH} ${ENABLE_LUA} ${i_make_args} ${CONFIGURE_BUILD_TYPE}
	make -j${cpuCore}

	if [ "${actionType}" = "update" ]; then
		/etc/init.d/httpd stop
		make install
		sleep 1
		echo "done"
		/etc/init.d/httpd start
		rm -f /www/server/apache/version_check.pl
		rm -rf ${Setup_Path}/src
		exit
	fi

	make install
	
	if [ ! -f "${Setup_Path}/bin/httpd" ];then
		echo '========================================================'
		GetSysInfo
		echo -e "ERROR: apache-${apache_24} installation failed.";
		rm -rf ${Setup_Path}
		exit 0;
	fi

	ln -sf ${Setup_Path}/bin/httpd /usr/bin/httpd
	ln -sf ${Setup_Path}/bin/ab /usr/bin/ab

	mkdir ${Setup_Path}/conf/vhost
	mkdir -p $Root_Path/wwwroot/default
	mkdir -p $Root_Path/wwwlogs
	mkdir -p $Root_Path/server/phpmyadmin
	chmod -R 755 ${Setup_Path}/conf/vhost
	chmod -R 755 $Root_Path/wwwroot/default
	chown -R www.www $Root_Path/wwwroot/default

	mv ${Setup_Path}/conf/httpd.conf ${Setup_Path}/conf/httpd.conf.bak

	wget -O ${Setup_Path}/conf/httpd.conf ${download_Url}/conf/httpd24.conf
	wget -O ${Setup_Path}/conf/extra/httpd-vhosts.conf ${download_Url}/conf/httpd-vhosts.conf
	wget -O ${Setup_Path}/conf/extra/httpd-default.conf ${download_Url}/conf/httpd-default.conf
	wget -O ${Setup_Path}/conf/extra/mod_remoteip.conf ${download_Url}/conf/mod_remoteip.conf

	Mpm_Opt

	sed -i "s#/www/wwwroot/default#/www/server/phpmyadmin#" ${Setup_Path}/conf/extra/httpd-vhosts.conf
	sed -i "s#IncludeOptional conf/vhost/\*\.conf#IncludeOptional /www/server/panel/vhost/apache/\*\.conf#" ${Setup_Path}/conf/httpd.conf
	sed -i '/LoadModule mpm_prefork_module modules\/mod_mpm_prefork.so/s/^/#/' ${Setup_Path}/conf/httpd.conf
	sed -i '/#LoadModule mpm_event_module modules\/mod_mpm_event.so/s/^#//' ${Setup_Path}/conf/httpd.conf

	SSL_Check
	CheckPHPVersion
	
	wget -O ${Setup_Path}/htdocs/index.html ${download_Url}/error/index.html -T20

	AA_PANEL_CHECK=$(cat /www/server/panel/config/config.json|grep "English")
	if [ "${AA_PANEL_CHECK}" ];then
		\cp -rf /www/server/panel/data/empty.html /www/server/apache/htdocs/index.html
		chmod 644 /www/server/apache/htdocs/index.html
		wget -O /www/server/panel/vhost/apache/0.default.conf ${download_Url}/conf/apache/en.0.default.conf
	fi
	wget -O /etc/init.d/httpd ${download_Url}/init/init.d.httpd -T20
	chmod +x /etc/init.d/httpd

	Service_Add
	
	mkdir -p /www/server/phpinfo
	/etc/init.d/httpd start
	
	cd ${Setup_Path}
	
	echo "2.4" > ${Setup_Path}/version.pl
	rm -f /www/server/panel/vhost/apache/phpinfo.conf
	rm -rf ${Setup_Path}/src
}

Install_Apache_22()
{
	Uninstall_Apache
	cd ${run_path}
	Run_User="www"
	groupadd ${Run_User}
	useradd -s /sbin/nologin -g ${Run_User} ${Run_User}
	
	mkdir -p ${Setup_Path}
	rm -rf ${Setup_Path}/*
	rm -f /etc/init.d/httpd
	cd ${Setup_Path}
	if [ ! -f "${Setup_Path}/src.tar.gz" ];then
		wget -O ${Setup_Path}/src.tar.gz ${download_Url}/src/httpd-${apache_22_version}.tar.gz -T20
	fi
	tar -zxvf src.tar.gz
	mv httpd-${apache_22_version} src
	cd src
	./configure --prefix=${Setup_Path} --enable-mods-shared=most --with-ssl=/usr/local/openssl --enable-headers --enable-mime-magic --enable-proxy --enable-so --enable-rewrite --enable-ssl --enable-deflate --enable-suexec --with-included-apr --with-mpm=prefork --with-expat=builtin
	make && make install
		
	if [ ! -f "${Setup_Path}/bin/httpd" ];then
		echo '========================================================'
		GetSysInfo
		echo -e "ERROR: apache-${apache_22_version} installation failed.";
		rm -rf ${Setup_Path}
		exit 0;
	fi

	mv ${Setup_Path}/conf/httpd.conf ${Setup_Path}/conf/httpd.conf.bak

	mkdir -p ${Setup_Path}/conf/vhost
	mkdir -p $Root_Path/wwwroot/default
	mkdir -p $Root_Path/wwwlogs
	chmod -R 755 $Root_Path/wwwroot/default
	chown -R www.www $Root_Path/wwwroot/default

	wget -O ${Setup_Path}/conf/httpd.conf ${download_Url}/conf/httpd22.conf -T20
	wget -O ${Setup_Path}/conf/extra/httpd-vhosts.conf ${download_Url}/conf/httpd-vhosts-22.conf -T20
	wget -O ${Setup_Path}/conf/extra/httpd-default.conf ${download_Url}/conf/httpd-default.conf -T20
	wget -O ${Setup_Path}/conf/extra/mod_remoteip.conf ${download_Url}/conf/mod_remoteip.conf -T20
	sed -i "s#Include conf/vhost/\*\.conf#Include /www/server/panel/vhost/apache/\*\.conf#" ${Setup_Path}/conf/httpd.conf
	sed -i "s#/www/wwwroot/default#/www/server/phpmyadmin#" ${Setup_Path}/conf/extra/httpd-vhosts.conf
	sed -i '/LoadModule php5_module/s/^/#/' ${Setup_Path}/conf/httpd.conf

	
	mkdir ${Setup_Path}/conf/vhost

	wget -O ${Setup_Path}/htdocs/index.html ${download_Url}/error/index.html -T20
	wget -O /etc/init.d/httpd ${download_Url}/init/init.d.httpd -T20
	chmod +x /etc/init.d/httpd
	chkconfig --add httpd
	
	chkconfig --level 2345 httpd on
	ln -sf ${Setup_Path}/bin/httpd /usr/bin/httpd

	cd ${Setup_Path}
	rm -f src.tar.gz
	mkdir -p /www/server/phpinfo
	echo "2.2" > ${Setup_Path}/version.pl
	echo '2.2' > /var/bt_apacheVersion.pl
	cat > /www/server/panel/vhost/apache/phpinfo.conf <<EOF
<VirtualHost *:80>
DocumentRoot "/www/server/phpinfo"
ServerAdmin phpinfo
ServerName 127.0.0.2
<Directory "/www/server/phpinfo">
	SetOutputFilter DEFLATE
	Options FollowSymLinks
	AllowOverride All
	Order allow,deny
	Allow from all
	DirectoryIndex index.php index.html index.htm default.php default.html default.htm
</Directory>
</VirtualHost>
EOF
	if [ -f "/www/server/php/52/libphp5.so" ];then
		\cp -a -r /www/server/php/52/libphp5.so /www/server/apache/modules/libphp5.so
		sed -i '/#LoadModule php5_module/s/^#//' ${Setup_Path}/conf/httpd.conf
	fi
	if [ -f "/www/server/php/53/libphp5.so" ];then
		\cp -a -r /www/server/php/53/libphp5.so /www/server/apache/modules/libphp5.so
		sed -i '/#LoadModule php5_module/s/^#//' ${Setup_Path}/conf/httpd.conf
	fi
	if [ -f "/www/server/php/54/libphp5.so" ];then
		\cp -a -r /www/server/php/54/libphp5.so /www/server/apache/modules/libphp5.so
		sed -i '/#LoadModule php5_module/s/^#//' ${Setup_Path}/conf/httpd.conf
	fi
	
	rm -f /www/server/panel/vhost/apache/btwaf.conf
	rm -f /www/server/panel/vhost/apache/total.conf
	
	if [ -f /www/server/apache/modules/libphp5.so ];then
		/etc/init.d/httpd start
	fi
}
Uninstall_Apache()
{
	if [ -f "/etc/init.d/httpd" ];then
		Service_Del
		/etc/init.d/httpd stop
		rm -f /etc/init.d/httpd
	fi
	pkill -9 httpd
	[ -f "${Setup_Path}/deb.pl" ] && apt-get remove bt-$(cat ${Setup_Path}/deb.pl) -y
	rm -rf ${Setup_Path}
	rm -f /usr/bin/httpd
}

actionType=$1
version=$2

if [ "$actionType" == "install" ] || [ "${actionType}" == "update" ];then
	[ "${ENABLE_SSL_PATH}" ] && Install_OpenSSL
	[ "${ENABLE_HTTP2_PATH}" ] && Install_Nghttp2
	if [ "$version" == "2.2" ];then
		Install_Apache_22
	else
		Install_Apache_24
	fi
elif [ "$actionType" == "uninstall" ];then
	Uninstall_Apache
fi


