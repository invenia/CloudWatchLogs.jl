using Mocking
Mocking.activate()

using CloudWatchLogs
using CloudWatchLogs: MAX_EVENT_SIZE

using AWS
using AWS.AWSExceptions
using Dates
using EzXML
using HTTP
using Printf
using Memento
using Memento.TestUtils
using Test
using TimeZones
using UUIDs

@service CloudFormation
@service CloudWatch_Logs
@service STS

const LOGGER = getlogger(CloudWatchLogs)


function assume_role(config::AWSConfig, role_arn::AbstractString; kwargs...)
    response = STS.assume_role(
        role_arn,
        session_name(),
        Dict(kwargs);
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
    ts = string(round(Int64, time()))

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

    xml = EzXML.root(EzXML.parsexml(response))
    ns = EzXML.namespace(xml)
    outputs_xml = findall("//ns:Stacks/ns:member[1]/ns:Outputs/ns:member", xml, ["ns"=>ns])
    for output_xml in outputs_xml
        key = string(findfirst("//ns:OutputKey/text()", output_xml, ["ns"=>ns]))
        val = string(findfirst("//ns:OutputValue/text()", output_xml, ["ns"=>ns]))
        outputs[key] = val
    end

    return outputs
end


@testset "CloudWatchLogs.jl" begin
    include("event.jl")
    include("mocked_aws.jl")
    include("online.jl")
end
