FROM debian:buster

ARG steam_user=anonymous
ARG steam_password=
ARG metamod_version=1.20
ARG amxmod_version=1.8.2

RUN apt update && apt install -y lib32gcc1 curl && \
# Install SteamCMD
  mkdir -p /opt/steam && cd /opt/steam && \
  curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -

# Install HLDS
ADD hlds_run.sh /bin/hlds_run.sh
RUN mkdir -p /opt/hlds && \ 
  chmod +x /bin/hlds_run.sh && \
# Workaround for "app_update 90" bug, see https://forums.alliedmods.net/showthread.php?p=2518786
  /opt/steam/steamcmd.sh +login $steam_user $steam_password +force_install_dir /opt/hlds +app_update 90 validate +quit && \
  /opt/steam/steamcmd.sh +login $steam_user $steam_password +force_install_dir /opt/hlds +app_update 70 validate +quit || : && \
  /opt/steam/steamcmd.sh +login $steam_user $steam_password +force_install_dir /opt/hlds +app_update 10 validate +quit || : && \
  /opt/steam/steamcmd.sh +login $steam_user $steam_password +force_install_dir /opt/hlds +app_update 90 validate +quit  && \
  mkdir -p ~/.steam && ln -s /opt/hlds ~/.steam/sdk32 && \
  ln -s /opt/steam/ /opt/hlds/steamcmd

ADD files/steam_appid.txt /opt/hlds/steam_appid.txt

# Install metamod
RUN mkdir -p /opt/hlds/cstrike/addons/metamod/dlls && \
  curl -sqL "http://prdownloads.sourceforge.net/metamod/metamod-$metamod_version-linux.tar.gz?download" | tar -C /opt/hlds/cstrike/addons/metamod/dlls -zxvf -

# Install dproto
RUN mkdir -p /opt/hlds/cstrike/addons/dproto
ADD files/dproto_i386.so /opt/hlds/cstrike/addons/dproto/dproto_i386.so
#ADD files/dproto.cfg /opt/hlds/cstrike/dproto.cfg

# Install AMX mod X
RUN curl -sqL "http://www.amxmodx.org/release/amxmodx-$amxmod_version-base-linux.tar.gz" | tar -C /opt/hlds/cstrike/ -zxvf - && \
  curl -sqL "http://www.amxmodx.org/release/amxmodx-$amxmod_version-cstrike-linux.tar.gz" | tar -C /opt/hlds/cstrike/ -zxvf -
  
# Add default config, mapcycle, liblist.gam and dproto config 
ADD files/server.cfg files/mapcycle.txt files/liblist.gam files/dproto.cfg /opt/hlds/cstrike/

# Configure addons
# Remove this line if you aren't going to install/use amxmodx and dproto
ADD files/plugins.ini /opt/hlds/cstrike/addons/metamod/plugins.ini
# Delete this file to use mapcycle.txt
ADD files/maps.ini /opt/hlds/cstrike/addons/amxmodx/configs/maps.ini
# Setup amxx's plugins
ADD files/parachute.sma files/c4timer.sma files/abd.sma /opt/hlds/cstrike/addons/amxmodx/scripting/
ADD files/parachute.amxx files/c4timer.amxx files/abd.amxx /opt/hlds/cstrike/addons/amxmodx/plugins/
ADD files/parachute.mdl /opt/hlds/cstrike/models/

# Add maps
ADD maps/* /opt/hlds/cstrike/maps/

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
c4timer.amxx' >> /opt/hlds/cstrike/addons/amxmodx/configs/plugins.ini && \
# Cleanup
 apt remove -y curl && \
 rm -rf /var/lib/apt/lists/*

WORKDIR /opt/hlds

ENTRYPOINT ["/bin/hlds_run.sh"]
