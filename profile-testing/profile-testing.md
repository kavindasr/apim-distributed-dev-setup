# Profile Testing

## Prerequisites
1. Newman – Install with `brew install newman`

This profile is used to verify basic functionality. Here, we execute a Postman collection using Newman.
**Note:** From APIM v4.5.0 onwards, Pizzashack is not available by default. Therefore, you need to add it manually. In this setup, Pizzashack need to be added to the ACP.

## How to Run the Profile Tests
1. Start the APIM distributed setup. Please refer to [README.md](../README.md).
2. Once the distributed setup is up and running, execute the following command to run the Postman collection:

```bash
newman run Profile-4.6.0.postman_collection.json \
    --environment APIM-4.6.0.postman_environment.json \
    --env-var "cluster_ip=127.0.0.1" \
    --env-var "operation_policy_file_path=./changeHTTPMethod_v2.j2" \
    --insecure \
    --reporters cli,junit \
    --reporter-junit-export newman-profile-results.xml \
    --delay-request 1000
```

- You can also run the Postman collection using the Postman app, which provides a user-friendly interface. However, note that the free version only allows 25 test runs.
