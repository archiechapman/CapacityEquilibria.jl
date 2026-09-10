# Solving one model with either backend. Both go through the same builder, so the two
# solvers cannot silently be given different equations.

"""
    ComplementaritySolution

What a solve returns. `status` is recorded but is not the pass criterion; `x` is the point,
and whether it is a solution is decided by recomputing a residual from `x`. `raw_status`
is the backend's own wording of `status`, kept because the MOI code is a coarsening of it.
"""
struct ComplementaritySolution
    backend::Symbol
    x::Vector{Float64}
    status::MOI.TerminationStatusCode
    raw_status::String
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
  - `:ccopt` — CCOpt's relaxation method, reached through the `MathOptComplements` bridges
    so that the same JuMP model serves both backends.

`build` must be a zero-argument function returning `(model, x)`, and is called afresh for
each backend rather than a model being reused: a JuMP model carries one optimizer and, for
CCOpt, a set of bridges, so reuse would mean the second solve sees a model the first one
has already altered.

`:ccopt` is CCOpt's *relaxation* method and only that. Its MathOptInterface layer builds a
`CCOpt.RelaxationSolver` unconditionally, with no raw attribute that selects the penalty
method (`FINDINGS.md` F-0004). The penalty method, and the relaxation method without the
bridges, are reached by the direct route: `solve_complementarity(M, q, backend)` with
`:ccopt_penalty` or `:ccopt_relaxation`, which builds the `MPCCModel` itself (`mpcc.jl`).
Those backends are refused here, because a JuMP builder does not give this method the
`(M, q)` the direct route needs.
"""
function solve_complementarity(build::Function, backend::Symbol; silent::Bool = true)
    if backend in DIRECT_BACKENDS
        throw(ArgumentError("backend $backend is the direct route and takes (M, q), not a " *
                            "JuMP builder: call solve_complementarity(M, q, $(repr(backend)))"))
    end
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
    return ComplementaritySolution(backend, value.(x), termination_status(model),
                                   _raw_status(model), t)
end

# CCOpt v0.1.0's MathOptInterface extension throws from `MOI.RawStatusString` (it reads a
# field its RelaxationSolver does not have), so the wording is fetched defensively: it is
# recorded for a reader, never used to decide anything.
function _raw_status(model)
    try
        return raw_status(model)
    catch err
        return "raw status unavailable: " * sprint(showerror, err)[1:min(end, 80)]
    end
end
