# Overview

Generic CloudWatch check plugin for Sensu.

# Installation

Put `check-cloudwatch.rb` into `/etc/sensu/plugins`.

# Requirement

`aws-sdk-core` gem.

With sensu embedded ruby, do

```
/opt/sensu/embedded/bin/gem install aws-sdk-core
```

# Usage

```
check-cloudwatch.rb (options)
    -k ACCESS_KEY_ID,                AWS access key id.
        --access-key-id
    -C, --critical-over N            Critical if metric statistics is over specified value.
    -c, --critical-under N           Critical if metric statistics is under specified value.
        --default-value N            Use this value if no datapoint found.
    -d DIMENSION_NAME_1:DIMENSION_VALUE_1,DIMENSION_NAME_2:DIMENSION_VALUE_2...,
        --dimensions                 CloudWatch dimension names and values, seperated by commas. (required)
        --end-time-offset N          Get metric statistics specified seconds ago.
        --interval N                 Time interval between start and end for CloudWatch statistics.
    -m, --metric METRIC_NAME:TYPE    CloudWatch metric name and statistics type. (required)
        --namespace NAMESPACE        CloudWatch namespace. (required)
        --period N                   CloudWatch datapoint period.
        --profile PROFILE            Profile name of AWS shared credential file entry.
    -r, --region REGION              AWS region.
    -s SECRET_ACCESS_KEY,            AWS secret access key.
        --secret-access-key
        --unit UNIT                  CloudWatch statistics unit.
    -W, --warning-over N             Warning if metric statistics is over specified value.
    -w, --warning-under N            Warning if metric statistics is under specified value.
```

You can omit `--access-key-id`, `--secret-access-key`, `--profile` and `--region`. If so, this script will try obtaining credentials/region from instance's IAM role and region.

# Example

```
$ ruby check-cloudwatch.rb --namespace AWS/ELB --metric Latency:Average --dimensions LoadBalancerName:myloadbalancer-ABCD1234EF5X --warning-over 0.01 --critical-over 0.1
CheckCloudWatch WARNING: Current metric statistic value: `0.019246597084210074` (Expected equal or under than `0.01`).

Namespace: AWS/ELB
Metric: Latency:Average
Dimensions: ["LoadBalancerName:myloadbalancer-ABCD1234EF5X"]
Start time: 2014-12-25 12:09:34 UTC
End time: 2014-12-25 12:19:34 UTC
Datapoint period: 60
```

# Changelog

**0.2.0**: replace `--metric-name` `--statistics` `--dimension-name` `--dimension-value` with `--metric` `--dimension`.
