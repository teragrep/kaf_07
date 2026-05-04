FROM ghcr.io/teragrep/cfp_01/systemd/el9:1.0.0

# Install dependencies
COPY rpm/kaf_07.rpm /kaf_07.rpm
RUN dnf -y install /kaf_07.rpm jq nmap-ncat rpm-build

# Create dummy packages for upgrading
COPY create_dummy_packages.sh /dummy/
RUN cd /dummy/ && ./create_dummy_packages.sh && dnf install -y *.rpm

# Install kaf_07
COPY rpm/kaf_07.rpm /kaf_07.rpm
RUN dnf -y install /kaf_07.rpm

# Move example config
RUN cp /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json.example /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json
RUN cp /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/kaf_04/authorize.json.example /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/kaf_04/authorize.json
RUN cp /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/kaf_05/credentials.json.example /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/kaf_05/credentials.json
COPY rpm/kaf_04.rpm /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/rpm/kaf_04.rpm
COPY rpm/kaf_05.rpm /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/rpm/kaf_05.rpm
COPY rpm/kaf_06.rpm /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/rpm/kaf_06.rpm

# Bootstrap
COPY cfp_01.entrypoint.sh /cfp_01.entrypoint.sh
