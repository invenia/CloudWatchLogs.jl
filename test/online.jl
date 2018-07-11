@testset "Online" begin

CI_USER_CFG = aws_config()
TEST_STACK_NAME = "CloudWatchLogs-jl-00007"
TEST_LOG_GROUP = "pubci-$TEST_STACK_NAME-cwl-test-group"
TEST_ROLE = stack_output(CI_USER_CFG, TEST_STACK_NAME)["LogTestRoleArn"]
CFG = aws_config(creds=assume_role(CI_USER_CFG, TEST_ROLE; DurationSeconds=7200))

@testset "Create/delete streams" begin
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

end
