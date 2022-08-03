#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

public_file=/www/server/panel/install/public.sh

NODE_URL='http://download.bt.cn';
download_Url=$NODE_URL

Root_Path=`cat /var/bt_setupPath.conf`
Setup_Path=$Root_Path/server/php
php_path=$Root_Path/server/php
mysql_dir=$Root_Path/server/mysql
mysql_config="${mysql_dir}/bin/mysql_config"
Is_64bit=`getconf LONG_BIT`
run_path='/root'
apacheVersion=`cat /var/bt_apacheVersion.pl`

php_55='5.5.38'
php_56='5.6.40'
php_70='7.0.33'
php_71='7.1.33'
php_72='7.2.29'
php_73='7.3.17'
php_74='7.4.5'
opensslVersion="1.0.2r"
curlVersion="7.64.1"

if [ -z "${cpuCore}" ]; then
	cpuCore="1"
fi

Service_Add(){
	if [ "${PM}" == "yum" ] || [ "${PM}" == "dnf" ]; then
		chkconfig --add php-fpm-${php_version}
		chkconfig --level 2345 php-fpm-${php_version} on

	elif [ "${PM}" == "apt-get" ]; then
		update-rc.d php-fpm-${php_version} defaults
	fi 
}
Service_Del(){
	if [ "${PM}" == "yum" ] || [ "${PM}" == "dnf" ]; then
		chkconfig --del php-fpm-${php_version}
		chkconfig --level 2345 php-fpm-${php_version} off
	elif [ "${PM}" == "apt-get" ]; then
		update-rc.d php-fpm-${php_version} remove
	fi
}
Configure_Get(){
	name=php/$php_version
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
}
Install_Openssl()
{
	if [ ! -f "/usr/local/openssl/bin/openssl" ];then
		cd ${run_path}
		wget ${download_Url}/src/openssl-${opensslVersion}.tar.gz
		tar -zxf openssl-${opensslVersion}.tar.gz
		cd openssl-${opensslVersion}
		./config --openssldir=/usr/local/openssl zlib-dynamic shared
		make -j${cpuCore} 
		make install
		echo  "/usr/local/openssl/lib" > /etc/ld.so.conf.d/zopenssl.conf
		ldconfig
		cd ..
		rm -f openssl-${opensslVersion}.tar.gz
		rm -rf openssl-${opensslVersion}
	fi	
}
Install_Curl()
{
	if [ "${PM}" == "yum" ];then
		CURL_OPENSSL_LIB_VERSION=$(/usr/local/curl/bin/curl -V|grep -oE OpenSSL.*[0-9][a-z]|cut -f 2 -d "/")
		OPENSSL_LIB_VERSION=$(/usr/local/openssl/bin/openssl version|awk '{print $2}')
	fi
	if [ ! -f "/usr/local/curl/bin/curl" ] || [ "${CURL_OPENSSL_LIB_VERSION}" != "${OPENSSL_LIB_VERSION}" ];then
		wget ${download_Url}/src/curl-${curlVersion}.tar.gz
		tar -zxf curl-${curlVersion}.tar.gz
		cd curl-${curlVersion}
		rm -rf /usr/local/curl	
		./configure --prefix=/usr/local/curl --enable-ares --without-nss --with-ssl=/usr/local/openssl
		make -j${cpuCore}
		make install
		cd ..
		rm -f curl-${curlVersion}.tar.gz
		rm -rf curl-${curlVersion}
	fi
}
Install_Icu4c(){
	cd ${run_path}
	icu4cVer=$(/usr/bin/icu-config --version)
	if [ ! -f "/usr/bin/icu-config" ] || [ "${icu4cVer:0:2}" -gt "60" ];then
		wget -O icu4c-60_3-src.tgz ${download_Url}/src/icu4c-60_3-src.tgz
		tar -xvf icu4c-60_3-src.tgz
		cd icu/source
		./configure --prefix=/usr/local/icu
		make -j${cpuCore}
		make install
		[ -f "/usr/bin/icu-config" ] && mv /usr/bin/icu-config /usr/bin/icu-config.bak 
		ln -sf /usr/local/icu/bin/icu-config /usr/bin/icu-config
		echo "/usr/local/icu/lib" > /etc/ld.so.conf.d/zicu.conf
		ldconfig
		cd ../../
		rm -rf icu
		rm -f icu4c-60_3-src.tgz 
	fi
}
Install_Libzip(){
	LIBZIP_VER=$(ldconfig -p|grep libzip.so.[3-5])
	if [ -z "${LIBZIP_VER}" ];then
		autoconfVer=$(autoconf -V|grep 'GNU Autoconf'|awk '{print $4}'|grep -oE .[0-9]+|grep -oE [0-9]+)
		if [ "${autoconfVer}" -lt "69" ]; then
			wget ${download_Url}/src/autoconf-2.69.tar.gz
			tar -xvf autoconf-2.69.tar.gz
			cd autoconf-2.69
			./configure --prefix=/usr
			make && make install
			cd ..
			rm -rf autoconf*
		fi
		cd ${run_path}
		libzipVer="1.5.2"
		wget -O libzip-${libzipVer}.tar.gz ${download_Url}/src/libzip-${libzipVer}.tar.gz
		tar -xvf libzip-${libzipVer}.tar.gz
		cd libzip-${libzipVer}
		mkdir build && cd build
		if [ "${PM}" = "yum" ]; then
			yum install cmake3 -y
			cmake3 .. 
		else
			cmake ..
		fi
		make -j${cpuCore}
		make install
		if [ "$Is_64bit" == "64" ];then
			ln -sf /usr/local/lib64/libzip.so /usr/local/lib/libzip.so
			ln -sf /usr/local/lib64/libzip.so.5 /usr/local/lib/libzip.so.5
		fi
		cd ../..
		rm -rf libzip*
		ldconfig
	fi
}
Install_Libsodium(){
	if [ ! -f "/usr/local/libsodium/lib/libsodium.so" ];then
		cd ${run_path}
		libsodiumVer="1.0.18"
		wget ${download_Url}/src/libsodium-${libsodiumVer}-stable.tar.gz
		tar -xvf libsodium-${libsodiumVer}-stable.tar.gz
		rm -f libsodium-${libsodiumVer}-stable.tar.gz
		cd libsodium-stable
		./configure --prefix=/usr/local/libsodium
		make -j${cpuCore}
		make install
		cd ..
		rm -f libsodium-${libsodiumVer}-stable.tar.gz
		rm -rf libsodium-stable
	fi
}
Create_Fpm(){
	cat >${php_setup_path}/etc/php-fpm.conf<<EOF
[global]
pid = ${php_setup_path}/var/run/php-fpm.pid
error_log = ${php_setup_path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi-${php_version}.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0666
user = www
group = www
pm = dynamic
pm.status_path = /phpfpm_${php_version}_status
pm.max_children = 30
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 10
request_terminate_timeout = 100
request_slowlog_timeout = 30
slowlog = var/log/slow.log
EOF
}

Set_PHP_FPM_Opt()
{
	MemTotal=`free -m | grep Mem | awk '{print  $2}'`
	if [[ ${MemTotal} -gt 1024 && ${MemTotal} -le 2048 ]]; then
		sed -i "s#pm.max_children.*#pm.max_children = 50#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.start_servers.*#pm.start_servers = 5#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 5#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 10#" ${php_setup_path}/etc/php-fpm.conf
	elif [[ ${MemTotal} -gt 2048 && ${MemTotal} -le 4096 ]]; then
		sed -i "s#pm.max_children.*#pm.max_children = 80#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.start_servers.*#pm.start_servers = 5#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 5#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 20#" ${php_setup_path}/etc/php-fpm.conf
	elif [[ ${MemTotal} -gt 4096 && ${MemTotal} -le 8192 ]]; then
		sed -i "s#pm.max_children.*#pm.max_children = 150#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.start_servers.*#pm.start_servers = 10#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 10#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 30#" ${php_setup_path}/etc/php-fpm.conf
	elif [[ ${MemTotal} -gt 8192 && ${MemTotal} -le 16384 ]]; then
		sed -i "s#pm.max_children.*#pm.max_children = 200#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.start_servers.*#pm.start_servers = 15#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 15#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 30#" ${php_setup_path}/etc/php-fpm.conf
	elif [[ ${MemTotal} -gt 16384 ]]; then
		sed -i "s#pm.max_children.*#pm.max_children = 300#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.start_servers.*#pm.start_servers = 20#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 20#" ${php_setup_path}/etc/php-fpm.conf
		sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 50#" ${php_setup_path}/etc/php-fpm.conf
	fi
	#backLogValue=$(cat ${php_setup_path}/etc/php-fpm.conf |grep max_children|awk '{print $3*1.5}')
	#sed -i "s#listen.backlog.*#listen.backlog = "${backLogValue}"#" ${php_setup_path}/etc/php-fpm.conf	
	sed -i "s#listen.backlog.*#listen.backlog = 8192#" ${php_setup_path}/etc/php-fpm.conf	
}

Set_Phpini(){
	sed -i 's/post_max_size =.*/post_max_size = 50M/g' ${php_setup_path}/etc/php.ini
	sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${php_setup_path}/etc/php.ini
	sed -i 's/;date.timezone =.*/date.timezone = PRC/g' ${php_setup_path}/etc/php.ini
	sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${php_setup_path}/etc/php.ini
	sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=1/g' ${php_setup_path}/etc/php.ini
	sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${php_setup_path}/etc/php.ini
	sed -i 's/;sendmail_path =.*/sendmail_path = \/usr\/sbin\/sendmail -t -i/g' ${php_setup_path}/etc/php.ini
	sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,putenv,chroot,chgrp,chown,shell_exec,popen,proc_open,pcntl_exec,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,pcntl_alarm,pcntl_fork,pcntl_waitpid,pcntl_wait,pcntl_wifexited,pcntl_wifstopped,pcntl_wifsignaled,pcntl_wifcontinued,pcntl_wexitstatus,pcntl_wtermsig,pcntl_wstopsig,pcntl_signal,pcntl_signal_dispatch,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_getpriority,pcntl_setpriority,imap_open,apache_setenv/g' ${php_setup_path}/etc/php.ini
	sed -i 's/display_errors = Off/display_errors = On/g' ${php_setup_path}/etc/php.ini
	sed -i 's/error_reporting =.*/error_reporting = E_ALL \& \~E_NOTICE/g' ${php_setup_path}/etc/php.ini

	if [ "${php_version}" = "52" ]; then
		sed -i "s#extension_dir = \"./\"#extension_dir = \"${php_setup_path}/lib/php/extensions/no-debug-non-zts-20060613/\"\n#" ${php_setup_path}/etc/php.ini
		sed -i 's#output_buffering =.*#output_buffering = On#' ${php_setup_path}/etc/php.ini
		sed -i 's/; cgi.force_redirect = 1/cgi.force_redirect = 0;/g' ${php_setup_path}/etc/php.ini
		sed -i 's/; cgi.redirect_status_env = ;/cgi.redirect_status_env = "yes";/g' ${php_setup_path}/etc/php.ini
	fi

	if [ "${php_version}" -ge "56" ]; then
		if [ -f "/etc/pki/tls/certs/ca-bundle.crt" ];then
			crtPath="/etc/pki/tls/certs/ca-bundle.crt"
		elif [ -f "/etc/ssl/certs/ca-certificates.crt" ]; then
			crtPath="/etc/ssl/certs/ca-certificates.crt"
		fi
		sed -i "s#;openssl.cafile=#openssl.cafile=${crtPath}#" ${php_setup_path}/etc/php.ini
		sed -i "s#;curl.cainfo =#curl.cainfo = ${crtPath}#" ${php_setup_path}/etc/php.ini
	fi

	sed -i 's/expose_php = On/expose_php = Off/g' ${php_setup_path}/etc/php.ini
	
}

Export_PHP_Autoconf()
{
	export PHP_AUTOCONF=/usr/local/autoconf-2.13/bin/autoconf
	export PHP_AUTOHEADER=/usr/local/autoconf-2.13/bin/autoheader
}

Ln_PHP_Bin()
{
	rm -f /usr/bin/php*
	rm -f /usr/bin/pear
	rm -f /usr/bin/pecl

    ln -sf ${php_setup_path}/bin/php /usr/bin/php
    ln -sf ${php_setup_path}/bin/phpize /usr/bin/phpize
    ln -sf ${php_setup_path}/bin/pear /usr/bin/pear
    ln -sf ${php_setup_path}/bin/pecl /usr/bin/pecl
    ln -sf ${php_setup_path}/sbin/php-fpm /usr/bin/php-fpm
}

Pear_Pecl_Set()
{
    pear config-set php_ini ${php_setup_path}/etc/php.ini
    pecl config-set php_ini ${php_setup_path}/etc/php.ini
}

Install_Composer()
{
	if [ ! -f "/usr/bin/composer" ];then
		wget -O /usr/bin/composer ${download_Url}/install/src/composer.phar -T 20;
		chmod +x /usr/bin/composer
		if [ "${download_Url}" == "http://$CN:5880" ];then
			composer config -g repo.packagist composer https://packagist.phpcomposer.com
		fi
	fi
}

fpmPhpinfo(){
	nginxPhpStatus=$(cat /www/server/panel/vhost/nginx/phpfpm_status.conf |grep 73)
	if [ "${nginxPhpStatus}" == "" ]; then
		rm -f /www/server/panel/vhost/nginx/phpfpm_status.conf
		wget -O /www/server/panel/vhost/nginx/phpfpm_status.conf ${download_Url}/conf/nginx/phpfpm_status.conf
	fi
	nginxPhpinfo=$(cat /www/server/panel/vhost/nginx/phpinfo.conf |grep 73)
	if [ "${nginxPhpinfo}" == "" ]; then
		rm -f /www/server/panel/vhost/nginx/phpinfo.conf
		wget -O /www/server/panel/vhost/nginx/phpinfo.conf ${download_Url}/conf/nginx/phpinfo.conf
	fi
	apachePhpinfo=$(cat /www/server/panel/vhost/apache/phpinfo.conf |grep 73)
	if [ "${apachePhpinfo}" == "" ];then
		rm -f /www/server/panel/vhost/apache/phpinfo.conf
		wget -O /www/server/panel/vhost/apache/phpinfo.conf ${download_Url}/conf/apache/phpinfo.conf

	fi
	apachePhpStatus=$(cat /www/server/apache/conf/extra/httpd-vhosts.conf |grep 73)
	if [ "${apachePhpStatus}" == "" ];then
		rm -f /www/server/apache/conf/extra/httpd-vhosts.conf
		wget -O /www/server/apache/conf/extra/httpd-vhosts.conf ${download_Url}/conf/apache/httpd-vhosts.conf
	fi
}

Uninstall_Zend(){
	sed -i "/zend_optimizer/s/^/;/" /www/server/php/${php_version}/etc/php.ini
	sed -i "/zend_extension/s/^/;/" /www/server/php/${php_version}/etc/php.ini
	sed -i "/zend_loader/s/^/;/" /www/server/php/${php_version}/etc/php.ini
	/etc/init.d/php-fpm-${php_version} restart
}

Install_PHP_52()
{
	if [ "${apacheVersion}" == "2.4" ];then
		rm -rf $Root_Path/server/php/52
		return;
	fi
	cd ${run_path}
	php_version="52"
	php_setup_path=${php_path}/${php_version}
	Export_PHP_Autoconf
	mkdir -p ${php_setup_path}
	rm -rf ${php_setup_path}/*
	cd ${php_setup_path}
	if [ ! -f "${php_setup_path}/src.tar.gz" ];then
		wget -O ${php_setup_path}/src.tar.gz ${download_Url}/src/php-5.2.17.tar.gz -T20
	fi
	tar zxf src.tar.gz
	mv php-5.2.17 src
	rm -rf /patch
	mkdir -p /patch
	if [ "${apacheVersion}" != '2.2' ];then
		wget ${download_Url}/src/php-5.2.17-fpm-0.5.14.diff.gz
		gzip -cd php-5.2.17-fpm-0.5.14.diff.gz | patch -d src -p1
	fi
	
	wget -O /patch/php-5.2.17-max-input-vars.patch ${download_Url}/src/patch/php-5.2.17-max-input-vars.patch -T20
	wget -O /patch/php-5.2.17-xml.patch ${download_Url}/src/patch/php-5.2.17-xml.patch -T20
	wget -O /patch/debian_patches_disable_SSLv2_for_openssl_1_0_0.patch ${download_Url}/src/patch/debian_patches_disable_SSLv2_for_openssl_1_0_0.patch -T20
	wget -O /patch/php-5.2-multipart-form-data.patch ${download_Url}/src/patch/php-5.2-multipart-form-data.patch -T20
	rm -f php-5.2.17-fpm-0.5.14.diff.gz
	cd src/
	patch -p1 < /patch/php-5.2.17-max-input-vars.patch
	patch -p0 < /patch/php-5.2.17-xml.patch
	patch -p1 < /patch/debian_patches_disable_SSLv2_for_openssl_1_0_0.patch
	patch -p1 < /patch/php-5.2-multipart-form-data.patch
	
	ln -s /usr/lib64/libjpeg.so /usr/lib/libjpeg.so
	ln -s /usr/lib64/libpng.so /usr/lib/libpng.so
	
	Configure_Get
	cd ${php_setup_path}/src
	./buildconf --force
	if [ "${apacheVersion}" != '2.2' ];then
		./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --with-mysql=${mysql_dir} --with-pdo-mysql=${mysql_dir} --with-mysqli=$Root_Path/server/mysql/bin/mysql_config --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --enable-discard-path --enable-magic-quotes --enable-safe-mode --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl=/usr/local/curl --enable-mbregex --enable-fastcgi --enable-fpm --enable-force-cgi-redirect --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf --with-openssl=/usr/local/openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext --with-mime-magic --with-iconv=/usr/local/libiconv ${i_make_args}
	else
		./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --with-apxs2=$Root_Path/server/apache/bin/apxs --with-mysql=${mysql_dir} --with-pdo-mysql=${mysql_dir} --with-mysqli=$Root_Path/server/mysql/bin/mysql_config --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --enable-discard-path --enable-magic-quotes --enable-safe-mode --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl=/usr/local/curl --enable-mbregex --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf --with-openssl=/usr/local/openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext --with-mime-magic ${i_make_args}
	fi
	if [ "${Is_64bit}" = "32" ];then
		sed -i 's/lcrypt$/lcrypt -lresolv/' Makefile
    fi
	make ZEND_EXTRA_LIBS='-liconv' -j${cpuCore}
    make install
	
    mkdir -p ${php_setup_path}/etc
    \cp php.ini-dist ${php_setup_path}/etc/php.ini
	
	cd ${php_setup_path}
	if [ ! -f "${php_setup_path}/bin/php" ];then
		echo '========================================================'
		GetSysInfo
		echo -e "ERROR: php-5.2 installation failed.";
		exit 0;
	fi
	
	#安装mysqli
	#cd ${Root_Path}/server/php/52/src/ext/mysqli/
	#${Root_Path}/server/php/52/bin/phpize
	#echo "${now_path}"
	#./configure --with-php-config=${php_setup_path}/bin/php-config  --with-mysqli=$Root_Path/server/mysql/bin/mysql_config
	#make
	#make install
	#cd ${php_setup_path}	

	Ln_PHP_Bin

	# php extensions

	Set_Phpini

	Pear_Pecl_Set
	
	mkdir -p /usr/local/zend/php52
	wget -O /usr/local/zend/php52/ZendOptimizer.so ${download_Url}/src/ZendOptimizer-${Is_64bit}.so -T 20
	
	mysqli='';
	if [ -f ${php_setup_path}/lib/php/extensions/no-debug-non-zts-20060613/mysqli.so ];then
		mysqli="extension=mysqli.so";
	fi

    cat >>${php_setup_path}/etc/php.ini<<EOF
$mysqli
;eaccelerator

;ionCube

[Zend Optimizer]
zend_optimizer.optimization_level=1
zend_extension="/usr/local/zend/php52/ZendOptimizer.so"

;xcache

EOF

	if [ "${apacheVersion}" != '2.2' ];then
		rm -f ${php_setup_path}/etc/php-fpm.conf
		wget -O ${php_setup_path}/etc/php-fpm.conf ${download_Url}/conf/php-fpm5.2.conf -T20
		wget -O /etc/init.d/php-fpm-52 ${download_Url}/init/php_fpm_52.init -T20
		chmod +x /etc/init.d/php-fpm-52

		Service_Add

		service php-fpm-52 start
	else
		if [ ! -f /www/server/php/52/libphp5.so ];then
			\cp -a -r $Root_Path/server/apache/modules/libphp5.so /www/server/php/52/libphp5.so
			sed -i '/#LoadModule php5_module/s/^#//' /www/server/apache/conf/httpd.conf
		fi
		/etc/init.d/httpd restart
	fi
	rm -f ${php_setup_path}/src.tar.gz	
	echo "5.2.17" > ${php_setup_path}/version.pl
}

Install_PHP_53()
{
	cd ${run_path}
	php_version="53"
	/etc/init.d/php-fpm-$php_version stop
	php_setup_path=${php_path}/${php_version}
	mkdir -p ${php_setup_path}
	rm -rf ${php_setup_path}/*
	cd ${php_setup_path}
	if [ ! -f "${php_setup_path}/src.tar.gz" ];then
		wget -O ${php_setup_path}/src.tar.gz ${download_Url}/src/php-5.3.29.tar.gz
	fi
	
	tar zxf src.tar.gz
	mv php-5.3.29 src
	cd src
	
	rm -rf /patch
	mkdir -p /patch
	wget -O /patch/php-5.3-multipart-form-data.patch ${download_Url}/src/patch/php-5.3-multipart-form-data.patch -T20
	patch -p1 < /patch/php-5.3-multipart-form-data.patch

	Configure_Get
	cd ${php_setup_path}/src
	if [ "${apacheVersion}" != '2.2' ];then
		./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --enable-fpm --with-fpm-user=www --with-fpm-group=www --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-magic-quotes --enable-safe-mode --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl=/usr/local/curl --enable-mbregex --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf --with-openssl=/usr/local/openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext --disable-fileinfo ${i_make_args}
	else
		./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --with-apxs2=$Root_Path/server/apache/bin/apxs --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-magic-quotes --enable-safe-mode --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl=/usr/local/curl --enable-mbregex --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf --with-openssl=/usr/local/openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext --disable-fileinfo ${i_make_args}
	fi
	if [ "${Is_64bit}" = "32" ];then
		sed -i 's/lcrypt$/lcrypt -lresolv/' Makefile
	fi
	make ZEND_EXTRA_LIBS='-liconv' -j${cpuCore}
	make install
	
	if [ ! -f "${php_setup_path}/bin/php" ];then
		echo '========================================================'
		GetSysInfo
		echo -e "ERROR: php-5.3 installation failed.";
		exit 0;
	fi

	Ln_PHP_Bin

	echo "Copy new php configure file..."
	mkdir -p ${php_setup_path}/etc
	\cp php.ini-production ${php_setup_path}/etc/php.ini
	
	cd ${run_path}
	# php extensions
	Set_Phpini
	Pear_Pecl_Set
	Install_Composer

	echo "Install ZendGuardLoader for PHP 5.3..."
	mkdir -p /usr/local/zend/php53
	if [ "${Is_64bit}" = "64" ] ; then
		wget ${download_Url}/src/ZendGuardLoader-php-5.3-linux-glibc23-x86_64.tar.gz
		tar zxf ZendGuardLoader-php-5.3-linux-glibc23-x86_64.tar.gz
		\cp ZendGuardLoader-php-5.3-linux-glibc23-x86_64/php-5.3.x/ZendGuardLoader.so /usr/local/zend/php53/
		rm -f ${run_path}/ZendGuardLoader-php-5.3-linux-glibc23-x86_64.tar.gz
		rm -rf ${run_path}/ZendGuardLoader-php-5.3-linux-glibc23-x86_64
	else
		wget ${download_Url}/src/ZendGuardLoader-php-5.3-linux-glibc23-i386.tar.gz
		tar zxf ZendGuardLoader-php-5.3-linux-glibc23-i386.tar.gz
		\cp ZendGuardLoader-php-5.3-linux-glibc23-i386/php-5.3.x/ZendGuardLoader.so /usr/local/zend/php53/
		rm -rf ZendGuardLoader-php-5.3-linux-glibc23-i386
		rm -f ZendGuardLoader-php-5.3-linux-glibc23-i386.tar.gz
	fi
	

	echo "Write ZendGuardLoader to php.ini..."
	cat >>${php_setup_path}/etc/php.ini<<EOF

;eaccelerator

;ionCube

;opcache

[Zend ZendGuard Loader]
zend_extension=/usr/local/zend/php53/ZendGuardLoader.so
zend_loader.enable=1
zend_loader.disable_licensing=0
zend_loader.obfuscation_level_support=3
zend_loader.license_path=

;xcache

EOF
if [ "${apacheVersion}" != '2.2' ];then
	Create_Fpm
	Set_PHP_FPM_Opt
	
	\cp ${php_setup_path}/src/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm-53
	chmod +x /etc/init.d/php-fpm-53
	
	Service_Add

	/etc/init.d/php-fpm-53 start
else
	if [ ! -f /www/server/php/53/libphp5.so ];then
		\cp -a -r $Root_Path/server/apache/modules/libphp5.so /www/server/php/53/libphp5.so
		sed -i '/#LoadModule php5_module/s/^#//' /www/server/apache/conf/httpd.conf
	fi
	/etc/init.d/httpd restart
fi
	rm -f ${php_setup_path}src.tar.gz
	echo "5.3.29" > ${php_setup_path}/version.pl
}


Install_PHP_54()
{
	cd ${run_path}
	php_version="54"
	/etc/init.d/php-fpm-$php_version stop
	php_setup_path=${php_path}/${php_version}
	
	mkdir -p ${php_setup_path}
	rm -rf ${php_setup_path}/*
	cd ${php_setup_path}
	if [ ! -f "${php_setup_path}/src.tar.gz" ];then
		wget -O ${php_setup_path}/src.tar.gz ${download_Url}/src/php-5.4.45.tar.gz -T20
	fi
	
	tar zxf src.tar.gz
	mv php-5.4.45 src
	cd src

	Configure_Get
	cd ${php_setup_path}/src
	if [ "${apacheVersion}" != '2.2' ];then
		./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --enable-fpm --with-fpm-user=www --with-fpm-group=www --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl=/usr/local/curl --enable-mbregex --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf --with-openssl=/usr/local/openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext --disable-fileinfo --enable-intl ${i_make_args}
	else
		./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --with-apxs2=$Root_Path/server/apache/bin/apxs --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl=/usr/local/curl --enable-mbregex --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf --with-openssl=/usr/local/openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext --disable-fileinfo --enable-intl --with-xsl ${i_make_args}
	fi
	if [ "${Is_64bit}" = "32" ];then
		sed -i 's/lcrypt$/lcrypt -lresolv/' Makefile
	fi
	make ZEND_EXTRA_LIBS='-liconv' -j${cpuCore}
	make install

	if [ ! -f "${php_setup_path}/bin/php" ];then
		echo '========================================================'
		GetSysInfo
		echo -e "ERROR: php-5.4 installation failed.";
		exit 0;
	fi
	
	Ln_PHP_Bin

	mkdir -p ${php_setup_path}/etc
	\cp php.ini-production ${php_setup_path}/etc/php.ini
	cd ${php_setup_path}
	# php extensions
	Set_Phpini
	Pear_Pecl_Set
	Install_Composer
	
	mkdir -p /usr/local/zend/php54
	if [ "${Is_64bit}" = "64" ] ; then
		wget ${download_Url}/src/ZendGuardLoader-70429-PHP-5.4-linux-glibc23-x86_64.tar.gz -T20
		tar zxf ZendGuardLoader-70429-PHP-5.4-linux-glibc23-x86_64.tar.gz
		\cp ZendGuardLoader-70429-PHP-5.4-linux-glibc23-x86_64/php-5.4.x/ZendGuardLoader.so /usr/local/zend/php54/
		rm -rf ZendGuardLoader-70429-PHP-5.4-linux-glibc23-x86_64
		rm -f ZendGuardLoader-70429-PHP-5.4-linux-glibc23-x86_64.tar.gz
	else
		wget ${download_Url}/src/ZendGuardLoader-70429-PHP-5.4-linux-glibc23-i386.tar.gz -T20
		tar zxf ZendGuardLoader-70429-PHP-5.4-linux-glibc23-i386.tar.gz
		\cp ZendGuardLoader-70429-PHP-5.4-linux-glibc23-i386/php-5.4.x/ZendGuardLoader.so /usr/local/zend/php54/
		rm -rf ZendGuardLoader-70429-PHP-5.4-linux-glibc23-i386
		rm -f ZendGuardLoader-70429-PHP-5.4-linux-glibc23-i386.tar.gz
	fi

	echo "Write ZendGuardLoader to php.ini..."
	cat >>${php_setup_path}/etc/php.ini<<EOF

;eaccelerator

;ionCube

;opcache

[Zend ZendGuard Loader]
zend_extension=/usr/local/zend/php54/ZendGuardLoader.so
zend_loader.enable=1
zend_loader.disable_licensing=0
zend_loader.obfuscation_level_support=3
zend_loader.license_path=

;xcache

EOF

if [ "${apacheVersion}" != '2.2' ];then
	Create_Fpm
	Set_PHP_FPM_Opt
	\cp ${php_setup_path}/src/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm-54
	chmod +x /etc/init.d/php-fpm-54

	Service_Add

	rm -f /tmp/php-cgi-54.sock
	/etc/init.d/php-fpm-54 start
else
	if [ ! -f /www/server/php/54/libphp5.so ];then
		\cp -a -r $Root_Path/server/apache/modules/libphp5.so /www/server/php/54/libphp5.so
		sed -i '/#LoadModule php5_module/s/^#//' /www/server/apache/conf/httpd.conf
	fi
	/etc/init.d/httpd restart
fi
	rm -f ${php_setup_path}/src.tar.gz
	echo "5.4.45" > ${php_setup_path}/version.pl
}

Install_PHP_55()
{
	cd ${run_path}
	php_version="55"
	/etc/init.d/php-fpm-$php_version stop
	php_setup_path=${php_path}/${php_version}
	mkdir -p ${php_setup_path}
	rm -rf ${php_setup_path}/*
	cd ${php_setup_path}

	Service_Add
	if [ ! -f "${php_setup_path}/src.tar.gz" ];then
		wget -O ${php_setup_path}/src.tar.gz ${download_Url}/src/php-${php_55}.tar.gz -T20
	fi
	
	tar zxf src.tar.gz
	mv php-${php_55} src
	cd src

	Configure_Get
	cd ${php_setup_path}/src
	./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --enable-fpm --with-fpm-user=www --with-fpm-group=www --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl=/usr/local/curl --enable-mbregex --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf --with-openssl=/usr/local/openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext --disable-fileinfo --enable-opcache --enable-intl ${i_make_args}
	if [ "${Is_64bit}" = "32" ];then
		sed -i 's/lcrypt$/lcrypt -lresolv/' Makefile
	fi
	make ZEND_EXTRA_LIBS='-liconv' -j${cpuCore}
	make install
	
	if [ ! -f "${php_setup_path}/bin/php" ];then
		echo '========================================================'
		GetSysInfo
		echo -e "ERROR: php-5.5 installation failed.";
		exit 0;
	fi
	
	Ln_PHP_Bin

	echo "Copy new php configure file..."
	mkdir -p ${php_setup_path}/etc
	\cp php.ini-production ${php_setup_path}/etc/php.ini

	cd ${php_setup_path}
	# php extensions
	Set_Phpini
	Pear_Pecl_Set
	Install_Composer

	echo "Install ZendGuardLoader for PHP 5.5..."
	mkdir -p /usr/local/zend/php55
	if [ "${Is_64bit}" = "64" ] ; then
		wget ${download_Url}/src/zend-loader-php5.5-linux-x86_64.tar.gz -T20
		tar zxf zend-loader-php5.5-linux-x86_64.tar.gz
		mkdir -p /usr/local/zend/
		\cp zend-loader-php5.5-linux-x86_64/ZendGuardLoader.so /usr/local/zend/php55/
		rm -rf zend-loader-php5.5-linux-x86_64
		rm -f zend-loader-php5.5-linux-x86_64.tar.gz
	else
		wget ${download_Url}/src/zend-loader-php5.5-linux-i386.tar.gz
		tar zxf zend-loader-php5.5-linux-i386.tar.gz
		mkdir -p /usr/local/zend/
		\cp zend-loader-php5.5-linux-i386/ZendGuardLoader.so /usr/local/zend/php55/
		rm -rf zend-loader-php5.5-linux-i386
		rm -f zend-loader-php5.5-linux-i386.tar.gz
	fi

	echo "Write ZendGuardLoader to php.ini..."
	cat >>${php_setup_path}/etc/php.ini<<EOF

;eaccelerator

;ionCube

;opcache

[Zend ZendGuard Loader]
zend_extension=/usr/local/zend/php55/ZendGuardLoader.so
zend_loader.enable=1
zend_loader.disable_licensing=0
zend_loader.obfuscation_level_support=3
zend_loader.license_path=

;xcache

EOF
	Create_Fpm
	Set_PHP_FPM_Opt
	echo "Copy php-fpm init.d file..."
	\cp ${php_setup_path}/src/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm-55
	chmod +x /etc/init.d/php-fpm-55
	
	Service_Add

	rm -f /tmp/php-cgi-55.sock
	/etc/init.d/php-fpm-55 start
	rm -f ${php_setup_path}/src.tar.gz
	echo "${php_55}" > ${php_setup_path}/version.pl
}

Install_PHP_56()
{
	cd ${run_path}
	php_version="56"
	/etc/init.d/php-fpm-$php_version stop
	php_setup_path=${php_path}/${php_version}
	
	mkdir -p ${php_setup_path}
	rm -rf ${php_setup_path}/*
	cd ${php_setup_path}
	if [ ! -f "${php_setup_path}/src.tar.gz" ];then
		wget -O ${php_setup_path}/src.tar.gz ${download_Url}/src/php-${php_56}.tar.gz -T20
	fi
	
	tar zxf src.tar.gz
	mv php-${php_56} src
	cd src

	Configure_Get
	cd ${php_setup_path}/src
	./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --enable-fpm --with-fpm-user=www --with-fpm-group=www --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl=/usr/local/curl --enable-mbregex --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf --with-openssl=/usr/local/openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext --disable-fileinfo --enable-opcache --enable-intl ${i_make_args}
	if [ "${Is_64bit}" = "32" ];then
		sed -i 's/lcrypt$/lcrypt -lresolv/' Makefile
	fi
	make ZEND_EXTRA_LIBS='-liconv' -j${cpuCore}
	make install

	if [ ! -f "${php_setup_path}/bin/php" ];then
		echo '========================================================'
		GetSysInfo
		echo -e "ERROR: php-5.6 installation failed.";
		rm -rf ${php_setup_path}
		exit 0;
	fi
	
	Ln_PHP_Bin

	echo "Copy new php configure file..."
	mkdir -p ${php_setup_path}/etc
	\cp php.ini-production ${php_setup_path}/etc/php.ini

	cd ${php_setup_path}
	# php extensions
	Set_Phpini
	Pear_Pecl_Set
	Install_Composer

	echo "Install ZendGuardLoader for PHP 5.6..."
	mkdir -p /usr/local/zend/php56
	if [ "${Is_64bit}" = "64" ] ; then
		wget ${download_Url}/src/zend-loader-php5.6-linux-x86_64.tar.gz -T20
		tar zxf zend-loader-php5.6-linux-x86_64.tar.gz
		\cp zend-loader-php5.6-linux-x86_64/ZendGuardLoader.so /usr/local/zend/php56/
		rm -rf zend-loader-php5.6-linux-x86_64
		rm -f zend-loader-php5.6-linux-x86_64.tar.gz
	else
		wget ${download_Url}/src/zend-loader-php5.6-linux-i386.tar.gz -T20
		tar zxf zend-loader-php5.6-linux-i386.tar.gz
		\cp zend-loader-php5.6-linux-i386/ZendGuardLoader.so /usr/local/zend/php56/
		rm -rf zend-loader-php5.6-linux-i386
		rm -f zend-loader-php5.6-linux-i386.tar.gz
	fi

	echo "Write ZendGuardLoader to php.ini..."
cat >>${php_setup_path}/etc/php.ini<<EOF

;eaccelerator

;ionCube

;opcache

[Zend ZendGuard Loader]
zend_extension=/usr/local/zend/php56/ZendGuardLoader.so
zend_loader.enable=1
zend_loader.disable_licensing=0
zend_loader.obfuscation_level_support=3
zend_loader.license_path=

;xcache

EOF

	Create_Fpm
	Set_PHP_FPM_Opt
	echo "Copy php-fpm init.d file..."
	\cp ${php_setup_path}/src/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm-56
	chmod +x /etc/init.d/php-fpm-56
	
	Service_Add

	rm -f /tmp/php-cgi-56.sock
	/etc/init.d/php-fpm-56 start
	rm -f ${php_setup_path}/src.tar.gz
	echo "${php_56}" > ${php_setup_path}/version.pl
}

Install_PHP_70()
{
	cd ${run_path}
	php_version="70"
	/etc/init.d/php-fpm-$php_version stop
	php_setup_path=${php_path}/${php_version}
	
	mkdir -p ${php_setup_path}
	rm -rf ${php_setup_path}/*
	cd ${php_setup_path}
	if [ ! -f "${php_setup_path}/src.tar.gz" ];then
		wget -O ${php_setup_path}/src.tar.gz ${download_Url}/src/php-${php_70}.tar.gz -T20
	fi
	
	tar zxf src.tar.gz
	mv php-${php_70} src
	cd src

	Configure_Get
	cd ${php_setup_path}/src
	./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl=/usr/local/curl --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf --with-openssl=/usr/local/openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext --disable-fileinfo --enable-opcache ${i_make_args}
	if [ "${Is_64bit}" = "32" ];then
		sed -i 's/lcrypt$/lcrypt -lresolv/' Makefile
    fi
    make ZEND_EXTRA_LIBS='-liconv' -j${cpuCore}
    make install

	if [ ! -f "${php_setup_path}/bin/php" ];then
		echo '========================================================'
		GetSysInfo
		echo -e "ERROR: php-7.0 installation failed.";
		rm -rf ${php_setup_path}
		exit 0;
	fi
	
	Ln_PHP_Bin

	echo "Copy new php configure file..."
	mkdir -p ${php_setup_path}/etc
	\cp php.ini-production ${php_setup_path}/etc/php.ini

	cd ${php_setup_path}
	# php extensions
	Set_Phpini
	Pear_Pecl_Set
	Install_Composer

	echo "Install ZendGuardLoader for PHP 7..."
	echo "unavailable now."

	echo "Write ZendGuardLoader to php.ini..."
cat >>${php_setup_path}/etc/php.ini<<EOF

;eaccelerator

;ionCube

;opcache

[Zend ZendGuard Loader]
;php7 do not support zendguardloader @Sep.2015,after support you can uncomment the following line.
;zend_extension=/usr/local/zend/php70/ZendGuardLoader.so
;zend_loader.enable=1
;zend_loader.disable_licensing=0
;zend_loader.obfuscation_level_support=3
;zend_loader.license_path=

;xcache

EOF

	Create_Fpm
	Set_PHP_FPM_Opt
	\cp ${php_setup_path}/src/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm-70
	chmod +x /etc/init.d/php-fpm-70
	
	Service_Add

	rm -f /tmp/php-cgi-70.sock
	/etc/init.d/php-fpm-70 start
	rm -f ${php_setup_path}/src.tar.gz
	echo "${php_70}" > ${php_setup_path}/version.pl
}

Install_PHP_71()
{
	cd ${run_path}
	php_version="71"
	/etc/init.d/php-fpm-$php_version stop
	php_setup_path=${php_path}/${php_version}
	
	mkdir -p ${php_setup_path}
	rm -rf ${php_setup_path}/*
	cd ${php_setup_path}
	if [ ! -f "${php_setup_path}/src.tar.gz" ];then
		wget -O ${php_setup_path}/src.tar.gz ${download_Url}/src/php-${php_71}.tar.gz -T20
	fi
	
	tar zxf src.tar.gz
	mv php-${php_71} src
	cd src

	Configure_Get
	cd ${php_setup_path}/src
	./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl=/usr/local/curl --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf --with-openssl=/usr/local/openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext --disable-fileinfo --enable-opcache ${i_make_args}
	if [ "${Is_64bit}" = "32" ];then
		sed -i 's/lcrypt$/lcrypt -lresolv/' Makefile
	fi
	make -j${cpuCore}
	make install

	if [ ! -f "${php_setup_path}/bin/php" ];then
		echo '========================================================'
		GetSysInfo
		echo -e "ERROR: php-7.1 installation failed.";
		rm -rf ${php_setup_path}
		exit 0;
	fi
	
	Ln_PHP_Bin

	echo "Copy new php configure file..."
	mkdir -p ${php_setup_path}/etc
	\cp php.ini-production ${php_setup_path}/etc/php.ini

	cd ${php_setup_path}
	# php extensions
	Set_Phpini
	Pear_Pecl_Set
	Install_Composer

	echo "Install ZendGuardLoader for PHP 7..."
	echo "unavailable now."

	echo "Write ZendGuardLoader to php.ini..."
cat >>${php_setup_path}/etc/php.ini<<EOF

;eaccelerator

;ionCube

;opcache

[Zend ZendGuard Loader]
;php7 do not support zendguardloader @Sep.2015,after support you can uncomment the following line.
;zend_extension=/usr/local/zend/php71/ZendGuardLoader.so
;zend_loader.enable=1
;zend_loader.disable_licensing=0
;zend_loader.obfuscation_level_support=3
;zend_loader.license_path=

;xcache

EOF

	Create_Fpm
	Set_PHP_FPM_Opt
	\cp ${php_setup_path}/src/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm-71
	chmod +x /etc/init.d/php-fpm-71
	
	Service_Add

	rm -f /tmp/php-cgi-71.sock
	/etc/init.d/php-fpm-71 start
	if [ -d "$Root_Path/server/nginx" ];then
		wget -O $Root_Path/server/nginx/conf/enable-php-71.conf ${download_Url}/conf/enable-php-71.conf -T20
	fi
	rm -f ${php_setup_path}/src.tar.gz
	echo "${php_71}" > ${php_setup_path}/version.pl
}

Install_PHP_72()
{
	cd ${run_path}
	php_version="72"
	/etc/init.d/php-fpm-$php_version stop
	php_setup_path=${php_path}/${php_version}
	
	mkdir -p ${php_setup_path}
	rm -rf ${php_setup_path}/*
	cd ${php_setup_path}
	if [ ! -f "${php_setup_path}/src.tar.gz" ];then
		wget -O ${php_setup_path}/src.tar.gz ${download_Url}/src/php-${php_72}.tar.gz -T20
	fi
	
	tar zxf src.tar.gz
	mv php-${php_72} src
	cd src

	Configure_Get
	cd ${php_setup_path}/src
	./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl=/usr/local/curl --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd --enable-gd-native-ttf --with-openssl=/usr/local/openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext --disable-fileinfo --enable-opcache ${i_make_args}
	if [ "${Is_64bit}" = "32" ];then
		sed -i 's/lcrypt$/lcrypt -lresolv/' Makefile
	fi
	make ZEND_EXTRA_LIBS='-liconv' -j${cpuCore}
	make install

	if [ ! -f "${php_setup_path}/bin/php" ];then
		echo '========================================================'
		GetSysInfo
		echo -e "ERROR: php-7.2 installation failed.";
		rm -rf ${php_setup_path}
		exit 0;
	fi
	
	Ln_PHP_Bin

	echo "Copy new php configure file..."
	mkdir -p ${php_setup_path}/etc
	\cp php.ini-production ${php_setup_path}/etc/php.ini

	cd ${php_setup_path}
	# php extensions
	Set_Phpini
	Pear_Pecl_Set
	Install_Composer

	echo "Install ZendGuardLoader for PHP 7..."
	echo "unavailable now."

	echo "Write ZendGuardLoader to php.ini..."
cat >>${php_setup_path}/etc/php.ini<<EOF

;eaccelerator

;ionCube

;opcache

[Zend ZendGuard Loader]
;php7 do not support zendguardloader @Sep.2015,after support you can uncomment the following line.
;zend_extension=/usr/local/zend/php72/ZendGuardLoader.so
;zend_loader.enable=1
;zend_loader.disable_licensing=0
;zend_loader.obfuscation_level_support=3
;zend_loader.license_path=

;xcache

EOF

	Create_Fpm	
	Set_PHP_FPM_Opt
	\cp ${php_setup_path}/src/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm-72
	chmod +x /etc/init.d/php-fpm-72
	
	Service_Add

	rm -f /tmp/php-cgi-72.sock
	/etc/init.d/php-fpm-72 start
	if [ -d "$Root_Path/server/nginx" ];then
		wget -O $Root_Path/server/nginx/conf/enable-php-72.conf ${download_Url}/conf/enable-php-72.conf -T20
	elif [ -d "$Root_Path/server/apache" ]; then
		wget -O $Root_Path/server/apache/conf/extra/httpd-vhosts.conf http://download.bt.cn/conf/httpd-vhosts.conf
		sed -i "s/php-cgi-VERSION/php-cgi-72/g" $Root_Path/server/apache/conf/extra/httpd-vhosts.conf
	fi

	rm -f ${php_setup_path}/src.tar.gz
	echo "${php_72}" > ${php_setup_path}/version.pl
}
Install_PHP_73()
{
	cd ${run_path}
	php_version="73"
	/etc/init.d/php-fpm-$php_version stop

	LibCurlVer=$(/usr/local/curl/bin/curl -V|grep curl|awk '{print $2}'|cut -d. -f2)
	if [[ "${LibCurlVer}" -le "60" ]]; then
		if [ ! -f "/usr/local/curl2/bin/curl" ];then
			curlVer="7.64.1"
			wget ${download_Url}/src/curl-${curlVer}.tar.gz
			tar -xvf curl-${curlVer}.tar.gz
			cd curl-${curlVer}
			./configure --prefix=/usr/local/curl2 --enable-ares --without-nss --with-ssl=/usr/local/openssl
			make -j${cpuCore}
			make install
			cd ..
			rm -rf curl*
		fi
	fi

	php_setup_path=${php_path}/${php_version}
	
	mkdir -p ${php_setup_path}
	rm -rf ${php_setup_path}/*
	cd ${php_setup_path}
	if [ ! -f "${php_setup_path}/src.tar.gz" ];then
		wget -O ${php_setup_path}/src.tar.gz ${download_Url}/src/php-${php_73}.tar.gz -T20
	fi
	
	if [ -f "/usr/local/curl2/bin/curl" ]; then
		withCurl="/usr/local/curl2"
	else
		withCurl="/usr/local/curl"
	fi

	if [ -f "/usr/local/openssl111/bin/openssl" ];then
		 curlOpensslLIB=$(/usr/local/curl/bin/curl -V|grep -oE OpenSSL/1.1.1[a-Z]|cut -d '/' -f 2)
		 opensslVersion=$(/usr/local/openssl111/bin/openssl version|awk '{print $2}')
		 if [ "${curlOpensslLIB}" == "${opensslVersion}" ];then
		 	withOpenssl="/usr/local/openssl111"
		 else
		 	withOpenssl="/usr/local/openssl"
		 fi
	else
		withOpenssl="/usr/local/openssl"
	fi

	tar zxf src.tar.gz
	mv php-${php_73} src
	cd src

	Configure_Get
	cd ${php_setup_path}/src
	./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl=${withCurl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd --with-openssl=${withOpenssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc  --enable-soap --with-gettext --disable-fileinfo --enable-opcache --with-sodium=/usr/local/libsodium ${i_make_args}
	if [ "${Is_64bit}" = "32" ];then
		sed -i 's/lcrypt$/lcrypt -lresolv/' Makefile
	fi
	make ZEND_EXTRA_LIBS='-liconv' -j${cpuCore}
	make install

	if [ ! -f "${php_setup_path}/bin/php" ];then
		echo '========================================================'
		GetSysInfo
		echo -e "ERROR: php-7.3 installation failed.";
		rm -rf ${php_setup_path}
		exit 0;
	fi
	
	cd ${php_setup_path}/src/ext/zip
	${php_setup_path}/bin/phpize
	./configure --enable-zip --with-php-config=${php_setup_path}/bin/php-config 
	make && make install
	cd ../../
	Ln_PHP_Bin

	echo "Copy new php configure file..."
	mkdir -p ${php_setup_path}/etc
	\cp php.ini-production ${php_setup_path}/etc/php.ini

	cd ${php_setup_path}  
	# php extensions
	Set_Phpini
	if [ -f "/www/server/php/73/lib/php/extensions/no-debug-non-zts-20180731/zip.so" ];then
		echo "extension = zip.so" >> ${php_setup_path}/etc/php.ini
	fi
	Pear_Pecl_Set
	Install_Composer

	echo "Install ZendGuardLoader for PHP 7..."
	echo "unavailable now."

	echo "Write ZendGuardLoader to php.ini..."
cat >>${php_setup_path}/etc/php.ini<<EOF

;eaccelerator

;ionCube

;opcache

[Zend ZendGuard Loader]
;php7 do not support zendguardloader @Sep.2015,after support you can uncomment the following line.
;zend_extension=/usr/local/zend/php72/ZendGuardLoader.so
;zend_loader.enable=1
;zend_loader.disable_licensing=0
;zend_loader.obfuscation_level_support=3
;zend_loader.license_path=

;xcache

EOF

	Create_Fpm
	Set_PHP_FPM_Opt
	\cp ${php_setup_path}/src/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm-73
	chmod +x /etc/init.d/php-fpm-73
	
	Service_Add

	rm -f /tmp/php-cgi-73.sock
	fpmPhpinfo
	/etc/init.d/php-fpm-73 start
	if [ -d "$Root_Path/server/nginx" ];then
		wget -O $Root_Path/server/nginx/conf/enable-php-73.conf ${download_Url}/conf/enable-php-73.conf -T20
	elif [ -d "$Root_Path/server/apache" ]; then
		wget -O $Root_Path/server/apache/conf/extra/httpd-vhosts.conf ${download_Url}/conf/httpd-vhosts.conf
		sed -i "s/php-cgi-VERSION/php-cgi-73/g" $Root_Path/server/apache/conf/extra/httpd-vhosts.conf
	fi

	rm -f ${php_setup_path}/src.tar.gz
	echo "${php_73}" > ${php_setup_path}/version.pl
}
Install_PHP_74()
{
	cd ${run_path}
	php_version="74"
	/etc/init.d/php-fpm-$php_version stop

	if [ "${PM}" == "yum" ] || [ "${PM}" == "dnf" ] ; then
		Centos8Check=$(cat /etc/redhat-release | grep ' 8.' | grep -iE 'centos|Red Hat')
		Centos7Check=$(cat /etc/redhat-release | grep ' 7.' | grep -iE 'centos|Red Hat')
		if [ "${Centos8Check}" ];then
			yum install libsodium-devel sqlite-devel libzip-devel -y
			mkdir onig 
			cd onig
			wget -O oniguruma-6.8.2.rpm ${download_Url}/rpm/remi/8/oniguruma-6.8.2.rpm
			wget -O oniguruma-devel-6.8.2.rpm ${download_Url}/rpm/remi/8/oniguruma-devel-6.8.2.rpm
			yum install * -y
			cd ..
			rm -rf onig
		elif [ "${Centos7Check}" ]; then
			yum install libsodium-devel sqlite-devel oniguruma-devel -y
			mkdir libzip
			cd libzip
			wget -O libzip5-1.5.2.rpm ${download_Url}/rpm/remi/7/libzip5-1.5.2.rpm
			wget -O libzip5-devel-1.5.2.rpm ${download_Url}/rpm/remi/7/libzip5-devel-1.5.2.rpm
			wget -O libzip5-tools-1.5.2.rpm ${download_Url}/rpm/remi/7/libzip5-tools-1.5.2.rpm
			yum install * -y
			cd ..
			rm -rf libzip
		fi
		Pack="libsodium-devel sqlite-devel oniguruma-devel"
		${PM} install ${Pack} -y
	elif [ "${PM}" == "apt-get" ]; then
		Pack="libsodium-dev libonig-dev libsqlite3-dev libcurl4-openssl-dev libwebp-dev"
		${PM} install ${Pack} -y
	fi

	LibCurlVer=$(/usr/local/curl/bin/curl -V|grep curl|awk '{print $2}'|cut -d. -f2)
	if [[ "${LibCurlVer}" -le "60" ]]; then
		if [ ! -f "/usr/local/curl2/bin/curl" ];then
			curlVer="7.64.1"
			wget ${download_Url}/src/curl-${curlVer}.tar.gz
			tar -xvf curl-${curlVer}.tar.gz
			cd curl-${curlVer}
			./configure --prefix=/usr/local/curl2 --enable-ares --without-nss --with-ssl=/usr/local/openssl
			make -j${cpuCore}
			make install
			cd ..
			rm -rf curl*
		fi
	fi

	php_setup_path=${php_path}/${php_version}
	mkdir -p ${php_setup_path}
	rm -rf ${php_setup_path}/*
	cd ${php_setup_path}
	if [ ! -f "${php_setup_path}/src.tar.gz" ];then
		wget -O ${php_setup_path}/src.tar.gz ${download_Url}/src/php-${php_74}.tar.gz -T20
	fi
	
	if [ -f "/usr/local/curl2/bin/curl" ]; then
		withCurl="/usr/local/curl2"
	else
		withCurl="/usr/local/curl"
	fi

	if [ -f "/usr/local/openssl111/bin/openssl" ];then
		 curlOpensslLIB=$(/usr/local/curl/bin/curl -V|grep -oE OpenSSL/1.1.1[a-Z]|cut -d '/' -f 2)
		 opensslVersion=$(/usr/local/openssl111/bin/openssl version|awk '{print $2}')
		 if [ "${curlOpensslLIB}" == "${opensslVersion}" ];then
		 	withOpenssl="/usr/local/openssl111"
		 else
		 	withOpenssl="/usr/local/openssl"
		 fi
	else
		withOpenssl="/usr/local/openssl"
	fi

	tar zxf src.tar.gz
	mv php-${php_74} src
	cd src

	Configure_Get
	cd ${php_setup_path}/src
	export CFLAGS="-I${withOpenssl}/include -I${withCurl}/include"
	export LIBS="-L${withOpenssl}/lib -L${withCurl}/lib"
	./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype --with-jpeg --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd --with-openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc  --enable-soap --with-gettext --disable-fileinfo --enable-opcache --with-sodium=/usr/local/libsodium --with-webp ${i_make_args}
	if [ "${Is_64bit}" = "32" ];then
		sed -i 's/lcrypt$/lcrypt -lresolv/' Makefile
	fi
	make ZEND_EXTRA_LIBS='-liconv' -j${cpuCore}
	make install

	if [ ! -f "${php_setup_path}/bin/php" ];then
		echo '========================================================'
		GetSysInfo
		echo -e "ERROR: php-7.4 installation failed.";
		rm -rf ${php_setup_path}
		exit 0;
	fi
	
	cd ${php_setup_path}/src/ext/zip
	${php_setup_path}/bin/phpize
	./configure --with-php-config=${php_setup_path}/bin/php-config 
	make && make install
	cd ../../
	Ln_PHP_Bin

	echo "Copy new php configure file..."
	mkdir -p ${php_setup_path}/etc
	\cp php.ini-production ${php_setup_path}/etc/php.ini

	cd ${php_setup_path}  
	# php extensions
	Set_Phpini
	if [ -f "/www/server/php/74/lib/php/extensions/no-debug-non-zts-20190902/zip.so" ];then
		echo "extension = zip.so" >> ${php_setup_path}/etc/php.ini
	fi
	Pear_Pecl_Set
	Install_Composer

	echo "Install ZendGuardLoader for PHP 7..."
	echo "unavailable now."

	echo "Write ZendGuardLoader to php.ini..."
cat >>${php_setup_path}/etc/php.ini<<EOF

;eaccelerator

;ionCube

;opcache

[Zend ZendGuard Loader]
;php7 do not support zendguardloader @Sep.2015,after support you can uncomment the following line.
;zend_extension=/usr/local/zend/php72/ZendGuardLoader.so
;zend_loader.enable=1
;zend_loader.disable_licensing=0
;zend_loader.obfuscation_level_support=3
;zend_loader.license_path=

;xcache

EOF

	Create_Fpm
	Set_PHP_FPM_Opt
	\cp ${php_setup_path}/src/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm-74
	chmod +x /etc/init.d/php-fpm-74
	
	Service_Add

	rm -f /tmp/php-cgi-74.sock
	fpmPhpinfo
	/etc/init.d/php-fpm-74 start
	if [ -d "$Root_Path/server/nginx" ];then
		wget -O $Root_Path/server/nginx/conf/enable-php-74.conf ${download_Url}/conf/enable-php-74.conf -T20
	elif [ -d "$Root_Path/server/apache" ]; then
		wget -O $Root_Path/server/apache/conf/extra/httpd-vhosts.conf ${download_Url}/conf/httpd-vhosts.conf
		sed -i "s/php-cgi-VERSION/php-cgi-74/g" $Root_Path/server/apache/conf/extra/httpd-vhosts.conf
	fi

	rm -f ${php_setup_path}/src.tar.gz
	echo "${php_74}" > ${php_setup_path}/version.pl
}
Update_PHP_56()
{
	cd ${run_path}
	php_version="56"
	php_setup_path=${php_path}/${php_version}
	php_update_path=${php_path}/${php_version}/update

	mkdir -p ${php_update_path}
	rm -rf ${php_update_path}/*
	
	cd ${php_update_path}
	if [ ! -f "${php_update_path}/src.tar.gz" ];then
		wget -O ${php_update_path}/src.tar.gz ${download_Url}/src/php-${php_56}.tar.gz -T20
	fi
	tar zxf src.tar.gz
	mv php-${php_56} src
	cd src

	Configure_Get
	cd ${php_update_path}/src
	./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --enable-fpm --with-fpm-user=www --with-fpm-group=www --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl=/usr/local/curl --enable-mbregex --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf --with-openssl=/usr/local/openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext --disable-fileinfo --enable-opcache --enable-intl ${i_make_args}
	if [ "${Is_64bit}" = "32" ];then
		sed -i 's/lcrypt$/lcrypt -lresolv/' Makefile
	fi
	make ZEND_EXTRA_LIBS='-liconv' -j${cpuCore}
	/etc/init.d/php-fpm-56 stop
	sleep 1
	make install
	sleep 1
	cd ${php_path}
	rm -rf ${php_update_path}
	/etc/init.d/php-fpm-56 start
	echo "${php_56}" > ${php_setup_path}/version.pl
	rm -f ${php_setup_path}/version_check.pl
}
Update_PHP_70()
{
	cd ${run_path}
	php_version="70"
	php_setup_path=${php_path}/${php_version}
	php_update_path=${php_path}/${php_version}/update

	mkdir -p ${php_update_path}
	rm -rf ${php_update_path}/*
	
	cd ${php_update_path}
	if [ ! -f "${php_update_path}/src.tar.gz" ];then
		wget -O ${php_update_path}/src.tar.gz ${download_Url}/src/php-${php_70}.tar.gz -T20
	fi
	tar zxf src.tar.gz
	mv php-${php_70} src
	cd src

	Configure_Get
	cd ${php_update_path}/src
	./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl=/usr/local/curl --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf --with-openssl=/usr/local/openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext --disable-fileinfo --enable-opcache ${i_make_args}
	if [ "${Is_64bit}" = "32" ];then
		sed -i 's/lcrypt$/lcrypt -lresolv/' Makefile
	fi
	make ZEND_EXTRA_LIBS='-liconv' -j${cpuCore}
	/etc/init.d/php-fpm-70 stop
	sleep 1
	make install
	rm -rf ${php_update_path}
	sleep 1
	cd ${php_path}
	/etc/init.d/php-fpm-70 start
	echo "${php_70}" > ${php_setup_path}/version.pl
	rm -f ${php_setup_path}/version_check.pl
}
Update_PHP_71()
{
	cd ${run_path}
	php_version="71"
	php_setup_path=${php_path}/${php_version}
	php_update_path=${php_path}/${php_version}/update

	mkdir -p ${php_update_path}
	rm -rf ${php_update_path}/*
	
	cd ${php_update_path}
	if [ ! -f "${php_update_path}/src.tar.gz" ];then
		wget -O ${php_update_path}/src.tar.gz ${download_Url}/src/php-${php_71}.tar.gz -T20
	fi
	tar zxf src.tar.gz
	mv php-${php_71} src
	cd src

	Configure_Get
	cd ${php_update_path}/src
	./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl=/usr/local/curl --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf --with-openssl=/usr/local/openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext --disable-fileinfo --enable-opcache ${i_make_args}
	if [ "${Is_64bit}" = "32" ];then
		sed -i 's/lcrypt$/lcrypt -lresolv/' Makefile
	fi   
	make ZEND_EXTRA_LIBS='-liconv' -j${cpuCore}
	/etc/init.d/php-fpm-71 stop
	sleep 1
	make install
	sleep 1
	cd ${php_path}
	rm -rf ${php_update_path}
	/etc/init.d/php-fpm-71 start
	echo "${php_71}" > ${php_setup_path}/version.pl
	rm -f ${php_setup_path}/version_check.pl
}
Update_PHP_72()
{
	cd ${run_path}
	php_version="72"
	php_setup_path=${php_path}/${php_version}
	php_update_path=${php_path}/${php_version}/update

	mkdir -p ${php_update_path}
	rm -rf ${php_update_path}/*
	
	cd ${php_update_path}
	if [ ! -f "${php_update_path}/src.tar.gz" ];then
		wget -O ${php_update_path}/src.tar.gz ${download_Url}/src/php-${php_72}.tar.gz -T20
	fi
	tar zxf src.tar.gz
	mv php-${php_72} src
	cd src

	Configure_Get
	cd ${php_update_path}/src
	./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl=/usr/local/curl --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd --enable-gd-native-ttf --with-openssl=/usr/local/openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext --disable-fileinfo --enable-opcache ${i_make_args}
	if [ "${Is_64bit}" = "32" ];then
		sed -i 's/lcrypt$/lcrypt -lresolv/' Makefile
	fi
	make ZEND_EXTRA_LIBS='-liconv' -j${cpuCore}
	/etc/init.d/php-fpm-72 stop
	sleep 1
	make install
	sleep 1
	cd ${php_path}
	rm -rf ${php_update_path}
	/etc/init.d/php-fpm-72 start
	echo "${php_72}" > ${php_setup_path}/version.pl
	rm -f ${php_setup_path}/version_check.pl
}
Update_PHP_73()
{
	cd ${run_path}
	php_version="73"
	php_setup_path=${php_path}/${php_version}
	php_update_path=${php_path}/${php_version}/update

	mkdir -p ${php_update_path}
	rm -rf ${php_update_path}/*
	
	cd ${php_update_path}
	if [ ! -f "${php_update_path}/src.tar.gz" ];then
		wget -O ${php_update_path}/src.tar.gz ${download_Url}/src/php-${php_73}.tar.gz -T20
	fi
	tar zxf src.tar.gz
	mv php-${php_73} src
	cd src

	if [ -f "/usr/local/curl2/bin/curl" ]; then
		withCurl="/usr/local/curl2"
	else
		withCurl="/usr/local/curl"
	fi

	if [ -f "/usr/local/openssl111/bin/openssl" ];then
		 curlOpensslLIB=$(/usr/local/curl/bin/curl -V|grep -oE OpenSSL/1.1.1[a-Z]|cut -d '/' -f 2)
		 opensslVersion=$(/usr/local/openssl111/bin/openssl version|awk '{print $2}')
		 if [ "${curlOpensslLIB}" == "${opensslVersion}" ];then
		 	withOpenssl="/usr/local/openssl111"
		 else
		 	withOpenssl="/usr/local/openssl"
		 fi
	else
		withOpenssl="/usr/local/openssl"
	fi

	Configure_Get
	cd ${php_update_path}/src
	./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/usr/local/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl=${withCurl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd --with-openssl=${withOpenssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc  --enable-soap --with-gettext --disable-fileinfo --enable-opcache --with-sodium=/usr/local/libsodium ${i_make_args}
	if [ "${Is_64bit}" = "32" ];then
		sed -i 's/lcrypt$/lcrypt -lresolv/' Makefile
	fi
	make ZEND_EXTRA_LIBS='-liconv' -j${cpuCore}
	/etc/init.d/php-fpm-73 stop
	sleep 1
	make install
	sleep 1
	if [ ! -f "/www/server/php/73/lib/php/extensions/no-debug-non-zts-20180731/zip.so" ];then
		cd ext/zip
		${php_setup_path}/bin/phpize
		./configure --enable-zip --with-php-config=${php_setup_path}/bin/php-config 
		make -j${cpuCore} && make install
		cd ../../
		ZIP_LOAD_CHECK=$(cat ${php_setup_path}/etc/php.ini|grep zip.so)
		if [ -z ${ZIP_LOAD_CHECK} ] && [ -f "/www/server/php/73/lib/php/extensions/no-debug-non-zts-20180731/zip.so" ]; then
			echo "extension = zip.so" >> ${php_setup_path}/etc/php.ini
		fi
	fi
	cd ${php_path}
	rm -rf ${php_update_path}
	#sed -i "/zip.so/d"  ${php_setup_path}/etc/php.ini
	/etc/init.d/php-fpm-73 start
	echo "${php_73}" > ${php_setup_path}/version.pl
	rm -f ${php_setup_path}/version_check.pl
}
Update_PHP_74()
{
	cd ${run_path}
	php_version="74"
	php_setup_path=${php_path}/${php_version}
	php_update_path=${php_path}/${php_version}/update
	Centos7Check=$(cat /etc/redhat-release | grep ' 7.' | grep -iE 'centos|Red Hat')
	if [ "${Centos7Check}" ]; then
		LIBZIP_CHECK=$(rpm -q libzip5-devel|grep "not installed")
		if [ "${LIBZIP_CHECK}" ];then
			mkdir libzip
			cd libzip
			wget -O libzip5-1.5.2.rpm ${download_Url}/rpm/remi/7/libzip5-1.5.2.rpm
			wget -O libzip5-devel-1.5.2.rpm ${download_Url}/rpm/remi/7/libzip5-devel-1.5.2.rpm
			wget -O libzip5-tools-1.5.2.rpm ${download_Url}/rpm/remi/7/libzip5-tools-1.5.2.rpm
			yum install * -y
			cd ..
			rm -rf libzip
		fi
	fi

	mkdir -p ${php_update_path}
	rm -rf ${php_update_path}/*
	
	cd ${php_update_path}
	if [ ! -f "${php_update_path}/src.tar.gz" ];then
		wget -O ${php_update_path}/src.tar.gz ${download_Url}/src/php-${php_74}.tar.gz -T20
	fi
	tar zxf src.tar.gz
	mv php-${php_74} src
	cd src

	if [ -f "/usr/local/curl2/bin/curl" ]; then
		withCurl="/usr/local/curl2"
	else
		withCurl="/usr/local/curl"
	fi

	if [ -f "/usr/local/openssl111/bin/openssl" ];then
		 curlOpensslLIB=$(/usr/local/curl/bin/curl -V|grep -oE OpenSSL/1.1.1[a-Z]|cut -d '/' -f 2)
		 opensslVersion=$(/usr/local/openssl111/bin/openssl version|awk '{print $2}')
		 if [ "${curlOpensslLIB}" == "${opensslVersion}" ];then
		 	withOpenssl="/usr/local/openssl111"
		 else
		 	withOpenssl="/usr/local/openssl"
		 fi
	else
		withOpenssl="/usr/local/openssl"
	fi

	Configure_Get
	cd ${php_update_path}/src
	export CFLAGS="-I${withOpenssl}/include -I${withCurl}/include"
	export LIBS="-L${withOpenssl}/lib -L${withCurl}/lib"
	./configure --prefix=${php_setup_path} --with-config-file-path=${php_setup_path}/etc --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype --with-jpeg --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd --with-openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc  --enable-soap --with-gettext --disable-fileinfo --enable-opcache --with-sodium=/usr/local/libsodium --with-webp ${i_make_args}
	if [ "${Is_64bit}" = "32" ];then
		sed -i 's/lcrypt$/lcrypt -lresolv/' Makefile
	fi
	make ZEND_EXTRA_LIBS='-liconv' -j${cpuCore}
	/etc/init.d/php-fpm-74 stop
	sleep 1
	make install
	sleep 1
	if [ ! -f "/www/server/php/74/lib/php/extensions/no-debug-non-zts-20190902/zip.so" ];then
		cd ext/zip
		${php_setup_path}/bin/phpize
		./configure --enable-zip --with-php-config=${php_setup_path}/bin/php-config 
		make -j${cpuCore} && make install
		cd ../../
		ZIP_LOAD_CHECK=$(cat ${php_setup_path}/etc/php.ini|grep zip.so)
		if [ -z ${ZIP_LOAD_CHECK} ] && [ -f "/www/server/php/74/lib/php/extensions/no-debug-non-zts-20190902/zip.so" ]; then
			echo "extension = zip.so" >> ${php_setup_path}/etc/php.ini
		fi
	fi
	cd ${php_path}
	rm -rf ${php_update_path}
	#sed -i "/zip.so/d"  ${php_setup_path}/etc/php.ini
	/etc/init.d/php-fpm-74 start
	echo "${php_73}" > ${php_setup_path}/version.pl
	rm -f ${php_setup_path}/version_check.pl
}
Bt_Check(){
	checkFile="/www/server/panel/install/check.sh"
	#wget -O ${checkFile} ${download_Url}/tools/check.sh			
	#. ${checkFile} 
}
SetPHPMyAdmin()
{
	if [ -f "/www/server/nginx/sbin/nginx" ]; then
		webserver="nginx"
	fi
	PHPVersion=""
	for phpV in 52 53 54 55 56 70 71 72 73
	do
		if [ -f "/www/server/php/${phpV}/bin/php" ]; then
			PHPVersion=${phpV}
		fi
	done

	[ -z "${PHPVersion}" ] && PHPVersion="00"
	if [ "${webserver}" == "nginx" ];then
		sed -i "s#$Root_Path/wwwroot/default#$Root_Path/server/phpmyadmin#" $Root_Path/server/nginx/conf/nginx.conf
		rm -f $Root_Path/server/nginx/conf/enable-php.conf
		\cp $Root_Path/server/nginx/conf/enable-php-$PHPVersion.conf $Root_Path/server/nginx/conf/enable-php.conf
		sed -i "/pathinfo/d" $Root_Path/server/nginx/conf/enable-php.conf
		/etc/init.d/nginx reload
	else
		sed -i "s#$Root_Path/wwwroot/default#$Root_Path/server/phpmyadmin#" $Root_Path/server/apache/conf/extra/httpd-vhosts.conf
		sed -i "0,/php-cgi/ s/php-cgi-\w*\.sock/php-cgi-${PHPVersion}.sock/" $Root_Path/server/apache/conf/extra/httpd-vhosts.conf
		/etc/init.d/httpd reload
	fi
}

Uninstall_PHP()
{
	php_version=${1/./}

	if [ -f "/www/server/php/${php_version}/rpm.pl" ];then
		yum remove -y bt-php${php_version}
		[ ! -f "/www/server/php/${php_version}/bin/php" ] && exit 0;
	fi
	service php-fpm-$php_version stop

	Service_Del

	rm -rf $php_path/$php_version
	rm -f /etc/init.d/php-fpm-$php_version

	if [ -f "$Root_Path/server/phpmyadmin/version.pl" ];then
		SetPHPMyAdmin
	fi

	for phpV in 52 53 54 55 56 70 71 72 73
	do
		if [ -f "/www/server/php/${phpV}/bin/php" ]; then
			rm -f /usr/bin/php
			ln -sf /www/server/php/${phpV}/bin/php /usr/bin/php
		fi
	done
}


actionType=$1
version=$2

if [ "$actionType" == 'install' ];then
	Install_Openssl
	Install_Curl
	Install_Icu4c
	case "$version" in
		'5.2')
			Install_PHP_52
			;;
		'5.3')
			Install_PHP_53
			;;
		'5.4')
			Install_PHP_54
			;;
		'5.5')
			Install_PHP_55
			;;
		'5.6')
			Install_PHP_56
			;;
		'7.0')
			Install_PHP_70
			;;
		'7.1')
			Install_PHP_71
			;;
		'7.2')
			Install_PHP_72
			;;
		'7.3')
			Install_Libzip
			Install_Libsodium
			Install_PHP_73
			;;
		'7.4')
			Install_Libsodium
			Install_PHP_74
			;;

	esac
	armCheck=$(uname -a|grep arm)
	[ "${armCheck}" ] && Uninstall_Zend
	Bt_Check
elif [ "$actionType" == 'uninstall' ];then
	Uninstall_PHP $version
elif [ "$actionType" == 'update' ];then
	case "$version" in
		'5.6')
			Update_PHP_56
			;;
		'7.0')
			Update_PHP_70
			;;
		'7.1')
			Update_PHP_71
			;;
		'7.2')
			Update_PHP_72
			;;
		'7.3')
			Install_Libzip
			Install_Libsodium
			Update_PHP_73
			;;
		'7.4')
			Update_PHP_74
	esac
fi

