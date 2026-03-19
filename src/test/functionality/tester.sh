#!/bin/bash
set -e
echo "Running tests on $(/var/cfengine/bin/cf-agent -V)";

# Run cfengine
echo "Running /var/cfengine/bin/cf-agent";
/var/cfengine/bin/cf-agent -KIf /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/install_kaf_07.cf -b install_kaf_07:install_kaf_07;

# Check that all packages have been installed
for package in kaf_04 kaf_05 kaf_06; do
    package_name="com.teragrep-${package}";
    echo "Checking if if ${package_name} was installed";
    if [[ ! "$(rpm -qa "${package_name}")" =~ ^${package_name} ]]; then
        echo "Failed to install ${package_name}";
        exit 1;
    fi;
done;

function check_file {
    echo "Checking if file ${1} exists";
    if [ ! -f "${1}" ]; then
        echo "Failed to copy config ${1}";
        exit 1;
    fi;
}

function check_dir {
    echo "Checking if directory ${1} exists";
    if [ ! -d "${1}" ]; then
        echo "Failed to create dir ${1}";
        exit 1;
    fi;
}

# Check dirs
LOGS_PATH="$(jq -r '.kaf_06.dirs.logs' /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json)";
echo "Checking if log dir ${LOGS_PATH} were properly made";
check_dir "${LOGS_PATH}"

# Check kaf_04
echo "Checking if kaf_04 configs got copied properly";
KAF_04_PATH="$(jq -r '.kaf_04.dirs.etc' /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json)";
for file in authorize.json cluster.json identitySuffix.json writer.json; do
    check_file "${KAF_04_PATH}/${file}";
done;

# Check kaf_05
echo "Checking if kaf_05 configs got copied properly";
KAF_05_PATH="$(jq -r '.kaf_05.dirs.etc' /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json)";
for file in credentials.cluster.json credentials.json credentials.writer.json identitySuffix.json; do
    check_file "${KAF_05_PATH}/${file}";
done;

# Check kaf_06
echo "Checking if kaf_06 kafka.jaas.conf got copied properly";
KAF_06_PATH="$(jq -r '.kaf_06.dirs.etc' /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json)";
check_file "${KAF_06_PATH}/kafka.jaas.conf";

# Check if broker/controller configurations exists - they should not at this point.
for file in kafka-broker.properties kafka-controller.properties; do
    echo "Checking if ${KAF_06_PATH}/${file} exists";
    if [ -f "${KAF_06_PATH}/${file}" ]; then
        echo "${KAF_06_PATH}/${file} exists but shouldn't, failing";
        exit 1;
    fi;
done;

# Check if broker/controller data dirs are made - they should nto at this point
DATA_PATH="$(jq -r '.kafka.config.log_dirs' /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json)";
for role in broker controller; do
    echo "Checking if ${DATA_PATH}/${role} exists";
    if [ -d "${DATA_PATH}/${role}" ]; then
        echo "${DATA_PATH}/${role} exists but shouldn't, failing";
        exit 1;
    fi;
done;

# Patch myself as a broker and re-run
echo "Patching configuration and adding this to brokers";
jq --arg hostname "$(hostname)" '.kafka.brokers |= .+ [{"hostname": $hostname, "id": "999"}]' /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json > /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json.patched;
mv -f /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json.patched /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json;
echo "Running /var/cfengine/bin/cf-agent again, should expand only broker config now";
/var/cfengine/bin/cf-agent -KIf /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/install_kaf_07.cf -b install_kaf_07:install_kaf_07;
check_file "${KAF_06_PATH}/kafka-broker.properties";
if [ -f "${KAF_06_PATH}/kafka-controller.properties" ]; then
    echo "${KAF_06_PATH}/kafka-controller.properties exists but shouldn't, failing";
    exit 1;
fi;

# Check dirs
echo "Checking if data dirs were properly made for broker";
check_dir "${DATA_PATH}/broker"
echo "Checking if meta.properties were properly made for broker";
check_file "${DATA_PATH}/broker/meta.properties"

# Patch myself as a controller and re-run
echo "Patching configuration and adding this to controllers";
jq --arg hostname "$(hostname)" '.kafka.controllers |= .+ [{"hostname": $hostname, "id": "999"}]' /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json > /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json.patched;
mv -f /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json.patched /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json;
echo "Running /var/cfengine/bin/cf-agent again, should expand controller config as well";
/var/cfengine/bin/cf-agent -KIf /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/install_kaf_07.cf -b install_kaf_07:install_kaf_07;
check_file "${KAF_06_PATH}/kafka-controller.properties";

# Check dirs
echo "Checking if data dirs were properly made for controller";
check_dir "${DATA_PATH}/controller"
echo "Checking if meta.properties were properly made for controller";
check_file "${DATA_PATH}/controller/meta.properties"

# Check service files
for role in broker controller; do
    check_file "/usr/lib/systemd/system/kaf_06-${role}.service";
done;

# Check that both configs are properly expanded;
for role in broker controller; do
    echo "Checking whether authorization configuration is correct for ${role}";
    # Check that authorizer exists
    if ! grep "authorizer.class.name=com.teragrep.kaf_04.TeragrepKafkaAuthorizer" "/opt/teragrep/kaf_06/config/kafka-${role}.properties"; then
        echo "Can't find TeragrepKafkaAuthorizer in /opt/teragrep/kaf_06/config/kafka-${role}.properties, failing";
        exit 1;
    fi;

    # The default authorizer jaas should contain credentials.file and such properties
    if ! grep "credentials.file" "/opt/teragrep/kaf_06/config/kafka-${role}.properties"; then
        echo "Wrong listener.name.sasl_plaintext.plain.sasl.jaas.config setting detected in /opt/teragrep/kaf_06/config/kafka-${role}.properties, failing";
        exit 1;
    fi;
done;

# Test JMX password expansion for broker, it should exist
for filetype in access password; do
    JMX_PATH="/opt/teragrep/kaf_06/config/jmxremote-broker.${filetype}";
    echo "Checking if '${JMX_PATH}' exists";
    if [ ! -f "${JMX_PATH}" ]; then
        echo "Failed to find '${JMX_PATH}', failing";
        exit 1;
    fi;
done;
JMX_PASSWORD="$(jq -r '.kafka.jmx.broker.password' /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json)";
JMX_PASSWORD_FILE="/opt/teragrep/kaf_06/config/jmxremote-broker.password";
echo "Checking if JMX password '${JMX_PASSWORD}' was correctly set in the '${JMX_PASSWORD_FILE}' file";
if ! grep "${JMX_PASSWORD}" "${JMX_PASSWORD_FILE}"; then
    echo "Can't find '${JMX_PASSWORD}' from '${JMX_PASSWORD_FILE}', failing";
    exit 1;
fi;

# Check if JMX files exist for controller
for filetype in access password; do
    JMX_PATH="/opt/teragrep/kaf_06/config/jmxremote-controller.${filetype}";
    echo "Checking if '${JMX_PATH}' exists";
    if [ -f "${JMX_PATH}" ]; then
        echo "Found '${JMX_PATH}', failing";
        exit 1;
    fi;
done;

# Check whether KAFKA_JMX_OPTS is enabled in service files
# Broker: Enabled
echo "Checking if KAFKA_JMX_OPTS exists in broker service file";
if ! grep "Environment=KAFKA_JMX_OPTS=" /usr/lib/systemd/system/kaf_06-broker.service; then
    echo "Can't find KAFKA_JMX_OPTS from broker service file, but it should exist, failing";
    exit 1;
fi;

# Controller: Disabled
echo "Checking if KAFKA_JMX_OPTS exists in controller service file";
if grep "Environment=KAFKA_JMX_OPTS=" /usr/lib/systemd/system/kaf_06-controller.service; then
    echo "Found KAFKA_JMX_OPTS from controller service file, but it shouldn't exist, failing";
    exit 1;
fi;

# Check if JAVA_HOME was set properly
EXPECTED_JAVA_HOME="$(jq --raw-output '.kafka.java_home' /var/cfengine/private/cf-scripts/promises/com.teragrep-kaf_07/config/config.json)";
if [ "${EXPECTED_JAVA_HOME}" == "" ]; then
    echo "Failed to find value for java_home from configuration, failing";
    exit 1;
fi;
echo "Checking if JAVA_HOME '${EXPECTED_JAVA_HOME}' was set properly in service files";
for role in broker controller; do
    echo "Checking for JAVA_HOME in service file for role ${role}";
    if ! grep "Environment=JAVA_HOME=\"${EXPECTED_JAVA_HOME}\"" "/usr/lib/systemd/system/kaf_06-${role}.service"; then
        echo "Failed to find correct JAVA_HOME for role '${role}', failing";
        exit 1;
    fi;
done;

# All is good
echo "Everything seems fine!";
exit 0;
