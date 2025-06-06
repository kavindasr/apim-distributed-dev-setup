DROP DATABASE IF EXISTS WSO2AM_SHARED_DB;
CREATE DATABASE WSO2AM_SHARED_DB CHARACTER SET latin1;

CREATE USER IF NOT EXISTS 'wso2carbon'@'%' IDENTIFIED BY 'wso2carbon';
GRANT ALL PRIVILEGES ON WSO2AM_SHARED_DB.* TO 'wso2carbon'@'%';
FLUSH PRIVILEGES;
