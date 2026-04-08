#!/bin/bash
set -e;
echo "Running tests on $(/var/cfengine/bin/cf-agent -V)";

# Patch config to point to right keytabs
jq --arg host "$(hostname -s)" '.kaf_06.keytabs.path="/shared/kafka_" + $host + ".keytab"' /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json > /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json.tmp;
mv -f /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json.tmp /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json;

# Run cfengine
echo "Running /var/cfengine/bin/cf-agent";
/var/cfengine/bin/cf-agent -KIf /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/install_kaf_07.cf -b install_kaf_07:install_kaf_07;

# Explicitly set java 8 as default once packages have been installed. This is for testing whether Kafka components use the explicitly set java 11 instead of falling back to default.
update-alternatives --set java java-1.8.0-openjdk.x86_64;

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

# Stop services
echo "Stopping kafka service(s)";
if [[ "$(hostname)" =~ ^broker.* ]]; then
    echo "Stopping broker only";
    systemctl stop kaf_06-broker;
fi;
if [[ "$(hostname)" =~ ^combined.* ]]; then
    echo "Stopping both broker and controller";
    systemctl stop kaf_06-broker;
    sleep 5;
    systemctl stop kaf_06-controller;
fi;
if [[ "$(hostname)" =~ ^controller.* ]]; then
    echo "Stopping controller only";
    sleep 5;
    systemctl stop kaf_06-controller;
fi;

systemctl start poweroff.target;
