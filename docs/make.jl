# Use
#
#     DOCUMENTER_DEBUG=true julia --color=yes make.jl local [fixdoctests]
#
# for local builds.

using Documenter
using LegendUpROOTIO

makedocs(
    sitename = "LegendUpROOTIO",
    modules = [LegendUpROOTIO],
    format = Documenter.HTML(
        prettyurls = !("local" in ARGS),
        canonical = "https://legend-exp.github.io/ShapesOfVariables.jl/stable/"
    ),
    pages=[
        "Home" => "index.md",
        "API" => "api.md",
        "LICENSE" => "LICENSE.md",
    ],
    doctest = ("fixdoctests" in ARGS) ? :fix : true,
    linkcheck = ("linkcheck" in ARGS),
    strict = !("local" in ARGS),
)

deploydocs(
    repo = "github.com/legend-exp/LegendUpROOTIO.jl.git",
    forcepush = true
)
