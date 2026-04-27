# apim-distributed-dev-setup

This repository provides a straightforward setup for a distributed API Management (APIM) development environment. You can either manually copy packs into the `components` directory or use the `--packs-dir` flag to automatically extract and set up components from zip files.

When you execute the startup script, it initializes a MySQL Docker container and runs the scripts located in `conf/mysql/scripts`. Subsequently, the APIM components are launched with the configurations specified below:

- **APIM-ACP**: Zero offset
- **APIM-TM**: Offset of 1
- **APIM-Universal-GW**: Offset of 2

### Prerequisites

- Docker Engine 20.10.x or newer
- Docker Compose v2.x or newer
- APIM packs
- WSO2 credentials (for pack updates)

### Getting Started

1. Clone the repository:
    ```bash
    git clone https://github.com/yourusername/apim-distributed-dev-setup.git
    cd apim-distributed-dev-setup
    ```

2. **Option A**: Extract the packs manually into the `components` directory:
    Ensure the packs are placed in the `components` directory with the following exact folder names:
    - `wso2am-acp`
    - `wso2am-tm`
    - `wso2am-universal-gw`
    ```
    components
    ├── wso2am-acp
    ├── wso2am-tm
    └── wso2am-universal-gw
    ```

    **Option B**: Use `--packs-dir` to automatically setup from zip files:
    ```bash
    sh run.sh --packs-dir=/path/to/zips start
    ```
    The script will detect component types based on filename (files containing `acp`, `tm`/`traffic`, or `gw`/`gateway`) and extract them with the correct names.

3. Build and start the APIM distributed setup:
    ```bash
    sh run.sh start --seed  # The `--seed` argument ensures that the database scripts are executed during startup.
    ```

4. Start the distributed setup without executing the database scripts:
    ```bash
    sh run.sh start
    ```

5. Access the portals at the following URLs:
    ```
    Control Plane: https://localhost:9443
    Gateway: https://localhost:8245
    ```

6. Stop the services:
    ```bash
    sh run.sh --stop
    ```

7. Stop services and remove the DB volume
    ```bash
    sh run.sh stop --clean
    ```

### Usage

```bash
./run.sh [options] <command>
```

**Commands:**
| Command | Description |
|---------|-------------|
| `start` | Start the services |
| `stop` | Stop the services |

**Options (can be combined):**
| Option | Description |
|--------|-------------|
| `--packs-dir=<path>` | Setup components from zip files in specified directory |
| `--update` | Update packs using WSO2 Update Tool before starting |
| `--update-staging` | Update packs to staging (TESTING level) before starting |
| `--seed` | Seed the database with initial scripts |
| `--clean` | Clean the services and remove DB volume (use with stop) |

**Examples:**
```bash
# Start services
sh run.sh start

# Seed DB and start
sh run.sh --seed start

# Update packs and start
sh run.sh --update start

# Update packs to staging and start
sh run.sh --update-staging start

# Setup from zips and start
sh run.sh --packs-dir=/path/to/zips start

# Full setup: extract zips, update to staging, seed DB, and start
sh run.sh --packs-dir=/path/to/zips --update-staging --seed start

# Stop and clean
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
