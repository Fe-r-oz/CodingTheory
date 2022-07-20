# Copyright (c) 2021, Eric Sabo
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

"""
    ⊕(A::fq_nmod_mat, B::fq_nmod_mat)
    directsum(A::fq_nmod_mat, B::fq_nmod_mat)

Return the direct sum of the two matrices `A` and `B`.
"""
function ⊕(A::fq_nmod_mat, B::fq_nmod_mat)
    base_ring(A) == base_ring(B) || error("Matrices must be over the same base ring in directsum.")

    return vcat(hcat(A, zero_matrix(base_ring(B), nrows(A), ncols(B))),
        hcat(zero_matrix(base_ring(A), nrows(B), ncols(A)), B))
end
directsum(A::fq_nmod_mat, B::fq_nmod_mat) = A ⊕ B

"""
    ⊗(A::fq_nmod_mat, B::fq_nmod_mat)
    kron(A::fq_nmod_mat, B::fq_nmod_mat)
    tensorproduct(A::fq_nmod_mat, B::fq_nmod_mat)
    kroneckerproduct(A::fq_nmod_mat, B::fq_nmod_mat)

Return the Kronecker product of the two matrices `A` and `B`.
"""
⊗(A::fq_nmod_mat, B::fq_nmod_mat) = kronecker_product(A, B)
kron(A::fq_nmod_mat, B::fq_nmod_mat) = kronecker_product(A, B)
tensorproduct(A::fq_nmod_mat, B::fq_nmod_mat) = kronecker_product(A, B)
kroneckerproduct(A::fq_nmod_mat, B::fq_nmod_mat) = kronecker_product(A, B)
# nrows(A::T) where T = size(A, 1)
# ncols(A::T) where T = size(A, 2)

# I think we should avoid length checking here and return it for entire matrix if given
# Hammingweight(v::T) where T <: Union{fq_nmod_mat, gfp_mat, Vector{S}} where S <: Integer = count(i->(i != 0), v)
"""
    Hammingweight(v::T) where T <: Union{fq_nmod_mat, Vector{S}} where S <: Integer
    weight(v::T) where T <: Union{fq_nmod_mat, Vector{S}} where S <: Integer
    wt(v::T) where T <: Union{fq_nmod_mat, Vector{S}} where S <: Integer

Return the Hamming weight of `v`.
"""
function Hammingweight(v::T) where T <: Union{fq_nmod_mat, Vector{S}} where S <: Integer
    count = 0
    for i in 1:length(v)
        if !iszero(v[i])
            count += 1
        end
    end
    return count
end
weight(v::T) where T <: Union{fq_nmod_mat, Vector{S}} where S <: Integer = Hammingweight(v)
wt(v::T) where T <: Union{fq_nmod_mat, Vector{S}} where S <: Integer = Hammingweight(v)

"""
    Hammingdistance(u::T, v::T) where T <: Union{fq_nmod_mat, Vector{S}} where S <: Integer
    distance(u::T, v::T) where T <: Union{fq_nmod_mat, Vector{S}} where S <: Integer
    dist(u::T, v::T) where T <: Union{fq_nmod_mat, Vector{S}} where S <: Integer

Return the Hamming distance between `u` and `v`.
"""
Hammingdistance(u::T, v::T) where T <: Union{fq_nmod_mat, Vector{S}} where S <: Integer = Hammingweight(u .- v)
distance(u::T, v::T) where T <: Union{fq_nmod_mat, Vector{S}} where S <: Integer = Hammingweight(u .- v)
dist(u::T, v::T) where T <: Union{fq_nmod_mat, Vector{S}} where S <: Integer = Hammingweight(u .- v)

"""
    tr(x::fq_nmod, K::FqNmodFiniteField, verify::Bool=false)

Return the relative trace of `x` from its base field to the field `K`.

If the optional parameter `verify` is set to `true`, the two fields are checked
for compatibility.
"""
function tr(x::fq_nmod, K::FqNmodFiniteField, verify::Bool=false)
    L = parent(x)
    q = order(K)
    if verify
        # shouldn't need Int casting here but just in case...
        Int64(characteristic(L)) == Int64(characteristic(K)) || error("The given field is not a subfield of the base ring of the element.")
        degree(L) % degree(K) == 0 || error("The given field is not a subfield of the base ring of the element.")
    end
    n = div(degree(L), degree(K))
    return sum([x^(q^i) for i in 0:(n - 1)])
end

function _expandelement(x::fq_nmod, K::FqNmodFiniteField, basis::Vector{fq_nmod}, verify::Bool=false)
    return [tr(x * i, K, verify) for i in basis]
end

function _expandrow(row::fq_nmod_mat, K::FqNmodFiniteField, basis::Vector{fq_nmod}, verify::Bool=false)
    new_row = _expandelement(row[1], K, basis, verify)
    for i in 2:ncols(row)
        new_row = vcat(new_row, _expandelement(row[i], K, basis, verify))
    end
    return matrix(K, 1, length(new_row), new_row)
end

"""
    expandmatrix(M::fq_nmod_mat, K::FqNmodFiniteField, basis::Vector{fq_nmod})

Return the matrix constructed by expanding the elements of `M` to the subfield
`K` using the provided `basis` for the base ring of `M` over `K`.

No check is done to ensure that `basis` is indeed a basis for the extension.
"""
function expandmatrix(M::fq_nmod_mat, K::FqNmodFiniteField, basis::Vector{fq_nmod})
    L = base_ring(M)
    L == K && return M
    Int64(characteristic(L)) == Int64(characteristic(K)) || error("The given field is not a subfield of the base ring of the element.")
    degree(L) % degree(K) == 0 || error("The given field is not a subfield of the base ring of the element.")
    n = div(degree(L), degree(K))
    n == length(basis) || error("Provided basis is of incorrect size for the given field and subfield.")
    # should really check if it is a basis
    return vcat([_expandrow(M[r, :], K, basis) for r in 1:nrows(M)]...)
end

"""
    symplecticinnerproduct(u::fq_nmod_mat, v::fq_nmod_mat)

Return the symplectic inner product of `u` and `v`.
"""
function symplecticinnerproduct(u::fq_nmod_mat, v::fq_nmod_mat)
    (nrows(u) == 1 || ncols(u) == 1) || error("First argument of symplectic inner product is not a vector: dims = $(size(u, 1)).")
    (nrows(v) == 1 || ncols(v) == 1) || error("Second argument of symplectic inner product is not a vector: dims = $(size(v, 1)).")
    length(u) == length(v) || error("Vectors must be the same length in symplectic inner product.")
    iseven(length(u)) || error("Vectors must have even length in symplectic inner product.")
    base_ring(u) == base_ring(v) || error("Vectors must be over the same field in symplectic inner product.")
    ncols = div(length(u), 2)
    return sum([u[i + ncols] * v[i] - v[i + ncols] * u[i] for i in 1:ncols])
end

"""
    aresymplecticorthogonal(A::fq_nmod_mat, B::fq_nmod_mat, symp::Bool=false)

Return `true` if the rows of the matrices `A` and `B` are symplectic orthogonal.

If the optional parameter `symp` is set to `true`, `A` and `B` are assumed to be
in symplectic form over the base field.
"""
function aresymplecticorthogonal(A::fq_nmod_mat, B::fq_nmod_mat, symp::Bool=false)
    E = base_ring(A)
    E == base_ring(B) || error("Matices in product must both be over the same base ring.")
    if symp
        iseven(ncols(A)) || error("Expected a symplectic input but the first input matrix has an odd number of columns.")
        iseven(ncols(B)) || error("Expected a symplectic input but the second input matrix has an odd number of columns.")
    else
        iseven(degree(E)) || error("The base ring of the given matrices are not a quadratic extension.")
        A = quadratictosymplectic(A)
        B = quadratictosymplectic(B)
    end

    AEuc = hcat(A[:, div(ncols(A), 2) + 1:end], -A[:, 1:div(ncols(A), 2)])
    iszero(AEuc * transpose(B)) || return false
    return true
end

# function traceinnerproduct(u::fq_nmod_mat, v::fq_nmod_mat)
#
# end

"""
    Hermitianinnerproduct(u::fq_nmod_mat, v::fq_nmod_mat)

Return the Hermitian inner product of `u` and `v`.
"""
function Hermitianinnerproduct(u::fq_nmod_mat, v::fq_nmod_mat)
    (nrows(u) == 1 || ncols(u) == 1) || error("First argument of Hermitian inner product is not a vector: dims = $(size(u, 1)).")
    (nrows(v) == 1 || ncols(v) == 1) || error("Second argument of Hermitian inner product is not a vector: dims = $(size(v, 1)).")
    length(u) == length(v) || error("Vectors must be the same length in Hermitian inner product.")
    base_ring(u) == base_ring(v) || error("Vectors must be over the same field in Hermitian inner product.")
    q2 = order(base_ring(u))
    issquare(q2) || error("The Hermitian inner product is only defined over quadratic field extensions.")
    q = Int64(sqrt(q2))
    return sum([u[i] * v[i]^q for i in 1:length(u)])
end

"""
    Hermitianconjugatematrix(A::fq_nmod_mat)

Return the Hermitian conjugate of the matrix `A`.
"""
function Hermitianconjugatematrix(A::fq_nmod_mat)
    B = copy(A)
    q2 = order(base_ring(A))
    issquare(q2) || error("The Hermitian conjugate is only defined over quadratic field extensions.")
    q = Int64(sqrt(q2))
    return B .^ q
end

# does this actually make any sense?
# """
#     entropy(x::Real)
#
# Return the entropy of the real number `x`.
# """
# function entropy(x::Real)
#     x != 0 || return 0
#     (0 < x <= 1 - 1 / q) || error("Number should be in the range [0, 1 - 1/order(field)].")
#     F = parent(x)
#     q = order(F)
#     return x * (log(q, q - 1) - log(q, x)) - (1 - x) * log(q, 1 - x)
# end

"""
    FpmattoJulia(M::fq_nmod_mat)

Return the `fq_nmod_mat` matrix `M` as a Julia Integer matrix.
"""
function FpmattoJulia(M::fq_nmod_mat)
    degree(base_ring(M)) == 1 || error("Cannot promote higher order elements to the integers.")
    # Fp = [i for i in 0:Int64(characteristic(base_ring(M)))]
    A = zeros(Int64, size(M))
    for c in 1:ncols(M)
        for r in 1:nrows(M)
            # A[r, c] = Fp[findfirst(x->x==M[r, c], Fp)]
            A[r, c] = coeff(M[r, c], 0)
        end
    end
    return A
end

"""
    istriorthogonal(G::fq_nmod_mat, verbose::Bool=false)
    istriorthogonal(G::Matrix{Int}, verbose::Bool=false)

Return `true` if the binary matrix `G` is triorthogonal (modulo 2).

If the optional parameter `verbos` is set to `true`, the first pair or triple of
non-orthogonal rows will be identified on the console.
"""
function istriorthogonal(G::fq_nmod_mat, verbose::Bool=false)
    Int(order(base_ring(G))) == 2 || error("Triothogonality is only defined over 𝔽_2.")
    nr, nc = size(G)
    for r1 in 1:nr
        for r2 in 1:nr
            @views g1 = G[r1, :]
            @views g2 = G[r2, :]
            @views if !iszero(sum([g1[1, i] * g2[1, i] for i in 1:nc]))
                verbose && println("Rows $r1 and $r2 are not orthogonal.")
                return false
            end
        end
    end

    for r1 in 1:nr
        for r2 in 1:nr
            for r3 in 1:nr
                @views g1 = G[r1, :]
                @views g2 = G[r2, :]
                @views g3 = G[r3, :]
                @views if !iszero(sum([g1[1, i] * g2[1, i] * g3[1, i] for i in 1:nc]))
                    verbose && println("Rows $r1, $r2, and $r3 are not orthogonal.")
                    return false
                end
            end
        end
    end
    return true
end

function istriorthogonal(G::Matrix{Int}, verbose::Bool=false)
    nr, nc = size(G)
    for r1 in 1:nr
        for r2 in 1:nr
            @views g1 = G[r1, :]
            @views g2 = G[r2, :]
            @views if !iszero(sum([g1[1, i] * g2[1, i] for i in 1:nc]) % 2)
                verbose && println("Rows $r1 and $r2 are not orthogonal.")
                return false
            end
        end
    end

    for r1 in 1:nr
        for r2 in 1:nr
            for r3 in 1:nr
                @views g1 = G[r1, :]
                @views g2 = G[r2, :]
                @views g3 = G[r3, :]
                @views if !iszero(sum([g1[1, i] * g2[1, i] * g3[1, i] for i in 1:nc]) % 2)
                    verbose && println("Rows $r1, $r2, and $r3 are not orthogonal.")
                    return false
                end
            end
        end
    end
    return true
end

#############################
  # Quantum Helper Functions
#############################

function printstringarray(A::Vector{String}, withoutIs=false)
    for a in A
        if !withoutIs
            println(a)
        else
            for i in a
                if i == 'I'
                    print(' ')
                else
                    print(i)
                end
            end
            print('\n')
        end
    end
end
printchararray(A::Vector{Vector{Char}}, withoutIs=false) = printstringarray(setchartostringarray(A), withoutIs)
printsymplecticarray(A::Vector{Vector{T}}, withoutIs=false) where T <: Integer = printstringarray(setsymplectictostringarray(A), withoutIs)

"""
    pseudoinverse(M::fq_nmod_mat)

Return the pseudoinverse of a stabilizer matrix `M` over a quadratic extension.

Note that this is not the Penrose-Moore pseudoinverse.
"""
function pseudoinverse(M::fq_nmod_mat)
    # let this fail elsewhere if not actually over a quadratic extension
    if degree(base_ring(M)) != 1
        M = transpose(quadratictosymplectic(M))
    else
        M = transpose(M)
    end

    nr, nc = size(M)
    MS = MatrixSpace(base_ring(M), nr, nr)
    _, E = rref(hcat(M, MS(1)))
    E = E[:, (nc + 1):end]
    pinv = E[1:nc, :]
    dual = E[nc + 1:nr, :]

    # verify
    _, Mrref = rref(M)
    MScols = MatrixSpace(base_ring(M), nc, nc)
    E * M == Mrref || error("Pseudoinverse calculation failed (transformation incorrect).")
    Mrref[1:nc, 1:nc] == MScols(1) || error("Pseudoinverse calculation failed (failed to get I).")
    iszero(Mrref[nc + 1:nr, :]) || error("Pseudoinverse calculation failed (failed to get zero).")
    pinv * M == MScols(1) || error("Pseudoinverse calculation failed (eq 1).")
    transpose(M) * transpose(pinv) == MScols(1) || error("Pseudoinverse calculation failed (eq 2).")
    iszero(transpose(M) * transpose(dual)) || error("Failed to correctly compute dual (rhs).")
    iszero(dual * M) || error("Failed to correctly compute dual (lhs).")
    return pinv
end

"""
    quadratictosymplectic(M::fq_nmod_mat)

Return the matrix `M` converted from the quadratic to the symplectic form.
"""
function quadratictosymplectic(M::fq_nmod_mat)
    E = base_ring(M)
    iseven(degree(E)) || error("The base ring of the given matrix is not a quadratic extension.")
    F, _ = FiniteField(Int64(characteristic(E)), div(degree(E), 2), "ω")
    nr = nrows(M)
    nc = ncols(M)
    Msym = zero_matrix(F, nr, 2 * nc)
    for c in 1:nc
        for r in 1:nr
            if !iszero(M[r, c])
                Msym[r, c] = F(coeff(M[r, c], 0))
                Msym[r, c + ncols] = F(coeff(M[r, c], 1))
            end
        end
    end
    return Msym
end

"""
    symplectictoquadratic(M::fq_nmod_mat)

Return the matrix `M` converted from the symplectic to the quadratic form.
"""
function symplectictoquadratic(M::fq_nmod_mat)
    iseven(ncols(M)) || error("Input to symplectictoquadratic is not of even length.")
    nr = nrows(M)
    nc = div(ncols(M), 2)
    F = base_ring(M)
    E, ω = FiniteField(Int64(characteristic(F)), 2 * degree(F), "ω")
    ϕ = embed(F, E)
    Mquad = zero_matrix(E, nr, nc)
    for c in 1:nc
        for r in 1:nr
            Mquad[r, c] = ϕ(M[r, c]) + ϕ(M[r, c + nc]) * ω
        end
    end
    return Mquad
end

function _Paulistringtosymplectic(str::T) where T <: Union{String, Vector{Char}}
    n = length(str)
    F, _ = FiniteField(2, 1, "ω")
    sym = zero_matrix(F, 1, 2 * n)
    for (i, c) in enumerate(str)
        if c == 'X'
            sym[1, i] = F(1)
        elseif c == 'Z'
            sym[1, i + n] = F(1)
        elseif c == 'Y'
            sym[1, i] = 1
            sym[1, i + n] = F(1)
        elseif c != 'I'
            error("Encountered non-{I, X, Y, Z} character in Pauli string. This function is only defined for binary strings.")
        end
    end
    return sym
end
_Paulistringtosymplectic(A::Vector{T}) where T <: Union{String, Vector{Char}} = vcat([_Paulistringtosymplectic(s) for s in A]...)
_Paulistringstofield(str::T) where T <: Union{String, Vector{Char}} = symplectictoquadratic(_Paulistringtosymplectic(str))
_Paulistringstofield(A::Vector{T}) where T <: Union{String, Vector{Char}} = vcat([_Paulistringstofield(s) for s in A]...)
# need symplectictoPaulistring
# quadratictoPaulistring

function _processstrings(SPauli::Vector{T}, charvec::Union{Vector{nmod}, Missing}=missing) where T <: Union{String, Vector{Char}}
    # Paulisigns = Vector{Int64}()
    StrPaulistripped = Vector{String}()
    for (i, s) in enumerate(SPauli)
        if s[1] ∈ ['I', 'X', 'Y', 'Z']
            # append!(Paulisigns, 1)
            push!(StrPaulistripped, s)
        elseif s[1] == '+'
            # append!(Paulisigns, 1)
            push!(StrPaulistripped, s[2:end])
        elseif s[1] == '-'
            # append!(Paulisigns, -1)
            push!(StrPaulistripped, s[2:end])
        else
            error("The first element of Pauli string $i is neither a Pauli character or +/-: $s.")
        end
    end

    n = length(StrPaulistripped[1])
    for s in StrPaulistripped
        for i in s
            i ∈ ['I', 'X', 'Y', 'Z'] || error("Element of provided Pauli string is not a Pauli character: $s.")
        end
        length(s) == n || error("Not all Pauli strings are the same length.")
    end

    if !ismissing(charvec)
        2 * n == length(charvec) || error("The characteristic value is of incorrect length.")
        R = ResidueRing(Nemo.ZZ, 4)
        for s in charvec
            modulus(s) == modulus(R) || error("Phases are not in the correct ring.")
        end
    else
        R = ResidueRing(Nemo.ZZ, 4)
        charvec = [R(0) for _ in 1:2 * n]
    end
    return StrPaulistripped, charvec
end

function largestconsecrun(arr::Vector{Int64})
    n = length(arr)
    maxlen = 1
    for i = 1:n
        mn = arr[i]
        mx = arr[i]

        for j = (i + 1):n
            mn = min(mn, arr[j])
            mx = max(mx, arr[j])

            if (mx - mn) == (j - i)
                maxlen = max(maxlen, mx - mn + 1)
            end
        end
    end

    return maxlen
end

function _removeempty(A::fq_nmod_mat, type::String)
    type ∈ ["rows", "cols"] || error("Unknown type in _removeempty; expected: `rows` or `cols`, received: $type")
    del = Vector{Int64}()
    if type == "rows"
        for r in 1:nrows(A)
            if iszero(A[r, :])
                append!(del, r)
            end
        end
        return isempty(del) ? A : A[setdiff(1:nrows(A), del), :]
    else
        for c in 1:ncols(A)
            if iszero(A[:, c])
                append!(del, c)
            end
        end
        return isempty(del) ? A : A[:, setdiff(1:ncols(A), del)]
    end
end

function _rref_no_col_swap(M::fq_nmod_mat, rowrange::UnitRange{Int}, colrange::UnitRange{Int})
    isempty(rowrange) && error("The row range cannot be empty in _rref_no_col_swap.")
    isempty(colrange) && error("The column range cannot be empty in _rref_no_col_swap.")
    A = deepcopy(M)

    i = rowrange.start
    j = colrange.start
    nr = rowrange.stop
    nc = colrange.stop
    while i <= nr && j <= nc
        # find first pivot
        ind = 0
        for k in i:nr
            if !iszero(A[k, j])
                ind = k
                break
            end
        end

        if !iszero(ind)
            # normalize pivot
            if !isone(A[ind, j])
                A[ind, :] *= inv(A[ind, j])
            end

            # swap to put the pivot in the next row
            if ind != i
                A[i, :], A[ind, :] = A[ind, :], A[i, :]
            end

            # eliminate
            for k = rowrange.start:nr
                if k != i
                    d = A[k, j]
                    @simd for l = j:nc
                        A[k, l] = (A[k, l] - d * A[i, l])
                    end
                end
            end
            i += 1
        end
        j += 1
    end
    return A
end



# #=
# Example of using the repeated iterator inside of product.
#
# It turns out that this is faster than the Nemo iterator and doesn't allocate.
#
# julia> @benchmark for i in Base.Iterators.product(Base.Iterators.repeated(0:1, 10)...) i end
# BenchmarkTools.Trial: 10000 samples with 137 evaluations.
#  Range (min … max):  713.022 ns …  1.064 μs  ┊ GC (min … max): 0.00% … 0.00%
#  Time  (median):     755.949 ns              ┊ GC (median):    0.00%
#  Time  (mean ± σ):   760.380 ns ± 24.121 ns  ┊ GC (mean ± σ):  0.00% ± 0.00%
#
#  Memory estimate: 0 bytes, allocs estimate: 0.
#
# julia> @benchmark for i in Nemo.AbstractAlgebra.ProductIterator([0:1 for _ in 1:10]) i end
# BenchmarkTools.Trial: 10000 samples with 1 evaluation.
#  Range (min … max):  34.064 μs …   2.604 ms  ┊ GC (min … max):  0.00% … 97.51%
#  Time  (median):     36.970 μs               ┊ GC (median):     0.00%
#  Time  (mean ± σ):   46.342 μs ± 124.916 μs  ┊ GC (mean ± σ):  16.57% ±  6.04%
#
#  Memory estimate: 176.50 KiB, allocs estimate: 2051.
#
# julia> @benchmark for i in Base.Iterators.product([0:1 for _ in 1:10]...) i end
# BenchmarkTools.Trial: 10000 samples with 1 evaluation.
#  Range (min … max):  53.741 μs …   1.465 ms  ┊ GC (min … max):  0.00% … 87.86%
#  Time  (median):     63.790 μs               ┊ GC (median):     0.00%
#  Time  (mean ± σ):   76.919 μs ± 104.655 μs  ┊ GC (mean ± σ):  12.40% ±  8.59%
#
#  Memory estimate: 432.88 KiB, allocs estimate: 2061.
# =#
#
#
# # Gray code iterator, naive formula, gives Ints instead of vectors
#
# struct GrayCodeNaive
#     n::Int
# end
#
# Base.iterate(G::GrayCodeNaive) = G.n < 64 ? (0, 1) : error("Don't handle cases this large")
#
# function Base.iterate(G::GrayCodeNaive, k)
#     k == 2^G.n && return nothing
#     return (k ⊻ (k >> 1), k + 1)
# end
#
# Base.length(G::GrayCodeNaive) = 2^G.n
#
# #=
# Benchmark result:
#
# julia> @benchmark for g in GrayCodeNaive(25) g end
# BenchmarkTools.Trial: 25 samples with 1 evaluation.
#  Range (min … max):  200.014 ms … 202.460 ms  ┊ GC (min … max): 0.00% … 0.00%
#  Time  (median):     200.305 ms               ┊ GC (median):    0.00%
#  Time  (mean ± σ):   200.626 ms ± 659.369 μs  ┊ GC (mean ± σ):  0.00% ± 0.00%
#
#  Memory estimate: 0 bytes, allocs estimate: 0.
# =#
#
#
#
# # Gray code iterator, chooses next based on previous, gives Ints instead of vectors
#
# struct GrayCode
#     n::Int
# end
#
# Base.iterate(G::GrayCode) = G.n < 64 ? (0, (0,1)) : error("Don't handle cases this large")
#
# function Base.iterate(G::GrayCode, state)
#     prev, k = state
#     k == 2 ^ G.n && return nothing
#     j = isodd(k) ? 0 : trailing_zeros(prev) + 1
#     next = prev ⊻ (1 << j)
#     return (next, (next, k+1))
# end
#
# Base.length(G::GrayCode) = 2^G.n
#
# #=
# Benchmark result:
#
# julia> @benchmark for g in GrayCode(25) g end
# BenchmarkTools.Trial: 15 samples with 1 evaluation.
#  Range (min … max):  348.661 ms … 349.411 ms  ┊ GC (min … max): 0.00% … 0.00%
#  Time  (median):     349.050 ms               ┊ GC (median):    0.00%
#  Time  (mean ± σ):   349.048 ms ± 225.710 μs  ┊ GC (mean ± σ):  0.00% ± 0.00%
#
#  Memory estimate: 0 bytes, allocs estimate: 0.
# =#
