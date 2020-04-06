FROM bateau/openttd

LABEL maintainer="Christoph Petersen <cp@peterschen.de>"

ADD --chown=1000:1000 config.sh /
ADD --chown=1000:1000 openttd.cfg /home/openttd/.openttd/openttd.cfg

CMD [ "/config.sh" ]
