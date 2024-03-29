# Use
#
#     DOCUMENTER_DEBUG=true julia --color=yes make.jl local [nonstrict] [fixdoctests]
#
# for local builds.

using Documenter
using LegendUpROOTIO

# Doctest setup
DocMeta.setdocmeta!(
    LegendUpROOTIO,
    :DocTestSetup,
    :(using LegendUpROOTIO);
    recursive=true,
)

makedocs(
    sitename = "LegendUpROOTIO",
    modules = [LegendUpROOTIO],
    format = Documenter.HTML(
        prettyurls = !("local" in ARGS),
        canonical = "https://legend-exp.github.io/LegendUpROOTIO.jl/stable/"
    ),
    pages = [
        "Home" => "index.md",
        "API" => "api.md",
        "LICENSE" => "LICENSE.md",
    ],
    doctest = ("fixdoctests" in ARGS) ? :fix : true,
    linkcheck = !("nonstrict" in ARGS),
    strict = !("nonstrict" in ARGS),
)

deploydocs(
    repo = "github.com/legend-exp/LegendUpROOTIO.jl.git",
    forcepush = true,
    push_preview = true,
)
