```
Usage: check-cloudwatch.rb (options)
    -k ACCESS_KEY_ID,                AWS access key id.
        --access-key-id
    -C, --critical-over N            Critical if metric statistics is over specified value.
    -c, --critical-under N           Critical if metric statistics is under specified value.
        --default-value N            Use this value if no datapoint found.
        --dimension-name DIMENSION_NAME
                                     CloudWatch dimension name. (required)
        --dimension-value DIMENSION_VALUE
                                     CloudWatch dimension value. (required)
        --end-time-offset N          Get metric statistics specified seconds ago.
        --interval N                 CloudWatch statistics method.
        --metric-name METRIC_NAME    CloudWatch metric name. (required)
        --namespace NAMESPACE        CloudWatch namespace. (required)
        --period N                   CloudWatch datapoint period.
        --profile PROFILE            Profile name of AWS shared credential file entry.
    -r, --region REGION              AWS region.
    -s SECRET_ACCESS_KEY,            AWS secret access key.
        --secret-access-key
        --statistics STATISTICS      CloudWatch statistics method. (required)
        --unit UNIT                  CloudWatch statistics unit.
    -W, --warning-over N             Warning if metric statistics is over specified value.
    -w, --warning-under N            Warning if metric statistics is under specified value.
```
