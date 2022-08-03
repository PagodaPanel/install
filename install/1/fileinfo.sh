#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

Install_Fileinfo()
{
    if [ ! -f "/www/server/php/$version/bin/php-config" ];then
        echo "php-$vphp 未安装,请选择其它版本!"
        echo "php-$vphp not install, Plese select other version!"
        return
    fi
    
    isInstall=`cat /www/server/php/$version/etc/php.ini|grep 'fileinfo.so'`
    if [ "${isInstall}" != "" ];then
        echo "php-$vphp 已安装过Fileinfo,请选择其它版本!"
        echo "php-$vphp not install, Plese select other version!"
        return
    fi
    
    if [ ! -d "/www/server/php/$version/src/ext/fileinfo" ];then
        public_file=/www/server/panel/install/public.sh

        NODE_URL='http://download.bt.cn';
        download_Url=$NODE_URL

        mkdir -p /www/server/php/$version/src
        wget -O ext-$version.zip $download_Url/install/ext/ext-$version.zip
        unzip -o ext-$version.zip -d /www/server/php/$version/src/ > /dev/null
        mv /www/server/php/$version/src/ext-$version /www/server/php/$version/src/ext
        rm -f ext-$version.zip
    fi
    
    case "${version}" in 
        '52')
            extFile='/www/server/php/52/lib/php/extensions/no-debug-non-zts-20060613/fileinfo.so'
        ;;
        '53')
            extFile='/www/server/php/53/lib/php/extensions/no-debug-non-zts-20090626/fileinfo.so'
        ;;
        '54')
            extFile='/www/server/php/54/lib/php/extensions/no-debug-non-zts-20100525/fileinfo.so'
        ;;
        '55')
            extFile='/www/server/php/55/lib/php/extensions/no-debug-non-zts-20121212/fileinfo.so'
        ;;
        '56')
            extFile='/www/server/php/56/lib/php/extensions/no-debug-non-zts-20131226/fileinfo.so'
        ;;
        '70')
            extFile='/www/server/php/70/lib/php/extensions/no-debug-non-zts-20151012/fileinfo.so'
        ;;
        '71')
            extFile='/www/server/php/71/lib/php/extensions/no-debug-non-zts-20160303/fileinfo.so'
        ;;
        '72')
            extFile='/www/server/php/72/lib/php/extensions/no-debug-non-zts-20170718/fileinfo.so'
        ;;
        '73')
            extFile='/www/server/php/73/lib/php/extensions/no-debug-non-zts-20180731/fileinfo.so'
        ;;
        '74')
            extFile='/www/server/php/74/lib/php/extensions/no-debug-non-zts-20190902/fileinfo.so'
        ;;
        '80')
            extFile='/www/server/php/80/lib/php/extensions/no-debug-non-zts-20200930/fileinfo.so'
        ;;
        '81')
            extFile='/www/server/php/81/lib/php/extensions/no-debug-non-zts-20210902/fileinfo.so'
        ;;
    esac
    
    Centos7Check=$(cat /etc/redhat-release|grep ' 7.'|grep -i centos)
    if [ "${Centos7Check}" ] && [ "${version}" -ge "80" ];then
        yum install centos-release-scl-rh -y
        yum install devtoolset-7-gcc devtoolset-7-gcc-c++ -y
        yum install cmake3 -y
        cmakeV="cmake3"
        export CC=/opt/rh/devtoolset-7/root/usr/bin/gcc
        export CXX=/opt/rh/devtoolset-7/root/usr/bin/g++
    fi
    
    if [ ! -f "${extFile}" ];then
        cd /www/server/php/$version/src/ext/fileinfo
        /www/server/php/$version/bin/phpize
        ./configure --with-php-config=/www/server/php/$version/bin/php-config
        if [ "${Centos7Check}" ] && [ "${version}" -ge "80" ];then
            sed -i "s#CFLAGS = -g -O2#CFLAGS = -std=c99 -g#g" Makefile
        fi
        if [ "${version}" -ge "80" ];then
            sed -i "s#CFLAGS = -g -O2#CFLAGS = -std=c99 -g -O2#g" Makefile
        fi
        # if [ "${Centos7Check}" ] && [ "${version}" -ge "81" ];then
        #     sed -i "s#CFLAGS = -g -O2#CFLAGS = -std=c99 -g#g" Makefile
        # fi
        make && make install
    fi
    
    if [ ! -f "${extFile}" ];then
        echo 'error';
        exit 0;
    fi

    echo -e "extension = $extFile" >> /www/server/php/$version/etc/php.ini
    if [ -f /www/server/php/$version/etc/php-cli.ini ];then
        echo -e "extension = $extFile" >> /www/server/php/$version/etc/php-cli.ini
    fi
    service php-fpm-$version reload
    echo '==============================================='
    echo 'successful!'
}

Uninstall_Fileinfo()
{
    if [ ! -f "/www/server/php/$version/bin/php-config" ];then
        echo "php-$vphp 未安装,请选择其它版本!"
        echo "php-$vphp not install, Plese select other version!"
        return
    fi
    
    isInstall=`cat /www/server/php/$version/etc/php.ini|grep 'fileinfo.so'`
    if [ "${isInstall}" = "" ];then
        echo "php-$vphp 未安装Fileinfo,请选择其它版本!"
        echo "php-$vphp not install Fileinfo, Plese select other version!"
        return
    fi

    sed -i '/fileinfo.so/d' /www/server/php/$version/etc/php.ini
    if [ -f /www/server/php/$version/etc/php-cli.ini ];then
        sed -i '/fileinfo.so/d' /www/server/php/$version/etc/php-cli.ini
    fi

    service php-fpm-$version reload
    echo '==============================================='
    echo 'successful!'
}

actionType=$1
version=$2
vphp=${version:0:1}.${version:1:1}
if [ "$actionType" == 'install' ];then
    Install_Fileinfo
elif [ "$actionType" == 'uninstall' ];then
    Uninstall_Fileinfo
fi
