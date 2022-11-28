module Models

using Distributions: UnivariateDistribution
using DataFrames: DataFrame

export Experiment, Grid, FleetSize, Plan, BenchmarkResult

mutable struct Experiment
    city::String
    scenarios::Matrix{Tuple{String, Float64}}
end

mutable struct Grid
    resolution::Real
    hexagons::DataFrame
    adjacent_distance::Real
end

mutable struct FleetSize
    demand::UnivariateDistribution
    required::Int64
    safety::Int64
end

mutable struct Plan
    grid::Grid
    couriers::DataFrame
    relocations::DataFrame
end

mutable struct BenchmarkResult
    as_is::DataFrame
    to_be::DataFrame
    metrics::DataFrame
    info::Dict{Symbol, Any}
end

end # module Models