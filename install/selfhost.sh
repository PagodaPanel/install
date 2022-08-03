#!/bin/bash

BTDIR='/www/server/panel'
ZIPFILE=''
SERVER='http://YOUR-BTCLOUD-SERVER'  # https://github.com/flucont/btcloud

while [ $# -gt 0 ]; do
    case $1 in
        -d|--dir)
            BTDIR=${2%/}
            shift
            ;;
        -s|--server)
            SERVER=$2
            shift
            ;;
        -z|--zipfile)
            ZIPFILE=$2
            shift
            ;;
        *)
            echo "Unknown option: \"$1\""
            exit
    esac
    shift
done

if  [ -z "$BTDIR" ] ;then
    echo "Program dir error!"
    exit
fi

Replace(){
    echo "Server: $SERVER"
    echo "Program dir: $BTDIR"

    rm -rf ${BTDIR}/class/*.so
    mv -f ${BTDIR}/class/PluginLoader-bak.py ${BTDIR}/class/PluginLoader.py
    sed -i "s|http://www.example.com|${SERVER}|g" ${BTDIR}/class/PluginLoader.py

    grep -rl --include=\*.py 'https://api.bt.cn' ${BTDIR}/class | xargs -I @ sed -i "s|https://api.bt.cn|${SERVER}|g" @

    grep -rl --include=\*.py --exclude=clearModel.py 'https://www.bt.cn/api' ${BTDIR}/class | xargs -I @ sed -i "s|https://www.bt.cn/api|${SERVER}/api|g" @
    grep -rl 'https://www.bt.cn/api' ${BTDIR}/script | xargs -I @ sed -i "s|https://www.bt.cn/api|${SERVER}/api|g" @

    sed -i "s|httpUrl = public.get_url()|httpUrl = public.GetConfigValue('home')|g" ${BTDIR}/class/ajax.py
    sed -i "s|public.get_url()|public.GetConfigValue('home')|g" ${BTDIR}/class/jobs.py
    sed -i "s|public.get_url()|public.GetConfigValue('home')|g" ${BTDIR}/class/system.py

    sed -i "s|^def GetConfigValue(key):|&\n    if key == 'home': return '${SERVER}'|g" ${BTDIR}/class/public.py
    sed -i "s|http://www.example.com|${SERVER}|g" ${BTDIR}/class/panelPlugin.py
    sed -i "s|#temp_file = temp_file.replace|temp_file = temp_file.replace|g" ${BTDIR}/class/panelPlugin.py

    # Uncomment it to use btcloud update script
    #grep -rl 'update6.sh' ${BTDIR} | xargs -I @ sed -i "s|https://cdn.jsdelivr.net/gh/PagodaPanel/install/install/update6.sh|${SERVER}/install/update6.sh|g" @
}

if [ -z "$ZIPFILE" ] ;then
    Replace
else
    ZIPFILE=$(realpath $ZIPFILE)
    echo "Zip FIle: $ZIPFILE"
    mkdir -p /tmp/pagodafile
    unzip -q -o $ZIPFILE -d /tmp/pagodafile
    BTDIR='/tmp/pagodafile/panel'
    Replace
    mv -f $ZIPFILE $ZIPFILE.bak
    cd /tmp/pagodafile && zip -q -r $ZIPFILE panel && cd -
    rm -rf /tmp/pagodafile
fi

echo Done!