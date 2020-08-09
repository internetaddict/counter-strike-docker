FROM debian:buster

ARG steam_user=anonymous
ARG steam_password=
ARG metamod_version=1.20
ARG amxmod_version=1.8.2

RUN apt update && apt install -y lib32gcc1 curl && \
# Install SteamCMD
  mkdir -p /opt/steam && useradd -d /opt/steam -s /bin/bash steam && cd /opt/steam && \
  curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxf - && \
  chown -R steam:steam /opt/steam && mkdir -p /opt/hlds && chown -R steam:steam /opt/hlds && mkdir -p /opt/steam/downloads/ && \
  # download  and save required packages
  curl -sqL "http://prdownloads.sourceforge.net/metamod/metamod-$metamod_version-linux.tar.gz?download" -o /opt/steam/downloads/metamod.tar.gz && \
  curl -sqL "http://www.amxmodx.org/release/amxmodx-$amxmod_version-base-linux.tar.gz" -o /opt/steam/downloads/amxmodx-base.tar.gz && \
  curl -sqL "http://www.amxmodx.org/release/amxmodx-$amxmod_version-cstrike-linux.tar.gz" -o /opt/steam/downloads/amxmodx-cstrike.tar.gz && \
  chown -R steam:steam /opt/steam/downloads/ && \ 
  # cleanup
  apt autoremove -y curl && \
  rm -rf /var/lib/apt/lists/*

USER steam

# Install HLDS
ADD --chown=steam:steam hlds_run.sh /bin/hlds_run.sh
RUN chmod +x /bin/hlds_run.sh && \
# Workaround for "app_update 90" bug, see https://forums.alliedmods.net/showthread.php?p=2518786
  /opt/steam/steamcmd.sh +login $steam_user $steam_password +force_install_dir /opt/hlds +app_update 90 validate +quit && \
  /opt/steam/steamcmd.sh +login $steam_user $steam_password +force_install_dir /opt/hlds +app_update 70 validate +quit || : && \
  /opt/steam/steamcmd.sh +login $steam_user $steam_password +force_install_dir /opt/hlds +app_update 10 validate +quit || : && \
  /opt/steam/steamcmd.sh +login $steam_user $steam_password +force_install_dir /opt/hlds +app_update 90 validate +quit  && \
  mkdir -p ~/.steam && ln -s /opt/hlds ~/.steam/sdk32 && \
  ln -s /opt/steam/ /opt/hlds/steamcmd

ADD --chown=steam:steam files/steam_appid.txt /opt/hlds/steam_appid.txt

# Install metamod
RUN mkdir -p /opt/hlds/cstrike/addons/metamod/dlls && \
  tar -C /opt/hlds/cstrike/addons/metamod/dlls -zxf /opt/steam/downloads/metamod.tar.gz && \
# Install AMX mod X
  tar -C /opt/hlds/cstrike/ -zxf /opt/steam/downloads/amxmodx-base.tar.gz && \
  tar -C /opt/hlds/cstrike/ -zxf /opt/steam/downloads/amxmodx-cstrike.tar.gz && \
# cleanup
  rm -rf /opt/steam/downloads/ && \
# Install dproto
  mkdir -p /opt/hlds/cstrike/addons/dproto

ADD --chown=steam:steam files/dproto_i386.so /opt/hlds/cstrike/addons/dproto/dproto_i386.so
#ADD files/dproto.cfg /opt/hlds/cstrike/dproto.cfg

# Add default config, mapcycle, liblist.gam and dproto config 
ADD --chown=steam:steam files/server.cfg files/mapcycle.txt files/liblist.gam files/dproto.cfg /opt/hlds/cstrike/

# Configure addons
# Remove this line if you aren't going to install/use amxmodx and dproto
ADD --chown=steam:steam files/plugins.ini /opt/hlds/cstrike/addons/metamod/plugins.ini
# Delete this file to use mapcycle.txt
ADD --chown=steam:steam files/maps.ini /opt/hlds/cstrike/addons/amxmodx/configs/maps.ini
# Setup amxx's plugins
ADD --chown=steam:steam files/parachute.sma files/c4timer.sma files/abd.sma /opt/hlds/cstrike/addons/amxmodx/scripting/
ADD --chown=steam:steam files/parachute.amxx files/c4timer.amxx files/abd.amxx /opt/hlds/cstrike/addons/amxmodx/plugins/
ADD --chown=steam:steam files/parachute.mdl /opt/hlds/cstrike/models/

# Add maps
ADD --chown=steam:steam maps/* /opt/hlds/cstrike/maps/

# amxx cvars config 
RUN echo 'sv_parachute "1" \n\
parachute_fallspeed "200" \n\
amx_bulletdamage_recieved "0" \n\
amx_bulletdamage "1" \n\
amx_showc4timer "3" \n\
amx_showc4flash "0" \n\
amx_showc4sprite "1" \n\
amx_showc4msg "0"' >> /opt/hlds/cstrike/addons/amxmodx/configs/amxx.cfg && \
# amxx enable 3rd party plugins
  echo 'parachute.amxx \n\
abd.amxx \n\
c4timer.amxx' >> /opt/hlds/cstrike/addons/amxmodx/configs/plugins.ini

WORKDIR /opt/hlds

ENTRYPOINT ["/bin/hlds_run.sh"]
