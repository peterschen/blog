#!/usr/bin/env sh

set +ex

CONFIG=/home/openttd/.openttd/openttd.cfg

# Default config values
SERVER_NAME=${SERVER_NAME:="OpenTTD on Google Cloud sample"}
MAP_X=${MAP_X:=10}
MAP_Y=${MAP_Y:=10}
GENERATION_SEED=${GENERATION_SEED:=658464965}

replace_setting()
{
    _setting=$1
    _value=$2
    _config=$3

    sed -i "s/## $_setting ##/$_setting = $_value/" "$_config"
}

if [ "$SERVER_PASSWORD" != "" ]; then 
    replace_setting "server_password" "$SERVER_PASSWORD" $CONFIG
fi

if [ "$RCON_PASSWORD" != "" ]; then 
    replace_setting "rcon_password" "$RCON_PASSWORD" $CONFIG
fi

if [ "$ADMIN_PASSWORD" != "" ]; then 
    replace_setting "admin_password" "$ADMIN_PASSWORD" $CONFIG
fi

# Server name
replace_setting "server_name" "$SERVER_NAME" $CONFIG

# Map size
replace_setting "map_x" "$MAP_X" $CONFIG
replace_setting "map_y" "$MAP_Y" $CONFIG

# Generation seed
replace_setting "generation_seed" "$GENERATION_SEED" $CONFIG

# Execute cmd from base image
exec /openttd.sh
