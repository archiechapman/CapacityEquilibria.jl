"""
    CapacityEquilibria

The complementarity plumbing and the dual-solver harness shared by every model in this
programme. No paper-specific data lives here (`DECISIONS.md`, D-0003); the models that use
this engine pass their own.

The one contract worth stating up front: a solver's termination status is never evidence
that it solved anything. Every solve goes through [`solve_complementarity`], which returns
the point alongside a residual recomputed from that point by [`lcp_residual`], and callers
are expected to judge the residual rather than the status (`DECISIONS.md`, D-0002).

Two routes to CCOpt exist. The JuMP route (`lcp_model` plus the MathOptComplements bridges)
reaches its relaxation method; the direct route (`lcp_mpcc`, an `MPCCModel` built by hand)
reaches both its relaxation and its penalty method. `solve_complementarity(M, q, backend)`
dispatches over all four backends.
"""
module CapacityEquilibria

using JuMP
using LinearAlgebra: norm
import LinearAlgebra
import SparseArrays

import MathOptInterface as MOI
import PATHSolver
import CCOpt
import MadNLP
import MathOptComplements
import MPCCModels
import NLPModels
import NLPModelsJuMP

export lcp_model, lcp_residual, solve_complementarity, ComplementaritySolution
export LCPVerticalModel, lcp_mpcc

include("pairing.jl")
include("lcp_nlp.jl")
include("mpcc.jl")
include("solve.jl")

end # module
