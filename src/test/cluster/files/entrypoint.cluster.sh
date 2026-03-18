#!/bin/bash
IPA_CLIENT_FLAGS="${IPA_CLIENT_FLAGS:---force-join}"

while ! nc -z "${IPA_SERVER_HOSTNAME}" 1337; do
    sleep 1;
done;

# shellcheck disable=SC2086 # Client flags are intentionally without quotes.
ipa-client-install --server "${IPA_SERVER_HOSTNAME}" --domain "${IPA_DOMAIN,,}" --unattended --no-ntp --principal "admin@${IPA_DOMAIN^^}" --password "${IPA_ADMIN_PASSWORD}" ${IPA_CLIENT_FLAGS};

set -e
echo "Running tests on $(/var/cfengine/bin/cf-agent -V)";

# Patch config to point to right keytabs
jq --arg host "$(hostname -s)" '.kaf_06.keytabs.path="/shared/kafka_" + $host + ".keytab"' /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json > /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json.tmp;
mv -f /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json.tmp /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json;

# Run cfengine
echo "Running /var/cfengine/bin/cf-agent";
/var/cfengine/bin/cf-agent -KIf /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/install_kaf_07.cf -b install_kaf_07:install_kaf_07;

# Fix parent directory permissions
echo "Fixing parent directory permissions";
chown srv-kaf_07:srv-kaf_07 /opt/teragrep/kafka;

# Run systemctl reload
systemctl daemon-reload;

# Start services
echo "Starting kafka service(s)";
if [[ "$(hostname)" =~ ^broker.* ]]; then
    echo "Starting broker only";
    systemctl start kaf_06-broker;
fi;
if [[ "$(hostname)" =~ ^combined.* ]]; then
    echo "Starting both broker and controller";
    systemctl start kaf_06-broker;
    systemctl start kaf_06-controller;
fi;
if [[ "$(hostname)" =~ ^controller.* ]]; then
    echo "Starting controller only";
    systemctl start kaf_06-controller;
fi;

# Wait for last signal to accept everything is done
echo "Waiting for connections to signal we are done here";
nc --verbose --recv-only --listen --source-port 12345;

systemctl start poweroff.target;
