FROM ghcr.io/teragrep/cfp_01/systemd/el9:1.0.0

# Install dependencies
COPY rpm/kaf_07.rpm /kaf_07.rpm
RUN dnf -y install /kaf_07.rpm

# Bootstrap
COPY cfp_01.entrypoint.sh /cfp_01.entrypoint.sh
