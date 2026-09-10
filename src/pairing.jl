# The complementarity pairing. See docs/COMPLEMENTARITY_PAIRING.md for why this file is
# small on purpose and why nothing here re-lists variables in "the same order".

"""
    lcp_model(M, q) -> (model, x)

Build the square linear complementarity problem

    0 ≤ x  ⟂  F(x) = Mx + q ≥ 0

as a JuMP model with a zero objective, and return the model together with the variable
vector. The complementarity constraint is a single `MOI.Complements` constraint over
`[F; x]`, which is the pairing: `F[i]` is paired with `x[i]` because they sit `n` apart in
one vector, not because two separate lists happened to be built in the same order.

This is the shape every equilibrium in this programme takes — residuals as constraints, a
constant objective — so it is also the shape the smoke test exercises, rather than a
friendlier problem that would not catch what this one catches.
"""
function lcp_model(M::AbstractMatrix, q::AbstractVector)
    n = length(q)
    size(M) == (n, n) || throw(DimensionMismatch(
        "M is $(size(M)) but q has length $n; the LCP must be square"))
    model = Model()
    @variable(model, x[1:n] >= 0)
    F = @expression(model, M * x .+ q)
    @constraint(model, [F; x] in MOI.Complements(2n))
    return model, x
end

# emit:lcp_residual:begin
"""
    lcp_residual(M, q, x) -> NamedTuple

Recompute how badly `x` fails to solve the LCP, from `x` alone. Returns the three ways it
can fail and the worst of them:

  - `primal`: violation of `x ≥ 0`
  - `dual`: violation of `F(x) ≥ 0`
  - `complementarity`: the largest `|xᵢ Fᵢ(x)|`
  - `worst`: the maximum of the three, which is the number to threshold on

Nothing here consults a solver, a status code, or a model object. That is the entire point:
this is the independent oracle a returned point is checked against, and a function that
asked the solver how it went would not be one (`QUALITY.md`, the `validated` tier).
"""
function lcp_residual(M::AbstractMatrix, q::AbstractVector, x::AbstractVector)
    F = M * x .+ q
    primal = maximum(max.(-x, 0.0))
    dual = maximum(max.(-F, 0.0))
    comp = maximum(abs.(x .* F))
    return (primal = primal, dual = dual, complementarity = comp,
            worst = max(primal, dual, comp))
end
# emit:lcp_residual:end
