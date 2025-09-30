#!/bin/bash

MYSQL_USER=wso2carbon
MYSQL_PASSWORD=wso2carbon
WSO2AM_SHARED_DB=WSO2AM_SHARED_DB
WSO2AM_DB=WSO2AM_DB

print_title() {
  local title="$1"
  echo
  tput bold
  tput setaf 2  # Green text
  echo "=== $title ==="
  tput sgr0     # Reset formatting
  echo
}

# Function to wait for a service to start
wait_for_service_start() {
    local service_name=$1
    local port_offset=$2
    local base_port=9763
    local check_port=$((base_port + port_offset))
    
    echo "Waiting for $service_name to start..."
    local max_retries=30
    local counter=0
    while [ $counter -lt $max_retries ]; do
        if curl --silent --fail http://localhost:$check_port/services/Version > /dev/null; then
            echo "$service_name is up and running"
            return 0
        fi
        echo "Waiting for $service_name to start... ($counter/$max_retries)"
        counter=$((counter+1))
        sleep 5
    done

    if [ $counter -eq $max_retries ]; then
        echo "Error: $service_name did not start within the expected time"
        return 1
    fi
}

stop_services() {
    print_title "Stopping apim-acp"
    sh ./components/wso2am-acp/bin/api-cp.sh --stop
    print_title "Stopping apim-tm"
    sh ./components/wso2am-tm/bin/traffic-manager.sh --stop
    print_title "Stopping apim-universal-gw"
    sh ./components/wso2am-universal-gw/bin/gateway.sh --stop

    # Stop docker containers
    docker-compose down
}

clean_services() {
    print_title "Cleaning services"
    docker volume rm apim-distributed-dev-setup_mysql-apim-data

    ps -ef | grep 'wso2' | grep -v grep | awk '{print $2}' | xargs -r kill -9
}

# Process input arguments
for c in $*
do
    if [ "$c" = "--stop" ] || [ "$c" = "-stop" ] || [ "$c" = "stop" ]; then
        CMD="stop"
    elif [ "$c" = "--start" ] || [ "$c" = "-start" ] || [ "$c" = "start" ]; then
          CMD="start"
    elif [ "$c" = "--seed" ] || [ "$c" = "-seed" ]; then
          SEED="seed"
    elif [ "$c" = "--restart" ] || [ "$c" = "-restart" ] || [ "$c" = "restart" ]; then
          CMD="restart"
    elif [ "$c" = "--clean" ] || [ "$c" = "-clean" ]; then
          CLEAN="clean"
    elif [ "$c" = "--help" ] || [ "$c" = "-h" ]; then
        echo "Usage: $0 [--start | --stop | --restart | --seed | --clean | --help]"
        echo "  start: Start the services"
        echo "  stop: Stop the services"
        # echo "  --restart: Restart the services"
        echo "  --seed: Seed the database, use with start"
        echo "  --clean: Clean the services, use with stop"
        exit 0
    else
        echo "Unknown option: $c"
        exit 1
    fi
done

# Stop services
if [ "$CMD" = "stop" ]; then
    stop_services

    if [ "$CLEAN" = "clean" ]; then
        clean_services
    fi
    exit 0
fi

mkdir -p logs
rm -rf logs/*

# Copy deployment.toml files
print_title "Copying deployment.toml files"
cp -v -r ./conf/apim-acp/repository/* ./components/wso2am-acp/repository/
cp -v -r ./conf/apim-tm/repository/* ./components/wso2am-tm/repository/
cp -v -r ./conf/apim-universal-gw/repository/* ./components/wso2am-universal-gw/repository/

# Copy mysql-connector-j-8.4.0.jar
print_title "Copying mysql-connector-j-8.4.0.jar"
cp -v ./lib/mysql-connector-j-8.4.0.jar ./components/wso2am-acp/repository/components/lib/
cp -v ./lib/mysql-connector-j-8.4.0.jar ./components/wso2am-tm/repository/components/lib/
cp -v ./lib/mysql-connector-j-8.4.0.jar ./components/wso2am-universal-gw/repository/components/lib/

# Start docker containers
print_title "Starting docker containers"
docker-compose up -d

# Wait for mysql to start
echo "Waiting for mysql to start..."
docker-compose exec mysql mysqladmin --silent --wait=60 -uroot -proot -h127.0.0.1 ping
if [ $? -ne 0 ]; then
    echo "Error: mysql did not start within the expected time"
    exit $?
fi

sleep 10

# Seed database if seed flag is set
if [ "$SEED" = "seed" ] && [ "$CMD" != "stop" ]; then
    print_title "Seeding database"
    docker-compose exec mysql mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h127.0.0.1 -e "USE $WSO2AM_SHARED_DB; source /home/dbScripts/mysql.sql"
    sleep 10
    docker-compose exec mysql mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h127.0.0.1 -e "USE $WSO2AM_DB; source /home/dbScripts/apimgt/mysql.sql"
    sleep 10
fi

# Start apim-acp
print_title "Starting apim-acp"
sh ./components/wso2am-acp/bin/api-cp.sh > logs/apim-acp.log 2>&1 &
if [ $? -ne 0 ]; then
    echo "Error starting apim-acp. Exiting."
    exit $?
fi
# Wait until apim-acp is fully started and responding
wait_for_service_start "apim-acp" 0

# Start apim-tm
print_title "Starting apim-tm"
sh ./components/wso2am-tm/bin/traffic-manager.sh -DportOffset=1 > logs/apim-tm.log 2>&1 &
if [ $? -ne 0 ]; then
    echo "Error starting apim-tm. Exiting."
    exit $?
fi
# Wait until apim-tm is fully started and responding
wait_for_service_start "apim-tm" 1

# Start apim-universal-gw
print_title "Starting apim-universal-gw"
sh ./components/wso2am-universal-gw/bin/gateway.sh -DportOffset=2 > logs/apim-universal-gw.log 2>&1 &
if [ $? -ne 0 ]; then
    echo "Error starting apim-universal-gw. Exiting."
    exit $?
fi
# Wait until apim-universal-gw is fully started and responding
wait_for_service_start "apim-universal-gw" 2
