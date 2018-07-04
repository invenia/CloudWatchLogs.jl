__precompile__()
module CloudWatchLogs

using AWSCore: AWSConfig, AWSException
using AWSSDK.CloudWatchLogs: describe_log_streams, put_log_events
using Compat: @__MODULE__, Nothing
using Memento
using Mocking
using TimeZones

export CloudWatchLogStream, submit_logs
export CloudWatchLogHandler
export StreamNotFoundException

const LOGGER = getlogger(@__MODULE__)
const MAX_BATCH_SIZE = 1048576

__init__() = Memento.register(LOGGER)

include("exceptions.jl")
include("event.jl")
include("stream.jl")
include("handler.jl")

end
