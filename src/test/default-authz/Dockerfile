FROM rockylinux/rockylinux:9

# Install dependencies
COPY rpm/cfengine.rpm /cfengine.rpm
COPY rpm/kaf_07.rpm /kaf_07.rpm
RUN dnf -y install /cfengine.rpm /kaf_07.rpm jq nmap-ncat

# Patch configs
COPY config/config-patch.json /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config-patch.json
RUN jq -s '.[0] * .[1]' /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json.example /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config-patch.json > /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json
COPY config/kaf_04/authorize.json /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/kaf_04/authorize.json
COPY config/kaf_05/credentials.json /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/kaf_05/credentials.json

# Copy rpms
COPY rpm/kaf_04.rpm /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/rpm/
COPY rpm/kaf_05.rpm /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/rpm/
COPY rpm/kaf_06.rpm /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/rpm/

# Bootstrap
COPY tester.sh /tester.sh
RUN chmod +x /tester.sh

# Run
ENTRYPOINT ["/tester.sh"]
CMD [""]
