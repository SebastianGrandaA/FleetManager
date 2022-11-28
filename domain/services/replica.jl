module Replica

using DataFrames: DataFrame
using Distances: haversine

using JonkerVolgenant: LinearAssignment

export match

function match(orders::DataFrame, couriers::DataFrame; kwargs...)::Vector{Float64}
    bigM = get(kwargs, :bigM, 10000.0)
    order_pickups = [(order[:lat], order[:lng]) for order in eachrow(orders)]
    couriers_locations = [(courier[:lat], courier[:lng]) for courier in eachrow(couriers)]
    arcs = build_arcs(
        order_pickups,
        couriers_locations,
        kwargs[:max_distance],
        kwargs[:speed],
        bigM,
    )
    solution = LinearAssignment(:min, arcs)

    match_times = [
        arcs[order, courier] for (order, courier) in enumerate(solution.assignment) if
        courier != 0 && arcs[order, courier] != bigM
    ]

    return match_times
end

function build_arcs(
    orders::Vector{Tuple{Float64, Float64}},
    couriers::Vector{Tuple{Float64, Float64}},
    max_distance::Int64,
    speed::Int64,
    bigM::Real,
)::Matrix{Float64}
    arcs = fill(bigM, (length(orders), length(couriers)))

    for (idx_order, order) in enumerate(orders)
        for (idx_courier, courier) in enumerate(couriers)
            @assert order != courier

            to_store_distance = distance(order, courier, :km)
            is_feasible = to_store_distance < max_distance
            time = 60 * (to_store_distance / speed)

            arcs[idx_order, idx_courier] = is_feasible ? time : bigM
        end
    end

    return arcs
end

function distance(from::Tuple{Real, Real}, to::Tuple{Real, Real}, unit::Symbol = :km)::Real
    radius = unit == :km ? 6371 : 6371 * 1000

    return haversine((from[2], from[1]), (to[2], to[1]), radius)
end

end # module Replica
