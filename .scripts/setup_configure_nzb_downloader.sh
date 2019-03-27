#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

setup_configure_nzb_downloader()
{
    info "Configuring NZB Downloader"
    info "- SabNZBd"
    info "  Updating API Key"
    warning "  !No code for updating API Key!"

    info "  Connecting to Sickrage"
    crudini --set /opt/sickrage/config.ini SABnzbd sab_apikey ${API_KEYS[sabnzbd]}

    if [ "${config[NZB_DOWNLOADER]}" == 'sabnzbd' ]; then
        info "  Enabling in HTPC"
        ENABLED_HTPC="on"
        ENABLED_OMBI="true"
    else
        info "  Disabling in HTPC"
        ENABLED_HTPC="0"
        ENABLED_OMBI="false"
    fi
    sqlite3 /opt/HTPCManager/userdata/database.db "UPDATE setting SET val='${ENABLED_HTPC}' where key='sabnzbd_enable';"

    if [ "$usenetpassword" != '' ]; then
        info "  Connecting to Usenet"
        service sabnzbdplus stop
        sleep 5
        sed -i 's/^api_key.*/api_key = '1234567890'/' /home/openflixr/.sabnzbd/sabnzbd.ini
        service sabnzbdplus start
        sleep 5
        curl -s 'http://localhost:8080/api?mode=set_config&section=servers&keyword=OpenFLIXR_Usenet_Server&output=xml&enable=1&apikey=1234567890'
        curl -s 'http://localhost:8080/api?mode=set_config&section=servers&keyword=OpenFLIXR_Usenet_Server&output=xml&ssl=$usenetssl&apikey=1234567890'
        curl -s 'http://localhost:8080/api?mode=set_config&section=servers&keyword=OpenFLIXR_Usenet_Server&output=xml&displayname=$usenetdescription&apikey=1234567890'
        curl -s 'http://localhost:8080/api?mode=set_config&section=servers&keyword=OpenFLIXR_Usenet_Server&output=xml&username=$usenetusername&apikey=1234567890'
        curl -s 'http://localhost:8080/api?mode=set_config&section=servers&keyword=OpenFLIXR_Usenet_Server&output=xml&password=$usenetpassword&apikey=1234567890'
        curl -s 'http://localhost:8080/api?mode=set_config&section=servers&keyword=OpenFLIXR_Usenet_Server&output=xml&host=$usenetservername&apikey=1234567890'
        curl -s 'http://localhost:8080/api?mode=set_config&section=servers&keyword=OpenFLIXR_Usenet_Server&output=xml&port=$usenetport&apikey=1234567890'
        curl -s 'http://localhost:8080/api?mode=set_config&section=servers&keyword=OpenFLIXR_Usenet_Server&output=xml&connections=$usenetthreads&apikey=1234567890'
        service sabnzbdplus stop
        sed -i 's/^api_key.*/api_key = '${API_KEYS[sabnzbd]}'/' /home/openflixr/.sabnzbd/sabnzbd.ini
    else
        service sabnzbdplus stop
        sleep 5
        sed -i 's/^api_key.*/api_key = '1234567890'/' /home/openflixr/.sabnzbd/sabnzbd.ini
        service sabnzbdplus start
        sleep 5
        curl -s 'http://localhost:8080/api?mode=set_config&section=servers&keyword=OpenFLIXR_Usenet_Server&output=xml&enable=0&apikey=1234567890'
        service sabnzbdplus stop
        sed -i 's/^api_key.*/api_key = '${API_KEYS[sabnzbd]}'/' /home/openflixr/.sabnzbd/sabnzbd.ini
    fi

    info "- NZBget"
    info "  Updating API Key"
    warning "  !No code for updating API Key!"

    if [ "${config[NZB_DOWNLOADER]}" == 'nzbget' ]; then
        info "  Enabling in HTPC"
        ENABLED_HTPC="on"
        ENABLED_OMBI="true"
    else
        info "  Disabling in HTPC"
        ENABLED_HTPC="0"
        ENABLED_OMBI="false"
    fi
    sqlite3 /opt/HTPCManager/userdata/database.db "UPDATE setting SET val='on' where key='nzbget_enable';"

}
