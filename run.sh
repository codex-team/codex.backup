#!/bin/bash


checkConfig () {
    # Check if config file does not exist
    if [ ! -f "backup.conf" ];then
        echo "Error: config file does not exist!"
        exit 1
    fi

    # Load vars fron config
    . backup.conf

    # Check config vars for not being empty
    if [[ "$CHAT_ID" = "" || "$BOT_TOKEN" = "" ]];then
        if [[ "$CHAT_ID" = "" ]];then
            echo "Error: chat_id is missing. Check config file."
        else
            echo "Error: bot_token is missing. Check config file."
        fi
        exit 1
    fi
}

##
# Function for sending document to telegram chat.
#
# Required var 'chat_id' — target chat id
# Required var 'bot_token' — Telegram bot`s token
#
# Usage: sendDocument path/to/file
# Returns: 0 for success
#          1 for failure
sendDocument () {

    # if file does not exist then return failure
    if [ ! -f "$1" ];then
        echo "Warning sendDocument(): file $1 does not exist!"
        return 1
    fi

    # sending file and saving response from Telegram
    local RESPONSE=`curl -X POST https://api.telegram.org/bot$BOT_TOKEN/sendDocument -F chat_id=$CHAT_ID -F document="@$1"`

    echo $RESPONSE

    # Check if response has substring '"ok":true'
    # then return success otherwise return failure
    if [[ "$RESPONSE" = *"\"ok\":true"* ]];then
        return 0
    else
        return 1
    fi
}

yaDiskUpload () {

    # if file does not exist then return failure
    if [ ! -f "$1" ];then
        echo "Warning yaDiskUpload(): file $1 does not exist!"
        return 1
    fi

    # Create dir 'sys'
    local FOLDER_PATH="/sys/${SERVER_LABEL}"

    echo "${FOLDER_PATH}/$1"

    local RESPONSE=`curl -s -X GET -G https://cloud-api.yandex.net/v1/disk/resources/upload -d path="${FOLDER_PATH}/$1" -d overwrite="true" -H "Authorization: $YADISK_TOKEN"`

    # get fucking $RESPONSE['href']
    local t=$RESPONSE
    local searchstring="href\":\""
    local rest=${t#*$searchstring}
    local start=$(( ${#t} - ${#rest} - ${#searchstring} + 7 ))
    t="${t:start}"
    searchstring="\""
    rest=${t#*$searchstring}
    local end=$(( ${#t} - ${#rest} - ${#searchstring} ))
    local url="${t:0:end}"
    # hurrah!!!!

    # echo $url

    local RESPONSE=`curl -X PUT $url -H "Authorization: $TOKEN" --data-binary @$1`

    echo $RESPONSE

    return 0


    # # Check if response has substring '"ok":true'
    # # then return success otherwise return failure
    # if [[ "$RESPONSE" = *"\"ok\":true"* ]];then
    #     return 0
    # else
    #     return 1
    # fi
}


##
# Function for sending message to telegram chat.
#
# Required var 'chat_id' — target chat id
# Required var 'bot_token' — Telegram bot`s token
#
# Usage: sendMessage "Hi there!"
sendMessage () {
    curl -s -X POST https://api.telegram.org/bot$BOT_TOKEN/sendMessage -F chat_id=$CHAT_ID -F text="$1" -F parse_mode="HTML"
}

addToReport () {
    local TARGET=$1
    local RESULT=$2

    REPORT+="<code>[$RESULT] $TARGET</code>"$'\n';
}


##
# copyDir "uploads" "/var/www/uploads" "$TEMP_DIR/uploads"
copyDir () {
    local LABEL="$1"
    local FROM="$2"
    local TO="$3"

    if [[ `ls $FROM` ]]; then
        mkdir -p $TO
        cp -rf $FROM/. $TO

        if [[ `ls $FROM` == `ls $TO` ]]; then
            addToReport "$LABEL" "OK"
        else
            addToReport "$LABEL: copy error" "Fail"
        fi
    else
        addToReport "$LABEL: check source dir" "Fail"
    fi
}

########### start script #########
#checkConfig


### insert config ####
# Config file

#########
# Main info
#
# Give a label for this server`s backups
SERVER_LABEL='codex-dev'
#
#########

#########
# Telegram bot config
#
CHAT_ID=''
BOT_TOKEN=''
#
#########

#########
# Yandex Disk config
#
YADISK_TOKEN=''
#
#########

#########
# Redis
#
REDIS_PASSWORD=''
# redis database usually located at /var/lib/redis/dump.rdb
REDIS_DB_PATH='/var/lib/redis/dump.rdb'
#
#########

#########
# MySQL
#
MYSQL_USER="root"
# this variable is not works
MYSQL_PASSWORD=""
#
#########

#########
# MONGO
#
MONGO_HOST="localhost" #different when not on same server
MONGO_PORT="27017" #could be different
#
#########

###







SECONDS=0
REPORT="Report for ${SERVER_LABEL} backup mission."$'\n\n'

##
# Creating backup dir
#
TEMP_DIR="temporary"
mkdir $TEMP_DIR



######### REDIS #########
mkdir $TEMP_DIR/redis
backupRedis () {

    if [[ ! $REDIS_PASSWORD ]]; then
        REDIS_COMMANDS="save";
    else
        REDIS_COMMANDS="auth ${REDIS_PASSWORD}\nsave"
    fi

    echo -e $REDIS_COMMANDS | redis-cli
    cp $REDIS_DB_PATH $TEMP_DIR/redis/dump.rdb

    if [ ! -f "$TEMP_DIR/redis/dump.rdb" ];then
        echo "Warning: redis database has not been saved!"
        return 1
    fi
    return 0
}

backupRedis
if [[ $? -eq 0 ]]; then
    addToReport "redis" "OK"
else
    addToReport "redis" "Fail"
fi


######### MySQL #########
mkdir $TEMP_DIR/mysql

backupMysql () {
    # nihuya ne rabotaet
    if [[ ! $MYSQL_PASSWORD ]]; then
        MYSQL_AUTH="-u$MYSQL_USER";
    else
        MYSQL_AUTH="-u$MYSQL_USER -p$MYSQL_PASSWORD"
    fi
    # it should work!!1
    # mysqldump $MYSQL_AUTH --all-databases > $TEMP_DIR/mysql/all-databases.sql


    # if root's password is "hello123!fkngworld":
    mysqldump -uroot -phello123\!fkngworld --all-databases > $TEMP_DIR/mysql/all-databases.sql

    if [ ! -f "$TEMP_DIR/mysql/all-databases.sql" ];then
        echo "Warning: mysql databases have not been saved!"
        return 1
    fi
    return 0
}

backupMysql
if [[ $? -eq 0 ]]; then
    addToReport "mysql" "OK"
else
    addToReport "mysql" "Fail"
fi

######### MONGO #########
mkdir $TEMP_DIR/mongo

backupMongo () {

    mongo admin --eval "printjson(db.fsyncLock())"
    mongodump -h $MONGO_HOST:$MONGO_PORT --out $TEMP_DIR/mongo
    mongo admin --eval "printjson(db.fsyncUnlock())"

    if [ ! -n "$(ls -A $TEMP_DIR/mongo)" ];then
        echo "Warning: mongo databases have not been saved!"
        return 1
    fi
    return 0
}

backupMongo
if [[ $? -eq 0 ]]; then
    addToReport "mongo" "OK"
else
    addToReport "mongo" "Fail"
fi


######### Uploads #########
copyDir "ifmo.su uploads" "/var/www/ifmo.su/upload" "$TEMP_DIR/ifmo.su"

######### Nginx #########
copyDir "sites-available" "/etc/nginx/sites-available" "$TEMP_DIR/nginx/"

##### ARCHIVE #####
# generate name
DATE=`date "+%Y-%m-%d_%H-%M"`
if [[ ! $SERVER_LABEL ]]; then SERVER_LABEL=`hostname`; fi
ARCHIVE_NAME="${SERVER_LABEL}_$DATE.tar.gz";

# create archive
tar -zcf $ARCHIVE_NAME $TEMP_DIR



SIZE=$( perl -e 'print -s shift' "$ARCHIVE_NAME" )

TOTAL_SIZE=`if [[ $(( $SIZE / 1024 /1024 )) > 0 ]]; then echo "$(( $SIZE / 1024 / 1024 ))MB"; else echo "$(( $SIZE / 1024 ))KB"; fi`


REPORT+=$'\n'"<code>Created $ARCHIVE_NAME ($TOTAL_SIZE)</code>"$'\n'

# send archive to Telegram
sendDocument $ARCHIVE_NAME

# if document has been sended correctly
if [[ $? -eq 0 ]]; then
    rm $ARCHIVE_NAME;
    rm -rf $TEMP_DIR;
    REPORT+="<code>[OK] Saving to Telegram</code>"$'\n'
    REPORT="[Success] "${REPORT}$'\n'"Archive has been sent to Telegram chat."
else
    REPORT+="<code>[Fail] Saving to Telegram</code>"$'\n'
    yaDiskUpload $ARCHIVE_NAME
    if [[ $? -eq 0 ]]; then
        rm $ARCHIVE_NAME;
        rm -rf $TEMP_DIR;
        REPORT+="<code>[OK] Saving to Yandex.Disk</code>"$'\n'
        REPORT="[Success] "${REPORT}$'\n'"Archive has been sent to Yandex.Disk."
    else
        REPORT+="<code>[Fail] Saving to Yandex.Disk</code>"$'\n'
        REPORT+="<code>[OK] Saving to local storage</code>"$'\n'
        REPORT="[Failure] "${REPORT}$'\n'"Archive has been saved on local disk."
    fi
fi

REPORT+=$'\n'"Total time: $SECONDS sec."

# TODO send backup report
sendMessage "$REPORT";
