#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
redis_version=6.2.6
runPath=/root
public_file=/www/server/panel/install/public.sh

NODE_URL='http://download.bt.cn';
download_Url=$NODE_URL

if [ -z "${cpuCore}" ]; then
	cpuCore="1"
fi

Error_Msg(){
	if [ "${actionType}" == "install" ];then
		AC_TYPE="安装"
	elif [ "${actionType}" == "update" ]; then
		AC_TYPE="升级"
	fi

	EN_CHECK=$(cat /www/server/panel/config/config.json |grep English)
	echo '========================================================'
	GetSysInfo
	echo -e "ERROR: redis-${redis_version} ${actionType} failed.";
	if [ "${EN_CHECK}" ];then
		echo -e "Please submit to https://forum.aapanel.com for help"
	else 
		echo -e "${AC_TYPE}失败，请截图以上报错信息发帖至论坛www.bt.cn/bbs求助"
	fi
	exit 1;
}

System_Lib(){
	if [ "${PM}" == "yum" ] || [ "${PM}" == "dnf" ] ; then
		Pack="sudo"
		${PM} install ${Pack} -y
	elif [ "${PM}" == "apt-get" ]; then
		Pack="sudo"
		${PM} install ${Pack} -y
	fi

}
Service_Add(){
	if [ -f "/usr/bin/yum" ];then
		chkconfig --add redis
		chkconfig --level 2345 redis on
	elif [ -f "/usr/bin/apt" ]; then
		apt-get install sudo -y	
		update-rc.d redis defaults
	fi
}
Service_Del(){
	if [ -f "/usr/bin/yum" ];then
		chkconfig --level 2345 redis off
	elif [ -f "/usr/bin/apt" ]; then
		update-rc.d redis remove
	fi
}
Gcc_Version_Check(){
	if [ "${PM}" == "yum" ];then
		Centos7Check=$(cat /etc/redhat-release | grep ' 7.' | grep -iE 'centos|Red Hat')
		gccV=$(gcc -v 2>&1|grep "gcc version"|awk '{printf("%d",$3)}')
		sysType=$(uname -a|grep x86_64)
		armType=$(uname -a|grep aarch64)
		if [ "${Centos7Check}" ];then
			yum install centos-release-scl-rh -y
			yum install devtoolset-7-gcc devtoolset-7-gcc-c++ -y
			if [ "${armType}" ];then
				yum install devtoolset-7-libatomic-devel -y
			fi
			if [ -f "/opt/rh/devtoolset-7/root/usr/bin/gcc" ] && [ "${sysType}" != "${armType}" ];then
				export CC=/opt/rh/devtoolset-7/root/usr/bin/gcc
			else
				redis_version="5.0.8"
			fi
		elif [ "${gccV}" -le "5" ];then
			redis_version="5.0.8"
		fi
	fi
}
ext_Path(){
	case "${version}" in 
		'53')
		extFile='/www/server/php/53/lib/php/extensions/no-debug-non-zts-20090626/redis.so'
		;;
		'54')
		extFile='/www/server/php/54/lib/php/extensions/no-debug-non-zts-20100525/redis.so'
		;;
		'55')
		extFile='/www/server/php/55/lib/php/extensions/no-debug-non-zts-20121212/redis.so'
		;;
		'56')
		extFile='/www/server/php/56/lib/php/extensions/no-debug-non-zts-20131226/redis.so'
		;;
		'70')
		extFile='/www/server/php/70/lib/php/extensions/no-debug-non-zts-20151012/redis.so'
		;;
		'71')
		extFile='/www/server/php/71/lib/php/extensions/no-debug-non-zts-20160303/redis.so'
		;;
		'72')
		extFile='/www/server/php/72/lib/php/extensions/no-debug-non-zts-20170718/redis.so'
		;;
		'73')
		extFile='/www/server/php/73/lib/php/extensions/no-debug-non-zts-20180731/redis.so'
		;;
		'74')
		extFile='/www/server/php/74/lib/php/extensions/no-debug-non-zts-20190902/redis.so'
		;;
		'80')
		extFile='/www/server/php/80/lib/php/extensions/no-debug-non-zts-20200930/redis.so'
		;;
		'81')
		extFile='/www/server/php/81/lib/php/extensions/no-debug-non-zts-20210902/redis.so'
		;;
	esac
}
Install_Redis()
{
	groupadd redis
	useradd -g redis -s /sbin/nologin redis
	if [ ! -f '/www/server/redis/src/redis-server' ];then
		rm -rf /www/server/redis
		cd /www/server

		wget -O redis-$redis_version.tar.gz $download_Url/src/redis-$redis_version.tar.gz
		tar zxvf redis-$redis_version.tar.gz
		mv redis-$redis_version redis
		cd redis
		make -j ${cpuCore}

		[ ! -f "/www/server/redis/src/redis-server" ] && Error_Msg
		
		VM_OVERCOMMIT_MEMORY=$(cat /etc/sysctl.conf|grep vm.overcommit_memory)
		NET_CORE_SOMAXCONN=$(cat /etc/sysctl.conf|grep net.core.somaxconn)
		if [ -z "${VM_OVERCOMMIT_MEMORY}" ] && [ -z "${NET_CORE_SOMAXCONN}" ];then
			echo "vm.overcommit_memory = 1" >> /etc/sysctl.conf
			echo "net.core.somaxconn = 1024" >> /etc/sysctl.conf
			sysctl -p
		fi
		

		ln -sf /www/server/redis/src/redis-cli /usr/bin/redis-cli
		chown -R redis.redis /www/server/redis
		#v=`cat /www/server/panel/class/common.py|grep "g.version = "|awk -F "'" '{print $2}'|awk -F "." '{print $1}'`
		v=`cat /www/server/panel/class/common.py|grep -E ".version = [\"|\']"|awk -F '[\"\47]+' '{print $2}'|awk -F '.' '{print $1}'`
		if [ "$v" -ge "6" ];then
			pluginPath=/www/server/panel/plugin/redis
			mkdir -p $pluginPath
			grep "English" /www/server/panel/config/config.json
			if [ "$?" -ne 0 ];then
				wget -O $pluginPath/redis_main.py $download_Url/install/plugin/redis/redis_main.py -T 5
				wget -O $pluginPath/index.html $download_Url/install/plugin/redis/index.html -T 5
				wget -O $pluginPath/info.json $download_Url/install/plugin/redis/info.json -T 5
				wget -O $pluginPath/icon.png $download_Url/install/plugin/redis/icon.png -T 5
			else
				wget -O $pluginPath/redis_main.py $download_Url/install/plugin/redis_en/redis_main.py -T 5
				wget -O $pluginPath/index.html $download_Url/install/plugin/redis_en/index.html -T 5
				wget -O $pluginPath/info.json $download_Url/install/plugin/redis_en/info.json -T 5
				wget -O $pluginPath/icon.png $download_Url/install/plugin/redis_en/icon.png -T 5
			fi
		fi
	
		sed -i 's/dir .\//dir \/www\/server\/redis\//g' /www/server/redis/redis.conf

		if [ -d "/www/server/panel/BTPanel" ]; then
			wget -O /etc/init.d/redis ${download_Url}/init/init7.redis
			wget -O /www/server/redis/redis.conf ${download_Url}/conf/redis.conf
		else
			wget -O /etc/init.d/redis ${download_Url}/init/init5.redis
		fi
	
		ARM_CHECK=$(uname -a|grep aarch64)
		if [ "${ARM_CHECK}" ];then
			echo "ignore-warnings ARM64-COW-BUG" >> /www/server/redis/redis.conf
		fi 
	
		chmod +x /etc/init.d/redis 
		/etc/init.d/redis start
		rm -f /www/server/redis-$redis_version.tar.gz
		cd $runPath
		echo $redis_version > /www/server/redis/version.pl
	fi
	
	if [ ! -d /www/server/php/$version ];then
		return;
	fi
	
	if [ ! -f "/www/server/php/$version/bin/php-config" ];then
		echo "php-$vphp 未安装,请选择其它版本!"
		echo "php-$vphp not install, Plese select other version!"
		return
	fi
	
	isInstall=`cat /www/server/php/$version/etc/php.ini|grep 'redis.so'`
	if [ "${isInstall}" != "" ];then
		echo "php-$vphp 已安装过Redis,请选择其它版本!"
		echo "php-$vphp not install, Plese select other version!"
		return
	fi
	

	if [ ! -f "${extFile}" ];then		
		if [ "${version}" == "52" ];then
			rVersion='2.2.7'
		elif [ "${version}" -ge "70" ];then
			rVersion='5.3.4'
		else
			rVersion='4.3.0'
		fi
		
		wget $download_Url/src/redis-$rVersion.tgz -T 5
		tar zxvf redis-$rVersion.tgz
		rm -f redis-$rVersion.tgz
		cd redis-$rVersion
		/www/server/php/$version/bin/phpize
		./configure --with-php-config=/www/server/php/$version/bin/php-config
		make && make install
		cd ../
		rm -rf redis-$rVersion*
	fi
	
	if [ ! -f "${extFile}" ];then
		echo 'error';
		exit 0;
	fi
	
	echo -e "\n[redis]\nextension = ${extFile}\n" >> /www/server/php/$version/etc/php.ini

	/etc/init.d/php-fpm-$version reload
	echo '==============================================='
	echo 'successful!'
}

Uninstall_Redis()
{
	if [ ! -d /www/server/php/$version/bin ];then
		pkill -9 redis
		rm -f /var/run/redis_6379.pid
		Service_Del
		rm -f /usr/bin/redis-cli
		rm -f /etc/init.d/redis
		rm -rf /www/server/redis
		rm -rf /www/server/panel/plugin/redis

		return;
	fi
	if [ ! -f "/www/server/php/$version/bin/php-config" ];then
		echo "php-$vphp 未安装,请选择其它版本!"
		echo "php-$vphp not install, Plese select other version!"
		return
	fi
	
	isInstall=`cat /www/server/php/$version/etc/php.ini|grep 'redis.so'`
	if [ "${isInstall}" = "" ];then
		echo "php-$vphp 未安装Redis,请选择其它版本!"
		echo "php-$vphp not install Redis, Plese select other version!"
		return
	fi
	
	sed -i '/redis.so/d' /www/server/php/$version/etc/php.ini
	sed -i '/\[redis\]/d' /www/server/php/$version/etc/php.ini
	
	/etc/init.d/php-fpm-$version reload
	echo '==============================================='
	echo 'successful!'
}
Update_redis()
{ 
	Centos6Check=$(cat /etc/redhat-release | grep ' 6.' | grep -iE 'centos|Red Hat')
	if [ "${redis_version}" == "5.0.8" ] || [ "${Centos6Check}" ];then
		echo "检测此服务器达不到redis-6.2.1升级要求"
		echo "中断升级"
		echo "不影响当前运行版本"
		exit 0
	fi

	# REDIS_VER=$(redis-cli -v|awk '{print $2}'|cut -d'.' -f1)
	# if [ "${REDIS_VER}" == "5" ];then
	# 	echo "reids 5.x 无法升级至6.x"
	# 	echo "如需使用请备份redis数据 卸载重装redis即可安装6.x版本"
	# 	exit 1
	# fi

	REDIS_CONF="/www/server/redis/redis.conf"
	REDIS_PORT=$(cat ${REDIS_CONF} |grep port|grep -v '#'|awk '{print $2}')
	REDIS_PASS=$(cat ${REDIS_CONF} |grep requirepass|grep -v '#'|awk '{print $2}')
	REDIS_HOST=$(cat ${REDIS_CONF} |grep bind|grep -v '#'|awk '{print $2}')
	REDIS_DIR=$(cat ${REDIS_CONF} |grep dir|grep -v '#'|awk '{print $2}')

	cd /www/server
	rm -rf /www/server/redis2
	
	wget -O redis-$redis_version.tar.gz $download_Url/src/redis-$redis_version.tar.gz
	tar zxvf redis-$redis_version.tar.gz
	rm -f redis-$redis_version.tar.gz
	mv redis-$redis_version redis2
	cd redis2
	make -j ${cpuCore}
	
	[ ! -f "/www/server/redis2/src/redis-server" ] && Error_Msg

	if [ -f "${REDIS_DIR}dump.rdb" ]; then
		\cp -rf ${REDIS_DIR}dump.rdb ${REDIS_DIR}dumpBak.rdb
		if [ -z "${REDIS_PASS}" ]; then
			/www/server/redis/src/redis-cli -p ${REDIS_PORT} <<EOF
SAVE
EOF
		else
			/www/server/redis/src/redis-cli -p ${REDIS_PORT} -a ${REDIS_PASS} <<EOF
SAVE
EOF
		fi
	fi

	/etc/init.d/redis stop
	sleep 1
	cd ..
	
	[ -f "/www/server/redis/dump.rdb" ] && \cp -rf /www/server/redis/dump.rdb /www/server/redis2/dump.rdb
	\cp -rf /www/server/redis/redis.conf /www/server/redis2/redis.conf

	if [ -d "/www/server/redisBak" ]; then
		tar czvf /www/backup/redisBak$(date +%Y%m%d).tar.gz /www/server/redisBak
		rm -rf /www/server/redisBak 
	fi

	mv /www/server/redis /www/server/redisBak
	mv redis2 redis
	chown -R redis.redis /www/server/redis
	rm -f /usr/bin/redis-cli
	ln -sf /www/server/redis/src/redis-cli /usr/bin/redis-cli
	/etc/init.d/redis start
	rm -f /www/server/redis/version_check.pl
	echo $redis_version > /www/server/redis/version.pl
}

actionType=$1
version=$2
vphp=${version:0:1}.${version:1:1}
if [ "$actionType" == 'install' ];then
	System_Lib
	ext_Path
	Gcc_Version_Check
	Install_Redis
	Service_Add
elif [ "$actionType" == 'uninstall' ];then
	Uninstall_Redis
elif [ "${actionType}" == "update" ]; then
	Gcc_Version_Check
	Update_redis
fi

