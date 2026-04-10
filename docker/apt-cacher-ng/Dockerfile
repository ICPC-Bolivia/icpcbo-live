FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-cacher-ng \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 3142

VOLUME ["/var/cache/apt-cacher-ng", "/var/log/apt-cacher-ng"]

CMD ["apt-cacher-ng", "ForeGround=1"]
