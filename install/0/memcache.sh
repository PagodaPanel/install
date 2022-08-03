#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

memcachedVer="1.6.6"
memcachedPhpVer="3.1.3"

Centos6Check=$(cat /etc/redhat-release|grep ' 6.'|grep -i centos)
if [ "${Centos6Check}" ];then
	memcachedVer="1.5.22"
fi

public_file=/www/server/panel/install/public.sh

NODE_URL='http://download.bt.cn';
download_Url=$NODE_URL

srcPath='/root';

System_Lib(){
	if [ "${PM}" == "yum" ] || [ "${PM}" == "dnf" ] ; then
		removePack="libmemcached libmemcached-devel"
		installPack="cyrus-sasl cyrus-sasl-devel libevent libevent-devel"
	elif [ "${PM}" == "apt-get" ]; then
		removePack="memcached"
		installPack="libsasl2-2 libsasl2-dev libevent-dev"
	fi
	[ "${removePack}" != "" ] && ${PM} remove ${removePack} -y
	[ "${installPack}" != "" ] && ${PM} install ${installPack} -y
}

Service_Add(){
	if [ "${PM}" == "yum" ] || [ "${PM}" == "dnf" ]; then
		chkconfig --add memcached
		chkconfig --level 2345 memcached on
	elif [ "${PM}" == "apt-get" ]; then
		update-rc.d memcached defaults
	fi 
}
Service_Del(){
 	if [ "${PM}" == "yum" ] || [ "${PM}" == "dnf" ]; then
		chkconfig --del memcached
		chkconfig --level 2345 memcached off
	elif [ "${PM}" == "apt-get" ]; then
		update-rc.d memcached remove
	fi
}
Ext_Path(){
	case "${version}" in 
		'52')
		extFile='/www/server/php/52/lib/php/extensions/no-debug-non-zts-20060613/memcache.so'
		;;
		'53')
		extFile='/www/server/php/53/lib/php/extensions/no-debug-non-zts-20090626/memcache.so'
		;;
		'54')
		extFile='/www/server/php/54/lib/php/extensions/no-debug-non-zts-20100525/memcache.so'
		;;
		'55')
		extFile='/www/server/php/55/lib/php/extensions/no-debug-non-zts-20121212/memcache.so'
		;;
		'56')
		extFile='/www/server/php/56/lib/php/extensions/no-debug-non-zts-20131226/memcache.so'
		;;
		'70')
		extFile='/www/server/php/70/lib/php/extensions/no-debug-non-zts-20151012/memcache.so'
		;;
		'71')
		extFile='/www/server/php/71/lib/php/extensions/no-debug-non-zts-20160303/memcache.so'
		;;
		'72')
		extFile='/www/server/php/72/lib/php/extensions/no-debug-non-zts-20170718/memcache.so'
		;;
		'73')
		extFile='/www/server/php/73/lib/php/extensions/no-debug-non-zts-20180731/memcache.so'
		;;
		'74')
		extFile='/www/server/php/74/lib/php/extensions/no-debug-non-zts-20190902/memcache.so'
		;;
		'80')
		extFile='/www/server/php/80/lib/php/extensions/no-debug-non-zts-20200930/memcache.so'
		;;
	esac
}

Install_Memcached()
{	
	if [ ! -f "/usr/local/memcached/bin/memcached" ];then
		groupadd memcached
		useradd -s /sbin/nologin -g memcached memcached
		cd $srcPath
		wget $download_Url/src/memcached-${memcachedVer}.tar.gz -T 5
		tar -xzf memcached-${memcachedVer}.tar.gz
		cd memcached-${memcachedVer}
		./configure --prefix=/usr/local/memcached
		make -j ${cpuCore} 
		make install
		ln -sf /usr/local/memcached/bin/memcached /usr/bin/memcached
		wget -O /etc/init.d/memcached $download_Url/init/init.d.memcached -T 5
		chmod +x /etc/init.d/memcached
		/etc/init.d/memcached start
		
		cd $srcPath
		rm -rf memcached*
	fi
	
	if [ -f "/usr/local/libmemcached/lib/libmemcached.so" ]; then
		LIB_MEMCACHED_SASL=$(ldd /usr/local/libmemcached/lib/libmemcached.so|grep sasl)
		[ -z "${LIB_MEMCACHED_SASL}" ] && rm -rf /usr/local/libmemcached
	fi

	if [ ! -f "/usr/local/libmemcached/lib/libmemcached.so" ];then
		cd $srcPath
		wget $download_Url/src/libmemcached-1.0.18.tar.gz -T 5
		tar -zxf libmemcached-1.0.18.tar.gz
		cd libmemcached-1.0.18
		./configure --prefix=/usr/local/libmemcached --with-memcached
		make && make install
		cd ../
		rm -rf libmemcached*
	fi

	if [ ! -d /www/server/php/$version ];then
		return;
	fi
	
	if [ ! -f "/www/server/php/$version/bin/php-config" ];then
		echo "php-$vphp 未安装,请选择其它版本!"
		echo "php-$vphp not install, Plese select other version!"
		return
	fi
	
	isInstall=`cat /www/server/php/$version/etc/php.ini|grep 'memcached.so'`
	if [ "${isInstall}" != "" ];then
		echo "php-$vphp 已安装过memcached,请选择其它版本!"
		echo "php-$vphp is already install memcached, Plese select other version!"
		return
	fi

	if [ ! -f "${extFile}" ];then
		if [ "${version}" -ge "70" ];then
			memcachedPHPVER="4.0.5.2"
			[ "${version}" == "80" ] && memcachedPHPVER="8.0"
			wget -c $download_Url/src/memcache-${memcachedPHPVER}.tgz -T 5
			tar -xvf memcache-${memcachedPHPVER}.tgz
			cd memcache-${memcachedPHPVER}
			/www/server/php/$version/bin/phpize
			./configure  --with-php-config=/www/server/php/$version/bin/php-config
			make && make install
			cd ..
			rm -rf memcache-${memcachedPHPVER}
			rm -f memcache-${memcachedPHPVER}.tgz
		else
			wget -c $download_Url/src/memcache-2.2.7.tgz -T 5
			tar -zxvf memcache-2.2.7.tgz
			cd memcache-2.2.7
			/www/server/php/$version/bin/phpize
			./configure  --with-php-config=/www/server/php/$version/bin/php-config --enable-memcache --with-zlib-dir
			make && make install
			cd ..
			rm -rf memcache*
		fi
	fi
	
	if [ ! -f "$extFile" ];then
		echo 'Install failed';
		exit 0;
	fi
	
	echo "extension=memcache.so" >> /www/server/php/$version/etc/php.ini
	/etc/init.d/php-fpm-$version reload
	echo '==============================================='
	echo 'successful!'
	/www/server/php/${version}/bin/php -m|grep memcached
}


Uninstall_Memcached()
{
	
	if [ ! -f "/www/server/php/$version/bin/php-config" ];then
		echo "php-$vphp 未安装,请选择其它版本!"
		echo "php-$vphp not install, Plese select other version!"
		return
	fi
	
	isInstall=`cat /www/server/php/$version/etc/php.ini|grep 'memcache.so'`
	if [ "${isInstall}" = "" ];then
		echo "php-$vphp 未安装memcache,请选择其它版本!"
		echo "php-$vphp not install memcache, Plese select other version!"
		return
	fi

	rm -f ${extFile}
	sed -i '/memcache.so/d'  /www/server/php/$version/etc/php.ini
	/etc/init.d/php-fpm-$version reload
	echo '==============================================='
	echo 'successful!'
}

actionType=$1
version=$2
vphp=${version:0:1}.${version:1:1}
if [ "$actionType" == 'install' ];then
	System_Lib
	Ext_Path
	Install_Memcached
	Service_Add
elif [ "$actionType" == 'uninstall' ];then
	Ext_Path
	Uninstall_Memcached
elif [ "${actionType}" == "update" ]; then
	Update_memcached
fi


