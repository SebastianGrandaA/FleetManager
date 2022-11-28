using Main.Models: Experiment
using Main.Experiments: create!
using Main.Benchmark: benchmark!

function run!(; kwargs...)::Nothing
    """Entrypoint for the application."""
    city = get(kwargs, :city, "Lima")
    dates = get(kwargs, :dates, ["20", "21", "22", "23", "24", "25", "26", "27", "28", "29"])
    hours = get(kwargs, :hours, ["13", "21"])
    saturations = get(kwargs, :saturations, [0.5, 0.8, 1.0, 1.5])
    dates = [
        "2022-11-$(day) $(hour):00:00" for day in dates for hour in hours
    ]
    scenarios = collect(Iterators.product(dates, saturations))
    experiment = Experiment(city, scenarios)
    settings = Dict(
        :max_distance => get(kwargs, :max_distance, 5),
        :max_hexagon_travel => get(kwargs, :max_hexagon_travel, 3),
        :grid_resolutions => get(kwargs, :grid_resolutions, 0:15),
        :demand_observations => get(kwargs, :demand_observations, 10),
        :confidence_level => get(kwargs, :confidence_level, 0.95),
        :service_level => get(kwargs, :service_level, 0.8),
        :significance_level => get(kwargs, :significance_level, 0.05),
        :shortage_cost => get(kwargs, :shortage_cost, 10),
        :overage_cost => get(kwargs, :overage_cost, 5),
        :risk_profile => get(kwargs, :risk_profile, :averse),
        :speed => get(kwargs, :speed, 10),
        :bigM => get(kwargs, :bigM, 10000.),
    )
    
    create!(experiment; settings...)
    benchmark!(experiment, saturations; settings...)
end
