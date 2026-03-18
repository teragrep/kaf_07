#!/bin/bash
IPA_CLIENT_FLAGS="${IPA_CLIENT_FLAGS:---force-join}"

while ! nc -z "${IPA_SERVER_HOSTNAME}" 1337; do
    sleep 1;
done;

# shellcheck disable=SC2086 # Client flags are intentionally without quotes.
ipa-client-install --server "${IPA_SERVER_HOSTNAME}" --domain "${IPA_DOMAIN,,}" --unattended --no-ntp --principal "admin@${IPA_DOMAIN^^}" --password "${IPA_ADMIN_PASSWORD}" ${IPA_CLIENT_FLAGS};

PREFIX="192.168.121";

KAFKA_HOSTS="${PREFIX}.101:9093,${PREFIX}.102:9093,${PREFIX}.103:9093";

# Writer with both Client and KafkaClient for testing purposes
jq -r '.kafka.credentials.writer | "KafkaClient { org.apache.kafka.common.security.plain.PlainLoginModule required username=\""+.username+"\" password=\""+.password+"\"; };"' /config.json > "/jaas/writer.jaas.conf";
jq -r '.kafka.credentials.writer | "Client { org.apache.kafka.common.security.plain.PlainLoginModule required username=\""+.username+"\" password=\""+.password+"\"; };"' /config.json >> "/jaas/writer.jaas.conf";

# Invalid writer, should not work
echo "KafkaClient { org.apache.kafka.common.security.plain.PlainLoginModule required username=\"not-working\" password=\"not-working\"; };" > "/jaas/not-working.jaas.conf";
echo "Client { org.apache.kafka.common.security.plain.PlainLoginModule required username=\"not-working\" password=\"not-working\"; };" >> "/jaas/not-working.jaas.conf";

# Kafka cluster
echo 'Client { com.sun.security.auth.module.Krb5LoginModule required useKeyTab=true keyTab="/shared/kafka_broker-one.keytab" serviceName="kafka" storeKey=true useTicketCache=false principal="kafka/broker-one.kafka3-default-authz-cluster.dev.test@KAFKA3-DEFAULT-AUTHZ-CLUSTER.DEV.TEST"; };' > /jaas/cluster.jaas.conf
echo 'KafkaClient { com.sun.security.auth.module.Krb5LoginModule required useKeyTab=true keyTab="/shared/kafka_broker-one.keytab" serviceName="kafka" storeKey=true useTicketCache=false principal="kafka/broker-one.kafka3-default-authz-cluster.dev.test@KAFKA3-DEFAULT-AUTHZ-CLUSTER.DEV.TEST"; };' >> /jaas/cluster.jaas.conf

# Check all brokers
for host in 101 102 103; do
    echo "Waiting to see if broker ${PREFIX}.${host}:9093 gets up";
    while ! nc -z "${PREFIX}.${host}" "9093"; do
        sleep 1;
    done;
done;

# Check all controllers
for host in 102 103 104; do
    echo "Waiting to see if controller ${PREFIX}.${host}:9094 gets up";
    while ! nc -z "${PREFIX}.${host}" "9094"; do
        sleep 1;
    done;
done;
echo "All hosts up, starting tests";

for topic in users-test admins-test; do
    echo "Creating ${topic} topic using cluster permissions";
    MESSAGE="$(KAFKA_OPTS="-Djava.security.auth.login.config=/jaas/cluster.jaas.conf" /opt/teragrep/kaf_06/bin/kafka-topics.sh --create --topic "${topic}" --partitions 3 --replication-factor 3 --bootstrap-server "${KAFKA_HOSTS}" --command-config /cluster.properties;)";
    echo "Got message: ${MESSAGE}";
    if ! [ "${MESSAGE}" == "Created topic ${topic}." ]; then
        echo "Failed to create topic, failing";
        exit 1;
    fi;
    echo "Writing to users-test topic";
    for message in one two three; do
        MESSAGE="$(KAFKA_OPTS="-Djava.security.auth.login.config=/jaas/writer.jaas.conf" /opt/teragrep/kaf_06/bin/kafka-console-producer.sh --topic "${topic}" --producer-property sasl.mechanism=PLAIN --producer-property security.protocol=SASL_PLAINTEXT --broker-list "${KAFKA_HOSTS}" 2>&1 <<< "topic ${topic} -> ${message}")"
        echo "Got content: ${MESSAGE}";
        if [[ "${MESSAGE}" =~ "ERROR" ]]; then
            echo "Failed to write messages, failing";
            exit 1;
        fi;
    done;
done;

for user in custom-user custom-admin; do
    for topic in users-test admins-test; do
        echo "Trying to read from topic ${topic} as ${user}";
        MESSAGE="$(KAFKA_OPTS="-Djava.security.auth.login.config=/jaas/${user}.jaas.conf" /opt/teragrep/kaf_06/bin/kafka-console-consumer.sh --topic "${topic}" --consumer-property sasl.mechanism=PLAIN --consumer-property security.protocol=SASL_PLAINTEXT --bootstrap-server "${KAFKA_HOSTS}" --max-messages 3 --from-beginning 2>&1)"
        echo "Got content: ${MESSAGE}";
        if [[ "${MESSAGE}" =~ "Not authorized to read from" ]]; then
            echo "Failed to read from topic what should be readable, failing";
            exit 1;
        fi;
    done;
done;

echo "Trying to read from topic users-test on an account that doesn't exist";
MESSAGE="$(KAFKA_OPTS="-Djava.security.auth.login.config=/jaas/not-working.jaas.conf" /opt/teragrep/kaf_06/bin/kafka-console-consumer.sh --topic "users-test" --consumer-property sasl.mechanism=PLAIN --consumer-property security.protocol=SASL_PLAINTEXT --bootstrap-server "${KAFKA_HOSTS}" --max-messages 3 --from-beginning 2>&1)"
echo "Got content: ${MESSAGE}";
if ! [[ "${MESSAGE}" =~ "Invalid username or password" ]]; then
    echo "Credentials provided should have been incorrect, failing";
    exit 1;
fi;

echo "Trying to create a topic with writers permissions";
MESSAGE="$(KAFKA_OPTS="-Djava.security.auth.login.config=/jaas/writer.jaas.conf" timeout -v 10s /opt/teragrep/kaf_06/bin/kafka-topics.sh --create --topic "make-writer-topic" --partitions 3 --replication-factor 3 --bootstrap-server "${KAFKA_HOSTS}" --command-config /producer.properties 2>&1;)";
echo "Got content: ${MESSAGE}";
if ! [ "${MESSAGE}" == "Created topic make-writer-topic." ]; then
    echo "Writer should be able to create a topic, failing";
    exit 1;
fi;

echo "Trying to create a topic with users permissions";
MESSAGE="$(KAFKA_OPTS="-Djava.security.auth.login.config=/jaas/custom-user.jaas.conf" timeout -v 10s /opt/teragrep/kaf_06/bin/kafka-topics.sh --create --topic "make-custom-user-topic" --partitions 3 --replication-factor 3 --bootstrap-server "${KAFKA_HOSTS}" --command-config /producer.properties 2>&1;)";
echo "Got content: ${MESSAGE}";
if ! [ "${MESSAGE}" == "Created topic make-custom-user-topic." ]; then
    echo "User should be able to make a topic, failing";
    exit 1;
fi;

# Ping all hosts
for host in 100 101 102 103 104; do
    echo "Signaling ${PREFIX}.${host} to shut down";
    nc -z "${PREFIX}.${host}" 12345;
done;

# Signal cluster was success
echo success > /return/cluster.status;

systemctl start poweroff.target;
