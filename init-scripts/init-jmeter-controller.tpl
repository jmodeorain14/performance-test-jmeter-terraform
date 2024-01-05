#!/bin/bash

# Retrieve the private IP address of the JMeter master EC2 instance
jmeter_master_private_ip_address=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# Retrieve the value of the jmeter_slave_count variable
jmeter_slave_count=${jmeter_slave_count}

# Get the list of the private IP addresses of the JMeter slave EC2 instances
jmeter_slaves_list="${jmeter_slave_private_ip_addresses_str}"

# Print the content of the private_ip_address variable
echo "JMeter Master Private IP: \"$jmeter_master_private_ip_address\"" > /etc/jmeter-master-output.tf

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
sudo sed -i 's/#jmeter.save.saveservice.response_message=true/jmeter.save.saveservice.response_message=true/g' jmeter.properties
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

echo "Create the TestResults and HTMLReport folders to store the test results files"
cd /home/ubuntu/apache-jmeter-5.5/bin/
sudo mkdir -p TestResults
sudo chmod a+w TestResults/
sudo mkdir -p HTMLReport
sudo chmod a+w HTMLReport/

# Wait for the JMeter Slave instance(s) to be ready before we execute the test
sleep 180

# Set the desired timezone and get the current date and time in the required format
echo "Generate the current date and timestamp"
timestamp=$(TZ="Europe/Zurich" date +'%Y-%m-%d_%H-%M-%S')

echo "Run the JMeter test"
echo "Save the results to a file with the timestamp in the filename"
cd /home/ubuntu/apache-jmeter-5.5/bin/
# Use the variable $jmeter_slaves_list as the -R option to pass all JMeter Slave IPs
# -e flag generates the report
# -o flag specifies the output directory where the HTML report will be saved
sudo ./jmeter -n -t POC01_BBC_NavigateToHomepage_v01.jmx -R "$jmeter_slaves_list" -Gthreads1=5 -Grampup1=10 -Giter1=100 -l "TestResults/${filename}" -e -o ./HTMLReport

# Check if the JMeter test execution was successful
if [ $? -eq 0 ]; then
    echo "L&P test executed successfully."

    # Upload the .jtl file to the S3 bucket
    echo "Upload the test results file from the EC2 instance to the S3 bucket"
    sudo aws s3 cp "/home/ubuntu/apache-jmeter-5.5/bin/TestResults/${filename}" "s3://${aws_s3_bucket_id}/test-results/"

    echo "Test results (.jtl) file uploaded to the S3 bucket"

    # Upload the HTML report to the S3 bucket
    echo "Upload the HTML report folder contents from the EC2 instance to the S3 bucket"
    sudo aws s3 sync "/home/ubuntu/apache-jmeter-5.5/bin/HTMLReport/" "s3://${aws_s3_bucket_id}/test-results/"
    
    echo "HTML report uploaded to the S3 bucket"

    # Signal successful completion of the test
    touch "test_completed.flag" # Create a flag file
    echo "export JMETER_TEST_COMPLETED=true" >> /home/ubuntu/env_vars.sh

else
    echo "L&P test execution failed."
fi

# Post the test result file to the Jtl Reporter
echo "Post the test result file to the Jtl Reporter"
curl -X POST 'http://{Jtl_Reporter_Public_IPv4_Address}:5000/api/projects/jmeterterraformproject/scenarios/jmeterterraformscenario/items' \
  -H 'x-access-token: {API_token}' \
  -F "kpi=@/home/ubuntu/apache-jmeter-5.5/bin/TestResults/${filename}" \
  -F 'environment="Test Environment"' \
  -F 'note="PoC Test"'
