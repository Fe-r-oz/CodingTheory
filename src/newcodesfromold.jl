# Copyright (c) 2023 Eric Sabo
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

"""
    permutecode(C::AbstractLinearCode, σ::Union{PermGroupElem, Perm{T}, Vector{T}}) where T <: Int

Return the code whose generator matrix is `C`'s with the columns permuted by `σ`.

# Notes
* If `σ` is a vector, it is interpreted as the desired column order for the generator matrix of `C`.
* If `typeof(C) <: AbstractQuasiCyclicCode`, returns a `LinearCode` object.
"""
function permutecode(C::AbstractLinearCode, σ::Union{PermGroupElem, Perm{T}, Vector{T}}) where T <: Integer
    C2 = deepcopy(C)
    P = permutation_matrix(C.F, typeof(σ) <: Perm ? σ.d : σ)
    size(P, 1) == C.n || throw(ArgumentError("Incorrect number of digits in permutation."))
    C2.G = C2.G * P
    C2.H = C2.H * P
    C2.Pstand = ismissing(C2.Pstand) ? P : C2.Pstand * P
    return C2
end

function permutecode(C::AbstractQuasiCyclicCode, σ::Union{PermGroupElem, Perm{T}, Vector{T}}) where T <: Integer
    P = permutation_matrix(C.F, typeof(σ) <: Perm ? σ.d : σ)
    size(P, 1) == C.n || throw(ArgumentError("Incorrect number of digits in permutation."))
    G = generatormatrix(C) * P
    H = paritycheckmatrix(C) * P
    C2 = LinearCode(G, H)
    ismissing(C2.d) && !ismissing(C.d) && setminimumdistance!(C2, C.d)
    return C2
end

"""
    codecomplement(C1::AbstractLinearCode, C2::AbstractLinearCode)
    quo(C1::AbstractLinearCode, C2::AbstractLinearCode)
    quotient(C1::AbstractLinearCode, C2::AbstractLinearCode)
    /(C2::AbstractLinearCode, C1::AbstractLinearCode)

Return the code `C2 / C1` given `C1 ⊆ C2`.
"""
function codecomplement(C1::AbstractLinearCode, C2::AbstractLinearCode)
    C1 ⊆ C2 || throw(ArgumentError("C1 ⊈ C2"))
    F = C1.F
    G1 = generatormatrix(C1)
    G2 = generatormatrix(C2)
    V = VectorSpace(F, C1.n)
    U, UtoV = sub(V, [V(G1[i, :]) for i in 1:nrows(G1)])
    W, WtoV = sub(V, [V(G2[i, :]) for i in 1:nrows(G2)])
    gensofUinW = [preimage(WtoV, UtoV(g)) for g in gens(U)]
    UinW, _ = sub(W, gensofUinW)
    Q, WtoQ = quo(W, UinW)
    C2modC1basis = [WtoV(x) for x in [preimage(WtoQ, g) for g in gens(Q)]]
    Fbasis = [[F(C2modC1basis[j][i]) for i in 1:dim(parent(C2modC1basis[1]))] for j in 1:length(C2modC1basis)]
    G = matrix(F, length(Fbasis), length(Fbasis[1]), reduce(vcat, Fbasis))
    for r in 1:length(Fbasis)
        v = G[r, :]
        (v ∈ C2 && v ∉ C1) || error("Error in creation of basis for C2 / C1.")
    end
    return LinearCode(G)
end
quo(C1::AbstractLinearCode, C2::AbstractLinearCode) = codecomplement(C1, C2)
quotient(C1::AbstractLinearCode, C2::AbstractLinearCode) = codecomplement(C1, C2)
/(C2::AbstractLinearCode, C1::AbstractLinearCode) = codecomplement(C1, C2)

"""
    ⊕(C1::AbstractLinearCode, C2::AbstractLinearCode)
    directsum(C1::AbstractLinearCode, C2::AbstractLinearCode) = C1 ⊕ C2

Return the direct sum code of `C1` and `C2`.

# Notes
* The direct sum code has generator matrix `G1 ⊕ G2` and parity-check matrix `H1 ⊕ H2`.
"""
function ⊕(C1::AbstractLinearCode, C2::AbstractLinearCode)
    C1.F == C2.F || throw(ArgumentError("Codes must be over the same field."))

    G1 = generatormatrix(C1)
    G2 = generatormatrix(C2)
    G = directsum(G1, G2)
    H1 = paritycheckmatrix(C1)
    H2 = paritycheckmatrix(C2)
    H = directsum(H1, H2)
    # ordering is tougher for standard form, easiest to just recompute:
    Gstand, Hstand, P, k = _standardform(G)
    k == C1.k + C2.k || error("Unexpected dimension in direct sum output.")

    if !ismissing(C1.d) && !ismissing(C2.d)
        d = minimum([C1.d, C2.d])
        return LinearCode(C1.F, C1.n, k, d, d, d, G, H, Gstand, Hstand, P, missing)
    else
        lb = minimum([C1.lbound, C2.lbound])
        ub = minimum([C1.ubound, C2.ubound])
        return LinearCode(C1.F, C1.n, k, missing, lb, ub, G, H, Gstand, Hstand, P, missing)
    end
end
directsum(C1::AbstractLinearCode, C2::AbstractLinearCode) = C1 ⊕ C2

"""
    ⊗(C1::AbstractLinearCode, C2::AbstractLinearCode)
    kron(C1::AbstractLinearCode, C2::AbstractLinearCode) = C1 ⊗ C2
    tensorproduct(C1::AbstractLinearCode, C2::AbstractLinearCode) = C1 ⊗ C2
    directproduct(C1::AbstractLinearCode, C2::AbstractLinearCode) = C1 ⊗ C2
    productcode(C1::AbstractLinearCode, C2::AbstractLinearCode) = C1 ⊗ C2

Return the (direct/tensor) product code of `C1` and `C2`.

# Notes
* The product code has generator matrix `G1 ⊗ G2`.
"""
function ⊗(C1::AbstractLinearCode, C2::AbstractLinearCode)
    C1.F == C2.F || throw(ArgumentError("Codes must be over the same field."))

    G = generatormatrix(C1) ⊗ generatormatrix(C2)
    Gstand, Hstand, P, k = _standardform(G)
    k == C1.k * C2.k || error("Unexpected dimension in direct product output.")
    H = ismissing(P) ? deepcopy(Hstand) : Hstand * P

    if !ismissing(C1.d) && !ismissing(C2.d)
        d = C1.d * C2.d
        return LinearCode(C1.F, C1.n * C2.n, k, d, d, d, G, H, Gstand, Hstand, P, missing)
    else
        return LinearCode(C1.F, C1.n * C2.n, k, missing, C1.lbound * C2.lbound,
            C1.ubound * C2.ubound, G, H, Gstand, Hstand, P, missing)

    end
end
kron(C1::AbstractLinearCode, C2::AbstractLinearCode) = C1 ⊗ C2
tensorproduct(C1::AbstractLinearCode, C2::AbstractLinearCode) = C1 ⊗ C2
directproduct(C1::AbstractLinearCode, C2::AbstractLinearCode) = C1 ⊗ C2
productcode(C1::AbstractLinearCode, C2::AbstractLinearCode) = C1 ⊗ C2
# TODO: fix product vs tensor product

"""
    extend(C::AbstractLinearCode, a::T, c::Integer) where T <: Union{CTMatrixTypes, Array{<:Integer}}
    extend(C::AbstractLinearCode, c::Integer)
    extend(C::AbstractLinearCode, a::T)
    extend(C::AbstractLinearCode)
    evenextension(C::AbstractLinearCode)

Return the extended code of `C` extending on column `c`. For each row
`g` of the generator matrix for `C`, a digit `-a ⋅ g` is inserted in
the `c`th position. If `c` isn't given, it is appended. If `a` isn't
given, then the 1s vector is used giving an even extension.
"""
function extend(C::AbstractLinearCode, a::T, c::Integer) where T <: Union{CTMatrixTypes, Array{<:Integer}}
    1 <= c <= C.n + 1 || throw(ArgumentError("The code has length $(C.n), so `c` must be between 1 and $(C.n + 1)."))
    length(a) == C.n || throw(ArgumentError("The vector `a` should have length $(C.n)."))
    b = isa(a, Array) ? matrix(C.F, 1, C.n, a) : (ncols(a) == 1 ? transpose(a) : a)
    nrows(b) == 1 || throw(ArgumentError("The argument `a` should be a vector."))

    newcol = zero_matrix(C.F, nrows(C.G), 1)
    isbinary = order(C.F) == 2
    for i in axes(newcol, 1)
        newcol[i, 1] = dot(b, view(C.G, i:i, :))
        isbinary || (newcol[i, 1] *= C.F(-1);)
    end
    Gnew = hcat(view(C.G, :, 1:c - 1), newcol, view(C.G, :, c:C.n))
    newrow = hcat(view(b, 1:1, 1:c - 1), matrix(C.F, 1, 1, [1]), view(b, 1:1, c:C.n))
    Hnew = vcat(newrow, hcat(view(C.H, :, 1:c - 1), zero_matrix(C.F, nrows(C.H), 1), view(C.H, :, c:C.n)))
    Cnew = LinearCode(Gnew, Hnew)
    if !ismissing(C.d) && ismissing(Cnew.d)
        if isbinary && all(isone(x) for x in a)
            Cnew.d = iseven(C.d) ? C.d : C.d + 1
            Cnew.lbound = Cnew.ubound = Cnew.d
        else
            Cnew.lbound = C.d
            Cnew.ubound = C.d + 1
        end
    end

    return Cnew
end
extend(C::AbstractLinearCode, c::Integer) = extend(C, ones(Int, C.n), c)
extend(C::AbstractLinearCode, a::T) where T <: Union{CTMatrixTypes, Array{<:Integer}} = extend(C, a, C.n + 1)
extend(C::AbstractLinearCode) = extend(C, ones(Int, C.n), C.n + 1)
evenextension(C::AbstractLinearCode) = extend(C)

"""
    puncture(C::AbstractLinearCode, cols::Vector{<:Integer})
    puncture(C::AbstractLinearCode, cols::Integer)

Return the code of `C` punctured at the columns in `cols`.

# Notes
* Deletes the columns from the generator matrix and then removes any potentially
  resulting zero rows.
"""
function puncture(C::AbstractLinearCode, cols::Vector{<:Integer})
    isempty(cols) && return C
    allunique(cols) || throw(ArgumentError("Columns to puncture are not unique."))
    cols ⊆ 1:C.n || throw(ArgumentError("Columns to puncture are not a subset of the index set."))
    length(cols) == C.n && throw(ArgumentError("Cannot puncture all columns of a generator matrix."))

    G = generatormatrix(C)[:, setdiff(1:C.n, cols)]
    G = _removeempty(G, :rows)
    Gstand, Hstand, P, k = _standardform(G)
    H = ismissing(P) ? deepcopy(Hstand) : Hstand * P

    ub1, _ = _minwtrow(G)
    ub2, _ = _minwtrow(Gstand)
    ub = C.lbound > 1 ? min(ub1, ub2, C.ubound) : min(ub1, ub2)
    lb = max(1, C.lbound - 1)
    return LinearCode(C.F, ncols(G), k, missing, lb, ub, G, H, Gstand, Hstand, P, missing)
end
puncture(C::AbstractLinearCode, cols::Integer) = puncture(C, [cols])

"""
    expurgate(C::AbstractLinearCode, rows::Vector{<:Integer})
    expurgate(C::AbstractLinearCode, rows::Integer)

Return the code of `C` expuragated at the rows in `rows`.

# Notes
* Deletes the rows from the generator matrix and then removes any potentially
  resulting zero columns.
"""
function expurgate(C::AbstractLinearCode, rows::Vector{<:Integer})
    isempty(rows) && return C
    allunique(rows) || throw(ArgumentError("Rows to expurgate are not unique."))
    G = generatormatrix(C)
    nr = nrows(G)
    rows ⊆ 1:nr || throw(ArgumentError("Rows to expurgate are not a subset of the index set."))
    length(rows) == nr && throw(ArgumentError("Cannot expurgate all rows of a generator matrix."))

    G = G[setdiff(1:nr, rows), :]
    Gstand, Hstand, P, k = _standardform(G)
    H = ismissing(P) ? deepcopy(Hstand) : Hstand * P

    ub1, _ = _minwtrow(G)
    ub2, _ = _minwtrow(Gstand)
    ub = min(ub1, ub2)
    return LinearCode(C.F, C.n, k, missing, C.lbound, ub, G, H, Gstand, Hstand, P, missing)
end
expurgate(C::AbstractLinearCode, rows::Integer) = expurgate(C, [rows])

"""
    augment(C::AbstractLinearCode, M::CTMatrixTypes)
    augment(C::AbstractLinearCode, M::Matrix{<:Integer})

Return the code of `C` whose generator matrix is augmented with `M`.

# Notes
* Vertically joins the matrix `M` to the bottom of the generator matrix of `C`.
"""
function augment(C::AbstractLinearCode, M::T) where T <: Union{CTMatrixTypes, Matrix{<:Integer}}
    iszero(M) && throw(ArgumentError("Zero matrix passed to augment."))
    C.n == ncols(M) || throw(ArgumentError("Rows to augment must have the same number of columns as the generator matrix."))
    C.F == base_ring(M) || throw(ArgumentError("Rows to augment must have the same base field as the code."))

    M = _removeempty(M, :rows)
    G = vcat(generatormatrix(C), M)
    Gstand, Hstand, P, k = _standardform(G)
    H = ismissing(P) ? deepcopy(Hstand) : Hstand * P

    ub1, _ = _minwtrow(G)
    ub2, _ = _minwtrow(Gstand)
    ub = min(ub1, ub2, C.ubound)
    return LinearCode(C.F, C.n, k, missing, 1, ub, G, H, Gstand, Hstand, P, missing)
end
augment(C::AbstractLinearCode, M::Matrix{<:Integer}) = augment(C, matrix(C.F, M))

"""
    shorten(C::AbstractLinearCode, L::Vector{<:Integer})
    shorten(C::AbstractLinearCode, L::Integer)

Return the code of `C` shortened on the indices `L`.

# Notes
* Shortening is expurgating followed by puncturing. This implementation uses the
  theorem that the dual of code shortened on `L` is equal to the puncture of the
  dual code on `L`, i.e., `dual(puncture(dual(C), L))`.
"""
shorten(C::AbstractLinearCode, L::Vector{<:Integer}) = isempty(L) ? (return C;) : (return dual(puncture(dual(C), L));)
shorten(C::AbstractLinearCode, L::Integer) = shorten(C, [L])

"""
    lengthen(C::AbstractLinearCode)

Return the lengthened code of `C`.

# Notes
* This augments the all 1's row and then extends.
"""
lengthen(C::AbstractLinearCode) = extend(augment(C, matrix(C.F, ones(Int, 1, C.n))))

"""
    uuplusv(C1::AbstractLinearCode, C2::AbstractLinearCode)
    Plotkinconstruction(C1::AbstractLinearCode, C2::AbstractLinearCode)

Return the Plotkin (u | u + v)-construction with `u ∈ C1` and `v ∈ C2`.
"""
function uuplusv(C1::AbstractLinearCode, C2::AbstractLinearCode)
    C1.F == C2.F || throw(ArgumentError("Base field must be the same in the Plotkin (u|u + v)-construction."))
    C1.n == C2.n || throw(ArgumentError("Both codes must have the same length in the Plotkin (u|u + v)-construction."))
    (iszero(C1.G) || iszero(C2.G)) && throw(ArgumentError("`uuplusv` not supported for zero codes."))

    G1 = generatormatrix(C1)
    G2 = generatormatrix(C2)
    G = vcat(hcat(G1, G1), hcat(parent(G2)(0), G2))
    H1 = paritycheckmatrix(C1)
    H2 = paritycheckmatrix(C2)
    H = vcat(hcat(H1, parent(H1)(0)), hcat(-H2, H2))
    Gstand, Hstand, P, k = _standardform(G)
    k == C1.k + C2.k || error("Something went wrong in the Plotkin (u|u + v)-construction;
        dimension ($k) and expected dimension ($(C1.k + C2.k)) are not equal.")

    if ismissing(C1.d) || ismissing(C2.d)
        lb = min(2 * C1.lbound, C2.lbound)
        ub1, _ = _minwtrow(G)
        ub2, _ = _minwtrow(Gstand)
        ub = min(ub1, ub2, 2 * C1.ubound, C2.ubound)
        return LinearCode(C1.F, 2 * C1.n, k, missing, lb, ub, G, H, Gstand, Hstand, P, missing)
    else
        d = min(2 * C1.d, C2.d)
        return LinearCode(C1.F, 2 * C1.n, k, d, d, d, G, H, Gstand, Hstand, P, missing)
    end
end
Plotkinconstruction(C1::AbstractLinearCode, C2::AbstractLinearCode) = uuplusv(C1, C2)

# TODO: add construction A, B, Y, B2

"""
    constructionX(C1::AbstractLinearCode, C2::AbstractLinearCode, C3::AbstractLinearCode)

Return the code generated by the construction X procedure.

# Notes
* Let `C1` be an [n, k, d], `C2` be an [n, k - l, d + e], and `C3` be an [m, l, e] linear code
  with `C2 ⊂ C1` be proper. Construction X creates a [n + m, k, d + e] linear code.
"""
function constructionX(C1::AbstractLinearCode, C2::AbstractLinearCode, C3::AbstractLinearCode)
    C1 ⊆ C2 || throw(ArgumentError("The first code must be a subcode of the second in construction X."))
    areequivalent(C1, C2) && throw(ArgumentError("The first code must be a proper subcode of the second in construction X."))
    C1.F == C2.F == C3.F || throw(ArgumentError("All codes must be over the same base ring in construction X."))
    C2.k == C1.k + dimension(C3) ||
        throw(ArgumentError("The dimension of the second code must be the sum of the dimensions of the first and third codes."))

    # could do some verification steps on parameters
    C = LinearCode(vcat(hcat(generatormatrix(C1 / C2), generatormatrix(C3)),
        hcat(C1.G, zero_matrix(C1.F, C1.k, length(C3)))))
    C.n == C1.n + C3.n || error("Something went wrong in construction X. Expected length
        $(C1.n + C3.n) but obtained length $(C.n)")

    if !ismissing(C1.d) && !ismissing(C2.d) && !ismissing(C3.d)
        C.d = minimum([C1.d, C2.d + C3.d])
    elseif ismissing(C.d)
        # pretty sure this holds
        setdistancelowerbound!(C, min(C1.lbound, C2.lbound + C3.lbound))
    end
    return C
end

"""
    constructionX3(C1::AbstractLinearCode, C2::AbstractLinearCode, C3::AbstractLinearCode,
        C4::AbstractLinearCode, C5::AbstractLinearCode))

Return the code generated by the construction X3 procedure.

# Notes
* Let C1 = [n, k1, d1], C2 = [n, k2, d2], C3 = [n, k3, d3], C4 = [n4, k2 - k1, d4], and
  C5 = [n5, k3 - k2, d5] with `C1 ⊂ C2 ⊂ C3`. Construction X3 creates an [n + n4 + n5, k3, d]
  linear code with d ≥ min{d1, d2 + d4, d3 + d5}.
"""
function constructionX3(C1::AbstractLinearCode, C2::AbstractLinearCode, C3::AbstractLinearCode,
    C4::AbstractLinearCode, C5::AbstractLinearCode)

    C1 ⊆ C2 || throw(ArgumentError("The first code must be a subcode of the second in construction X3."))
    areequivalent(C1, C2) && throw(ArgumentError("The first code must be a proper subcode of the second in construction X3."))
    C2 ⊆ C3 || throw(ArgumentError("The second code must be a subcode of the third in construction X3."))
    areequivalent(C2, C3) && throw(ArgumentError("The second code must be a proper subcode of the third in construction X3."))
    # the above lines check C1.F == C2.F == field(C3)
    C1.F == C4.F  == C5.F || throw(ArgumentError("All codes must be over the same base ring in construction X3."))
    C3.k == C2.k + C4.k ||
        throw(ArgumentError("The dimension of the third code must be the sum of the dimensions of the second and fourth codes in construction X3."))
    C2.k == C1.k + C5.k ||
        throw(ArgumentError("The dimension of the second code must be the sum of the dimensions of the first and fifth codes in construction X3."))

    C2modC1 = C2 / C1
    C3modC2 = C3 / C2
    F = C1.F

    # could do some verification steps on parameters
    G = vcat(hcat(generatormatrix(C1), zero_matrix(F, C1.k, C4.n), zero_matrix(F, C1.k, C5.n)),
    hcat(C2modC1.G, C4.G, zero_matrix(F, C4.k, C5.n)),
    hcat(C3modC2.G, zero_matrix(F, C5.k, C4.n), generatormatrix(C5)))
    C = LinearCode(G)
    if !ismissing(C1.d) && !ismissing(C2.d) && !ismissing(C3.d) && !ismissing(C4.d) && !ismissing(C5.d) && ismissing(C.d)
        setlowerdistancebound!(C, minimum([C1.d, C2.d + C4.d, C3.d + C5.d]))
    end
    return C
end

"""
    upluswvpluswuplusvplusw(C1::AbstractLinearCode, C2::AbstractLinearCode)

Return the code generated by the (u + w | v + w | u + v + w)-construction.

# Notes
* Let C1 = [n, k1, d1] and C2 = [n, k2, d2]. This construction produces an [3n, 2k1 + k2]
  linear code. For binary codes, wt(u + w | v + w | u + v + w) = 2 wt(u ⊻ v) - wt(w) + 4s,
  where s = |{i | u_i = v_i = 0, w_i = 1}|.
"""
function upluswvpluswuplusvplusw(C1::AbstractLinearCode, C2::AbstractLinearCode)
    C1.F == C2.F || throw(ArgumentError("All codes must be over the same base ring in the (u + w | v + w | u + v + w)-construction."))
    C1.n == C2.n || throw(ArgumentError("All codes must be the same length in the (u + w | v + w | u + v + w)-construction."))

    G1 = generatormatrix(C1)
    G2 = generatormatrix(C2)
    Z = zero_matrix(C1.F, C1.k, C1.n)
    # could do some verification steps on parameters
    return LinearCode(vcat(hcat(G1, Z,  G1),
                           hcat(G2, G2, G2),
                           hcat(Z,  G1, G1)))
end

"""
    subcode(C::AbstractLinearCode, k::Int)

Return a `k`-dimensional subcode of `C`.
"""
function subcode(C::AbstractLinearCode, k::Int)
    k >= 1 && k < C.k || throw(ArgumentError("Cannot construct a $k-dimensional subcode of an $(C.k)-dimensional code."))

    k != C.k || return C
    return if ismissing(C.Pstand)
        LinearCode(view(generatormatrix(C, true), 1:k, :))
    else
        LinearCode(view(generatormatrix(C, true), 1:k, :) * C.Pstand)
    end
end

"""
    subcode(C::AbstractLinearCode, rows::Vector{Int})

Return a subcode of `C` using the rows of the generator matrix of `C` listed in
`rows`.
"""
function subcode(C::AbstractLinearCode, rows::Vector{Int})
    isempty(rows) && throw(ArgumentError("Row index set empty in subcode."))
    allunique(rows) || throw(ArgumentError("Rows are not unique."))
    rows ⊆ 1:C.k || throw(ArgumentError("Rows are not a subset of the index set."))

    length(rows) == C.k && return C
    return LinearCode(generatormatrix(C)[setdiff(1:C.k, rows), :])
end

"""
    subcodeofdimensionbetweencodes(C1::AbstractLinearCode, C2::AbstractLinearCode, k::Int)

Return a subcode of dimenion `k` between `C1` and `C2`.

# Notes
* This function arguments generators of `C1 / C2` to  `C2` until the desired dimenion is reached.
"""
function subcodeofdimensionbetweencodes(C1::AbstractLinearCode, C2::AbstractLinearCode, k::Int)
    C2 ⊆ C1 || throw(ArgumentError("C2 must be a subcode of C1"))
    C2.k <= k <= C1.k || throw(ArgumentError("The dimension must be between that of C1 and C2."))
    
    k == C2.k && return C2
    k == C1.k && return C1
    C = C1 / C2
    return if ismissing(C.Pstand)
        augment(C2, generatormatrix(C, true)[1:k - C2.k, :])
    else
        augment(C2, generatormatrix(C, true)[1:k - C2.k, :] * C.Pstand)
    end
end

"""
    juxtaposition(C1::AbstractLinearCode, C2::AbstractLinearCode)

Return the code generated by the horizontal concatenation of the generator
matrices of `C1` then `C2`.
"""
function juxtaposition(C1::AbstractLinearCode, C2::AbstractLinearCode)
    C1.F == C2.F || throw(ArgumentError("Cannot juxtapose two codes over different fields."))
    G1 = generatormatrix(C1)
    G2 = generatormatrix(C2)
    nrows(G1) == nrows(G2) || throw(ArgumentError("Cannot juxtapose codes with generator matrices with a different number of rows."))

    return LinearCode(hcat(G1, G2))
end

"""
    expandedcode(C::AbstractLinearCode, K::CTFieldTypes, β::Vector{<:CTFieldElem})

Return the expanded code of `C` constructed by exapnding the generator matrix
to the subfield `K` using the basis `β` for `field(C)` over `K`.
"""
function expandedcode(C::AbstractLinearCode, K::CTFieldTypes, β::Vector{<:CTFieldElem})
    flag, λ = isbasis(C.F, K, β)
    flag || throw(ArgumentError("β is not a basis for the extension"))

    # D = _expansiondict(C.F, K, λ)
    # m = div(degree(C.F), degree(K))

    G = generatormatrix(C)
    Gnew = zero_matrix(C.F, nrows(G) * length(β), ncols(G))
    currrow = 1
    for r in 1:nrows(G)
        for βi in β
            Gnew[currrow, :] = βi * view(G, r:r, :)
            currrow += 1
        end
    end
    # Gexp = _expandmatrix(Gnew, D, m)
    Gexp = expandmatrix(Gnew, K, β)

    H = paritycheckmatrix(C)
    Hnew = zero_matrix(C.F, nrows(H) * length(β), ncols(H))
    currrow = 1
    for r in 1:nrows(H)
        for βi in β
            Hnew[currrow, :] = βi * view(H, r:r, :)
            currrow += 1
        end
    end
    Hexp = expandmatrix(Hnew, K, λ)
    # Hexp = _expandmatrix(Hnew, D, m)

    Cnew = LinearCode(Gexp, Hexp)
    Cnew.G = change_base_ring(K, Cnew.G)
    Cnew.H = change_base_ring(K, Cnew.H)
    Cnew.Gstand = change_base_ring(K, Cnew.Gstand)
    Cnew.Hstand = change_base_ring(K, Cnew.Hstand)
    ismissing(Cnew.Pstand) || (Cnew.Pstand = change_base_ring(K, new.Pstand);)
    Cnew.F = K
    Cnew.lbound = C.lbound
    Cnew.ubound, _ = _minwtrow(Cnew.G)
    return Cnew
end

# """
#     subfieldsubcode(C::AbstractLinearCode, K::FqNmodFiniteField)
#
# Return the subfield subcode code of `C` over `K` using Delsarte's theorem.
#
# Use this method if you are unsure of the dual basis to the basis you which
# to expand with.
# """
# function subfieldsubcode(C::AbstractLinearCode, K::FqNmodFiniteField)
#     return dual(tracecode(dual(C), K))
# end

"""
    subfieldsubcode(C::AbstractLinearCode, K::CTFieldTypes, basis::Vector{<:CTFieldElem})

Return the subfield subcode code of `C` over `K` using the provided dual `basis`
for the field of `C` over `K`.
"""
function subfieldsubcode(C::AbstractLinearCode, K::CTFieldTypes, basis::Vector{<:CTFieldElem})
    Cnew = LinearCode(transpose(expandmatrix(transpose(paritycheckmatrix(C)), K, basis)), true)
    Cnew.G = change_base_ring(K, Cnew.G)
    Cnew.H = change_base_ring(K, Cnew.H)
    Cnew.Gstand = change_base_ring(K, Cnew.Gstand)
    Cnew.Hstand = change_base_ring(K, Cnew.Hstand)
    ismissing(Cnew.Pstand) || (Cnew.Pstand = change_base_ring(K, new.Pstand);)
    Cnew.F = K
    return Cnew
end

"""
    tracecode(C::AbstractLinearCode, K::CTFieldTypes, basis::Vector{<:CTFieldElem})

Return the trace code of `C` over `K` using the provided dual `basis`
for the field of `C` over `K` using Delsarte's theorem.
"""
tracecode(C::AbstractLinearCode, K::CTFieldTypes, basis::Vector{<:CTFieldElem}) = dual(subfieldsubcode(dual(C), K, basis))

# R.Pellikaan, On decoding by error location and dependent sets of error
# positions, Discrete Mathematics, 106107 (1992), 369-381.
# the Schur product of vector spaces is highly basis dependent and is often the
# full vector space (an [n, n, 1] code)
# might be a cyclic code special case in
# "On the Schur Product of Vector Spaces over Finite Fields"
# Christiaan Koster
"""
    entrywiseproductcode(C::AbstractLinearCode, D::AbstractLinearCode)
    *(C::AbstractLinearCode, D::AbstractLinearCode)
    Schurproductcode(C::AbstractLinearCode, D::AbstractLinearCode)
    Hadamardproductcode(C::AbstractLinearCode, D::AbstractLinearCode)
    componentwiseproductcode(C::AbstractLinearCode, D::AbstractLinearCode)

Return the entrywise product of `C` and `D`.

# Notes
* This is known to often be the full ambient space.
"""
function entrywiseproductcode(C::AbstractLinearCode, D::AbstractLinearCode)
    C.F == D.F || throw(ArgumentError("Codes must be over the same field in the Schur product."))
    C.n == D.n || throw(ArgumentError("Codes must have the same length in the Schur product."))
    if isa(C, ReedMullerCode)

        r = C.r + D.r
        if r <= C.n
            return ReedMullerCode(r, C.m)
        else
            return ReedMullerCode(C.m, C.m)
        end
    else
        GC = generatormatrix(C)
        GD = generatormatrix(D)
        nrC = nrows(GC)
        nrD = nrows(GD)

        # TODO: Oscar doesn't work well with dot operators
        # TODO: I think this choice of indices only works for C == D
        indices = Vector{Tuple{Int, Int}}()
        for i in 1:nrC
            for j in 1:nrD
                i <= j && push!(indices, (i, j))
            end
        end
        return LinearCode(matrix(C.F, reduce(vcat, GC[i, :] .* GD[j, :] for (i, j) in indices)))
    end
    # TODO: verify C ⊂ it?
end
*(C::AbstractLinearCode, D::AbstractLinearCode) = entrywiseproductcode(C, D)
Schurproductcode(C::AbstractLinearCode, D::AbstractLinearCode) = entrywiseproductcode(C, D)
Hadamardproductcode(C::AbstractLinearCode, D::AbstractLinearCode) = entrywiseproductcode(C, D)
componentwiseproductcode(C::AbstractLinearCode, D::AbstractLinearCode) = entrywiseproductcode(C, D)

# needs significant testing, works so far
function evensubcode(C::AbstractLinearCode)
    F = C.F
    Int(order(F)) == 2 || throw(ArgumentError("Even-ness is only defined for binary codes."))

    VC, ψ = VectorSpace(C)
    GFVS = VectorSpace(F, 1)
    homo1quad = ModuleHomomorphism(VC, GFVS, matrix(F, dim(VC), 1,
        reduce(vcat, [F(weight(ψ(g).v) % 2) for g in gens(VC)])))
    evensub, ϕ1 = kernel(homo1quad)
    iszero(dim(evensub)) ? (return missing;) : (return LinearCode(reduce(vcat, [ψ(ϕ1(g)).v for g in gens(evensub)]));)
end

# needs significant testing, works so far
function doublyevensubcode(C::AbstractLinearCode)
    F = C.F
    Int(order(C.F)) == 2 || throw(ArgumentError("Even-ness is only defined for binary codes."))

    VC, ψ = VectorSpace(C)
    GFVS = VectorSpace(F, 1)

    # first get the even subspace
    homo1quad = ModuleHomomorphism(VC, GFVS, matrix(F, dim(VC), 1,
        reduce(vcat, [F(weight(ψ(g).v) % 2) for g in gens(VC)])))
    evensub, ϕ1 = kernel(homo1quad)

    if !iszero(dim(evensub))
        # now control the overlap (Ward's divisibility theorem)
        homo2bi = ModuleHomomorphism(evensub, evensub, matrix(F, dim(evensub),
            dim(evensub),
            reduce(vcat, [F(weight(matrix(F, 1, C.n, ψ(ϕ1(gens(evensub)[i])).v .*
                ψ(ϕ1(gens(evensub)[j])).v)) % 2)
            for i in 1:dim(evensub), j in 1:dim(evensub)])))
        evensubwoverlap, μ1 = kernel(homo2bi)

        if !iszero(dim(evensubwoverlap))
            # now apply the weight four condition
            homo2quad = ModuleHomomorphism(evensubwoverlap, GFVS, matrix(F,
                dim(evensubwoverlap), 1, reduce(vcat, [F(div(weight(ψ(ϕ1(μ1(g))).v),
                2) % 2) for g in gens(evensubwoverlap)])))
            foursub, ϕ2 = kernel(homo2quad)

            if !iszero(dim(foursub))
                return LinearCode(reduce(vcat, [ψ(ϕ1(μ1(ϕ2(g)))).v for g in gens(foursub)]))
            end
        end
    end
    return missing
end

# currently incomplete
# function triplyevensubcode(C::AbstractLinearCode)
#     F = C.F
#     VC, ψ = VectorSpace(C)
#     GFVS = VectorSpace(F, 1)
#
#     # first get the even subspace
#     homo1quad = ModuleHomomorphism(VC, GFVS, matrix(F, dim(VC), 1, vcat([F(weight(ψ(g).v) % 2) for g in gens(VC)]...)))
#     evensub, ϕ1 = kernel(homo1quad)
#
#     # now control the overlap (Ward's divisibility theorem)
#     homo2bi = ModuleHomomorphism(evensub, evensub, matrix(F, dim(evensub), dim(evensub),
#         vcat([F(weight(matrix(F, 1, C.n, ψ(ϕ1(gens(evensub)[i])).v .* ψ(ϕ1(gens(evensub)[j])).v)) % 2)
#         for i in 1:dim(evensub), j in 1:dim(evensub)]...)))
#     evensubwoverlap, μ1 = kernel(homo2bi)
#
#     # now apply the weight four condition
#     homo2quad = ModuleHomomorphism(evensubwoverlap, GFVS, matrix(F, dim(evensubwoverlap), 1,
#         vcat([F(div(weight(ψ(ϕ1(μ1(g))).v), 2) % 2) for g in gens(evensubwoverlap)]...)))
#     foursub, ϕ2 = kernel(homo2quad)
#
#     # now control the triple overlap
#     ###########
#     # how do we actually represent this?
#
#
#     # now apply the weight eight condition
#     homo3 = ModuleHomomorphism(foursub, GFVS, matrix(F, dim(foursub), 1, vcat([F(div(weight(ψ(ϕ1(ϕ2(g))).v), 4) % 2) for g in gens(foursub)]...)))
#     eightsub, ϕ3 = kernel(homo3)
#     # # println(dim(eightsub))
#     # # println(vcat([ψ(ϕ1(ϕ2(ϕ3(g)))).v for g in gens(eightsub)]...))
#     #
#     # q, γ = quo(foursub, eightsub)
#     # println(dim(q))
#     # # println([preimage(γ, g).v for g in gens(q)])
#     # return LinearCode(vcat([ψ(ϕ1(ϕ2(preimage(γ, g)))).v for g in gens(q)]...))
#     # # return LinearCode(vcat([ψ(ϕ1(ϕ2(ϕ3(g)))).v for g in gens(eightsub)]...))
#
#     return LinearCode(vcat([ψ(ϕ1(μ1(ϕ2(g)))).v for g in gens(foursub)]...))
# end
