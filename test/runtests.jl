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
@service STS

function assume_role(config::AWSConfig, role_arn::AbstractString; kwargs...)
    response = STS.assume_role(
        role_arn,
        session_name(),
        Dict(kwargs...);
        aws_config=config
    )

    response_creds = response["Credentials"]
    response_user = response["AssumedRoleUser"]

    AWSCredentials(
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
    ts = string(round(Int, time()))

    # RoleSessionName must be no more than 64 characters
    max_name_length = 64 - length(ts) - 1

    if length(name) > max_name_length
        name = name[1:max_name_length-3] * "..."
    end

    return "$name-$ts"
end

function stack_output(config::AWSConfig, stack_name::AbstractString)
    outputs = Dict{String, String}()


    response = CloudFormation.describe_stacks(
        Dict("StackName" => stack_name);
        aws_config=config
    )

    for entry in response["DescribeStacksResult"]["Stacks"]["member"]["Outputs"]
        outputs[entry["OutputKey"]] = entry["OutputValue"]
    end

    return outputs
end


@testset "CloudWatchLogs.jl" begin
    include("event.jl")
    include("mocked_aws.jl")
    include("online.jl")
end
