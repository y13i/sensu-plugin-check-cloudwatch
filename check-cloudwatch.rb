#!/usr/bin/env ruby

require "sensu-plugin/check/cli"
require "aws-sdk-core"
require "net/http"

class CheckCloudWatch < Sensu::Plugin::Check::CLI
  VERSION = "0.1.0"

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

  option :metric_name,
    description: "CloudWatch metric name.",
    long:        "--metric-name METRIC_NAME",
    required:    true

  option :dimension_name,
    description: "CloudWatch dimension name.",
    long:        "--dimension-name DIMENSION_NAME",
    required:    true

  option :dimension_value,
    description: "CloudWatch dimension value.",
    long:        "--dimension-value DIMENSION_VALUE",
    required:    true

  option :statistics,
    description: "CloudWatch statistics method.",
    long:        "--statistics STATISTICS",
    default:     "Average",
    required:    true

  option :unit,
    description: "CloudWatch statistics unit.",
    long:        "--unit UNIT"

  option :interval,
    description: "CloudWatch statistics method.",
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
      "",
      "Namespace: #{config[:namespace]}",
      "Metric: #{config[:metric_name]}",
      "Dimension: #{config[:dimension_name]}/#{config[:dimension_value]}",
      "Start time: #{start_time}",
      "End time: #{end_time}",
      "Datapoint period: #{config[:period]}",
      "Statistics: #{config[:statistics]}",
    ]

    [:over, :under].each do |over_or_under|
      [:critical, :warning].each do |severity|
        threshold = config[:"#{severity}_#{over_or_under}"]

        next unless threshold

        case over_or_under
        when :over
          if metric_value > threshold
            @messages[1] = "(Expected equal or under than #{threshold})."
            send severity, message
          end
        when :under
          if metric_value < threshold
            @messages[1] = "(Expected equal or over than #{threshold})."
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

    params = {
      namespace:   config[:namespace],
      metric_name: config[:metric_name],
      start_time:  start_time,
      end_time:    end_time,
      period:      config[:period],
      statistics:  [config[:statistics]],

      dimensions: [
        {
          name:  config[:dimension_name],
          value: config[:dimension_value],
        }
      ],
    }

    params.update(unit: config[:unit]) if config[:unit]

    response = cloudwatch_client.get_metric_statistics(params)
    unknown "CloudWatch GetMetricStatics unsuccessful." unless response.successful?

    datapoints = response.data.datapoints

    @metric_value = if datapoints.empty?
      config[:default_value]
    else
      datapoints.sort_by {|datapoint| datapoint.timestamp}.last.send(config[:statistics].downcase.intern)
    end
  end

  def end_time
    @end_time ||= Time.now - config[:end_time_offset]
  end

  def start_time
    @start_time ||= end_time - config[:interval]
  end

  def message
    @messages.compact.join("\n")
  end
end
