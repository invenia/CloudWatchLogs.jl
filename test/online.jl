@testset "Online" begin

CI_USER_CFG = aws_config()
TEST_STACK_NAME = "CloudWatchLogs-jl-00009"
TEST_RESOURCE_PREFIX = "pubci-$TEST_STACK_NAME-cwl-test"
TEST_LOG_GROUP = "$TEST_RESOURCE_PREFIX-group"
FORBIDDEN_LOG_GROUP = "$TEST_RESOURCE_PREFIX-group-forbidden"
FORBIDDEN_GROUP_LOG_STREAM = "$TEST_RESOURCE_PREFIX-group-forbidden-stream"
BAD_STREAM_LOG_GROUP = "$TEST_RESOURCE_PREFIX-group-badstream"
FORBIDDEN_LOG_STREAM = "$TEST_RESOURCE_PREFIX-stream-forbidden"
TEST_ROLE = stack_output(CI_USER_CFG, TEST_STACK_NAME)["LogTestRoleArn"]
CFG = aws_config(creds=assume_role(CI_USER_CFG, TEST_ROLE; DurationSeconds=7200))

@testset "Create/delete streams" begin
    @testset "Named stream" begin
        stream_name = "pubci-create_stream-001-$(uuid1())"
        @test create_stream(CFG, TEST_LOG_GROUP, stream_name) == stream_name

        response = CloudWatchLogsSDK.describe_log_streams(
            CFG;
            logGroupName=TEST_LOG_GROUP,
            logStreamNamePrefix=stream_name,
            orderBy="LogStreamName",  # orderBy and limit will ensure we get just the one
            limit=1,                  # matching result
        )

        streams = response["logStreams"]

        @test !isempty(streams)
        @test streams[1]["logStreamName"] == stream_name

        delete_stream(CFG, TEST_LOG_GROUP, stream_name)

        response = CloudWatchLogsSDK.describe_log_streams(
            CFG;
            logGroupName=TEST_LOG_GROUP,
            logStreamNamePrefix=stream_name,
            orderBy="LogStreamName",  # orderBy and limit will ensure we get just the one
            limit=1,                  # matching result
        )

        streams = response["logStreams"]

        @test isempty(streams) || streams[1]["logStreamName"] != stream_name
    end

    @testset "Unnamed stream" begin
        stream_name = create_stream(CFG, TEST_LOG_GROUP)

        response = CloudWatchLogsSDK.describe_log_streams(
            CFG;
            logGroupName=TEST_LOG_GROUP,
            logStreamNamePrefix=stream_name,
            orderBy="LogStreamName",  # orderBy and limit will ensure we get just the one
            limit=1,                  # matching result
        )

        streams = response["logStreams"]

        @test !isempty(streams)
        @test streams[1]["logStreamName"] == stream_name

        delete_stream(CFG, TEST_LOG_GROUP, stream_name)

        response = CloudWatchLogsSDK.describe_log_streams(
            CFG;
            logGroupName=TEST_LOG_GROUP,
            logStreamNamePrefix=stream_name,
            orderBy="LogStreamName",  # orderBy and limit will ensure we get just the one
            limit=1,                  # matching result
        )

        streams = response["logStreams"]

        @test isempty(streams) || streams[1]["logStreamName"] != stream_name
    end

    @testset "Not allowed" begin
        @test_throws AWSException create_stream(CFG, FORBIDDEN_LOG_GROUP)
        @test_throws AWSException delete_stream(CFG, FORBIDDEN_LOG_GROUP, FORBIDDEN_GROUP_LOG_STREAM)
    end
end

@testset "CloudWatchLogStream" begin
    @testset "Normal log submission" begin
        start_time = CloudWatchLogs.unix_timestamp_ms()
        stream_name = "pubci-create_stream-002-$(uuid1())"
        @test create_stream(CFG, TEST_LOG_GROUP, stream_name) == stream_name

        stream = CloudWatchLogStream(CFG, TEST_LOG_GROUP, stream_name)
        @test submit_log(stream, LogEvent("Hello AWS")) == 1
        @test submit_logs(stream, LogEvent.(["Second log", "Third log"])) == 2

        sleep(1)  # wait until AWS has injested the logs; this may or may not be enough
        response = CloudWatchLogsSDK.get_log_events(
            CFG;
            logGroupName=TEST_LOG_GROUP,
            logStreamName=stream_name,
            startFromHead=true,
        )

        time_range = (start_time - 10):(CloudWatchLogs.unix_timestamp_ms() + 10)

        @test length(response["events"]) == 3
        messages = map(response["events"]) do event
            @test round(Int, event["timestamp"]) in time_range
            event["message"]
        end

        @test messages == ["Hello AWS", "Second log", "Third log"]
        delete_stream(CFG, TEST_LOG_GROUP, stream_name)
    end

    @testset "Not allowed" begin
        @test_throws AWSException CloudWatchLogStream(CFG, FORBIDDEN_LOG_GROUP, FORBIDDEN_GROUP_LOG_STREAM)

        stream = CloudWatchLogStream(CFG, BAD_STREAM_LOG_GROUP, FORBIDDEN_LOG_STREAM, nothing)
        @test_throws AWSException submit_log(stream, LogEvent("Foo"))
    end
end

end
