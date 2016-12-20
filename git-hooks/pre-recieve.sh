#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CS_CONFIG_PATH="${DIR}/cs-config/vsk_${STASH_REPO_NAME}_cs_config"
COMMAND="php-cs-fixer fix --dry-run --diff"
TEMP_DIR=`mktemp -d`
LOG_FILE=$(mktemp /tmp/php-cs-fixer.XXXXXXX)
CS_FIXER_OUTPUT=$(mktemp /tmp/php-cs-fixer-output.XXXXXXX)
trap "{ rm -rf ${TEMP_DIR}; rm -rf ${LOG_FILE}; rm -rf ${CS_FIXER_OUTPUT}; }" EXIT

date +%Y-%m-%dT%H:%M:%S%z >> ${LOG_FILE}
echo -e "Script name: $0
script dir: ${DIR}
config path: ${CS_CONFIG_PATH}
Positional arguments: ${@}
STASH_USER_NAME: $STASH_USER_NAME
STASH_USER_EMAIL: $STASH_USER_EMAIL
STASH_REPO_NAME_: $STASH_REPO_NAME
STASH_IS_ADMIN_: $STASH_IS_ADMIN
" >> ${LOG_FILE}

while read old_rev new_rev ref_name; do
    echo -e "Ref update:
Old value: $old_rev
New value: $new_rev
Ref name:  $ref_name
" >> ${LOG_FILE}

    if [ "$old_rev" = "0000000000000000000000000000000000000000" ];
    then
        old_rev="dev"
    fi

    if [ "$new_rev" = "0000000000000000000000000000000000000000" ];
    then
        exit 0
    fi

    files=$(git diff --name-only ${old_rev} ${new_rev})
    for file in ${files}; do
        object=$(git ls-tree --full-name -r ${new_rev} | egrep "(\s)${file}\$" | awk '{ print $3 }')
        if [ -z ${object} ]; then continue; fi
        mkdir -p "${TEMP_DIR}/`dirname ${file}`" &> /dev/null
        git cat-file blob ${object} > ${TEMP_DIR}/${file}
    done;

    mkdir -p "${TEMP_DIR}/for-cs-config" &> /dev/null

    cp ${CS_CONFIG_PATH} ${TEMP_DIR}/.php_cs

    ${COMMAND} ${TEMP_DIR} >> ${CS_FIXER_OUTPUT} 2>&1
    STATUS=$?
    cat ${CS_FIXER_OUTPUT} >> ${LOG_FILE}

    echo -e "STATUS $STATUS" >> ${LOG_FILE}
done

cat ${LOG_FILE} >> /tmp/external-hooks-php-cs-fixer.log

if [ ${STATUS} -ne 0 ]; then
  echo -e "There are coding style contradictions in your commit.
Please fix it in files below.
"
    cat ${CS_FIXER_OUTPUT}
fi

exit ${STATUS}
