@testset "LogEvent" begin

@testset "Timestamp" begin
    time_in_ms = round(Int, time() * 1000)

    event = LogEvent("Foo", time_in_ms)
    @test timestamp(event) == time_in_ms

    dt = DateTime(Dates.UTM(time_in_ms + Dates.UNIXEPOCH))
    event = LogEvent("Foo", dt)
    @test timestamp(event) == time_in_ms

    zdt = ZonedDateTime(dt, tz"UTC")
    event = LogEvent("Foo", zdt)
    @test timestamp(event) == time_in_ms

    event = LogEvent("Foo")
    one_hour = Dates.value(Millisecond(Hour(1)))
    @test test_in_ms <= timestamp(event) <= test_in_ms + one_hour
end

end
