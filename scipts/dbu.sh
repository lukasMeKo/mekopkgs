#!/usr/bin/env bash

find_db() {
    doctl databases ls -o json |
        jq -r ".[] | select(.name | contains(\"$1\")) | .db_names[] | select(contains(\"$2\"))" |
        sort -r |
        head -n1
}

conn_str() {
    ID=$(doctl databases ls -o json | jq ".[] | select(.name | contains(\"$1\")) | .id")
    doctl databases conn "$ID" -o json |
        jq -r ".uri" |
        rg -r "$2" 'defaultdb'
}

INSTANCE=${2?}
DB=${3:-appdata}

case "$1" in
    "db")
        find_db "$INSTANCE" "$DB"
        ;;
    "conn")
        conn_str "$INSTANCE" "${2:-$(find_db "$INSTANCE" "$DB")}"
        ;;
    *)
        printf "expect conn|db, got '%s'\n" "$1"> /dev/stderr
        exit 1
        ;;
esac
