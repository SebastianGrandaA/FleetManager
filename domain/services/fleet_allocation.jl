module FleetAllocation

using H3.API: h3Distance, stringToH3, rad2deg, h3ToGeo
using JonkerVolgenant: LinearAssignment
using DataFrames: DataFrame, groupby, nrow, combine

using Main.Models: Grid
using Main.GridBuilder: coordinates_to_hexagon

export relocate

function relocate(grid::Grid, couriers::DataFrame; kwargs...)::DataFrame
    """
    Match overcapacity with undercapacity hexagons to minimize the total travel time and
    update courier locations accordingly.
    """
    relocations = match(grid; kwargs...)
    relocations_per_hexagon = combine(
        groupby(
            relocations,
            [:receiver, :provider, :source_lat, :source_lng, :target_lat, :target_lng],
        ),
        nrow => :n_couriers,
        :distance => sum => :total_distance,
    )
    couriers.hexagonID = [
        coordinates_to_hexagon((courier.lat, courier.lng), grid.resolution) for
        courier in eachrow(couriers)
    ]
    couriers.is_relocated .= false

    update!(couriers, relocations_per_hexagon)

    return relocations
end

function match(grid::Grid; kwargs...)::DataFrame
    bigM = kwargs[:bigM]
    receivers, providers = build_nodes(grid.hexagons)
    arcs = build_arcs(receivers, providers, kwargs[:max_hexagon_travel], bigM)
    solution = LinearAssignment(:min, arcs)
    @assert solution.feasible

    assignment = solution.assignment

    return parse(assignment, receivers, providers, arcs, grid.adjacent_distance, bigM)
end

function build_nodes(hexagons::DataFrame)::Tuple{Vector{String}, Vector{String}}
    receivers, providers = [], []

    for hexagon in eachrow(hexagons)
        nodes = repeat([hexagon.hexagonID], abs(hexagon.capacity))

        hexagon.is_receiver ? append!(receivers, nodes) : append!(providers, nodes)
    end

    return receivers, providers
end

function build_arcs(
    receivers::Vector{String},
    providers::Vector{String},
    max_hexagon_travel::Int64,
    bigM::Real,
)::Matrix{Float64}
    arcs = fill(bigM, (length(receivers), length(providers)))

    for (idx_receiver, receiver) in enumerate(receivers)
        for (idx_provider, provider) in enumerate(providers)
            @assert receiver != provider

            distance = h3Distance(stringToH3(receiver), stringToH3(provider))
            is_feasible = distance < max_hexagon_travel
            arcs[idx_receiver, idx_provider] = is_feasible ? distance : bigM
        end
    end

    return arcs
end

function parse(
    solution::Vector{Int32},
    receivers::Vector{String},
    providers::Vector{String},
    arcs::Matrix{Float64},
    adjacent_distance::Real,
    bigM::Real,
)::DataFrame
    relocations = DataFrame(
        receiver = String[],
        provider = String[],
        distance = Real[],
        source_lat = Real[],
        source_lng = Real[],
        target_lat = Real[],
        target_lng = Real[],
    )

    for (receiver, provider) in enumerate(solution)
        provider == 0 && continue
        hexagon_distance = arcs[receiver, provider]

        if hexagon_distance != bigM
            source = h3ToGeo(stringToH3(providers[provider]))
            target = h3ToGeo(stringToH3(receivers[receiver]))

            relocation = (
                receivers[receiver],
                providers[provider],
                hexagon_distance * adjacent_distance,
                rad2deg(source.lat),
                rad2deg(source.lon),
                rad2deg(target.lat),
                rad2deg(target.lon),
            )

            push!(relocations, relocation)
        end
    end

    return relocations
end

function update!(couriers::DataFrame, relocations::DataFrame)::Nothing
    for relocation in eachrow(relocations)
        required = relocation.n_couriers

        for courier in eachrow(couriers)
            required <= 0 && break

            if !(courier.is_relocated) && courier.hexagonID == relocation.provider
                courier.hexagonID = relocation.receiver
                courier.lat = relocation.target_lat
                courier.lng = relocation.target_lng
                courier.is_relocated = true
                required -= 1
            end
        end
    end

    return nothing
end

end # module FleetAllocation