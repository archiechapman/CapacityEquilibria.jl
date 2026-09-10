# The linear complementarity problem  0 ≤ x ⟂ Mx + q ≥ 0  as an NLPModel in the vertical
# form CCOpt's reformulations expect:
#
#     variables    z = (x, w) ∈ ℝ²ⁿ,  x ≥ 0,  w ≥ 0
#     constraints  w − Mx = q          (n linear equalities; so w = F(x))
#     objective    0
#     pairs        x[i] ⟂ w[i],  i = 1..n   (declared separately, by index, in lcp_mpcc)
#
# This is the same lifting the MathOptComplements bridges perform on the JuMP route, done
# by hand so that CCOpt's PenaltySolver — which the JuMP route cannot reach (FINDINGS.md
# F-0004) — can be run on exactly the LCP the other backends see. Every callback is a
# direct transcription of the two lines above: the Jacobian is the constant [−M I], the
# Hessian is empty, the gradient is zero.
#
# Written against NLPModels and the standard library only, and deliberately free of
# `using` lines and of references to anything else in this package: the benchmarks
# repository's emitter splices this file verbatim into the self-contained test file it
# offers upstream to CCOpt.jl, so the model those tests exercise is byte-for-byte the one
# the engine runs. Keep it that way.

# emit:lcp_nlp:begin
"""
    LCPVerticalModel(M, q) <: NLPModels.AbstractNLPModel

The LCP `0 ≤ x ⟂ Mx + q ≥ 0` as a feasibility NLP in `z = (x, w)`, `w − Mx = q`, `x, w ≥ 0`,
with a zero objective. The complementarity between `x[i]` and `w[i]` is *not* part of this
model; it is declared on top of it by `MPCCModels.MPCCModel(nlp, 1:n, n+1:2n)`.
"""
struct LCPVerticalModel{T, VT <: AbstractVector{T}} <: NLPModels.AbstractNLPModel{T, VT}
    n::Int
    A::SparseArrays.SparseMatrixCSC{T, Int}   # [−M  I], the constant Jacobian
    meta::NLPModels.NLPModelMeta{T, VT}
    counters::NLPModels.Counters
end

function LCPVerticalModel(M::AbstractMatrix{T}, q::AbstractVector{T}) where {T}
    n = length(q)
    size(M) == (n, n) || throw(DimensionMismatch(
        "M is $(size(M)) but q has length $n; the LCP must be square"))
    A = SparseArrays.sparse([-Matrix{T}(M)  Matrix{T}(LinearAlgebra.I, n, n)])
    meta = NLPModels.NLPModelMeta{T, Vector{T}}(
        2n;
        x0 = zeros(T, 2n),
        lvar = zeros(T, 2n),
        uvar = fill(T(Inf), 2n),
        ncon = n,
        y0 = zeros(T, n),
        lcon = Vector{T}(q),
        ucon = Vector{T}(q),
        nnzj = SparseArrays.nnz(A),
        lin_nnzj = SparseArrays.nnz(A),
        nln_nnzj = 0,
        nnzh = 0,
        lin = collect(1:n),
        islp = true,
        minimize = true,
        name = "LCP, vertical form, n = $n",
    )
    return LCPVerticalModel{T, Vector{T}}(n, A, meta, NLPModels.Counters())
end

# --- objective: identically zero ------------------------------------------------------------

NLPModels.obj(::LCPVerticalModel{T}, ::AbstractVector) where {T} = zero(T)

function NLPModels.grad!(::LCPVerticalModel, ::AbstractVector, gx::AbstractVector)
    fill!(gx, 0)
    return gx
end

function NLPModels.objgrad!(nlp::LCPVerticalModel, x::AbstractVector, gx::AbstractVector)
    return NLPModels.obj(nlp, x), NLPModels.grad!(nlp, x, gx)
end

# --- constraints: c(z) = Az = w − Mx, all linear -------------------------------------------

NLPModels.cons!(nlp::LCPVerticalModel, z::AbstractVector, cz::AbstractVector) =
    LinearAlgebra.mul!(cz, nlp.A, z)
NLPModels.cons_lin!(nlp::LCPVerticalModel, z::AbstractVector, cz::AbstractVector) =
    LinearAlgebra.mul!(cz, nlp.A, z)
NLPModels.cons_nln!(::LCPVerticalModel, ::AbstractVector, cz::AbstractVector) = cz

function _lcp_jac_structure!(A::SparseArrays.SparseMatrixCSC, rows, cols)
    k = 1
    @inbounds for col in 1:size(A, 2), p in A.colptr[col]:(A.colptr[col + 1] - 1)
        rows[k] = A.rowval[p]
        cols[k] = col
        k += 1
    end
    return rows, cols
end

function _lcp_jac_coord!(A::SparseArrays.SparseMatrixCSC, vals)
    k = 1
    @inbounds for col in 1:size(A, 2), p in A.colptr[col]:(A.colptr[col + 1] - 1)
        vals[k] = A.nzval[p]
        k += 1
    end
    return vals
end

NLPModels.jac_structure!(nlp::LCPVerticalModel, rows::AbstractVector{<:Integer},
                         cols::AbstractVector{<:Integer}) =
    _lcp_jac_structure!(nlp.A, rows, cols)
NLPModels.jac_lin_structure!(nlp::LCPVerticalModel, rows::AbstractVector{<:Integer},
                             cols::AbstractVector{<:Integer}) =
    _lcp_jac_structure!(nlp.A, rows, cols)
NLPModels.jac_nln_structure!(::LCPVerticalModel, rows::AbstractVector{<:Integer},
                             cols::AbstractVector{<:Integer}) = (rows, cols)

NLPModels.jac_coord!(nlp::LCPVerticalModel, ::AbstractVector, vals::AbstractVector) =
    _lcp_jac_coord!(nlp.A, vals)
NLPModels.jac_lin_coord!(nlp::LCPVerticalModel, ::AbstractVector, vals::AbstractVector) =
    _lcp_jac_coord!(nlp.A, vals)
NLPModels.jac_nln_coord!(::LCPVerticalModel, ::AbstractVector, vals::AbstractVector) = vals

NLPModels.jprod!(nlp::LCPVerticalModel, ::AbstractVector, v::AbstractVector, Jv::AbstractVector) =
    LinearAlgebra.mul!(Jv, nlp.A, v)
NLPModels.jprod_lin!(nlp::LCPVerticalModel, ::AbstractVector, v::AbstractVector, Jv::AbstractVector) =
    LinearAlgebra.mul!(Jv, nlp.A, v)
NLPModels.jprod_nln!(::LCPVerticalModel, ::AbstractVector, ::AbstractVector, Jv::AbstractVector) = Jv

NLPModels.jtprod!(nlp::LCPVerticalModel, ::AbstractVector, v::AbstractVector, Jtv::AbstractVector) =
    LinearAlgebra.mul!(Jtv, transpose(nlp.A), v)
NLPModels.jtprod_lin!(nlp::LCPVerticalModel, ::AbstractVector, v::AbstractVector, Jtv::AbstractVector) =
    LinearAlgebra.mul!(Jtv, transpose(nlp.A), v)
NLPModels.jtprod_nln!(::LCPVerticalModel, ::AbstractVector, ::AbstractVector, Jtv::AbstractVector) = Jtv

# --- Hessian of the Lagrangian: empty, everything is linear ---------------------------------

NLPModels.hess_structure!(::LCPVerticalModel, rows::AbstractVector{<:Integer},
                          cols::AbstractVector{<:Integer}) = (rows, cols)

NLPModels.hess_coord!(::LCPVerticalModel{T}, ::AbstractVector{T}, ::AbstractVector{T},
                      vals::AbstractVector{T}; obj_weight::Real = one(T)) where {T} = vals

function NLPModels.hprod!(::LCPVerticalModel{T}, ::AbstractVector{T}, ::AbstractVector{T},
                          ::AbstractVector{T}, Hv::AbstractVector;
                          obj_weight::Real = one(T)) where {T}
    fill!(Hv, 0)
    return Hv
end
# emit:lcp_nlp:end
