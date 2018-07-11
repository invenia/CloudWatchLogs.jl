struct CloudWatchLogStream
    config::AWSConfig
    log_group_name::String
    log_stream_name::String
    token::Ref{Union{String, Nothing}}

    function CloudWatchLogStream(
        config::AWSConfig,
        log_group_name::AbstractString,
        log_stream_name::AbstractString,
    )
        stream = new(config, log_group_name, log_stream_name, Ref{Union{String, Nothing}}())
        update_sequence_token!(stream)
        return stream
    end
end

function create_stream(
    config::AWSConfig,
    log_group_name::AbstractString,
    # this probably won't collide, most callers should add identifying information though
    log_stream_name::AbstractString="julia-$(uuid4())",
)
    create_log_stream(config; logGroupName=log_group_name, logStreamName=log_stream_name)
    return log_stream_name
end

function delete_stream(
    config::AWSConfig,
    log_group_name::AbstractString,
    log_stream_name::AbstractString,
)
    delete_log_stream(config; logGroupName=log_group_name, logStreamName=log_stream_name)
    return nothing
end

sequence_token(stream::CloudWatchLogStream) = stream.token[]

function new_sequence_token(stream::CloudWatchLogStream)
    return new_sequence_token(stream.config, stream.log_group_name, stream.log_stream_name)
end

function new_sequence_token(
    config::AWSConfig,
    log_group::AbstractString,
    log_stream::AbstractString,
)::Union{String, Nothing}
    response = @mock describe_log_streams(
        config;
        logGroupName=log_group,
        logStreamNamePrefix=log_stream,
        orderBy="LogStreamName",  # orderBy and limit will ensure we get just the one
        limit=1,                  # matching result
    )

    streams = response["logStreams"]

    if isempty(streams) || streams[1]["logStreamName"] != log_stream
        msg = isempty(streams) ? nothing : "Did you mean $(streams[1]["logStreamName"])?"
        error(LOGGER, StreamNotFoundException(log_stream, log_group, msg))
    end

    return get(streams[1], "uploadSequenceToken") do
        debug(LOGGER) do
            string(
                "Log group '$log_group' stream '$log_stream' has no sequence token yet. ",
                "Using null as a default. ",
            )
        end

        return nothing
    end
end

function update_sequence_token!(
    stream::CloudWatchLogStream,
    token=new_sequence_token(stream),
)
    stream.token[] = token
end

function _put_log_events(stream::CloudWatchLogStream, events::AbstractVector{LogEvent})
    put_log_events(
        stream.config;
        logEvents=events,
        logGroupName=stream.log_group_name,
        logStreamName=stream.log_stream_name,
        sequenceToken=sequence_token(stream),
    )
end

function submit_logs(stream::CloudWatchLogStream, events::AbstractVector{LogEvent})
    function retry_cond(s, e)
        if e isa AWSException
            if 500 <= e.cause.status <= 504
                return (s, true)
            elseif e.cause.status == 400 && e.code == "InvalidSequenceTokenException"
                debug(LOGGER) do
                    string(
                        "CloudWatchLogStream encountered InvalidSequenceTokenException. ",
                        "Are you logging to the same stream from multiple tasks?",
                    )
                end

                update_sequence_token!(stream)

                return (s, true)
            end
        end

        return (s, false)
    end

    f = retry(check=retry_cond) do
        @mock _put_log_events(stream, events)
    end

    min_valid_event = 1
    max_valid_event = length(events)

    try
        json_response = f()

        if haskey(json_response, "nextSequenceToken")
            update_sequence_token!(stream, json_response["nextSequenceToken"])
        end

        if haskey(json_response, "rejectedLogEventsInfo")
            rejected_info = json_response["rejectedLogEventsInfo"]

            if haskey(rejected_info, "expiredLogEventEndIndex")
                idx = Int(rejected_info["expiredLogEventEndIndex"]) + 1
                min_valid_event = max(min_valid_event, idx)

                warn(LOGGER) do
                    string(
                        "Cannot log the following events, ",
                        "as they are older than the log retention policy allows: ",
                        events[1:idx],
                    )
                end
            end

            if haskey(rejected_info, "tooOldLogEventEndIndex")
                idx = Int(rejected_info["tooOldLogEventEndIndex"]) + 1
                min_valid_event = max(min_valid_event, idx)

                warn(LOGGER) do
                    string(
                        "Cannot log the following events, ",
                        "as they are more than 14 days old: ",
                        events[1:idx],
                    )
                end
            end

            if haskey(rejected_info, "tooNewLogEventStartIndex")
                idx = Int(rejected_info["tooNewLogEventStartIndex"]) + 1
                max_valid_event = min(max_valid_event, idx)

                warn(LOGGER) do
                    string(
                        "Cannot log the following events, ",
                        "as they are newer than 2 hours in the future: ",
                        events[idx:end],
                    )
                end
            end
        end
    catch e
        warn(LOGGER, CapturedException(e, catch_backtrace()))
    end

    return length(min_valid_event:max_valid_event)
end
