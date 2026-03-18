#!/bin/bash
set -e
echo "Running tests on $(/var/cfengine/bin/cf-agent -V)";

# Run cfengine
OUTPUT="$(/var/cfengine/bin/cf-agent -KIf /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/install_kaf_07.cf -b install_kaf_07:install_kaf_07)"

echo "Testing if all messages that should be missing are missing";
for message in kaf_04.rpm kaf_05.rpm kaf_06.rpm config.json authorize.json credentials.json; do
    echo -n "Looking for ${message}: ";
    if ! grep "${message}" <<< "${OUTPUT}"; then
        echo "Can't find ${message}, failing";
        exit 1;
    fi;
done;

# All is good
echo "Everything seems fine!";
exit 0;
