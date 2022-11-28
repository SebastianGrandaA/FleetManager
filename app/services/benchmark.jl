module Benchmark

using DataFrames: DataFrame, append!
using HypothesisTests: KruskalWallisTest, pvalue
using Statistics: mean

using Main.Models: BenchmarkResult, Experiment
using Main.Replica: match
using Main.Instances: gather
using Main.BenchmarkResults: save!

export benchmark!

function benchmark!(experiment::Experiment, saturations::Vector{Float64}; kwargs...)::Nothing
    as_is_results = Dict{Float64, Vector{Float64}}(saturation => [] for saturation in saturations)
    to_be_results = Dict{Float64, Vector{Float64}}(saturation => [] for saturation in saturations)
    metrics = DataFrame(
        saturation = [],
        avg_time_before = [],
        avg_time_after = [],
        time_improvement = [],
        unassigned_before = [],
        unassigned_after = [],
        unassigned_improvement = [],
    )

    for (date, saturation) in experiment.scenarios
        push!(saturations, saturation)
        path = joinpath(experiment.city, date)
        input_path = joinpath("datasets", path)
        output_path = joinpath("results", path, "sat_$(saturation)")

        orders, couriers = gather(input_path, saturation)
        relocated_couriers =
            gather(output_path, saturation, couriers_file = "relocated_couriers")

        as_is = match(orders, couriers; kwargs...)
        to_be = match(orders, relocated_couriers; kwargs...)
        append!(as_is_results[saturation], as_is)
        append!(to_be_results[saturation], to_be)

        avg_time_before = mean(as_is)
        avg_time_after = mean(to_be)
        time_improvement = 100 * (avg_time_before - avg_time_after) / avg_time_before
        n_orders = size(orders, 1)
        unassigned_before = n_orders - length(as_is)
        unassigned_after = n_orders - length(to_be)
        (unassigned_before < 0 || unassigned_after < 0) &&
            error("Unassigned orders cannot be negative")
        unassigned_improvement =
            100 * (unassigned_before - unassigned_after) / unassigned_before

        append!(
            metrics,
            DataFrame(
                saturation = [saturation],
                avg_time_before = [avg_time_before],
                avg_time_after = [avg_time_after],
                time_improvement = [time_improvement],
                unassigned_before = [unassigned_before],
                unassigned_after = [unassigned_after],
                unassigned_improvement = [unassigned_improvement],
            ),
        )
    end

    for saturation in saturations
        path = joinpath("results", experiment.city, "benchmark", "sat_$(saturation)")
        test = KruskalWallisTest(as_is_results[saturation], to_be_results[saturation])
        p_value = pvalue(test)
        success = p_value < kwargs[:significance_level]

        result = BenchmarkResult(
            DataFrame(times = as_is_results[saturation]),
            DataFrame(times = to_be_results[saturation]),
            filter(row -> row.saturation == saturation, metrics),
            Dict(:is_significant => success, :p_value => p_value)
        )       
        save!(path, result)

        @info "Benchmarking  $(experiment.city) with saturation $(saturation) finished."
    end

    return nothing
end

end # module Benchmark
