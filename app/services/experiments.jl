module Experiments

using Main.Models: Experiment
using Main.Instances: gather
using Main.Manager: fleet_management
using Main.Relocations: save!

export create!

function create!(experiment::Experiment; kwargs...)::Nothing
    for (date, saturation) in experiment.scenarios
        path = joinpath(experiment.city, date)
        input_path = joinpath("datasets", path)
        output_path = joinpath("results", path, "sat_$(saturation)")

        orders, couriers = gather(input_path, saturation)
        plan = fleet_management(orders, couriers; kwargs...)

        save!(output_path, plan)
        @info "Experiment $(experiment.city) $(date) $(saturation) saved."
    end

    return nothing
end

end # module Experiments
