"""
    LogEvent(message, timestamp)

Log event for submission to CloudWatch Logs.
"""
struct LogEvent
    message::String
    timestamp::Int

    function LogEvent(message, timestamp)
        if isempty(message)
            throw(ArgumentError("Log Event message must be non-empty"))
        end

        if timestamp < 0
            throw(ArgumentError("Log Event timestamp must be non-negative"))
        end

        new(message, timestamp)
    end
end

"""
    aws_size(event::LogEvent) -> Int

Returns the size of a log event as represented by AWS, used to calculate the log batch size.

See the Amazon CloudWatch Logs documentation for [`PutLogEvents`](https://docs.aws.amazon.com/AmazonCloudWatchLogs/latest/APIReference/API_PutLogEvents.html#CWL-PutLogEvents-request-sequenceToken).
"""
aws_size(event::LogEvent) = sizeof(event.message) + 26

message(event::LogEvent) = event.message
timestamp(event::LogEvent) = event.timestamp
