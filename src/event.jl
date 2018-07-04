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
