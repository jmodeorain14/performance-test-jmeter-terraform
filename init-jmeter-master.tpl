#!/bin/bash

# Retrieve the private IP address of the JMeter master EC2 instance
jmeter_master_private_ip_address=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# Retrieve the value of the jmeter_slave_count variable
jmeter_slave_count=${jmeter_slave_count}

# Get the list of the private IP addresses of the JMeter slave EC2 instances
jmeter_slaves_list="${jmeter_slave_private_ip_addresses_str}"

# Print the content of the private_ip_address variable
echo "JMeter Master Private IP: \"$jmeter_master_private_ip_address\"" > /etc/jmeter-master-output.tf

echo "Creating a new file on the new EC2 instance"
echo "Hello, JMeter Master!" > /dev/hellojmetermaster.txt

echo "Update Ubuntu OS"
sudo apt-get update -y

echo "Install AWS CLI"
sudo apt-get install -y awscli

echo "Install libs3-2"
sudo apt-get install -y libs3-2

echo "Install OpenJDK JRE in headless mode"
sudo apt-get install -y openjdk-19-jre-headless

echo "Install Python"
sudo apt-get install -y python3

echo "Install InfluxDB v1.8.0"
cd /home/ubuntu
sudo wget https://dl.influxdata.com/influxdb/releases/influxdb_1.8.10_amd64.deb
sudo dpkg -i influxdb_1.8.10_amd64.deb

echo "Start InfluxDB"
cd /etc
sudo service influxdb start

echo "Install InfluxDB CLI"
cd /home/ubuntu
sudo wget https://dl.influxdata.com/influxdb/releases/influxdb2-client-2.7.3-linux-amd64.tar.gz
sudo tar xvzf -i influxdb2-client-2.7.3-linux-amd64.tar.gz

echo "Create a new database"
cd /home/ubuntu
influx -execute 'CREATE DATABASE jmeter'

echo "Install Grafana v9.4.7"
sudo apt-get install -y adduser libfontconfig1
sudo wget https://dl.grafana.com/oss/release/grafana_9.4.7_amd64.deb
sudo dpkg -i grafana_9.4.7_amd64.deb

echo "Start Grafana"
sudo /bin/systemctl start grafana-server

echo "Download JMeter"
cd /home/ubuntu
sudo wget https://dlcdn.apache.org//jmeter/binaries/apache-jmeter-5.5.tgz
sudo tar xvzf apache-jmeter-5.5.tgz

# The following jmeter.properties settings are used to limit the size of the .jtl test result file
echo "Update jmeter.properties"
cd apache-jmeter-5.5/bin/
sudo sed -i 's/#server_port=1099/server_port=1099/g' jmeter.properties
sudo sed -i 's/#server.rmi.localport=4000/server.rmi.localport=4000/g' jmeter.properties
sudo sed -i 's/#jmeter.save.saveservice.output_format=csv/jmeter.save.saveservice.output_format=csv/g' jmeter.properties
sudo sed -i 's/#jmeter.save.saveservice.data_type=true/jmeter.save.saveservice.data_type=false/g' jmeter.properties
sudo sed -i 's/#jmeter.save.saveservice.label=true/jmeter.save.saveservice.label=true/g' jmeter.properties
sudo sed -i 's/#jmeter.save.saveservice.response_code=true/jmeter.save.saveservice.response_code=true/g' jmeter.properties
sudo sed -i 's/#jmeter.save.saveservice.response_data.on_error=false/jmeter.save.saveservice.response_data.on_error=false/g' jmeter.properties
sudo sed -i 's/#jmeter.save.saveservice.response_message=true/jmeter.save.saveservice.response_message=false/g' jmeter.properties
sudo sed -i 's/#jmeter.save.saveservice.successful=true/jmeter.save.saveservice.successful=true/g' jmeter.properties
sudo sed -i 's/#jmeter.save.saveservice.thread_name=true/jmeter.save.saveservice.thread_name=true/g' jmeter.properties
sudo sed -i 's/#jmeter.save.saveservice.time=true/jmeter.save.saveservice.time=true/g' jmeter.properties
sudo sed -i 's/#jmeter.save.saveservice.subresults=true/jmeter.save.saveservice.subresults=false/g' jmeter.properties
sudo sed -i 's/#jmeter.save.saveservice.assertions=true/jmeter.save.saveservice.assertions=false/g' jmeter.properties
sudo sed -i 's/#jmeter.save.saveservice.latency=true/jmeter.save.saveservice.latency=true/g' jmeter.properties
sudo sed -i 's/#jmeter.save.saveservice.bytes=true/jmeter.save.saveservice.bytes=true/g' jmeter.properties
sudo sed -i 's/#jmeter.save.saveservice.hostname=false/jmeter.save.saveservice.hostname=true/g' jmeter.properties
sudo sed -i 's/#jmeter.save.saveservice.thread_counts=true/jmeter.save.saveservice.thread_counts=true/g' jmeter.properties
sudo sed -i 's/#jmeter.save.saveservice.sample_count=false/jmeter.save.saveservice.sample_count=true/g' jmeter.properties
sudo sed -i 's/#jmeter.save.saveservice.assertion_results_failure_message=true/jmeter.save.saveservice.assertion_results_failure_message=false/g' jmeter.properties
sudo sed -i 's/#jmeter.save.saveservice.timestamp_format=yyyy/MM/dd HH:mm:ss.SSS/jmeter.save.saveservice.timestamp_format=yyyy/MM/dd HH:mm:ss.SSS/g' jmeter.properties
sudo sed -i 's/#jmeter.save.saveservice.default_delimiter=,/jmeter.save.saveservice.default_delimiter=;/g' jmeter.properties
sudo sed -i 's/#jmeter.save.saveservice.print_field_names=true/jmeter.save.saveservice.print_field_names=true/g' jmeter.properties

echo "Generate the SSL certificate"
name="rmi"
orgUnit="unknown"
orgName="unknown"
city="unknown"
state="unknown"
countryCode="unknown"
cd apache-jmeter-5.5/bin
sudo keytool -genkey -alias rmi -keyalg RSA -keystore rmi_keystore.jks -validity 7 -keysize 2048 -storepass changeit -dname "CN=$name, OU=$orgUnit, O=$orgName, L=$city, ST=$state, C=$countryCode"

echo "Upload the SSL certificate file from the EC2 instance to the S3 bucket"
sudo aws s3 cp "/home/ubuntu/apache-jmeter-5.5/bin/rmi_keystore.jks" "s3://${aws_s3_bucket_id}/rmi_keystore.jks"

echo "Copy the JMeter test script file from the S3 bucket to the EC2 instance"
sudo aws s3 cp "s3://${aws_s3_bucket_id}/POC01_BBC_NavigateToHomepage_v01.jmx" "/home/ubuntu/apache-jmeter-5.5/bin/"

echo "Create the TestResults folder to store the test results file"
cd /home/ubuntu/apache-jmeter-5.5/bin/
sudo mkdir -p TestResults
sudo chmod a+w TestResults/

# Wait for the JMeter Slave instance to be ready before we execute the test
sleep 180

# Set the desired timezone and get the current date and time in the required format
echo "Generate the current date and timestamp"
timestamp=$(TZ="Europe/Zurich" date +'%Y-%m-%d_%H-%M-%S')

# Print the JMeter command with options before running it
echo "Running the JMeter test with the following command:"
echo "./jmeter -n -t POC01_BBC_NavigateToHomepage_v01.jmx -R \"$jmeter_slaves_list\" -Gthreads1=1 -Grampup1=10 -Giter1=5 -l \"TestResults/${filename}\""

echo "Run the JMeter test"
echo "Save the results to a file with the timestamp in the filename"
cd /home/ubuntu/apache-jmeter-5.5/bin/
# Use the variable $jmeter_slaves_list as the -R option to pass all JMeter Slave IPs
sudo ./jmeter -n -t POC01_BBC_NavigateToHomepage_v01.jmx -R "$jmeter_slaves_list" -Gthreads1=1 -Grampup1=10 -Giter1=2 -l "TestResults/${filename}"

echo "Upload the test results file from the EC2 instance to the S3 bucket"
sudo aws s3 cp "/home/ubuntu/apache-jmeter-5.5/bin/TestResults/${filename}" "s3://${aws_s3_bucket_id}/test-results/"
