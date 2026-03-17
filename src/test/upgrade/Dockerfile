FROM rockylinux/rockylinux:9

# Install dependencies
COPY rpm/cfengine.rpm /cfengine.rpm
COPY rpm/kaf_07.rpm /kaf_07.rpm
RUN dnf -y install /cfengine.rpm /kaf_07.rpm jq nmap-ncat

# Install dummy packages for upgrading
COPY dummy/*.rpm /dummy/
RUN dnf install -y /dummy/*.rpm

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
COPY tester.sh /tester.sh
RUN chmod +x /tester.sh

# Run
ENTRYPOINT ["/tester.sh"]
CMD [""]
