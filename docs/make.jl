using Documenter, CloudWatchLogs

makedocs(;
    modules=[CloudWatchLogs],
    format=:html,
    pages=[
        "Home" => "index.md",
        "API" => "pages/api.md",
        "Setup a Test Stack" => "pages/setup.md",
    ],
    repo="https://github.com/invenia/CloudWatchLogs.jl/blob/{commit}{path}#L{line}",
    sitename="CloudWatchLogs.jl",
    authors="Invenia Technical Computing Corporation",
    assets=[
        "assets/invenia.css",
        "assets/logo.png",
    ],
)

deploydocs(;
    repo="github.com/invenia/CloudWatchLogs.jl",
    target="build",
    julia="0.6",
    deps=nothing,
    make=nothing,
)
