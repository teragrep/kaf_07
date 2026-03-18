#!/bin/bash
set -e
echo "Running tests on $(/var/cfengine/bin/cf-agent -V)";

echo "Patching configuration and adding this to brokers and controllers";
jq --arg hostname "$(hostname)" '.kafka.brokers |= .+ [{"hostname": $hostname, "id": "999"}] | .kafka.controllers |= .+ [{"hostname": $hostname, "id": "999"}]' /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json > /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json.patched;
mv -f /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json.patched /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json;

# Run cfengine
echo "Running /var/cfengine/bin/cf-agent";
/var/cfengine/bin/cf-agent -KIf /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/install_kaf_07.cf -b install_kaf_07:install_kaf_07;

for role in broker controller; do
    CONFIG_FILE="/opt/teragrep/kaf_06/config/kafka-${role}.properties";

    # Check config existing
    echo "Checking if ${CONFIG_FILE} exists";
    if ! [ -f "${CONFIG_FILE}" ]; then
        echo "${CONFIG_FILE} doesn't exist, failing";
        exit 1;
    fi;

    # Check that no authorizer must be defined in files
    echo "Checking if authorizer.class.name configuration exists"
    if grep "authorizer.class.name" "${CONFIG_FILE}"; then
        echo "Found authorizer.class.name but it shouldn't exist in ${CONFIG_FILE}, failing";
        exit 1;
    fi;

    echo "Checking if kaf_04 configurations exist";
    if grep "teragrep.kaf_04" "${CONFIG_FILE}"; then
        echo "Found kaf_04 in ${CONFIG_FILE}, failing";
        exit 1;
    fi;
done;

# All is good
echo "Everything seems fine!";
exit 0;
