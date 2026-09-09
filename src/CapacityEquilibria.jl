"""
    CapacityEquilibria

The complementarity plumbing and the dual-solver harness shared by every model in this
programme. No paper-specific data lives here (`DECISIONS.md`, D-0003); the models that use
this engine pass their own.

The one contract worth stating up front: a solver's termination status is never evidence
that it solved anything. Every solve goes through [`solve_complementarity`], which returns
the point alongside a residual recomputed from that point by [`lcp_residual`], and callers
are expected to judge the residual rather than the status (`DECISIONS.md`, D-0002).
"""
module CapacityEquilibria

using JuMP
using LinearAlgebra: norm

import MathOptInterface as MOI
import PATHSolver
import CCOpt
import MathOptComplements
import NLPModelsJuMP

export lcp_model, lcp_residual, solve_complementarity, ComplementaritySolution

include("pairing.jl")
include("solve.jl")

end # module
