# Solving one model with either backend. Both go through the same builder, so the two
# solvers cannot silently be given different equations.

"""
    ComplementaritySolution

What a solve returns. `status` is recorded but is not the pass criterion; `x` is the point,
and whether it is a solution is decided by recomputing a residual from `x`.
"""
struct ComplementaritySolution
    backend::Symbol
    x::Vector{Float64}
    status::MOI.TerminationStatusCode
    solve_time::Float64
end

function Base.show(io::IO, s::ComplementaritySolution)
    print(io, "ComplementaritySolution(", s.backend, ", status=", s.status,
          ", n=", length(s.x), ", ", round(s.solve_time; digits = 3), "s)")
end

"""
    solve_complementarity(build, backend; silent = true) -> ComplementaritySolution

Solve the model produced by `build()` with `backend`, one of:

  - `:path` — PATH via `MOI.Complements`. Ground truth (`DECISIONS.md`, D-0002).
  - `:ccopt` — CCOpt, reached through the `MathOptComplements` bridges so that the same
    JuMP model serves both backends.

`build` must be a zero-argument function returning `(model, x)`, and is called afresh for
each backend rather than a model being reused: a JuMP model carries one optimizer and, for
CCOpt, a set of bridges, so reuse would mean the second solve sees a model the first one
has already altered.

`:ccopt` is CCOpt's *relaxation* method and only that. Its MathOptInterface layer builds a
`CCOpt.RelaxationSolver` unconditionally, with no raw attribute that selects the penalty
method, so reaching `CCOpt.PenaltySolver` means going around JuMP and constructing the
`MPCCModels.MPCCModel` directly. That route is not built here yet — see `FINDINGS.md`.
"""
function solve_complementarity(build::Function, backend::Symbol; silent::Bool = true)
    model, x = build()
    if backend === :path
        set_optimizer(model, PATHSolver.Optimizer)
    elseif backend === :ccopt
        MathOptComplements.Bridges.add_all_bridges(model)
        set_optimizer(model, CCOpt.Optimizer)
    else
        throw(ArgumentError("unknown backend $backend; expected :path or :ccopt"))
    end
    silent && set_silent(model)
    t = @elapsed optimize!(model)
    return ComplementaritySolution(backend, value.(x), termination_status(model), t)
end
