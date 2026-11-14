FROM mariadb:13.0.2@sha256:54f493ea0d60b621a5bff84e5b20100f8b86b6efa6b79158e04756c5194a5e4d

RUN apt-get update && \
    apt-get install -y \
        less \
        mycli \
        tzdata && \
    apt-get clean && \
    rm -fr /var/lib/apt/lists/* /tmp/* /var/tmp/*
