module Relocations

using CSV
using JSON
using DataFrames: groupby
using Statistics: mean

using Main.Models: Plan

export save!

function save!(path::String, plan::Plan)::Nothing
    info = Dict(
        :resolution => plan.grid.resolution,
        :adjacent_distance => plan.grid.adjacent_distance
    )
    !(isdir(path)) && mkpath(path)

    push!(info, :avg_couriers_per_hexagon => mean([size(group, 1) for group in groupby(plan.couriers, :hexagonID)]))
    push!(info, :avg_orders_per_hexagon => mean([sum(group.orders) for group in groupby(plan.grid.hexagons, :hexagonID)]))

    CSV.write(joinpath(path, "relocations.csv"), plan.relocations)
    CSV.write(joinpath(path, "grid.csv"), plan.grid.hexagons)
    CSV.write(joinpath(path, "relocated_couriers.csv"), plan.couriers)

    open(joinpath(path, "info.json"), "w") do io
        JSON.print(io, info)
    end
    
    return nothing
end

end # module Relocations