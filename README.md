# terraformkafkacluster


------

# make sure to fix the __consumer_offsets topic
bin/kafka-topics.sh --zookeeper zookeeper1:2181/kafka --config min.insync.replicas=1 --topic __consumer_offsets --alter

# read the topic on broker 1 by connecting to broker 2!
bin/kafka-console-consumer.sh --bootstrap-server kafka2:9092 --topic first_topic --from-beginning

# DO THE SAME FOR BROKER 3

# After, you should see three brokers here
bin/zookeeper-shell.sh localhost:2181
ls /kafka/brokers/ids

------

# we can create topics with replication-factor 3 now!
bin/kafka-topics.sh --zookeeper zookeeper1:2181,zookeeper2:2181,zookeeper3:2181/kafka --create --topic second_topic --replication-factor 3 --partitions 3

# we can publish data to Kafka using the bootstrap server list!
bin/kafka-console-producer.sh --broker-list kafka1:9092,kafka2:9092,kafka3:9092 --topic second_topic

# we can read data using any broker too!
bin/kafka-console-consumer.sh --bootstrap-server kafka1:9092,kafka2:9092,kafka3:9092 --topic second_topic --from-beginning

# we can create topics with replication-factor 3 now!
bin/kafka-topics.sh --zookeeper zookeeper1:2181,zookeeper2:2181,zookeeper3:2181/kafka --create --topic third_topic --replication-factor 3 --partitions 3

# let's list topics
bin/kafka-topics.sh --zookeeper zookeeper1:2181,zookeeper2:2181,zookeeper3:2181/kafka --list

# publish some data
bin/kafka-console-producer.sh --broker-list kafka1:9092,kafka2:9092,kafka3:9092 --topic third_topic

# let's delete that topic
bin/kafka-topics.sh --zookeeper zookeeper1:2181,zookeeper2:2181,zookeeper3:2181/kafka --delete --topic third_topic

# it should be deleted shortly:
bin/kafka-topics.sh --zookeeper zookeeper1:2181,zookeeper2:2181,zookeeper3:2181/kafka --list


------


# make sure you can access the zookeeper endpoints
nc -vz zookeeper1 2181
nc -vz zookeeper2 2181
nc -vz zookeeper3 2181

# make sure you can access the kafka endpoints
nc -vz kafka1 9092
nc -vz kafka2 9092
nc -vz kafka3 9092


------


# create a topic with replication factor of 3
bin/kafka-topics.sh --zookeeper zookeeper1:2181,zookeeper2:2181,zookeeper3:2181/kafka --create --topic fourth_topic --replication-factor 3 --partitions 3

# generate 10KB of random data
base64 /dev/urandom | head -c 10000 | egrep -ao "\w" | tr -d '\n' > file10KB.txt

# in a new shell: start a continuous random producer
bin/kafka-producer-perf-test.sh --topic fourth_topic --num-records 10000 --throughput 10 --payload-file file10KB.txt --producer-props acks=1 bootstrap.servers=kafka1:9092,kafka2:9092,kafka3:9092 --payload-delimiter A

# in a new shell: start a consumer
bin/kafka-console-consumer.sh --bootstrap-server kafka1:9092,kafka2:9092,kafka3:9092 --topic fourth_topic


------

# make sure you're in the /home/ubuntu/kafka directory
cat config/server.properties
echo "unclean.leader.election.enable=false" >> config/server.properties
cat config/server.properties

# look at the logs - what was the value before?
cat logs/server.log | grep unclean.leader
# stop the broker
sudo service kafka stop
# restart the broker
sudo service kafka start
# look at the logs - what is the value after?
cat logs/server.log | grep unclean.leader
