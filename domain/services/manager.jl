module Manager

using DataFrames: DataFrame

using Main.Models: Plan
using Main.GridBuilder: build
using Main.FleetSizeOptimization: determine_fleet_size!
using Main.FleetPool: select_hubs!
using Main.FleetAllocation: relocate

export fleet_management

function fleet_management(orders::DataFrame, couriers::DataFrame; kwargs...)::Plan
    """Four steps: grid system, fleet size, fleet pool and fleet allocation."""
    grid = build(orders, couriers; kwargs...)

    determine_fleet_size!(grid; kwargs...)
    select_hubs!(grid.hexagons)
    relocations = relocate(grid, couriers; kwargs...)

    return Plan(grid, couriers, relocations)
end

end # module Manager