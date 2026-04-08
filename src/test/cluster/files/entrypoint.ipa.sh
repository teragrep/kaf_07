#!/usr/bin/bash
# Shared shared directory doesn't exist, halt.
if [ ! -d /shared ]; then
    echo "Can't continue, /shared doesn't exist";
    exit 1;
fi;
set -e;

echo "${IPA_01_ADMIN_PASSWORD}" | kinit admin;
ipa pwpolicy-mod global_policy --maxlife=0 --minlife=0;

# Force add host first so we don't have to do trickery between hosts joining and then creating keytabs and..
for node in broker-one combined-two combined-three controller-four; do
    echo "Creating new host";
    ipa host-add --force "${node}.kafka3-cluster.dev.test";
    echo "Creating keytabs for kafka/${node}";
    ipa service-add --force "kafka/${node}.kafka3-cluster.dev.test@KAFKA3-CLUSTER.DEV.TEST";
    ipa-getkeytab -s ipa.kafka3-cluster.dev.test -p "kafka/${node}.kafka3-cluster.dev.test@KAFKA3-CLUSTER.DEV.TEST" -k "/shared/kafka_${node}.keytab" -e aes256-cts-hmac-sha1-96,aes128-cts-hmac-sha1-96;
done;

chmod 644 /shared/*

# Create users
for user in $(jq -r '.[].identity' /config/kaf_05/credentials.json); do
    echo "Creating users '${user}'";
    ipa user-add "${user}" --first="${user}" --last="${user}";
done;

# Create groups
for group in $(jq -r '.[].group' /config/kaf_04/authorize.json); do
    echo "Creating group '${group}'";
    ipa group-add "${group}";
done;

# Add users to groups
echo "Adding users to groups";
ipa group-add-member kafka-admins --users=admin-user
ipa group-add-member kafka-users --users=normal-user

# Just to signal health check
touch /ipa_01.ready;

echo "Waiting for poweroff connection";
nc --verbose --recv-only --listen --source-port 12345;
systemctl start poweroff.target;
