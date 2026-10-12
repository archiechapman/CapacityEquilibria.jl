# Is the RawStatusString fix offered to CCOpt.jl a fix, and is its test a test?
#
#     julia scripts/check_raw_status_fix.jl [REV]            # REV defaults to master
#
# `FINDINGS.md` F-0007: CCOpt's `MOI.get(::Optimizer, ::MOI.RawStatusString)` reads a field
# its solver does not have, so it throws after every solve. `upstream/ccopt_raw_status_string/`
# holds two patches against CCOpt.jl: `test.patch` adds `test_raw_status_string` to their
# `test/MOI_wrapper.jl`, and `fix.patch` corrects the getter.
#
# A test offered with a fix is only evidence if it has been seen to fail without the fix.
# So this clones CCOpt at REV, applies the test alone and requires it to FAIL, then applies
# the fix and requires it to PASS. Anything else exits nonzero. It runs the one new test,
# not their whole MathOptInterface suite, in a throwaway project holding CCOpt's own
# declared test dependencies and the clone itself.
#
# Needs git and the network.

import Pkg
import TOML

const REPO = normpath(joinpath(@__DIR__, ".."))
const PATCHES = joinpath(REPO, "upstream", "ccopt_raw_status_string")
const URL = "https://github.com/madsuite-org/CCOpt.jl"
const REV = isempty(ARGS) ? "master" : ARGS[1]

work = mktempdir(; prefix = "ccopt_rawstatus_")
clone = joinpath(work, "CCOpt.jl")
gitc(args...) = run(`git -C $clone -c core.autocrlf=false $args`)

run(`git -c core.autocrlf=false clone --quiet $URL $clone`)
gitc("checkout", "--quiet", REV)
sha = readchomp(`git -C $clone rev-parse --short HEAD`)
println("CCOpt.jl at $REV ($sha), cloned to $clone")

# The project: their declared test dependencies, plus the clone under test.
env = joinpath(work, "env")
deps = sort(collect(keys(TOML.parsefile(joinpath(clone, "test", "Project.toml"))["deps"])))
stdlibs = ("LinearAlgebra", "SparseArrays", "Test")
setup = """
    import Pkg
    Pkg.activate(raw"$env")
    Pkg.develop(path = raw"$clone")
    Pkg.add([$(join(("\"$d\"" for d in deps if d ∉ stdlibs), ", "))])
"""
run(pipeline(`$(Base.julia_cmd()) --startup-file=no -e $setup`; stdout = devnull))

# Their MOI_wrapper.jl ends by running its whole suite; drop that line and run one test.
driver = joinpath(work, "driver.jl")
write(driver, """
    using Test
    src = read(joinpath(raw"$clone", "test", "MOI_wrapper.jl"), String)
    src = replace(src, r"\\nTestMOI\\.runtests\\(\\)\\s*\\z" => "\\n")
    include_string(Main, src, "MOI_wrapper.jl")
    @testset "RawStatusString" begin
        TestMOI.test_raw_status_string()
    end
""")

"""Run the driver; return whether it passed and everything it printed."""
function run_driver()
    out = IOBuffer()
    proc = run(pipeline(ignorestatus(`$(Base.julia_cmd()) --startup-file=no --project=$env $driver`);
                        stdout = out, stderr = out))
    return proc.exitcode == 0, String(take!(out))
end

# The defect, as F-0007 records it. A failure for any other reason (a setup error, a
# changed test) is not evidence that the test detects this defect.
const DEFECT = "has no field opt"

gitc("apply", joinpath(PATCHES, "test.patch"))
println("\n--- the test alone, against unpatched CCOpt: expected to FAIL ---")
without_fix, log_without = run_driver()
right_reason = occursin(DEFECT, log_without)
println(without_fix ? "it passed" :
        right_reason ? "it failed, on the defect: $DEFECT" : "it failed, for another reason:")
!without_fix && !right_reason && println(log_without)

gitc("apply", joinpath(PATCHES, "fix.patch"))
println("\n--- the test with the fix: expected to PASS ---")
with_fix, log_with = run_driver()
println(with_fix ? "it passed" : "it failed:")
with_fix || println(log_with)

println()
if !without_fix && right_reason && with_fix
    println("PASSED: on CCOpt $REV ($sha) the test fails without the fix, on the defect itself,")
    println("and passes with it.")
    exit(0)
elseif without_fix
    println("FAILED: the test passes without the fix, so on $REV ($sha) it tests nothing,")
    println("or the defect has been fixed upstream.")
elseif !right_reason
    println("FAILED: without the fix the test fails, but not on the defect it is for.")
else
    println("FAILED: the test still fails with the fix applied.")
end
exit(1)
