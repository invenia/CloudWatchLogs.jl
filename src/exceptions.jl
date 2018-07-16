abstract type CloudWatchLogsException <: Exception end

struct StreamNotFoundException <: CloudWatchLogsException
    stream::String
    group::String
    msg::Union{String, Nothing}
end

StreamNotFoundException(stream, group) = StreamNotFoundException(stream, group, nothing)

function Base.showerror(io::IO, exception::StreamNotFoundException)
    print(io, "Log stream ", exception.stream, " not found in group ", exception.group, ".")

    if exception.msg !== nothing
        print(io, " ", exception.msg)
    end
end

struct LogSubmissionException <: CloudWatchLogsException
    msg::String
end
