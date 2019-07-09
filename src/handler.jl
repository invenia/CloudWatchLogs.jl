# Do not share a stream between processes
# The token would be shared so putting would give InvalidSequenceTokenException a lot
struct CloudWatchLogHandler{F<:Formatter} <: Handler{F, Union{}}
    stream::CloudWatchLogStream
    channel::Channel{LogEvent}  # only one task should read from this channel
    fmt::F
end

"""
    CloudWatchLogHandler(
        config::AWSConfig,
        log_group_name,
        log_stream_name,
        formatter::Memento.Formatter,
    )

Construct a Memento Handler for logging to a CloudWatch Log Stream.
This constructor creates a task which asynchronously submits logs to the stream.

A CloudWatch Log Event has only two properties: `timestamp` and `message`.

If a `Record` has a `date` property it will be used as the `timestamp`, otherwise the
current time will be captured when `Memento.emit` is called.
All `DateTime`s will be assumed to be in UTC.

The `message` will be generated by calling `Memento.format` on the `Record` with this
handler's `formatter`.
"""
function CloudWatchLogHandler(
    config::AWSConfig,
    log_group_name::AbstractString,
    log_stream_name::AbstractString,
    formatter::F=DefaultFormatter(),
) where F<:Formatter
    ch = Channel{LogEvent}(Inf)
    handler = CloudWatchLogHandler(
        CloudWatchLogStream(config, log_group_name, log_stream_name),
        ch,
        formatter,
    )

    tsk = @async process_logs!(handler)
    # channel will be closed if task fails, to avoid unknowingly discarding logs
    bind(ch, tsk)

    return handler
end

function process_available_logs!(handler::CloudWatchLogHandler)
    events = Vector{LogEvent}()
    batch_size = 0

    while isready(handler.channel) && length(events) < MAX_BATCH_LENGTH
        event = fetch(handler.channel)
        batch_size += aws_size(event)
        if batch_size <= MAX_BATCH_SIZE
            take!(handler.channel)
            push!(events, event)
        else
            break
        end
    end

    if isempty(events)
        warn(LOGGER, string(
            "Channel was ready but no events were found. ",
            "Is there another task pulling logs from this handler?",
        ))
    end

    try
        @mock submit_logs(handler.stream, events)
    catch e
        warn(LOGGER, CapturedException(e, catch_backtrace()))
    end
end

"""
    process_logs!(handler::CloudWatchLogHandler)

Continually pulls logs from the handler's channel and submits them to AWS.
This function should terminate silently when the channel is closed.
"""
function process_logs!(handler::CloudWatchLogHandler)
    group = handler.stream.log_group_name
    stream = handler.stream.log_stream_name

    debug(LOGGER, "Handler for group '$group' stream '$stream' initiated")

    try
        while isopen(handler.channel)  # might be able to avoid the error in this case
            wait(handler.channel)
            process_available_logs!(handler)
            sleep(PUTLOGEVENTS_RATE_LIMIT)  # wait at least this long due to AWS rate limits
        end
    catch err
        if !(err isa InvalidStateException && err.state === :closed)
            log(
                LOGGER,
                :error,
                "Handler for group '$group' stream '$stream' terminated unexpectedly",
            )
            error(LOGGER, CapturedException(err, catch_backtrace()))
        end
    end

    debug(LOGGER, "Handler for group '$group' stream '$stream' terminated normally")

    return nothing
end

function Memento.emit(handler::CloudWatchLogHandler, record::Record)
    dt = haskey(record, :date) ? record.:date : Dates.now(tz"UTC")
    message = format(handler.fmt, record)
    event = LogEvent(message, dt)
    put!(handler.channel, event)
end
