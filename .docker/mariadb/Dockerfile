FROM mariadb

RUN apt-get update && \
    apt-get install -y tzdata mycli && \
    apt-get clean && \
    rm -fr /var/lib/apt/lists/* /tmp/* /var/tmp/*
