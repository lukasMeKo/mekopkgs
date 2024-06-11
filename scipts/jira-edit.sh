#!/usr/bin/env bash

if [[ $# -gt 0 ]]
then
    ISSUE=$1
else
    ISSUE=$(git rev-parse --abbrev-ref HEAD | rg -o 'MK-\d+' || exit)
fi

TMP=$(mktemp)
USER="$(pass api_tokens/jira | sed '1q;d'):$(pass api_tokens/jira | sed '2q;d')"
URL="https://mekorp.atlassian.net/rest/api/2/issue/$ISSUE"

# Download description
printf "    Loading %s..." "$ISSUE"
if curl --request GET --url "$URL" --user "$USER" \
    --header 'Accept: application/json' 2>/dev/null |
    jq -r '.fields.description' > "$TMP"
then
    printf "\r\e[32m OK\e[0m\n"
else
    printf "\r\e[31mERR\e[0m\n"
    exit
fi

nvim '+setfiletype confluencewiki' "$TMP"

printf "    Submit? (Y/n) \r"
read -n 1 -r
if [[ "$REPLY" =~ ^[Yy]$ ]]
then
    printf "\r\e[32mYes\e[0m\n"
    printf "    Uploading description..."
    # Upload description
    if curl --request PUT --url "$URL" --user "$USER" \
         --header 'Content-Type: application/json' \
         --data "$(jq -R -s '{fields: { description: .}}' < "$TMP" )" \
         2>/dev/null
    then
        printf "\r\e[32m OK\e[0m\n"
    else
        printf "\r\e[31mERR\e[0m\n"
        exit
    fi
else
    printf "\r\e[31m No\e[0m\n"
fi
rm "$TMP"
