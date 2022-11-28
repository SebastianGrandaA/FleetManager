module FleetSizeOptimization

using DataFrames: DataFrameRow
using Distributions: Poisson, Gamma, UnivariateDistribution, quantile, cdf, pdf

using Main.Models: FleetSize, Grid

export determine_fleet_size!

function determine_fleet_size!(grid::Grid; kwargs...)::Nothing
    grid.hexagons.fleet_size = [
        fleet_size(hexagon, grid.adjacent_distance; kwargs...) for
        hexagon in eachrow(grid.hexagons)
    ]

    return nothing
end

function fleet_size(hexagon::DataFrameRow, adjacent_distance::Real; kwargs...)::FleetSize
    hexagon.orders == 0 && return FleetSize(Poisson(0), 0, 0)

    shortage_cost, overage_cost = kwargs[:shortage_cost], kwargs[:overage_cost]
    confidence_level, service_level = kwargs[:confidence_level], kwargs[:service_level]
    risk_profile, speed = kwargs[:risk_profile], kwargs[:speed]
    travel_time = adjacent_distance / speed

    demand_min, demand_max =
        confidence_interval(hexagon.demand_observations, confidence_level)
    fleet_min = newsvendor(demand_min, shortage_cost, overage_cost)
    fleet_max = newsvendor(demand_max, shortage_cost, overage_cost)
    selection_criteria =
        risk_profile == :averse ? risk_averse_newsvendor : risk_seeker_newsvendor
    fleet_optimal = selection_criteria(
        fleet_min:fleet_max,
        (demand_min, demand_max),
        shortage_cost,
        overage_cost,
    )
    demand = fleet_optimal[:demand]
    safety = safety_stock(demand, hexagon.capacity, travel_time, service_level)
    additional = max(0, safety - fleet_optimal[:fleet_size])

    return FleetSize(demand, fleet_optimal[:fleet_size], additional)
end

function confidence_interval(
    observations::Vector{Int64},
    confidence_level::Real,
)::Tuple{Poisson, Poisson}
    """Garrwood confidence interval for Poisson distribution."""
    M, ∑ = length(observations), sum(observations)
    λ_lower = quantile(Gamma(∑, 1 / M), (1 - confidence_level) / 2)
    λ_upper = quantile(Gamma(∑ + 1, 1 / M), (1 + confidence_level) / 2)

    return Poisson(λ_lower), Poisson(λ_upper)
end

function newsvendor(
    demand::UnivariateDistribution,
    shortage_cost::Real,
    overage_cost::Real,
)::Real
    """Optimal fleet size using the Newsvendor model."""
    critical_fractile = shortage_cost / (shortage_cost + overage_cost)

    return quantile(demand, critical_fractile)
end

function expected_cost(
    demand::Poisson,
    fleet_size::Real,
    shortage_cost::Real,
    overage_cost::Real,
)::Real
    """
    Expected cost of a fleet of size for the Poisson distribution
    """
    ∑ = sum(1 - cdf(demand, i) for i in fleet_size:1e5)

    return overage_cost * (fleet_size - demand.λ) + ∑ * (shortage_cost + overage_cost)
end

function minimum_cost(
    fleet_size::Real,
    demand_interval::Tuple{Poisson, Poisson},
    shortage_cost::Real,
    overage_cost::Real,
)::Tuple{Real, Poisson}
    """
    Demand with the minimum expected cost for a fleet of size.
    """
    cost_min, demand_min = findmin(
        Dict(
            demand => expected_cost(demand, fleet_size, shortage_cost, overage_cost) for
            demand in demand_interval
        ),
    )

    return cost_min, demand_min
end

function maximum_cost(
    fleet_size::Real,
    demand_interval::Tuple{Poisson, Poisson},
    shortage_cost::Real,
    overage_cost::Real,
)::Tuple{Real, Poisson}
    """
    Demand with the maximum expected cost for a fleet of size.
    """
    cost_max, demand_max = findmax(
        Dict(
            demand => expected_cost(demand, fleet_size, shortage_cost, overage_cost) for
            demand in demand_interval
        ),
    )

    return cost_max, demand_max
end

function risk_averse_newsvendor(
    fleet_range::UnitRange{Int64},
    demand_interval::Tuple{Poisson, Poisson},
    shortage_cost::Real,
    overage_cost::Real,
)::Dict{Symbol, Any}
    fleet_size_maximum = Dict(
        fleet_size =>
            maximum_cost(fleet_size, demand_interval, shortage_cost, overage_cost) for
        fleet_size in fleet_range
    )
    _, selected_fleet_size = findmin(i -> first(values(i)), fleet_size_maximum)

    return Dict(
        :fleet_size => selected_fleet_size,
        :demand => fleet_size_maximum[selected_fleet_size][2],
        :cost => fleet_size_maximum[selected_fleet_size][1],
    )
end

function risk_seeker_newsvendor(
    fleet_range::UnitRange{Int64},
    demand_interval::Tuple{Poisson, Poisson},
    shortage_cost::Real,
    overage_cost::Real,
)::Dict{Symbol, Any}
    fleet_size_minimum = Dict(
        fleet_size =>
            minimum_cost(fleet_size, demand_interval, shortage_cost, overage_cost) for
        fleet_size in fleet_range
    )
    _, selected_fleet_size = findmin(i -> first(values(i)), fleet_size_minimum)

    return Dict(
        :fleet_size => selected_fleet_size,
        :demand => fleet_size_minimum[selected_fleet_size][2],
        :cost => fleet_size_minimum[selected_fleet_size][1],
    )
end

function safety_stock(
    demand::UnivariateDistribution,
    capacity::Int64,
    travel_time::Real,
    service_level::Real,
)::Int64
    lead = lead_time(demand, capacity, travel_time)
    security_factor = quantile(demand, service_level)
    standard_deviation = sqrt(demand.λ)
    safety = sqrt(lead) * security_factor * standard_deviation * 0.1

    return trunc(Int64, safety)
end

function lead_time(demand::UnivariateDistribution, capacity::Int64, travel_time::Real)::Real
    """The required travel time to meet the deficit weighted by the probability of any given new arrival."""
    is_deficit = capacity < 0

    return sum(
        pdf(demand, new_arrivals) * (travel_time * (
            if is_deficit
                abs(capacity) + new_arrivals # required to meet deficit + new arrivals
            else
                max(0, new_arrivals - capacity) # required if new arrivals exceed capacity
            end
        )) for new_arrivals in 1:1e5
    )
end

end # module FleetSizeOptimization
