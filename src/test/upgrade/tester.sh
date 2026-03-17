#!/bin/bash
set -e
echo "Running tests on $(/var/cfengine/bin/cf-agent -V)";

check_versions() {
    echo "Checking version for '$1'";
    VERSION="$(rpm -q --queryformat "%{VERSION}" "${1}")";
    echo "Checking if current version '${VERSION}' is '${2}'";
    if [ "${VERSION}" != "${2}" ]; then
        echo "Something went wrong with the old version, failing";
        exit 1;
    fi;
}

# Check dummy versions to exist
for package in kaf_04 kaf_05 kaf_06; do
    check_versions "com.teragrep-${package}" "1.0.0";
done;

# Run cfengine
echo "Running /var/cfengine/bin/cf-agent";
/var/cfengine/bin/cf-agent -KIf /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/install_kaf_07.cf -b install_kaf_07:install_kaf_07;

# Versions should be upgraded
for package in kaf_04 kaf_05 kaf_06; do
    check_versions "com.teragrep-${package}" "$(rpm -q --queryformat "%{VERSION}" "/var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/rpm/${package}.rpm")";
done;

# All is good
echo "Everything seems fine!";
exit 0;
