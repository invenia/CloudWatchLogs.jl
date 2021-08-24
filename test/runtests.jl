using CloudWatchLogs
using CloudWatchLogs: MAX_EVENT_SIZE

using AWS
using AWS: AWSException
using Dates
using EzXML
using HTTP
using Printf
using Memento
using Memento.TestUtils
using Mocking
using Test
using TimeZones
using UUIDs

Mocking.activate()

const LOGGER = getlogger(CloudWatchLogs)

@service CloudFormation
@service CloudWatch_Logs
@service STS

function assume_role(config::AWSConfig, role_arn::AbstractString, params::AbstractDict)
    response = STS.assume_role(role_arn, session_name(), params; aws_config=config)

    response = response["AssumeRoleResult"]
    response_creds = response["Credentials"]
    response_user = response["AssumedRoleUser"]

    return AWSCredentials(
        response_creds["AccessKeyId"],
        response_creds["SecretAccessKey"],
        response_creds["SessionToken"],
        response_user["Arn"],
    )
end

function session_name()
    user = get(ENV, "USER", "unknown")
    location = gethostname()

    name = "$user@$location"
    ts = string(round(Int64, time()))

    # RoleSessionName must be no more than 64 characters
    max_name_length = 64 - length(ts) - 1

    if length(name) > max_name_length
        name = name[1:(max_name_length - 3)] * "..."
    end

    return "$name-$ts"
end

function stack_output(config::AWSConfig, stack_name::AbstractString)
    outputs = Dict{String,String}()

    response = CloudFormation.describe_stacks(
        Dict("StackName" => stack_name); aws_config=config
    )

    response = response["DescribeStacksResult"]["Stacks"]["member"]["Outputs"]["member"]

    # If there's only a single output value
    if response isa AbstractDict
        response = [response]
    end

    for entry in response
        outputs[entry["OutputKey"]] = entry["OutputValue"]
    end

    return outputs
end

@testset "CloudWatchLogs.jl" begin
    include("event.jl")
    include("mocked_aws.jl")
    include("online.jl")
end
