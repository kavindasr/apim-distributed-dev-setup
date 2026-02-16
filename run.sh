#!/bin/bash

MYSQL_USER=wso2carbon
MYSQL_PASSWORD=wso2carbon
WSO2AM_SHARED_DB=WSO2AM_SHARED_DB
WSO2AM_DB=WSO2AM_DB
UPDATE_PACKS=""
UPDATE_STAGING=""
PACKS_DIR=""

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

u2() {
    if [ -x "./bin/update_tool_setup.sh" ]; then
        ./bin/update_tool_setup.sh
    fi

    if [ -x "./bin/wso2update_darwin" ]; then
        ./bin/wso2update_darwin --username "$WSO2_USERNAME" --password "$WSO2_PASSWORD" "$@"
    elif [ -x "./bin/wso2update_darwin_arm64" ]; then
        ./bin/wso2update_darwin_arm64 --username "$WSO2_USERNAME" --password "$WSO2_PASSWORD" "$@"
    else
        echo "No suitable wso2update binary found."
        return 1
    fi
}

process_pack() {
    local zip_file="$1"
    shift
    local zip_dir
    local zip_name
    zip_dir=$(dirname "$zip_file")
    zip_name=$(basename "$zip_file")

    echo "Processing $zip_file ..."

    local work_dir
    work_dir=$(mktemp -d)

    unzip -q "$zip_file" -d "$work_dir"

    local root_dir
    root_dir=$(find "$work_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)

    if [ -z "$root_dir" ]; then
        echo "Failed to detect extracted directory for $zip_file"
        rm -rf "$work_dir"
        return 1
    fi

    pushd "$root_dir" > /dev/null

    echo "Updating the update tool for $zip_file ..."
    u2 || echo "Update tool step completed (may have updated or already up-to-date)"

    echo "Running wso2 update for $zip_file ..."
    u2 "$@" || echo "WSO2 update step completed"

    popd > /dev/null

    pushd "$work_dir" > /dev/null
    zip -qr "../$zip_name" .
    popd > /dev/null

    mv "$work_dir/../$zip_name" "$zip_dir/$zip_name"

    rm -rf "$work_dir"

    echo "Completed $zip_file"
}

update_packs() {
    print_title "Updating packs"

    for component_dir in ./components/wso2am-acp ./components/wso2am-tm ./components/wso2am-universal-gw; do
        if [ ! -d "$component_dir" ]; then
            echo "Warning: $component_dir does not exist. Skipping."
            continue
        fi

        echo "Updating $component_dir ..."
        cd "$component_dir" || continue

        echo "Updating the update tool for $component_dir ..."
        u2 || echo "Update tool step completed (may have updated or already up-to-date)"

        echo "Running wso2 update for $component_dir ..."
        u2 || echo "WSO2 update step completed"

        cd - > /dev/null || exit 1
        echo "Completed $component_dir"
    done
}

setup_packs() {
    source_dir="$1"
    
    if [ ! -d "$source_dir" ]; then
        echo "Error: Directory '$source_dir' does not exist"
        return 1
    fi

    print_title "Setting up packs from $source_dir"

    # Find all zip files in the source directory
    zip_count=$(find "$source_dir" -maxdepth 1 -name "*.zip" | wc -l)

    if [ "$zip_count" -eq 0 ]; then
        echo "No zip files found in $source_dir"
        return 1
    fi

    # Create components directory if it doesn't exist
    mkdir -p ./components

    find "$source_dir" -maxdepth 1 -name "*.zip" | while read -r zip_file; do
        zip_name=$(basename "$zip_file")
        target_name=""

        # Determine target directory name based on zip filename (case insensitive)
        case "$zip_name" in
            *[Aa][Cc][Pp]*)
                target_name="wso2am-acp"
                ;;
            *[Tt][Mm]* | *[Tt]raffic*)
                target_name="wso2am-tm"
                ;;
            *[Gg][Ww]* | *[Gg]ateway*)
                target_name="wso2am-universal-gw"
                ;;
            *)
                echo "Warning: Could not determine component type for $zip_name (expected 'acp', 'tm', or 'gw' in filename). Skipping."
                continue
                ;;
        esac

        echo "Processing $zip_name -> $target_name"

        # Remove existing target directory if it exists
        if [ -d "./components/$target_name" ]; then
            echo "Removing existing ./components/$target_name"
            rm -rf "./components/$target_name"
        fi

        # Create temp directory for extraction
        work_dir=$(mktemp -d)

        # Unzip to temp directory
        unzip -q "$zip_file" -d "$work_dir"

        # Find the extracted root folder (exclude __MACOSX metadata folder)
        root_dir=$(find "$work_dir" -mindepth 1 -maxdepth 1 -type d ! -name "__MACOSX" | head -n 1)

        if [ -z "$root_dir" ]; then
            echo "Error: Failed to detect extracted directory for $zip_name"
            rm -rf "$work_dir"
            continue
        fi

        # Move extracted directory to components with the target name
        mv "$root_dir" "./components/$target_name"
        
        # Cleanup temp directory
        rm -rf "$work_dir"

        echo "Installed $zip_name as ./components/$target_name"
    done

    echo "Pack setup completed"
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
        elif [ "$c" = "--update" ] || [ "$c" = "-update" ]; then
            UPDATE_PACKS="update"
        elif [ "$c" = "--update-staging" ] || [ "$c" = "-update-staging" ]; then
            UPDATE_PACKS="update"
            UPDATE_STAGING="staging"
    elif echo "$c" | grep -q '^--packs-dir='; then
            PACKS_DIR=$(echo "$c" | sed 's/^--packs-dir=//')
    elif echo "$c" | grep -q '^-packs-dir='; then
            PACKS_DIR=$(echo "$c" | sed 's/^-packs-dir=//')
    elif [ "$c" = "--help" ] || [ "$c" = "-h" ]; then
        echo "Usage: $0 [options] <command>"
        echo ""
        echo "Commands:"
        echo "  start                 Start the services"
        echo "  stop                  Stop the services"
        echo ""
        echo "Options (can be combined):"
        echo "  --packs-dir=<path>    Setup components from zip files in specified directory"
        echo "  --update              Update packs before starting"
        echo "  --update-staging      Update packs to staging (TESTING level) before starting"
        echo "  --seed                Seed the database"
        echo "  --clean               Clean the services (use with stop)"
        echo ""
        echo "Examples:"
        echo "  $0 start                                      # Start services"
        echo "  $0 --seed start                               # Seed DB and start"
        echo "  $0 --update start                             # Update packs and start"
        echo "  $0 --packs-dir=/path/to/zips start            # Setup from zips and start"
        echo "  $0 --packs-dir=/path/to/zips --update --seed start  # Full setup"
        echo "  $0 stop --clean                               # Stop and clean"
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

# Setup packs from specified directory
if [ -n "$PACKS_DIR" ]; then
    setup_packs "$PACKS_DIR"
fi

if [ "$UPDATE_PACKS" = "update" ] && [ "$CMD" != "stop" ]; then
    read -p "Enter WSO2 username: " WSO2_USERNAME
    read -s -p "Enter WSO2 password: " WSO2_PASSWORD
    echo ""
    export WSO2_USERNAME
    export WSO2_PASSWORD

    if [ "$UPDATE_STAGING" = "staging" ]; then
        export WSO2_UPDATES_UPDATE_LEVEL_STATE=TESTING
        echo "Updating packs to staging (TESTING level)..."
    fi

    update_packs
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
