const AbstractSparseADType = Union{AbstractSparseForwardMode, AbstractSparseReverseMode,
    AbstractSparseFiniteDifferences}

struct AutoSparseEnzyme <: AbstractSparseReverseMode end

# Sparsity Detection
abstract type AbstractMaybeSparsityDetection end
abstract type AbstractSparsityDetection <: AbstractMaybeSparsityDetection end

struct NoSparsityDetection <: AbstractMaybeSparsityDetection end

Base.@kwdef struct SymbolicsSparsityDetection{A <: ArrayInterface.ColoringAlgorithm} <:
                   AbstractSparsityDetection
    alg::A = GreedyD1Color()
end

Base.@kwdef struct JacPrototypeSparsityDetection{
    J, A <: ArrayInterface.ColoringAlgorithm,
} <: AbstractSparsityDetection
    jac_prototype::J
    alg::A = GreedyD1Color()
end

Base.@kwdef struct AutoSparsityDetection{A <: ArrayInterface.ColoringAlgorithm} <:
                   AbstractSparsityDetection
    alg::A = GreedyD1Color()
end

# Function Specifications
abstract type AbstractMaybeSparseJacobianCache end

"""
    sparse_jacobian!(J::AbstractMatrix, ad, cache::AbstractMaybeSparseJacobianCache, f, x)
    sparse_jacobian!(J::AbstractMatrix, ad, cache::AbstractMaybeSparseJacobianCache, f!, fx,
        x)

Inplace update the matrix `J` with the Jacobian of `f` at `x` using the AD backend `ad`.

`cache` is the cache object returned by `sparse_jacobian_cache`.
"""
function sparse_jacobian! end

"""
    sparse_jacobian_cache(ad::AbstractADType, sd::AbstractSparsityDetection, f, x; fx=nothing)
    sparse_jacobian_cache(ad::AbstractADType, sd::AbstractSparsityDetection, f!, fx, x)

Takes the underlying AD backend `ad`, sparsity detection algorithm `sd`, function `f`,
and input `x` and returns a cache object that can be used to compute the Jacobian.

If `fx` is not specified, it will be computed by calling `f(x)`.

## Returns

A cache for computing the Jacobian of type `AbstractMaybeSparseJacobianCache`.
"""
function sparse_jacobian_cache end

"""
    sparse_jacobian(ad::AbstractADType, sd::AbstractMaybeSparsityDetection, f, x; fx=nothing)
    sparse_jacobian(ad::AbstractADType, sd::AbstractMaybeSparsityDetection, f!, fx, x)

Sequentially calls `sparse_jacobian_cache` and `sparse_jacobian!` to compute the Jacobian of
`f` at `x`. Use this if the jacobian for `f` is computed exactly once. In all other
cases, use `sparse_jacobian_cache` once to generate the cache and use `sparse_jacobian!`
with the same cache to compute the jacobian.
"""
function sparse_jacobian(ad::AbstractADType, sd::AbstractMaybeSparsityDetection, args...;
    kwargs...)
    cache = sparse_jacobian_cache(ad, sd, args...; kwargs...)
    J = __init_𝒥(cache)
    return sparse_jacobian!(J, ad, cache, args...)
end

"""
    sparse_jacobian(ad::AbstractADType, cache::AbstractMaybeSparseJacobianCache, f, x)
    sparse_jacobian(ad::AbstractADType, cache::AbstractMaybeSparseJacobianCache, f!, fx, x)

Use the sparsity detection `cache` for computing the sparse Jacobian. This allocates a new
Jacobian at every function call
"""
function sparse_jacobian(ad::AbstractADType, cache::AbstractMaybeSparseJacobianCache,
    args...)
    J = __init_𝒥(cache)
    return sparse_jacobian!(J, ad, cache, args...)
end

"""
    sparse_jacobian!(J::AbstractMatrix, ad::AbstractADType, sd::AbstractSparsityDetection,
        f, x; fx=nothing)
    sparse_jacobian!(J::AbstractMatrix, ad::AbstractADType, sd::AbstractSparsityDetection,
        f!, fx, x)

Sequentially calls `sparse_jacobian_cache` and `sparse_jacobian!` to compute the Jacobian of
`f` at `x`. Use this if the jacobian for `f` is computed exactly once. In all other
cases, use `sparse_jacobian_cache` once to generate the cache and use `sparse_jacobian!`
with the same cache to compute the jacobian.
"""
function sparse_jacobian!(J::AbstractMatrix, ad::AbstractADType,
    sd::AbstractMaybeSparsityDetection, args...; kwargs...)
    cache = sparse_jacobian_cache(ad, sd, args...; kwargs...)
    return sparse_jacobian!(J, ad, cache, args...)
end

## Internal
function __gradient end
function __gradient! end
function __jacobian! end

function __init_𝒥 end

# Misc Functions
__chunksize(::AutoSparseForwardDiff{C}) where {C} = C

__f̂(f, x, idxs) = dot(vec(f(x)), idxs)

function __f̂(f!, fx, x, idxs)
    f!(fx, x)
    return dot(vec(fx), idxs)
end

@generated function __getfield(c::T, ::Val{S}) where {T, S}
    hasfield(T, S) && return :(c.$(S))
    return :(nothing)
end

function __init_𝒥(c::AbstractMaybeSparseJacobianCache)
    T = promote_type(eltype(c.fx), eltype(c.x))
    return __init_𝒥(__getfield(c, Val(:jac_prototype)), T, c.fx, c.x)
end
__init_𝒥(::Nothing, ::Type{T}, fx, x) where {T} = similar(fx, T, length(fx), length(x))
__init_𝒥(J, ::Type{T}, _, _) where {T} = similar(J, T, size(J, 1), size(J, 2))
