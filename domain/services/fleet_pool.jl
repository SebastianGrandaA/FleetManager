module FleetPool

using DataFrames: DataFrame, DataFrameRow, nrow
using JuMP: Model, @variable, @constraint, @objective, optimize!, value, with_optimizer
using GLPK: Optimizer

export select_hubs!

function select_hubs!(hexagons::DataFrame)::Nothing
    """
    Select hubs that maximize city-level pool benefit and 
    determine, for each hexagon, whether is a receiver, provider or balanced according to the required fleet size.
    """
    hexagons.pool_benefit = [benefit(hexagon, hexagons) for hexagon in eachrow(hexagons)]
    hubs = select_hubs(
        size(hexagons, 1),
        hexagons.hexagonID,
        hexagons.neighbors,
        hexagons.pool_benefit,
    )
    hexagons.is_hub = [hexagon in hubs for hexagon in 1:nrow(hexagons)]

    return update!(hexagons)
end

function benefit(hexagon::DataFrameRow, hexagons::DataFrame)::Real
    neighborhood = filter(hex -> hex.hexagonID in hexagon.neighbors, eachrow(hexagons))
    isempty(neighborhood) && return 0.0

    σ_pool = sqrt(sum(neighbor.fleet_size.demand.λ for neighbor in neighborhood))
    ∑σ = sum(sqrt(neighbor.fleet_size.demand.λ) for neighbor in neighborhood)

    return 1 - (σ_pool / ∑σ)
end

function select_hubs(
    H::Int64,
    IDs::Vector{String},
    coverage::Vector{Vector{String}},
    weights::Vector{Float64},
)::Vector{Int64}
    weights = [w > 0 ? w : 0 for w in weights]

    model = Model(with_optimizer(Optimizer))
    @variable(model, is_hub[1:H], Bin)
    @constraint(
        model,
        [i in 1:H],
        sum(is_hub[j] * (IDs[j] in coverage[i] ? 1 : 0) for j in 1:H) <= 1
    )
    @objective(model, Max, sum(is_hub[i] * weights[i] for i in 1:H))
    optimize!(model)

    return findall(value.(is_hub) .> 0.5)
end

function update!(hexagons::DataFrame)::Nothing
    hexagons.fleet_pool = [pool(hexagon, hexagons) for hexagon in eachrow(hexagons)]

    hexagons.required_fleet = [required_fleet(hexagon) for hexagon in eachrow(hexagons)]
    hexagons.is_receiver = hexagons.required_fleet .> 0
    hexagons.is_provider = hexagons.required_fleet .< 0
    hexagons.is_balanced = hexagons.required_fleet .== 0

    return nothing
end

function pool(hub::DataFrameRow, hexagons::DataFrame)::Dict{Symbol, Real}
    if !(hub.is_hub)
        has_been_pooled = length(hub.neighbors) == 1
        has_been_pooled && return Dict{Symbol, Real}(:safety_fleet => 0)

        hub.neighbors = []
        return Dict{Symbol, Real}()
    end

    pooled_safety = deepcopy(hub.fleet_size.safety)

    for neighbor_id in hub.neighbors
        search = filter(hex -> hex.hexagonID == neighbor_id, hexagons)
        isempty(search) && continue
        neighbor = first(search)

        if neighbor.hexagonID == hub.hexagonID
            neighbor.pool_benefit < 0 && @warn "Hub $(neighbor.hexagonID) has a negative pool benefit."

            hub.neighbors = setdiff(hub.neighbors, neighbor_id)
        else
            @assert !(neighbor.is_hub)

            neighbor.neighbors = [hub.hexagonID]
            pooled_safety += neighbor.fleet_size.safety
        end
    end

    return Dict(:safety_fleet => pooled_safety)
end

function required_fleet(hexagon::DataFrameRow)::Real
    available = hexagon.capacity > 0 ? hexagon.capacity : 0
    required = hexagon.fleet_size.required
    safety =
        coalesce(get(hexagon.fleet_pool, :safety_fleet, missing), hexagon.fleet_size.safety)

    return (required + safety) - available
end

end # module FleetPool