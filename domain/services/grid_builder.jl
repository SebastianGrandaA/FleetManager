module GridBuilder

using DataFrames: DataFrame, groupby, combine, nrow, outerjoin
using H3.API: geoToH3, GeoCoord, h3ToString, deg2rad, hexAreaKm2, kRing, stringToH3
using Distributions: Poisson

using Main.Models: Grid

export build, coordinates_to_hexagon

function build(orders::DataFrame, couriers::DataFrame; kwargs...)::Grid
    resolution, longest_distance =
        select_grid_resolution(kwargs[:max_distance], kwargs[:grid_resolutions])
    distance_centroids = 2 * apotem(longest_distance)

    orders.hexagonID = [
        coordinates_to_hexagon((restaurant.lat, restaurant.lng), resolution) for
        restaurant in eachrow(orders)
    ]
    orders_per_hexagon = combine(groupby(orders, :hexagonID), :orders => sum => :orders)

    couriers.hexagonID = [
        coordinates_to_hexagon((courier.lat, courier.lng), resolution) for
        courier in eachrow(couriers)
    ]
    couriers_per_hexagon = combine(groupby(couriers, :hexagonID), nrow => :couriers)

    grid = outerjoin(orders_per_hexagon, couriers_per_hexagon, on = :hexagonID)
    grid.couriers = coalesce.(grid.couriers, 0)
    grid.orders = coalesce.(grid.orders, 0)
    grid.capacity = grid.couriers .- grid.orders
    grid.demand_observations = [
        rand(Poisson(hexagon.orders), kwargs[:demand_observations]) for
        hexagon in eachrow(grid)
    ]
    grid.neighbors =
        [h3ToString.(kRing(stringToH3(hexagon.hexagonID), 1)) for hexagon in eachrow(grid)]

    return Grid(resolution, grid, distance_centroids)
end

function select_grid_resolution(
    max_allowed_distance::Int64,
    grid_resolutions::UnitRange{Int64},
)::Tuple{Real, Real}
    longest_per_resolution =
        [longest_distance(resolution) for resolution in grid_resolutions]
    Δ, best =
        findmin(longest -> abs(longest - max_allowed_distance), longest_per_resolution)

    return best, longest_per_resolution[best]
end

function longest_distance(resolution::Real)::Real
    return radius(hexAreaKm2(resolution)) * sqrt(3)
end

radius(area::Real)::Real = sqrt(2 * area / 3 * sqrt(3))

function apotem(longest::Real)::Real
    return (longest * sqrt(3)) / (2 * sqrt(13))
end

function coordinates_to_hexagon(coordinates::Tuple{Real, Real}, resolution::Int64)::String
    return h3ToString(
        geoToH3(GeoCoord(deg2rad(coordinates[1]), deg2rad(coordinates[2])), resolution),
    )
end

end # module GridBuilder
