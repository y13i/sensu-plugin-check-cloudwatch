#!/usr/bin/env ruby

require "sensu-plugin/check/cli"
require "aws-sdk-core"

class CheckCloudWatch < Sensu::Plugin::Check::CLI
  VERSION = "0.2.0"

  option :profile,
    description: "Profile name of AWS shared credential file entry.",
    long:        "--profile PROFILE"

  option :access_key_id,
    description: "AWS access key id.",
    short:       "-k ACCESS_KEY_ID",
    long:        "--access-key-id ACCESS_KEY_ID"

  option :secret_access_key,
    description: "AWS secret access key.",
    short:       "-s SECRET_ACCESS_KEY",
    long:        "--secret-access-key SECRET_ACCESS_KEY"

  option :region,
    description: "AWS region.",
    short:       "-r REGION",
    long:        "--region REGION"

  option :warning_over,
    description: "Warning if metric statistics is over specified value.",
    short:       "-W N",
    long:        "--warning-over N",
    proc:        proc {|v| v.to_f}

  option :critical_over,
    description: "Critical if metric statistics is over specified value.",
    short:       "-C N",
    long:        "--critical-over N",
    proc:        proc {|v| v.to_f}

  option :warning_under,
    description: "Warning if metric statistics is under specified value.",
    short:       "-w N",
    long:        "--warning-under N",
    proc:        proc {|v| v.to_f}

  option :critical_under,
    description: "Critical if metric statistics is under specified value.",
    short:       "-c N",
    long:        "--critical-under N",
    proc:        proc {|v| v.to_f}

  option :namespace,
    description: "CloudWatch namespace.",
    long:        "--namespace NAMESPACE",
    required:    true

  option :metric,
    description: "CloudWatch metric name and statistics type.",
    short:       "-m METRIC_NAME:TYPE",
    long:        "--metric METRIC_NAME:TYPE",
    required:    true

  option :dimensions,
    description: "CloudWatch dimension names and values, seperated by commas.",
    short:       "-d DIMENSION_NAME_1:DIMENSION_VALUE_1,DIMENSION_NAME_2:DIMENSION_VALUE_2...",
    long:        "--dimensions DIMENSION_NAME_1:DIMENSION_VALUE_1,DIMENSION_NAME_2:DIMENSION_VALUE_2...",
    required:    true,
    proc:        proc {|v| v.split(",")}

  option :unit,
    description: "CloudWatch statistics unit.",
    long:        "--unit UNIT"

  option :interval,
    description: "Time interval between start and end for CloudWatch statistics.",
    long:        "--interval N",
    default:     600,
    proc:        proc {|v| v.to_i}

  option :end_time_offset,
    description: "Get metric statistics specified seconds ago.",
    long:        "--end-time-offset N",
    default:     0,
    proc:        proc {|v| v.to_i}

  option :period,
    description: "CloudWatch datapoint period.",
    long:        "--period N",
    default:     60,
    proc:        proc {|v| v.to_i}

  option :default_value,
    description: "Use this value if no datapoint found.",
    long:        "--default-value N",
    proc:        proc {|v| v.to_f}

  def run
    @messages = [
      "Current metric statistic value: `#{metric_value}`",
      nil,
      "Namespace: #{config[:namespace]}",
      "Metric: #{config[:metric]}",
      "Dimensions: #{config[:dimensions]}",
      "Start time: #{start_time}",
      "End time: #{end_time}",
      "Datapoint period: #{config[:period]}",
    ]

    [:over, :under].each do |over_or_under|
      [:critical, :warning].each do |severity|
        threshold = config[:"#{severity}_#{over_or_under}"]

        next unless threshold

        case over_or_under
        when :over
          if metric_value > threshold
            @messages.first << " (Expected equal or under than `#{threshold}`)."
            send severity, message
          end
        when :under
          if metric_value < threshold
            @messages.first << " (Expected equal or over than `#{threshold}`)."
            send severity, message
          end
        end
      end
    end

    ok message
  end

  private

  def aws_configuration
    hash = {}

    [:profile, :access_key_id, :secret_access_key, :region].each do |option|
      hash.update(option => config[option]) if config[option]
    end

    hash.update(region: own_region) if hash[:region].nil?
    hash
  end

  def own_region
    @own_region ||= begin
      require "net/http"

      timeout 3 do
        Net::HTTP.get("169.254.169.254", "/latest/meta-data/placement/availability-zone").chop
      end
    rescue
      nil
    end
  end

  def cloudwatch_client
    @cloudwatch_client ||= Aws::CloudWatch::Client.new aws_configuration
  end

  def metric_value
    return @metric_value if @metric_value

    metric_name, statistics = config[:metric].split(":")

    params = {
      namespace:   config[:namespace],
      metric_name: metric_name,
      start_time:  start_time,
      end_time:    end_time,
      period:      config[:period],
      statistics:  [statistics],
      dimensions:  config[:dimensions].map {|d| name, value = d.split(":"); {name: name, value: value}},
    }

    params.update(unit: config[:unit]) if config[:unit]

    response = cloudwatch_client.get_metric_statistics(params)
    unknown "CloudWatch GetMetricStatics unsuccessful." unless response.successful?

    datapoints = response.data.datapoints

    @metric_value = if datapoints.empty?
      config[:default_value]
    else
      datapoints.sort_by {|datapoint| datapoint.timestamp}.last.send(statistics.downcase.intern)
    end
  end

  def end_time
    @end_time ||= Time.now - config[:end_time_offset]
  end

  def start_time
    @start_time ||= end_time - config[:interval]
  end

  def message
    @messages.join("\n")
  end
end
