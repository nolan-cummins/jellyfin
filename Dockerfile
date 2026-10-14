# syntax=docker/dockerfile:1

# Build stage - compile jellyfin-server from forked source
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY . .
RUN dotnet publish Jellyfin.Server/Jellyfin.Server.csproj \
    -c Release -r linux-x64 --self-contained \
    -o /app/jellyfin \
    -p:DebugSymbols=false -p:DebugType=none -p:TreatWarningsAsErrors=false

FROM ghcr.io/linuxserver/baseimage-ubuntu:resolute

ARG BUILD_DATE
ARG VERSION
ARG JELLYFIN_RELEASE
LABEL build_version="Custom hybrid:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="nolan"

ARG DEBIAN_FRONTEND="noninteractive"
ENV NVIDIA_DRIVER_CAPABILITIES="compute,video,utility"
ENV MALLOC_TRIM_THRESHOLD_=131072
ENV ATTACHED_DEVICES_PERMS="/dev/dri /dev/dvb /dev/vchiq /dev/vc-mem /dev/video1? -type c"

RUN \
  echo "**** add jellyfin repo for ffmpeg and web ****" && \
  curl -s https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key | gpg --dearmor | tee /usr/share/keyrings/jellyfin.gpg >/dev/null && \
  echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/jellyfin.gpg] https://repo.jellyfin.org/ubuntu resolute main' > /etc/apt/sources.list.d/jellyfin.list && \
  echo "**** install runtime packages ****" && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
    at \
    libicu-dev \
    libjemalloc2 \
    mesa-va-drivers \
    xmlstarlet \
    jellyfin-ffmpeg7 \
    jellyfin-web && \
  echo "**** setup jellyfin-server dir ****" && \
  mkdir -p /usr/lib/jellyfin/bin && \
  echo "**** cleanup ****" && \
  rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

# Copy built jellyfin-server from build stage
COPY --from=build /app/jellyfin/ /usr/lib/jellyfin/bin/
# Create symlink so s6 run script can find the binary at /usr/bin/jellyfin
RUN ln -s /usr/lib/jellyfin/bin/jellyfin /usr/bin/jellyfin

# Copy s6 service definitions
COPY root/ /
RUN chmod +x /usr/local/bin/patch-jellyfin-web.sh && /usr/local/bin/patch-jellyfin-web.sh

EXPOSE 8096 8920
VOLUME /config