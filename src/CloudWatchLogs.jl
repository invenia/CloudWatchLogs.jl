__precompile__()
module CloudWatchLogs

using AWSCore: AWSConfig, AWSException
using AWSSDK.CloudWatchLogs:
    describe_log_streams,
    create_log_stream,
    delete_log_stream,
    put_log_events
using Compat: @__MODULE__, Nothing
using Compat.UUIDs
using Memento
using Mocking
using TimeZones

export CloudWatchLogStream, LogEvent, submit_log, submit_logs, create_stream, delete_stream
export CloudWatchLogHandler
export StreamNotFoundException, LogSubmissionException

const LOGGER = getlogger(@__MODULE__)

# Info on limits:
# https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/cloudwatch_limits_cwl.html

# 1 MB (maximum). This limit cannot be changed.
const MAX_BATCH_SIZE = 1048576

# 256 KB (maximum). This limit cannot be changed.
const MAX_EVENT_SIZE = 262144

# https://docs.aws.amazon.com/AmazonCloudWatchLogs/latest/APIReference/API_PutLogEvents.html#CWL-PutLogEvents-request-logEvents
const MAX_BATCH_LENGTH = 10000

# 5 requests per second per log stream. This limit cannot be changed.
const AWS_RATE_LIMIT = 0.2
const AWS_DELAYS = ExponentialBackOff(n=10, first_delay=AWS_RATE_LIMIT, factor=1.1)

__init__() = Memento.register(LOGGER)

include("exceptions.jl")
include("event.jl")
include("stream.jl")
include("handler.jl")

end
