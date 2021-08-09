FROM mariadb

RUN apt-get update

RUN apt-get install -y \
        tzdata \
        mycli
RUN apt-get clean && \
        rm -fr /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN cp /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
RUN echo "America/Sao_Paulo" >  /etc/timezone