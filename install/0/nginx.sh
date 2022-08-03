#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
LANG=en_US.UTF-8

public_file=/www/server/panel/install/public.sh

NODE_URL='http://download.bt.cn';
download_Url=$NODE_URL

tengine='2.3.3'
nginx_108='1.8.1'
nginx_112='1.12.2'
nginx_114='1.14.2'
nginx_115='1.15.10'
nginx_116='1.16.1'
nginx_117='1.17.10'
nginx_118='1.18.0'
nginx_119='1.19.8'
nginx_120='1.20.2'
nginx_121='1.21.4'
openresty='1.19.9.1'

Root_Path=$(cat /var/bt_setupPath.conf)
Setup_Path=$Root_Path/server/nginx
run_path="/root"
Is_64bit=$(getconf LONG_BIT)

ARM_CHECK=$(uname -a|grep -E 'aarch64|arm|ARM')
LUAJIT_VER="2.0.4"
LUAJIT_INC_PATH="luajit-2.0"

if [ "${ARM_CHECK}" ];then 
	LUAJIT_VER="2.1.0-beta3"
	LUAJIT_INC_PATH="luajit-2.1"
fi

loongarch64Check=$(uname -a|grep loongarch64)
if [ "${loongarch64Check}" ];then
	wget -O nginx.sh ${download_Url}/install/0/loongarch64/nginx.sh && sh nginx.sh $1 $2
	exit;
fi

if [ -z "${cpuCore}" ]; then
	cpuCore="1"
fi

System_Lib(){
	if [ "${PM}" == "yum" ] || [ "${PM}" == "dnf" ] ; then
		Pack="gcc gcc-c++ curl curl-devel libtermcap-devel ncurses-devel libevent-devel readline-devel libuuid-devel"
		${PM} install ${Pack} -y
	elif [ "${PM}" == "apt-get" ]; then
		Pack="gcc g++ libgd3 libgd-dev libevent-dev libncurses5-dev libreadline-dev uuid-dev"
		${PM} install ${Pack} -y
	fi
}
Service_Add(){
	if [ "${PM}" == "yum" ] || [ "${PM}" == "dnf" ]; then
		chkconfig --add nginx
		chkconfig --level 2345 nginx on
	elif [ "${PM}" == "apt-get" ]; then
		update-rc.d nginx defaults
	fi 
}
Service_Del(){
 	if [ "${PM}" == "yum" ] || [ "${PM}" == "dnf" ]; then
		chkconfig --del nginx
		chkconfig --level 2345 nginx off
	elif [ "${PM}" == "apt-get" ]; then
		update-rc.d nginx remove
	fi
}
Set_Time(){
	BASH_DATE=$(stat nginx.sh|grep Modify|awk '{print $2}'|tr -d '-')
	SYS_DATE=$(date +%Y%m%d)
	[ "${SYS_DATE}" -lt "${BASH_DATE}" ] && date -s "$(curl https://www.bt.cn/api/index/get_date)"
}
Install_Jemalloc(){
	if [ ! -f '/usr/local/lib/libjemalloc.so' ]; then
		wget -O jemalloc-5.0.1.tar.bz2 ${download_Url}/src/jemalloc-5.0.1.tar.bz2
		tar -xvf jemalloc-5.0.1.tar.bz2
		cd jemalloc-5.0.1
		./configure
		make && make install
		ldconfig
		cd ..
		rm -rf jemalloc*
	fi
}
Install_LuaJIT()
{
	if [ ! -f '/usr/local/lib/libluajit-5.1.so' ] || [ ! -f "/usr/local/include/${LUAJIT_INC_PATH}/luajit.h" ];then
		wget -c -O LuaJIT-${LUAJIT_VER}.tar.gz ${download_Url}/install/src/LuaJIT-${LUAJIT_VER}.tar.gz -T 10
		tar xvf LuaJIT-${LUAJIT_VER}.tar.gz
		cd LuaJIT-${LUAJIT_VER}
		make linux
		make install
		cd ..
		rm -rf LuaJIT-*
		export LUAJIT_LIB=/usr/local/lib
		export LUAJIT_INC=/usr/local/include/${LUAJIT_INC_PATH}/
		ln -sf /usr/local/lib/libluajit-5.1.so.2 /usr/local/lib64/libluajit-5.1.so.2
		echo "/usr/local/lib" >> /etc/ld.so.conf
		ldconfig
	fi
}
Install_cjson()
{
	if [ ! -f /usr/local/lib/lua/5.1/cjson.so ];then
		wget -O lua-cjson-2.1.0.tar.gz $download_Url/install/src/lua-cjson-2.1.0.tar.gz -T 20
		tar xvf lua-cjson-2.1.0.tar.gz
		rm -f lua-cjson-2.1.0.tar.gz
		cd lua-cjson-2.1.0
		make
		make install
		cd ..
		rm -rf lua-cjson-2.1.0
	fi
}
Download_Src(){
	mkdir -p ${Setup_Path}
	cd ${Setup_Path}
	rm -rf ${Setup_Path}/src
	if [ "${version}" == "tengine" ] || [ "${version}" == "openresty" ]; then
		wget -O ${Setup_Path}/src.tar.gz ${download_Url}/src/${version}-${nginxVersion}.tar.gz -T20
		tar -xvf src.tar.gz
		mv ${version}-${nginxVersion} src
	else
		wget -O ${Setup_Path}/src.tar.gz ${download_Url}/src/nginx-${nginxVersion}.tar.gz -T20
		tar -xvf src.tar.gz
		tar -xvf src.tar.gz
		mv nginx-${nginxVersion} src
	fi

	cd src

	if [ -z "${GMSSL}" ];then
		TLSv13_NGINX=$(echo ${nginxVersion}|tr -d '.'|cut -c 1-3)
		if [ "${TLSv13_NGINX}" -ge "115" ] && [ "${TLSv13_NGINX}" != "181" ];then
			opensslVer="1.1.1m"
		else
			opensslVer="1.0.2u"
		fi
		wget -O openssl.tar.gz ${download_Url}/src/openssl-${opensslVer}.tar.gz
		tar -xvf openssl.tar.gz
		mv openssl-${opensslVer} openssl
		rm -f openssl.tar.gz
	else
		wget -O GmSSL-master.zip ${download_Url}/src/GmSSL-master.zip
		unzip GmSSL-master.zip 
		mv GmSSL-master openssl
		rm -f GmSSL-master.zip
	fi

	pcre_version="8.43"
    wget -O pcre-$pcre_version.tar.gz ${download_Url}/src/pcre-$pcre_version.tar.gz
	tar zxf pcre-$pcre_version.tar.gz

	wget -O ngx_cache_purge.tar.gz ${download_Url}/src/ngx_cache_purge-2.3.tar.gz
	tar -zxvf ngx_cache_purge.tar.gz
	mv ngx_cache_purge-2.3 ngx_cache_purge
	rm -f ngx_cache_purge.tar.gz

	wget -O nginx-sticky-module.zip ${download_Url}/src/nginx-sticky-module.zip
	unzip -o nginx-sticky-module.zip
	rm -f nginx-sticky-module.zip

	wget -O nginx-http-concat.zip ${download_Url}/src/nginx-http-concat-1.2.2.zip
	unzip -o nginx-http-concat.zip
	mv nginx-http-concat-1.2.2 nginx-http-concat
	rm -f nginx-http-concat.zip

	#lua_nginx_module
	LuaModVer="0.10.13"
	wget -c -O lua-nginx-module-${LuaModVer}.zip ${download_Url}/src/lua-nginx-module-${LuaModVer}.zip
	unzip -o lua-nginx-module-${LuaModVer}.zip
	mv lua-nginx-module-${LuaModVer} lua_nginx_module
	rm -f lua-nginx-module-${LuaModVer}.zip
	
	#ngx_devel_kit
	NgxDevelKitVer="0.3.1"
	wget -c -O ngx_devel_kit-${NgxDevelKitVer}.zip ${download_Url}/src/ngx_devel_kit-${NgxDevelKitVer}.zip
	unzip -o ngx_devel_kit-${NgxDevelKitVer}.zip
	mv ngx_devel_kit-${NgxDevelKitVer} ngx_devel_kit
	rm -f ngx_devel_kit-${NgxDevelKitVer}.zip	
	
	#nginx-dav-ext-module
	NgxDavVer="3.0.0"
	wget -c -O nginx-dav-ext-module-${NgxDavVer}.tar.gz ${download_Url}/src/nginx-dav-ext-module-${NgxDavVer}.tar.gz
	tar -xvf nginx-dav-ext-module-${NgxDavVer}.tar.gz
	mv nginx-dav-ext-module-${NgxDavVer} nginx-dav-ext-module
	rm -f nginx-dav-ext-module-${NgxDavVer}.tar.gz

	if [ "${Is_64bit}" = "64" ]; then
		if [ "${version}" == "1.15" ] || [ "${version}" == "1.17" ] || [ "${version}" == "tengine" ];then
			NGX_PAGESPEED_VAR="1.13.35.2"
			wget -O ngx-pagespeed-${NGX_PAGESPEED_VAR}.tar.gz ${download_Url}/src/ngx-pagespeed-${NGX_PAGESPEED_VAR}.tar.gz
			tar -xvf ngx-pagespeed-${NGX_PAGESPEED_VAR}.tar.gz
			mv ngx-pagespeed-${NGX_PAGESPEED_VAR} ngx-pagespeed
			rm -f ngx-pagespeed-${NGX_PAGESPEED_VAR}.tar.gz
		fi
	fi
}
Install_Configure(){
	Run_User="www"
	wwwUser=$(cat /etc/passwd|grep www)
	if [ "${wwwUser}" == "" ];then
		groupadd ${Run_User}
		useradd -s /sbin/nologin -g ${Run_User} ${Run_User}
	fi

	[ -f "/www/server/panel/install/nginx_prepare.sh" ] && . /www/server/panel/install/nginx_prepare.sh
	[ -f "/www/server/panel/install/nginx_configure.pl" ] && ADD_EXTENSION=$(cat /www/server/panel/install/nginx_configure.pl)
	if [ -f "/usr/local/lib/libjemalloc.so" ] && [ -z "${ARM_CHECK}" ];then
		jemallocLD="--with-ld-opt="-ljemalloc""
	fi

	if [ "${version}" == "1.8" ];then
		ENABLE_HTTP2="--with-http_spdy_module"
	else
		ENABLE_HTTP2="--with-http_v2_module --with-stream --with-stream_ssl_module --with-stream_ssl_preread_module"
	fi
	
	WebDav_NGINX=$(echo ${nginxVersion}|tr -d '.'|cut -c 1-3) 
	if [ "${WebDav_NGINX}" -ge "114" ] && [ "${WebDav_NGINX}" != "181" ];then	
		ENABLE_WEBDAV="--with-http_dav_module --add-module=${Setup_Path}/src/nginx-dav-ext-module"
	fi

	if [ "${version}" == "openresty" ];then
		ENABLE_LUA="--with-luajit"
	elif [ -z "${ARM_CHECK}" ] && [ -f "/usr/local/include/${LUAJIT_INC_PATH}/luajit.h" ];then
		ENABLE_LUA="--add-module=${Setup_Path}/src/ngx_devel_kit --add-module=${Setup_Path}/src/lua_nginx_module"
	fi

	name=nginx
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

	# if [ "${GMSSL}" ];then
	# 	sed -i "s/$OPENSSL\/.openssl\//$OPENSSL\//g" auto/lib/openssl/conf
	# fi

	export LUAJIT_LIB=/usr/local/lib
	export LUAJIT_INC=/usr/local/include/${LUAJIT_INC_PATH}/
	export LD_LIBRARY_PATH=/usr/local/lib/:$LD_LIBRARY_PATH 

	./configure --user=www --group=www --prefix=${Setup_Path} ${ENABLE_LUA} --add-module=${Setup_Path}/src/ngx_cache_purge --add-module=${Setup_Path}/src/nginx-sticky-module --with-openssl=${Setup_Path}/src/openssl --with-pcre=pcre-${pcre_version} ${ENABLE_HTTP2} --with-http_stub_status_module --with-http_ssl_module --with-http_image_filter_module --with-http_gzip_static_module --with-http_gunzip_module --with-ipv6 --with-http_sub_module --with-http_flv_module --with-http_addition_module --with-http_realip_module --with-http_mp4_module --with-ld-opt="-Wl,-E" --with-cc-opt="-Wno-error" ${jemallocLD} ${ENABLE_WEBDAV} ${ENABLE_NGX_PAGESPEED} ${ADD_EXTENSION} ${i_make_args}
	make -j${cpuCore}
}
Install_Nginx(){
	make install
	if [ "${version}" == "openresty" ];then
		ln -sf /www/server/nginx/nginx/html /www/server/nginx/html
		ln -sf /www/server/nginx/nginx/conf /www/server/nginx/conf
		ln -sf /www/server/nginx/nginx/logs /www/server/nginx/logs
		ln -sf /www/server/nginx/nginx/sbin /www/server/nginx/sbin
		if [ -d "/www/server/btwaf" ];then
			ln -s /www/server/nginx/lualib/resty /www/server/btwaf
		fi
	fi

	if [ ! -f "${Setup_Path}/sbin/nginx" ];then
		echo '========================================================'
		GetSysInfo
		echo -e "ERROR: nginx-${nginxVersion} installation failed.";
		echo -e "安装失败，请截图以上报错信息发帖至论坛www.bt.cn/bbs求助"
		rm -rf ${Setup_Path}
		exit 1;
	fi

	ln -sf ${Setup_Path}/sbin/nginx /usr/bin/nginx
	rm -f ${Setup_Path}/conf/nginx.conf

	cd ${Setup_Path}
	rm -f src.tar.gz
}
Update_Nginx(){
	if [ "${nginxVersion}" = "openresty" ]; then
		make install
		echo -e "done"
		nginx -v
		echo "${nginxVersion}" > ${Setup_Path}/version.pl
		rm -f ${Setup_Path}/version_check.pl
		exit;
	fi
	if [ ! -f ${Setup_Path}/src/objs/nginx ]; then
		echo '========================================================'
		GetSysInfo
		echo -e "ERROR: nginx-${nginxVersion} installation failed.";
		echo -e "升级失败，请截图以上报错信息发帖至论坛www.bt.cn/bbs求助"
		exit 1;
	fi
	sleep 1
	/etc/init.d/nginx stop
	mv -f ${Setup_Path}/sbin/nginx ${Setup_Path}/sbin/nginxBak
	\cp -rfp ${Setup_Path}/src/objs/nginx ${Setup_Path}/sbin/
	sleep 1
	/etc/init.d/nginx start
	rm -rf ${Setup_Path}/src
	nginx -v

	echo "${nginxVersion}" > ${Setup_Path}/version.pl
	rm -f ${Setup_Path}/version_check.pl
	if [ "${version}" == "tengine" ]; then
		echo "2.2.4(${tengine})" > ${Setup_Path}/version_check.pl
	fi
	exit
}
Set_Conf(){
	Default_Website_Dir=$Root_Path'/wwwroot/default'
	mkdir -p ${Default_Website_Dir}
	mkdir -p ${Root_Path}/wwwlogs
	mkdir -p ${Setup_Path}/conf/vhost
	mkdir -p /usr/local/nginx/logs
	mkdir -p ${Setup_Path}/conf/rewrite
	
	mkdir -p /www/wwwlogs/load_balancing/tcp
	mkdir -p /www/server/panel/vhost/nginx/tcp

	wget -O ${Setup_Path}/conf/nginx.conf ${download_Url}/conf/nginx1.conf -T20
	wget -O ${Setup_Path}/conf/pathinfo.conf ${download_Url}/conf/pathinfo.conf -T20
	wget -O ${Setup_Path}/conf/enable-php.conf ${download_Url}/conf/enable-php.conf -T20
	wget -O ${Setup_Path}/html/index.html ${download_Url}/error/index.html -T 5

	chmod 755 /www/server/nginx/
	chmod 755 /www/server/nginx/html/
	chmod 755 /www/wwwroot/
	chmod 644 /www/server/nginx/html/*
	
	cat > ${Root_Path}/server/panel/vhost/nginx/phpfpm_status.conf<<EOF
server {
	listen 80;
	server_name 127.0.0.1;
	allow 127.0.0.1;
	location /nginx_status {
		stub_status on;
		access_log off;
	}
EOF
	echo "" > /www/server/nginx/conf/enable-php-00.conf
	for phpV in 52 53 54 55 56 70 71 72 73 74 75 80 81
	do
		cat > ${Setup_Path}/conf/enable-php-${phpV}.conf<<EOF
	location ~ [^/]\.php(/|$)
	{
		try_files \$uri =404;
		fastcgi_pass  unix:/tmp/php-cgi-${phpV}.sock;
		fastcgi_index index.php;
		include fastcgi.conf;
		include pathinfo.conf;
	}
EOF
		cat >> ${Root_Path}/server/panel/vhost/nginx/phpfpm_status.conf<<EOF
	location /phpfpm_${phpV}_status {
		fastcgi_pass unix:/tmp/php-cgi-${phpV}.sock;
		include fastcgi_params;
		fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
	}
EOF
	done
	echo \} >> ${Root_Path}/server/panel/vhost/nginx/phpfpm_status.conf
	
	cat > ${Setup_Path}/conf/proxy.conf<<EOF
proxy_temp_path ${Setup_Path}/proxy_temp_dir;
proxy_cache_path ${Setup_Path}/proxy_cache_dir levels=1:2 keys_zone=cache_one:20m inactive=1d max_size=5g;
client_body_buffer_size 512k;
proxy_connect_timeout 60;
proxy_read_timeout 60;
proxy_send_timeout 60;
proxy_buffer_size 32k;
proxy_buffers 4 64k;
proxy_busy_buffers_size 128k;
proxy_temp_file_write_size 128k;
proxy_next_upstream error timeout invalid_header http_500 http_503 http_404;
proxy_cache cache_one;
EOF
	
	cat > ${Setup_Path}/conf/luawaf.conf<<EOF
lua_shared_dict limit 10m;
lua_package_path "/www/server/nginx/waf/?.lua";
init_by_lua_file  /www/server/nginx/waf/init.lua;
access_by_lua_file /www/server/nginx/waf/waf.lua;
EOF

	mkdir -p /www/wwwlogs/waf
	chown www.www /www/wwwlogs/waf
	chmod 744 /www/wwwlogs/waf
	mkdir -p /www/server/panel/vhost
	wget -O waf.zip ${download_Url}/install/waf/waf.zip
	unzip -o waf.zip -d $Setup_Path/ > /dev/null
	if [ ! -d "/www/server/panel/vhost/wafconf" ];then
		mv $Setup_Path/waf/wafconf /www/server/panel/vhost/wafconf
	fi

	sed -i "s#include vhost/\*.conf;#include /www/server/panel/vhost/nginx/\*.conf;#" ${Setup_Path}/conf/nginx.conf
	sed -i "s#/www/wwwroot/default#/www/server/phpmyadmin#" ${Setup_Path}/conf/nginx.conf
	sed -i "/pathinfo/d" ${Setup_Path}/conf/enable-php.conf
	sed -i "s/#limit_conn_zone.*/limit_conn_zone \$binary_remote_addr zone=perip:10m;\n\tlimit_conn_zone \$server_name zone=perserver:10m;/" ${Setup_Path}/conf/nginx.conf
	sed -i "s/mime.types;/mime.types;\n\t\tinclude proxy.conf;\n/" ${Setup_Path}/conf/nginx.conf
	#if [ "${nginx_version}" == "1.12.2" ] || [ "${nginx_version}" == "openresty" ] || [ "${nginx_version}" == "1.14.2" ];then
	sed -i "s/mime.types;/mime.types;\n\t\t#include luawaf.conf;\n/" ${Setup_Path}/conf/nginx.conf
	#fi

	PHPVersion=""
	for phpVer in 52 53 54 55 56 70 71 72 73 74 80;
	do
		if [ -d "/www/server/php/${phpVer}/bin" ]; then
			PHPVersion=${phpVer}
		fi
	done

	if [ "${PHPVersion}" ];then
		\cp -r -a ${Setup_Path}/conf/enable-php-${PHPVersion}.conf ${Setup_Path}/conf/enable-php.conf
	fi

	AA_PANEL_CHECK=$(cat /www/server/panel/config/config.json|grep "English")
	if [ "${AA_PANEL_CHECK}" ];then
		#\cp -rf /www/server/panel/data/empty.html /www/server/nginx/html/index.html
		wget -O /www/server/nginx/html/index.html ${download_Url}/error/index_en_nginx.html -T 5
		chmod 644 /www/server/nginx/html/index.html
		wget -O /www/server/panel/vhost/nginx/0.default.conf ${download_Url}/conf/nginx/en.0.default.conf
	fi   

	wget -O /etc/init.d/nginx ${download_Url}/init/nginx.init -T 5
	chmod +x /etc/init.d/nginx
}
Set_Version(){
	if [ "${version}" == "tengine" ]; then
		echo "-Tengine2.2.3" > ${Setup_Path}/version.pl
		echo "2.2.4(${tengine})" > ${Setup_Path}/version_check.pl
	elif [ "${version}" == "openresty" ]; then
		echo "openresty" > ${Setup_Path}/version.pl
		echo "openresty-${openresty}" > ${Setup_Path}/version_check.pl
	else
		echo "${nginxVersion}" > ${Setup_Path}/version.pl
	fi
	
	if [ "${GMSSL}" ];then
		echo "1.18国密版" > ${Setup_Path}/version_check.pl
	fi
}

Uninstall_Nginx()
{
	if [ -f "/etc/init.d/nginx" ];then
		Service_Del
		/etc/init.d/nginx stop
		rm -f /etc/init.d/nginx
	fi
	[ -f "${Setup_Path}/rpm.pl" ] && yum remove bt-$(cat ${Setup_Path}/rpm.pl) -y
	[ -f "${Setup_Path}/deb.pl" ] && apt-get remove bt-$(cat ${Setup_Path}/deb.pl) -y
	pkill -9 nginx
	rm -rf ${Setup_Path}
}

actionType=$1
version=$2

if [ "${actionType}" == "uninstall" ]; then
	Service_Del
	Uninstall_Nginx
else
	case "${version}" in
		'1.10')
		nginxVersion=${nginx_112}
		;;
		'1.12')
		nginxVersion=${nginx_112}
		;;
		'1.14')
		nginxVersion=${nginx_114}
		;;		
		'1.15')
		nginxVersion=${nginx_115}
		;;
		'1.16')
		nginxVersion=${nginx_116}
		;;
		'1.17')
		nginxVersion=${nginx_117}
		;;
		'1.18')
		nginxVersion=${nginx_118}
		;;
		'1.18.gmssl')
		nginxVersion=${nginx_118}
		GMSSL="True"
		;;
		'1.19')
		nginxVersion=${nginx_119}
		;;
		'1.20')
		nginxVersion=${nginx_120}
		;;
		'1.21')
		nginxVersion=${nginx_121}
		;;
		'1.8')
		nginxVersion=${nginx_108}
		;;
		'openresty')
		nginxVersion=${openresty}
		;;
		*)
		nginxVersion=${tengine}
		version="tengine"
		;;
	esac
	if [ "${actionType}" == "install" ];then
		if [ -f "/www/server/nginx/sbin/nginx" ]; then
			Uninstall_Nginx
		fi
		System_Lib
		if [ -z "${ARM_CHECK}" ];then
			Install_Jemalloc
			Install_LuaJIT
			Install_cjson
		fi
		Download_Src
		Install_Configure
		Install_Nginx
		Set_Conf
		Set_Version
		Service_Add
		/etc/init.d/nginx start
	elif [ "${actionType}" == "update" ];then
		Download_Src
		Install_Configure
		Update_Nginx
	fi
fi

