# apim-distributed-dev-setup

This repository provides a straightforward setup for a distributed API Management (APIM) development environment. Begin by copying the required packs into the `components` directory.

When you execute the startup script, it initializes a MySQL Docker container and runs the scripts located in `conf/mysql/scripts`. Subsequently, the APIM components are launched with the configurations specified below:

- **APIM-CP**: Zero offset
- **APIM-TM**: Offset of 1
- **APIM-GW**: Offset of 2

### Prerequisites

- Docker Engine 20.10.x or newer
- Docker Compose v2.x or newer
- APIM 4.0.0 pack

### Getting Started

1. Clone the repository:
    ```bash
    git clone https://github.com/yourusername/apim-distributed-dev-setup.git
    cd apim-distributed-dev-setup
    ```

2. Update the pack to the required update level and rename the pack to ``wso2am``.

3. Copy the renamed pack into the `components` directory:
    Ensure the pack are placed in the `components` directory with the following folder name:
    - `wso2am`
    ```
    components
    └── wso2am
    ```

4. Build and start the APIM distributed setup:
    ```bash
    sh run.sh start --seed  # The `--seed` argument ensures that the database scripts are executed during startup.
    ```

5. Start the distributed setup without executing the database scripts:
    ```bash
    sh run.sh start
    ```

6. Access the portals at the following URLs:
    ```
    Control Plane: https://localhost:9443
    Gateway: https://localhost:8245
    ```

7. Stop the services:
    ```bash
    sh run.sh --stop
    ```

8. Stop services and remove the DB volume
    ```bash
    sh run.sh stop --clean
    ```

### Environment Configuration

To update any configuration files in the `conf/repository` directory of the packs, make the changes in the `conf/repository` directory. These updates will be automatically copied to the required location when you execute the `run.sh` script.

### Troubleshooting

- Logs for each APIM component can be found in the `logs/` directory. 
- To terminate all WSO2 Java services, use the following command:
    ```bash
    ps -ef | grep 'wso2' | grep -v grep | awk '{print $2}' | xargs -r kill -9
    ```
- If you encounter a database issue, retry the operation. 
