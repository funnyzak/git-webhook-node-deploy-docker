#!/bin/bash


# send notification to url 
function notify_url_single(){
    ACTION_NAME=$1
    NOTIFY_URL=$2

    echo "$APP_NAME $ACTION_NAME. 【$NOTIFY_URL】Web Notify Notification Sending...\n"

    # current timestamp
    CURRENT_TS=$(date +%s)
    curl "$NOTIFY_URL" \
        -H "Content-Type: application/json" \
        -d "{
                \"_time\": \"$CURRENT_TS\",
                \"_name\": \"$APP_NAME\",
                \"_action\": \"$ACTION_NAME\"
        }"
    curl -G "$NOTIFY_URL" \
        -d "_time=$CURRENT_TS&_name=$APP_NAME&_action=$ACTION_NAME"

    echo "$APP_NAME $ACTION_NAME. 【$NOTIFY_URL】Web Notify Notification Sended\n"
}

# send notification to dingtalk
function dingtalk_notify_single() {
    ACTION_NAME=`parse_action_label $1`
    TOKEN=$2

    echo "$APP_NAME $ACTION_NAME. DingTalk Notification Sending...\n"
    curl "https://oapi.dingtalk.com/robot/send?access_token=${TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
        "msgtype": "markdown",
        "markdown": {
            "title":"'"$APP_NAME"' '"$ACTION_NAME"'.",
            "text": "#### 【'"$APP_NAME"'】 '"$ACTION_NAME"'. \n> Branch：'"$(parse_git_branch)"' \n\n> Commit Msg：'"$(parse_git_message)"'\n\n> Commit ID: '"$(parse_git_hash)"'\n"
        },
            "at": {
            "isAtAll": true
            }
        }'

    echo "$APP_NAME $ACTION_NAME. DingTalk Notification Sended.\n"
}

function ifttt_single() {
    ACTION_NAME=`parse_action_label $1`
    NOTIFY_URL=$2
    
     echo "$APP_NAME $ACTION_NAME. 【$NOTIFY_URL】IFTTT Notify Notification Sended\n"
    curl -X POST -H "Content-Type: application/json" -d "{\"value1\":\"$APP_NAME\",\"value2\":\"$ACTION_NAME\",\"value3\":\"$(date)\"}" "$NOTIFY_URL"
     echo "$APP_NAME $ACTION_NAME. 【$NOTIFY_URL】IFTTT Notify Notification Sended\n"
}

function parse_action_label(){
    if [ -n "$NOTIFY_ACTION_LABEL" ]; then
        label_arr=(${NOTIFY_ACTION_LABEL//|/ })
        action_idx=(parse_action_index $1)
        echo "${label_arr[action_idx]}"
    else
        echo $1
    fi
}

ACTION_ARRAY=(StartUp BeforePull AfterPull AfterPackage)
function parse_action_index(){
    for i in "${!ACTION_ARRAY[@]}"; do
        if [ "${ACTION_ARRAY[$i]}" = "${1}" ]; then
            echo "${i}";
        fi
    done
}

# $3 url or token list
# $1 func name
# $2 action
function notify_run(){
    if [ -n "$3" ]; then
        for item in ${3//|/ }
        do
            eval "$1 $2 $item"
        done
    fi
}


# notify all notify service
function notify_all(){
    notify_run "notify_url_single" $1 $NOTIFY_URL_LIST
    notify_run "ifttt_single" $1 $IFTTT_HOOK_URL_LIST
    notify_run "dingtalk_notify_single" $1 $DINGTALK_TOKEN_LIST
}


# record end time as long as "$1" is present
# record start:elasped_package_time 
# record end: elasped_package_time "end"
function elasped_package_time(){
    if [ -n "$1" ]; then
        # 计算部署耗时
        PULL_START_TS=`cat /tmp/PULL_START_TS`
        ELAPSED_TIME=`expr $(date +%s) - $PULL_START_TS`
        ELAPSED_TIME_M=`expr $ELAPSED_TIME / 60`
        ELAPSED_TIME_S=`expr $ELAPSED_TIME % 60`
        ELAPSED_TIME_LABEL="${ELAPSED_TIME_M}分${ELAPSED_TIME_S}秒"

        if [ $ELAPSED_TIME -ge 60 ]
        then
            ELAPSED_TIME_LABEL="${ELAPSED_TIME_M}分${ELAPSED_TIME_S}秒"
        else
            ELAPSED_TIME_LABEL="${ELAPSED_TIME_S}秒"
        fi
        # 耗时临时缓存
        echo $ELAPSED_TIME > /tmp/ELAPSED_TIME
        echo $ELAPSED_TIME_LABEL > /tmp/ELAPSED_TIME_LABEL
    else
        echo $(date +%s) > /tmp/PULL_START_TS
    fi
}


# checks if branch has something pending
parse_git_dirty() {
    git diff --quiet --ignore-submodules HEAD 2>/dev/null
    [ $? -eq 1 ] && echo "*"
}

# gets the current git branch
parse_git_branch() {
    git branch --no-color 2>/dev/null | sed -e '/^[^*]/d' -e "s/* \(.*\)/\1$(parse_git_dirty)/"
}

# get last commit hash prepended with @ (i.e. @8a323d0)
parse_git_hash() {
    git rev-parse --short HEAD 2>/dev/null | sed "s/\(.*\)/@\1/"
}

# get last commit message
parse_git_message() {
    git show --pretty=format:%s -s HEAD 2>/dev/null
}

