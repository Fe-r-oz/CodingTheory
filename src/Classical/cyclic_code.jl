# Copyright (c) 2021, 2023 Eric Sabo
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

#############################
        # constructors
#############################
# TODO: these consctructors reuse a lot of the same code, extract

"""
    CyclicCode(q::Int, n::Int, cosets::Vector{Vector{Int}})

Return the CyclicCode of length `n` over `GF(q)` with `q`-cyclotomic cosets `cosets`.

# Notes
* This function will auto determine if the constructed code is BCH or Reed-Solomon
and call the appropriate constructor.

# Examples
```julia
julia> q = 2; n = 15; b = 3; δ = 4;
julia> cosets = defining_set([i for i = b:(b + δ - 2)], q, n, false);
julia> C = CyclicCode(q, n, cosets)
```
"""
function CyclicCode(q::Int, n::Int, cosets::Vector{Vector{Int}})
    (q <= 1 || n <= 1) && throw(DomainError("Invalid parameters passed to CyclicCode constructor: q = $q, n = $n."))
    factors = Nemo.factor(q)
    length(factors) == 1 || throw(DomainError("There is no finite field of order $q."))
    (p, t), = factors

    # t == 1 ? (F = GF(p);) : (F = GF(p, t, :α);)
    F = GF(p, t, :α)
    deg = ord(n, q)
    E = GF(p, t * deg, :α)
    if t * deg == 1
        α = E(2)
    else
        α = gen(E)
    end
    R, x = polynomial_ring(E, :x)
    β = α^(div(BigInt(q)^deg - 1, n))

    def_set = sort!(reduce(vcat, cosets))
    k = n - length(def_set)
    com_cosets = complement_qcosets(q, n, cosets)
    g = _generator_polynomial(R, β, def_set)
    h = _generator_polynomial(R, β, reduce(vcat, com_cosets))
    e = _idempotent(g, h, n)
    G = _generator_matrix(E, n, k, g)
    H = _generator_matrix(E, n, n - k, reverse(h))
    G_stand, H_stand, P, rnk = _standard_form(G)
    # HT will serve as a lower bound on the minimum weight
    # take the weight of g as an upper bound
    δ, b, HT = find_delta(n, cosets)
    ub = wt(G[1, :])

    # verify
    tr_H = transpose(H)
    flag, h_test = divides(x^n - 1, g)
    flag || error("Incorrect generator polynomial, does not divide x^$n - 1.")
    h_test == h || error("Division of x^$n - 1 by the generator polynomial does not yield the constructed parity check polynomial.")
    # e * e == e || error("Idempotent polynomial is not an idempotent.")
    size(H) == (n - k, k) && (temp = H; H = tr_H; tr_H = temp;)
    iszero(G * tr_H) || error("Generator and parity check matrices are not transpose orthogonal.")

    if t == 1
        F = GF(p)
        G = change_base_ring(F, G)
        H = change_base_ring(F, H)
        G_stand = change_base_ring(F, G_stand)
        H_stand = change_base_ring(F, H_stand)
        ismissing(P) || (P = change_base_ring(F, P);)
    end

    if δ >= 2 && def_set == defining_set([i for i in b:(b + δ - 2)], q, n, true)
        if deg == 1 && n == q - 1
            # known distance, should probably not do δ, HT here
            d = n - k + 1
            return ReedSolomonCode(F, E, R, β, n, k, d, b, d, d, d, d, cosets,
                sort!([arr[1] for arr in cosets]), def_set, g, h, e, G,
                H, G_stand, H_stand, P, missing)
        end

        return BCHCode(F, E, R, β, n, k, missing, b, δ, HT, HT, ub,
            cosets, sort!([arr[1] for arr in cosets]), def_set, g, h, e, G,
            H, G_stand, H_stand, P, missing)
    end

    return CyclicCode(F, E, R, β, n, k, missing, b, δ, HT, HT, ub,
        cosets, sort!([arr[1] for arr in cosets]), def_set, g, h, e, G,
        H, G_stand, H_stand, P, missing)
end

"""
    CyclicCode(n::Int, g::FqPolyRingElem)

Return the length `n` cyclic code generated by the polynomial `g`.
"""
function CyclicCode(n::Int, g::FqPolyRingElem)
    n <= 1 && throw(DomainError("Invalid parameters passed to CyclicCode constructor: n = $n."))
    R = parent(g)
    flag, h = divides(gen(R)^n - 1, g)
    flag || throw(ArgumentError("Given polynomial does not divide x^$n - 1."))

    F = base_ring(R)
    q = Int(order(F))
    p = Int(characteristic(F))
    t = Int(degree(F))
    deg = ord(n, q)
    E = GF(p, t * deg, :α)
    if t * deg == 1
        α = E(2)
    else
        α = gen(E)
    end
    β = α^(div(q^deg - 1, n))
    ord_E = Int(order(E))
    R_E, y = polynomial_ring(E, :y)
    g_E = R_E([E(i) for i in collect(coefficients(g))])
    # _, h = divides(gen(R_E)^n - 1, g_E)

    dic = Dict{FqFieldElem, Int}()
    for i in 0:ord_E - 1
        dic[β^i] = i
    end
    cosets = defining_set(sort!([dic[rt] for rt in roots(g_E)]), q, n, false)
    def_set = sort!(reduce(vcat, cosets))
    k = n - length(def_set)
    e = _idempotent(g, h, n)
    G = _generator_matrix(E, n, k, g)
    H = _generator_matrix(E, n, n - k, reverse(h))
    G_stand, H_stand, P, rnk = _standard_form(G)
    # HT will serve as a lower bound on the minimum weight
    # take the weight of g as an upper bound
    δ, b, HT = find_delta(n, cosets)
    upper = wt(G[1, :])

    # verify
    tr_H = transpose(H)
    # e * e == e || error("Idempotent polynomial is not an idempotent.")
    size(H) == (n - k, k) && (temp = H; H = tr_H; tr_H = temp;)
    iszero(G * tr_H) || error("Generator and parity check matrices are not transpose orthogonal.")

    if t == 1
        F = GF(p)
        G = change_base_ring(F, G)
        H = change_base_ring(F, H)
        G_stand = change_base_ring(F, G_stand)
        H_stand = change_base_ring(F, H_stand)
        ismissing(P) || (P = change_base_ring(F, P);)
    end

    if δ >= 2 && def_set == defining_set([i for i in b:(b + δ - 2)], q, n, true)
        if deg == 1 && n == q - 1
            d = n - k + 1
            return ReedSolomonCode(F, E, R, β, n, k, d, b, d, d, d, d, cosets,
                sort!([arr[1] for arr in cosets]), def_set, g, h, e, G,
                H, G_stand, H_stand, P, missing)
        end

        return BCHCode(F, E, R, β, n, k, missing, b, δ, HT, HT, upper,
            cosets, sort!([arr[1] for arr in cosets]), def_set, g, h, e, G,
            H, G_stand, H_stand, P, missing)
    end

    return CyclicCode(F, E, R, β, n, k, missing, b, δ, HT, HT, upper,
        cosets, sort!([arr[1] for arr in cosets]), def_set, g, h, e, G,
        H, G_stand, H_stand, P, missing)
end

# self orthogonal cyclic codes are even-like
# does this require them too have even minimum distance?
# self orthogonal code must contain all of its self orthogonal q-cosets and at least one of every q-coset pair
"""
    BCHCode(q::Int, n::Int, δ::Int, b::Int = 0)

Return the BCHCode of length `n` over `GF(q)` with design distance `δ` and offset
`b`.

# Notes
* This function will auto determine if the constructed code is Reed-Solomon
and call the appropriate constructor.

# Examples
```julia
julia> q = 2; n = 15; b = 3; δ = 4;
julia> B = BCHCode(q, n, δ, b)
[15, 5, ≥7; 1]_2 BCH code over splitting field GF(16).
2-Cyclotomic cosets:
        C_1 ∪ C_3 ∪ C_5
Generator polynomial:
        x^10 + x^8 + x^5 + x^4 + x^2 + x + 1
Generator matrix: 5 × 15
        1 1 1 0 1 1 0 0 1 0 1 0 0 0 0
        0 1 1 1 0 1 1 0 0 1 0 1 0 0 0

        0 0 1 1 1 0 1 1 0 0 1 0 1 0 0
        0 0 0 1 1 1 0 1 1 0 0 1 0 1 0
        0 0 0 0 1 1 1 0 1 1 0 0 1 0 1
```
"""
function BCHCode(q::Int, n::Int, δ::Int, b::Int = 0)
    δ >= 2 || throw(DomainError("BCH codes require δ ≥ 2 but the constructor was given δ = $δ."))
    (q <= 1 || n <= 1) && throw(DomainError("Invalid parameters passed to BCHCode constructor: q = $q, n = $n."))
    factors = Nemo.factor(q)
    length(factors) == 1 || throw(DomainError("There is no finite field of order $q."))
    (p, t), = factors

    # t == 1 ? (F = GF(p);) : (F = GF(p, t, :α);)
    F = GF(p, t, :α)
    deg = ord(n, q)
    E = GF(p, t * deg, :α)
    if t * deg == 1
        α = E(2)
    else
        α = gen(E)
    end
    R, x = polynomial_ring(E, :x)
    β = α^(div(q^deg - 1, n))

    cosets = defining_set([i for i in b:(b + δ - 2)], q, n, false)
    def_set = sort!(reduce(vcat, cosets))
    k = n - length(def_set)
    com_cosets = complement_qcosets(q, n, cosets)
    g = _generator_polynomial(R, β, def_set)
    h = _generator_polynomial(R, β, reduce(vcat, com_cosets))
    e = _idempotent(g, h, n)
    G = _generator_matrix(E, n, k, g)
    H = _generator_matrix(E, n, n - k, reverse(h))
    G_stand, H_stand, P, rnk = _standard_form(G)
    # HT will serve as a lower bound on the minimum weight
    # take the weight of g as an upper bound
    δ, b, HT = find_delta(n, cosets)
    upper = wt(G[1, :])

    # verify
    tr_H = transpose(H)
    flag, h_test = divides(x^n - 1, g)
    flag || error("Incorrect generator polynomial, does not divide x^$n - 1.")
    h_test == h || error("Division of x^$n - 1 by the generator polynomial does not yield the constructed parity check polynomial.")
    # e * e == e || error("Idempotent polynomial is not an idempotent.")
    size(H) == (n - k, k) && (temp = H; H = tr_H; tr_H = temp;)
    iszero(G * tr_H) || error("Generator and parity check matrices are not transpose orthogonal.")

    if t == 1
        F = GF(p)
        G = change_base_ring(F, G)
        H = change_base_ring(F, H)
        G_stand = change_base_ring(F, G_stand)
        H_stand = change_base_ring(F, H_stand)
        ismissing(P) || (P = change_base_ring(F, P);)
    end

    if deg == 1 && n == q - 1
        d = n - k + 1
        return ReedSolomonCode(F, E, R, β, n, k, d, b, d, d, d, d, cosets,
            sort!([arr[1] for arr in cosets]), def_set, g, h, e, G,
            H, G_stand, H_stand, P, missing)
    end

    return BCHCode(F, E, R, β, n, k, missing, b, δ, HT, HT, upper,
        cosets, sort!([arr[1] for arr in cosets]), def_set, g, h, e, G,
        H, G_stand, H_stand, P, missing)
end

"""
    ReedSolomonCode(q::Int, δ::Int, b::Int = 0)

Return the ReedSolomonCode over `GF(q)` with distance `d` and offset `b`.

# Examples
```julia
julia> ReedSolomonCode(8, 3, 0)
[7, 5, ≥3; 0]_8 Reed Solomon code.
8-Cyclotomic cosets:
        C_0 ∪ C_1
Generator polynomial:
        x^2 + (α + 1)*x + α
Generator matrix: 5 × 7
        α α + 1 1 0 0 0 0
        0 α α + 1 1 0 0 0
        0 0 α α + 1 1 0 0
        0 0 0 α α + 1 1 0
        0 0 0 0 α α + 1 1

julia> ReedSolomonCode(13, 5, 1)
[12, 8, ≥5; 1]_13 Reed Solomon code.
13-Cyclotomic cosets:
        C_1 ∪ C_2 ∪ C_3 ∪ C_4
Generator polynomial:
        x^4 + 9*x^3 + 7*x^2 + 2*x + 10
Generator matrix: 8 × 12
        10 2 7 9 1 0 0 0 0 0 0 0
        0 10 2 7 9 1 0 0 0 0 0 0
        0 0 10 2 7 9 1 0 0 0 0 0
        0 0 0 10 2 7 9 1 0 0 0 0
        0 0 0 0 10 2 7 9 1 0 0 0
        0 0 0 0 0 10 2 7 9 1 0 0
        0 0 0 0 0 0 10 2 7 9 1 0
        0 0 0 0 0 0 0 10 2 7 9 1
```
"""
function ReedSolomonCode(q::Int, d::Int, b::Int = 0)
    d >= 2 || throw(DomainError("Reed Solomon codes require δ ≥ 2 but the constructor was given d = $d."))
    q > 4 || throw(DomainError("Invalid or too small parameters passed to ReedSolomonCode constructor: q = $q."))

    # n = q - 1
    # if ord(n, q) != 1
    #     error("Reed Solomon codes require n = q - 1.")
    # end

    factors = Nemo.factor(q)
    length(factors) == 1 || error("There is no finite field of order $q.")
    (p, t), = factors

    F = GF(p, t, :α)
    if t == 1
        α = F(2)
    else
        α = gen(F)
    end
    R, x = polynomial_ring(F, :x)

    n = q - 1
    cosets = defining_set([i for i in b:(b + d - 2)], q, n, false)
    def_set = sort!(reduce(vcat, cosets))
    k = n - length(def_set)
    com_cosets = complement_qcosets(q, n, cosets)
    g = _generator_polynomial(R, α, def_set)
    # println(g)
    h = _generator_polynomial(R, α, reduce(vcat, com_cosets))
    # println(h)
    # println(g * h)
    e = _idempotent(g, h, n)
    G = _generator_matrix(F, n, k, g)
    H = _generator_matrix(F, n, n - k, reverse(h))
    G_stand, H_stand, P, rnk = _standard_form(G)

    # verify
    tr_H = transpose(H)
    flag, h_test = divides(x^n - 1, g)
    flag || error("Incorrect generator polynomial, does not divide x^$n - 1.")
    h_test == h || error("Division of x^$n - 1 by the generator polynomial does not yield the constructed parity check polynomial.")
    # e * e == e || error("Idempotent polynomial is not an idempotent.")
    size(H) == (n - k, k) && (temp = H; H = tr_H; tr_H = temp;)
    iszero(G * tr_H) || error("Generator and parity check matrices are not transpose orthogonal.")
    iszero(G_stand * tr_H) || error("Column swap appeared in _standard_form.")

    # TODO: known weight enumerator
    return ReedSolomonCode(F, F, R, α, n, k, d, b, d, d, d, d, cosets,
        sort!([arr[1] for arr in cosets]), def_set, g, h, e, G, H,
        G_stand, H_stand, P, missing)
end

# TODO: think further about how I use δ here
# sagemath disagrees with my answers here but matching its parameters gives a false supercode
"""
    BCHCode(C::AbstractCyclicCode)

Return the BCH supercode of the cyclic code `C`.
"""
function BCHCode(C::AbstractCyclicCode)
    typeof(C) <: AbstractBCHCode && return C
    δ, b, _ = find_delta(C.n, C.qcosets)
    B = BCHCode(Int(order(C.F)), C.n, δ, b)
    C ⊆ B && return B
    error("Failed to create BCH supercode.")
end

# covered nicely in van Lint and Betten et al
"""
    QuadraticResidueCode(q::Int, n::Int)

Return the cyclic code whose roots are the quadratic residues of `q`, `n`.
"""
QuadraticResidueCode(q::Int, n::Int) = CyclicCode(q, n, [quadratic_residues(q, n)])

#TODO: cyclic code constructors from zeros and nonzeros

#############################
      # getter functions
#############################

"""
    splitting_field(C::AbstractCyclicCode)

Return the splitting field of the generator polynomial.
"""
splitting_field(C::AbstractCyclicCode) = C.E

"""
    polynomial_ring(C::AbstractCyclicCode)

Return the polynomial ring of the generator polynomial.
"""
polynomial_ring(C::AbstractCyclicCode) = C.R

"""
    primitive_root(C::AbstractCyclicCode)

Return the primitive root of the splitting field.
"""
primitive_root(C::AbstractCyclicCode) = C.β

"""
    offset(C::AbstractBCHCode)

Return the offset of the BCH code.
"""
offset(C::AbstractBCHCode) = C.b

"""
    design_distance(C::AbstractBCHCode)

Return the design distance of the BCH code.
"""
design_distance(C::AbstractBCHCode) = C.δ

"""
    qcosets(C::AbstractCyclicCode)

Return the q-cyclotomic cosets of the cyclic code.
"""
qcosets(C::AbstractCyclicCode) = C.qcosets

"""
    qcosets_reps(C::AbstractCyclicCode)

Return the set of representatives for the q-cyclotomic cosets of the cyclic code.
"""
qcosets_reps(C::AbstractCyclicCode) = C.qcosets_reps


defining_set(C::AbstractCyclicCode) = C.def_set

"""
    zeros(C::AbstractCyclicCode)

Return the zeros of `C`.
"""
zeros(C::AbstractCyclicCode) = [C.β^i for i in C.def_set]

"""
    nonzeros(C::AbstractCyclicCode)

Return the nonzeros of `C`.
"""
nonzeros(C::AbstractCyclicCode) = [C.β^i for i in setdiff(0:C.n - 1, C.def_set)]

"""
    generator_polynomial(C::AbstractCyclicCode)

Return the generator polynomial of the cyclic code.
"""
generator_polynomial(C::AbstractCyclicCode) = C.g

"""
    parity_check_polynomial(C::AbstractCyclicCode)

Return the parity-check polynomial of the cyclic code.
"""
parity_check_polynomial(C::AbstractCyclicCode) = C.h

"""
    idempotent(C::AbstractCyclicCode)

Return the idempotent (polynomial) of the cyclic code.
"""
idempotent(C::AbstractCyclicCode) = C.e

"""
    BCH_bound(C::AbstractCyclicCode)

Return the BCH bound for `C`.
"""
BCH_bound(C::AbstractCyclicCode) = C.δ

# """
#     HT_bound(C::AbstractCyclicCode)

# Return the Hartmann-Tzeng refinement to the BCH bound for `C`.

# This is a lower bound on the minimum distance of `C`.
# """
# HT_bound(C::AbstractCyclicCode) = C.HT

"""
    is_narrow_sense(C::AbstractBCHCode)

Return `true` if the BCH code is narrowsense.
"""
is_narrowsense(C::AbstractBCHCode) = iszero(C.b) # should we define this as b = 1 instead?

"""
    is_reversible(C::AbstractCyclicCode)

Return `true` if the cyclic code is reversible.
"""
is_reversible(C::AbstractCyclicCode) = [C.n - i for i in C.def_set] ⊆ C.def_set

"""
    is_degenerate(C::AbstractCyclicCode)

Return `true` if the cyclic code is degenerate.

# Notes
* A cyclic code is degenerate if the parity-check polynomial divides `x^r - 1` for
some `r` less than the length of the code.
"""
function is_degenerate(C::AbstractCyclicCode)
    x = gen(C.R)
    for r in 1:C.n - 1
        flag, _ = divides(x^r - 1, C.h)
        flag && return true
    end
    return false
end

"""
    is_primitive(C::AbstractBCHCode)

Return `true` if the BCH code is primitive.
"""
is_primitive(C::AbstractBCHCode) = C.n == Int(order(C.F)) - 1

"""
    is_antiprimitive(C::AbstractBCHCode)

Return `true` if the BCH code is antiprimitive.
"""
is_antiprimitive(C::AbstractBCHCode) = C.n == Int(order(C.F)) + 1

#############################
      # setter functions
#############################

#############################
     # general functions
#############################

function _generator_polynomial(R::FqPolyRing, β::FqFieldElem, Z::Vector{Int})
    # from_roots(R, [β^i for i in Z]) - R has wrong type for this
    g = one(R)
    x = gen(R)
    for i in Z
        g *= (x - β^i)
    end
    return g
end
_generator_polynomial(R::FqPolyRing, β::FqFieldElem, qcosets::Vector{Vector{Int}}) = _generator_polynomial(R, β, reduce(vcat, qcosets))

function _generator_matrix(F::FqField, n::Int, k::Int, g::FqPolyRingElem)
    # if g = x^10 + α^2*x^9 + x^8 + α*x^7 + x^3 + α^2*x^2 + x + α
    # g.coeffs = [α  1  α^2  1  0  0  0  α  1  α^2  1]
    coeffs = collect(coefficients(g))
    len = length(coeffs)
    k + len - 1 <= n || error("Too many coefficients for $k shifts in _generator_matrix.")

    G = zero_matrix(F, k, n)
    for i in 1:k
        G[i:i, i:i + len - 1] = coeffs
    end
    return G
end

# TODO: make flat optional throughout
 """
    defining_set(nums::Vector{Int}, q::Int, n::Int, flat::Bool = true)

Returns the set of `q`-cyclotomic cosets of the numbers in `nums` modulo `n`.

# Notes
* If `flat` is set to true, the result will be a single flattened and sorted array.
"""
function defining_set(nums::Vector{Int}, q::Int, n::Int, flat::Bool = true)
    arr = Vector{Vector{Int}}()
    arr_flat = Vector{Int}()
    for x in nums
        Cx = cyclotomic_coset(x, q, n)
        if Cx[1] ∉ arr_flat
            arr_flat = [arr_flat; Cx]
            push!(arr, Cx)
        end
    end

    flat && return sort!(reduce(vcat, arr))
    return arr
end

function _idempotent(g::FqPolyRingElem, h::FqPolyRingElem, n::Int)
    # solve 1 = a(x) g(x) + b(x) h(x) for a(x) then e(x) = a(x) g(x) mod x^n - 1
    d, a, b = gcdx(g, h)
    return mod(g * a, gen(parent(g))^n - 1)
end

# TODO: these
# MattsonSolomontransform(f, n)
# inverseMattsonSolomontransform

"""
    find_delta(n::Int, cosets::Vector{Vector{Int}})

Return the number of consecutive elements of `cosets`, the offset for this, and
a lower bound on the distance of the code defined with length `n` and
cyclotomic cosets `cosets`.

# Notes
* The lower bound is determined by applying the Hartmann-Tzeng bound refinement to
the BCH bound.
"""
# TODO: check why d is sometimes lower than HT but never than BCH
function find_delta(n::Int, cosets::Vector{Vector{Int}})
    def_set = sort!(reduce(vcat, cosets))
    runs = Vector{Vector{Int}}()
    for x in def_set
        used_def_set = Vector{Int}()
        reps = Vector{Int}()
        coset_num = 0
        for i in 1:length(cosets)
            if x ∈ cosets[i]
                coset_num = i
                append!(used_def_set, cosets[i])
                append!(reps, x)
                break
            end
        end

        y = x + 1
        while y ∈ def_set
            if y ∈ used_def_set
                append!(reps, y)
            else
                coset_num = 0
                for i in 1:length(cosets)
                    if y ∈ cosets[i]
                        coset_num = i
                        append!(used_def_set, cosets[i])
                        append!(reps, y)
                        break
                    end
                end
            end
            y += 1
        end
        push!(runs, reps)
    end

    run_lens = [length(i) for i in runs]
    (consec, ind) = findmax(run_lens)
    # there are δ - 1 consecutive numbers for designed distance δ
    δ = consec + 1
    # start of run
    offset = runs[ind][1]
    # BCH Bound is thus d ≥ δ

    # moving to Hartmann-Tzeng Bound refinement
    currbound = δ
    # if consec > 1
    #     for A in runs
    #         if length(A) == consec
    #             for b in 1:(n - 1)
    #                 if gcd(b, n) ≤ δ
    #                     for s in 0:(δ - 2)
    #                         B = [mod(j * b, n) for j in 0:s]
    #                         AB = [x + y for x in A for y in B]
    #                         if AB ⊆ def_set
    #                             if currbound < δ + s
    #                                 currbound = δ + s
    #                             end
    #                         end
    #                     end
    #                 end
    #             end
    #         end
    #     end
    # end

    return δ, offset, currbound
end

"""
    dual_defining_set(def_set::Vector{Int}, n::Int)

Return the defining set of the dual code of length `n` and defining set `def_set`.
"""
dual_defining_set(def_set::Vector{Int}, n::Int) = sort!([mod(n - i, n) for i in setdiff(0:n - 1, def_set)])

"""
    is_cyclic(C::AbstractLinearCode)

Return `true` and the equivalent cyclic code object if `C` is a cyclic code; otherwise,
return `false, missing`.
"""
function is_cyclic(C::AbstractLinearCode)
    typeof(C) <: AbstractCyclicCode && (return true, C;)
    
    ord_F = Int(order(C.F))
    gcd(C.n, ord_F) == 1 || return false
    (p, t), = Nemo.factor(ord_F)
    deg = ord(C.n, ord_F)
    E = GF(p, t * deg, :α)
    α = gen(E)
    R, x = polynomial_ring(E, :x)
    # β = α^(div(q^deg - 1, n))

    G = generatormatrix(C)
    nc = ncols(G)
    g = R([E(G[1, i]) for i in 1:nc])
    for r in 2:nrows(G)
        g = gcd(g, R([E(G[r, i]) for i in 1:nc]))
    end
    isone(g) && return false
    degree(g) == C.n - C.k || return false
    # need to setup x
    flag, h = divides(x^C.n - 1, g)
    flag || return false
    G_cyc = _generator_matrix(C.F, C.n, C.k, g)
    for r in 1:nrows(G_cyc)
        (G_cyc[r, :] ∈ C) || (return false;)
    end

    return true, CyclicCode(C.n, g)
end

"""
    complement(C::AbstractCyclicCode)

Return the cyclic code whose cyclotomic cosets are the completement of `C`'s.
"""
function complement(C::AbstractCyclicCode)
    ord_C = Int(order(C.F))
    D = CyclicCode(ord_C, C.n, complement_qcosets(ord_C, C.n, C.qcosets))
    (C.h != D.g || D.e != (1 - C.e)) && error("Error constructing the complement cyclic code.")
    return D
end

# C1 ⊆ C2 iff g_2(x) | g_1(x) iff T_2 ⊆ T_1
"""
    ⊆(C1::AbstractCyclicCode, C2::AbstractCyclicCode)
    ⊂(C1::AbstractCyclicCode, C2::AbstractCyclicCode)
    is_subcode(C1::AbstractCyclicCode, C2::AbstractCyclicCode)

Return whether or not `C1` is a subcode of `C2`.
"""
⊆(C1::AbstractCyclicCode, C2::AbstractCyclicCode) = C2.def_set ⊆ C1.def_set
⊂(C1::AbstractCyclicCode, C2::AbstractCyclicCode) = C1 ⊆ C2
is_subcode(C1::AbstractCyclicCode, C2::AbstractCyclicCode) = C1 ⊆ C2

# TODO: discuss eqivalent vs == vs === here
"""
    ==(C1::AbstractCyclicCode, C2::AbstractCyclicCode)

Return whether or not `C1` and `C2` have the same fields, lengths, and defining sets.
"""
==(C1::AbstractCyclicCode, C2::AbstractCyclicCode) = C1.F == C2.F && C1.n == C2.n && C1.def_set == C2.def_set && C1.β == C2.β

# this checks def set, need to rewrite == for linear first
"""
    is_self_dual(C::AbstractCyclicCode)

Return whether or not `C == dual(C)`.
"""
is_self_dual(C::AbstractCyclicCode) = C == dual(C)

# don't think this is necessary in order to invoke the ⊆ for CyclicCode
# function is_self_orthogonal(C::AbstractCyclicCode)
#     # A code is self-orthogonal if it is a subcode of its dual.
#     return C ⊆ dual(C)
# end

# function μa(C::CyclicCode)
#     # check gcd(a, n) = 1
#     # technically changes g(x) and e(x) but the q-cosets are the same?
# end

"""
    ∩(C1::AbstractCyclicCode, C2::AbstractCyclicCode)

Return the intersection code of `C1` and `C2`.
"""
function ∩(C1::AbstractCyclicCode, C2::AbstractCyclicCode)
    # has generator polynomial lcm(g_1(x), g_2(x))
    # has generator idempotent e_1(x) e_2(x)
    if C1.F == C2.F && C1.n == C2.n
        ord_C1 = Int(order(C1.F))
        return CyclicCode(ord_C1, C1.n, defining_set(C1.def_set ∪ C2.def_set, ord_C1,
            C1.n, false))
    else
        throw(ArgumentError("Cannot intersect two codes over different base fields or lengths."))
    end
end

"""
    +(C1::AbstractCyclicCode, C2::AbstractCyclicCode)

Return the addition code of `C1` and `C2`.
"""
function +(C1::AbstractCyclicCode, C2::AbstractCyclicCode)
    # has generator polynomial gcd(g_1(x), g_2(x))
    # has generator idempotent e_1(x) + e_2(x) - e_1(x) e_2(x)
    if C1.F == C2.F && C1.n == C2.n
        def_set = C1.def_set ∩ C2.def_set
        if length(def_set) != 0
            ord_C1 = Int(order(C1.F))
            return CyclicCode(ord_C1, C1.n, defining_set(def_set, ord_C1, C1.n, false))
        else
            error("Addition of codes has empty defining set.")
        end
    else
        throw(ArgumentError("Cannot add two codes over different base fields or lengths."))
    end
end

# "Schur products of linear codes: a study of parameters"
# Diego Mirandola
# """
#     entrywise_product_code(C::AbstractCyclicCode)
#     *(C::AbstractCyclicCode)
#     Schur_product_code(C::AbstractCyclicCode)
#     Hadamard_product_code(C::AbstractCyclicCode)
#     componentwise_product_code(C::AbstractCyclicCode)
#
# Return the entrywise product of `C` with itself, which is also a cyclic code.
#
# Note that this is known to often be the full ambient space.
# """
# function entrywise_product_code(C::AbstractCyclicCode)
#     # generator polynomial is gcd(g*g, g*g*x, g*g*x^{k - 1})
#     R = parent(g)
#     g = generator_polynomial(C)
#     coefs_g = collect(coefficients(g))
#     n = length(coefs_g)
#     cur = R([coefs_g[i] * coefs_g[i] for i in 1:n])
#     for i in 1:dimension(C) - 1
#         coefs_g_x = collect(coefficents(g * x^i))
#         cur = gcd(cur, R([coefs_g[i] * coefs_g_x[i] for i in 1:n]))
#     end
#     return CyclicCode(cur)
# end
# *(C::AbstractCyclicCode) = entrywise_product_code(C)
# Schur_product_code(C::AbstractCyclicCode) = entrywise_product_code(C)
# Hadamard_product_code(C::AbstractCyclicCode) = entrywise_product_code(C)
# componentwise_product_code(C::AbstractCyclicCode) = entrywise_product_code(C)
