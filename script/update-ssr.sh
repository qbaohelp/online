#!/bin/bash

ROOT_DIR=$(cd `dirname $(readlink -f "$0")` && pwd)
NODE_CMD=/root/.nvm/versions/node/v8.16.2/bin/node
LOGS_DIR=${ROOT_DIR}/logs
LST_DATE=$(date +%Y%m%d --date='-2 day')
CUR_DATE=$(date +%Y%m%d)

function del_history_commit() {
    git checkout --orphan latest_branch
    git add -A
    git commit -am "commit message"
    git branch -D master
    git branch -m master
    git push -f origin master
    git branch --set-upstream-to=origin/master master
}

function git_update() {
    # git add . && git commit -m "update ssr and ss data" && git push --set-upstream origin master
    del_history_commit > /dev/null
}

function replace_html() {
    target_html=$1

    template='js/template.html'
    total=`cat ${template} |wc -l`
    line_no=`cat ${template} |sed -n -e '/${Content}/='`
    update_dt=`cat raw_ss-sub |grep 'date=' |awk -F'=' '{print $2}'`

    # echo "$line_no  $total"
    context_size=$(cat raw_ss-sub |grep -v 'date=' |wc -w)
    echo "the new json_ssrs size:`echo ${context_size}`"
    sed -n "1,`expr ${line_no} - 1`p" ${template} > html_text
    cat raw_ss-sub |grep -v 'date=' >> html_text
    sed -n "`expr ${line_no} + 1`,${total}p" ${template} >> html_text
    sed -i "s/\${Date}/${update_dt}/g" html_text
    
    mv html_text ${target_html}
}

function get_data() {
    text_file=$1
    out_file=$2
    encrypto=$3

    total=$(sed -n '$=' $text_file)
    endline=$(expr $total - 1)
    flag='ssr:'
    if [ "$encrypto" == "false" ]; then
        flag='ss:'
        sed "$endline,\$d" $text_file > raw_${out_file}
    fi
    text=$(sed "$endline,\$d" $text_file |grep "${flag}")
    echo $text | base64 > $out_file
}

function urldecode() {
    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

function write_ss_context() {
    out_file=$1
    ss_encode=$(urldecode $2 |sed 's/ss:\/\///g' |sed 's/#/=/g')
    ss_decode=$(echo "${ss_encode%=*}=" |base64 -d 2>/dev/null)
    echo "ss-json row: ${ss_decode}"
    ss_address=${ss_decode#*@}
    ss_method=${ss_decode%@*}
cat << EOF >> $out_file
  {
    "server": "${ss_address%:*}",
    "server_port": "${ss_address#*:}",
    "password": "${ss_method#*:}",
    "method": "${ss_method%:*}",
    "remarks": "${ss_encode#*=}",
    "route": "bypass-lan-china",
    "ipv6": true
  },
EOF
# {
    # "remote_dns": "dns.google",
    # "metered": false,
    # "proxy_apps": { "enabled": false },
    # "udpdns": false
# }
}

function get_content_viencoding() {
    html_ss=$1

    WEB_URL='https://viencoding.com/ss-ssr-share'
    curl -s "$WEB_URL" |sed -n 's/<code>\(.*\)<\/code><br>/\1/p' |sed 's/ //g' > ssr_text
    cat ssr_text |grep 'ss:' > ss_text

    get_data 'ssr_text' 'ssrsub' true
    get_data 'ss_text' 'ss-sub' false
    replace_html ${html_ss}

    rm -rf ssr_text ss_text ss-sub
    git_update
}

# update data of Lncn.org
function get_content_lncn() {
    html_ss=$1

    rawss='raw_ss-sub'
    last_date=`if [ -f ${rawss} ]; then cat ${rawss} |grep 'date='|awk -F'=' '{print $2}'; else echo ''; fi`
    last_ssrs=`if [ -f ${rawss} ]; then cat ${rawss} |grep 'ss:' |tr -s [:space:] |tr -s '\n'; else echo ''; fi`
    last_data_size=$(echo ${last_ssrs} |sed 's/ /\n/g' |sed '/^$/d' |wc -l)
    
    lncn_data=`curl -s -d '' https://lncn.org/api/SSR`
    json_date=`echo ${lncn_data} |jq -r .date`
    json_ssrs=`echo ${lncn_data} |jq -r .ssrs`
    json_ipen=`echo ${lncn_data} |jq -r .ip`
    decodekey=$(echo "${json_ipen}==" |base64 -d 2>/dev/null)

    # echo $json_ssrs
    echo "last_date[\"${last_date}\"], json_date[\"${json_date}\"]"
    echo "last_data size: ${last_data_size}"
    if [[ ${last_data_size} -eq 0 || "${last_date}" != "${json_date}" ]]; then
        echo "date=${json_date}" > ${rawss}
        
        echo "[" > ss_text
        all_ssr=`${NODE_CMD} ${ROOT_DIR}/js/update-ssr.js ${json_ssrs} ${decodekey} |sort |cut -d'|' -f2`
        for ssr in ${all_ssr}; do
            ss=${ssr%,*}
            ssrUrl=${ssr#*,}
            
            echo $ss >> ${rawss}
            write_ss_context ss_text $ss
            echo $ssrUrl >> ssr_text
        done
        echo "]" >> ss_text
        if [[ -f "ssr_text" ]]; then
            replace_html ${html_ss}
            cat ${rawss} |grep -v 'date=' | base64 > ss-sub
            cat ss_text |sed ':t;N;s/\n//;b t' |sed 's/,]/]/g' |jq . > ss-json
            cat ssr_text | base64 > ssrsub
        fi

        rm -rf ss_text ssr_text
        git_update
    fi
}

# main function code
function main() {
    echo "start execute at `date "+%Y-%m-%d %H:%M:%S"`"
    OLD=`pwd`
    cd $ROOT_DIR
    # get_content_viencoding '/home/dist/html/index.html'
    get_content_lncn '/home/dist/html/index.html'
    cd $OLD
    echo ""
}
if [[ -d "${LOGS_DIR}" ]]; then rm -rf ${LOGS_DIR}/script-${LST_DATE}.log; else mkdir ${LOGS_DIR};fi
main >> ${LOGS_DIR}/script-${CUR_DATE}.log 2>&1
