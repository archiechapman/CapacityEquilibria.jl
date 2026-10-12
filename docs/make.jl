# Build the documentation site.
#
#     julia --project=docs -e 'using Pkg; Pkg.instantiate()'
#     julia --project=docs docs/make.jl
#
# The site is written to docs/build/. Every code block in the tutorial pages runs during the
# build and carries its own assertions, so a claim the pages make that stops being true
# fails the build rather than going stale. The first build takes a few minutes, most of it
# compiling CCOpt and MadNLP.
#
# The design notes and the two ledgers are not duplicated into docs/src. They are copied in
# from their canonical locations at build time, so the site cannot drift from them.

using Documenter
using CapacityEquilibria

const DOCS = @__DIR__
const REPO = normpath(joinpath(DOCS, ".."))
const GENERATED = joinpath(DOCS, "src", "generated")

# Canonical file => page in the site.
const COPIED = [
    joinpath(REPO, "docs", "BRIEF.md") => "brief.md",
    joinpath(REPO, "docs", "BOUNDARY.md") => "boundary.md",
    joinpath(REPO, "docs", "COMPLEMENTARITY_PAIRING.md") => "pairing.md",
    joinpath(REPO, "FINDINGS.md") => "findings.md",
    joinpath(REPO, "DECISIONS.md") => "decisions.md",
]

# Julia's Markdown reads `$` as interpolation, so a dollar sign in the copied prose would
# vanish from the page. Escape every `$` outside code, where a backslash would show.
function escape_dollars(text::AbstractString)
    out = String[]
    fenced = false
    for line in split(text, '\n')
        if startswith(lstrip(line), "```")
            fenced = !fenced
        elseif !fenced
            parts = String.(split(line, '`'))
            for k in 1:2:length(parts)
                parts[k] = replace(parts[k], "\$" => "\\\$")
            end
            line = join(parts, '`')
        end
        push!(out, line)
    end
    return join(out, '\n')
end

rm(GENERATED; force = true, recursive = true)
mkpath(GENERATED)
for (src, dst) in COPIED
    write(joinpath(GENERATED, dst), escape_dollars(read(src, String)))
end

makedocs(;
    sitename = "CapacityEquilibria.jl",
    authors = "Archie Chapman",
    modules = [CapacityEquilibria],
    checkdocs = :exports,
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        edit_link = nothing,
        repolink = "https://github.com/archiechapman/CapacityEquilibria.jl",
    ),
    remotes = nothing,
    pages = [
        "Home" => "index.md",
        "Tutorials" => [
            "One LCP, four routes" => "tutorial.md",
            "When the residual stops measuring accuracy" => "degenerate.md",
        ],
        "API reference" => "api.md",
        "Design notes" => [
            "Brief" => "generated/brief.md",
            "Boundary" => "generated/boundary.md",
            "The complementarity pairing" => "generated/pairing.md",
        ],
        "Ledgers" => [
            "Findings" => "generated/findings.md",
            "Decisions" => "generated/decisions.md",
        ],
    ],
)

# Deployment happens only from CI. Run locally, this is skipped.
if get(ENV, "CI", "false") == "true"
    deploydocs(; repo = "github.com/archiechapman/CapacityEquilibria.jl.git",
               devbranch = "main", push_preview = false)
end
