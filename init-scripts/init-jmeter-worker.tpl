#!/bin/bash

# Retrieve the private IP address of the JMeter Slave instance
private_ip_address=$(hostname -I | awk '{print $1}')

# Print the contents of the private_ip_address variable
echo "Private IP Address: $private_ip_address"

echo "Update Ubuntu OS"
sudo apt-get update -y

echo "Install AWS CLI"
sudo apt-get install -y awscli

echo "Install libs3-2"
sudo apt-get install -y libs3-2

echo "Install OpenJDK JRE in headless mode"
sudo apt-get install -y openjdk-19-jre-headless

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

echo "Download CMD Runner in the JMeter lib directory"
cd /home/ubuntu/apache-jmeter-5.5/lib
sudo wget https://repo1.maven.org/maven2/kg/apc/cmdrunner/2.3/cmdrunner-2.3.jar

echo "Download JMeter Plugin Manager in the JMeter ext directory"
cd /home/ubuntu/apache-jmeter-5.5/lib/ext/
sudo wget https://repo1.maven.org/maven2/kg/apc/jmeter-plugins-manager/1.9/jmeter-plugins-manager-1.9.jar

echo "Install the Plugins Manager"
sudo java -cp /home/ubuntu/apache-jmeter-5.5/lib/ext/jmeter-plugins-manager-1.9.jar org.jmeterplugins.repository.PluginManagerCMDInstaller

echo "Provide execute permissions to the PluginsManagerCMD.sh file"
cd /home/ubuntu/apache-jmeter-5.5/bin/
sudo chmod +x PluginsManagerCMD.sh

echo "Install the BlazeMeter Uploader plugin"
cd /home/ubuntu/apache-jmeter-5.5/bin/
sudo ./PluginsManagerCMD.sh install jpgc-sense

echo "Update jmeter.properties"
cd apache-jmeter-5.5/bin/
sudo sed -i 's/#server_port=1099/server_port=1099/g' jmeter.properties
sudo sed -i 's/#server.rmi.localport=4000/server.rmi.localport=4000/g' jmeter.properties

echo "Copy the SSL certificate file from the S3 bucket to the EC2 instance"
sudo aws s3 cp s3://${aws_s3_bucket_id}/rmi_keystore.jks /home/ubuntu/apache-jmeter-5.5/bin/

# Loop to check if the file has been successfully downloaded and is present before proceeding
echo "Copy the SSL certificate file from the S3 bucket to the EC2 instance"
while ! sudo aws s3 cp s3://${aws_s3_bucket_id}/rmi_keystore.jks /home/ubuntu/apache-jmeter-5.5/bin/; do
    echo "Waiting for the file to be downloaded..."
    sleep 30
done

echo "Start the JMeter server on port 4000"
cd /home/ubuntu/apache-jmeter-5.5/bin/
sudo ./jmeter-server -Djava.rmi.server.hostname=$private_ip_address -Dserver_port=4000 -Djavax.net.ssl.keyStore=rmi_keystore.jks -Djavax.net.ssl.keyStorePassword=changeit -Djavax.net.ssl.keyAlias=rmi
