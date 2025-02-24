FROM mariadb

RUN apt-get update && \
    apt-get install -y \
        less \
        mycli \
        tzdata && \
    apt-get clean && \
    rm -fr /var/lib/apt/lists/* /tmp/* /var/tmp/*
