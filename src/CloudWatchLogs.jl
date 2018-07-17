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
const MAX_BATCH_SIZE = 1048576
const MAX_BATCH_LENGTH = 10000

__init__() = Memento.register(LOGGER)

include("exceptions.jl")
include("event.jl")
include("stream.jl")
include("handler.jl")

end
