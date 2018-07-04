using Mocking
Mocking.enable(; force=true)

using CloudWatchLogs
using Compat.Test

using AWSCore: AWSConfig
using Memento

const LOGGER = getlogger(CloudWatchLogs)


@testset "CloudWatchLogs.jl" begin
    include("mocked_aws.jl")
end
