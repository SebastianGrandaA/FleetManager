module BenchmarkResults

using CSV
using JSON
using DataFrames: describe
using PlotlyJS: plot, box, scatter, savefig, Layout

using Main.Models: BenchmarkResult

export save!

function save!(path::String, result::BenchmarkResult)::Nothing
    !(isdir(path)) && mkpath(path)

    CSV.write(joinpath(path, "metrics.csv"), result.metrics)

    linechart_kwargs = Dict(:mode => "markers+lines+text")
    savefig(
        plot(
            [
                scatter(
                    x = collect(1:length(result.metrics.avg_time_before)),
                    y = result.metrics.avg_time_before,
                    name = "Control";
                    linechart_kwargs...,
                ),
                scatter(
                    x = collect(1:length(result.metrics.avg_time_after)),
                    y = result.metrics.avg_time_after,
                    name = "Experimental";
                    linechart_kwargs...,
                ),
            ],
            Layout(
                title = "Tiempo promedio a tienda de las asignaciones en los escenarios",
                xaxis_title = "Instancia",
                yaxis_title = "Tiempo (minutos)",
            ),
        ),
        joinpath(path, "avg_time_scenarios.png"),
    )

    CSV.write(joinpath(path, "summary_as_is.csv"), describe(result.as_is))
    CSV.write(joinpath(path, "summary_to_be.csv"), describe(result.to_be))

    boxplot_kwargs = Dict(:boxmean => true)
    savefig(
        plot(
            [
                box(y=result.as_is.times, name = "Control"; boxplot_kwargs...),
                box(y=result.to_be.times, name = "Experimental"; boxplot_kwargs...),
            ],
            Layout(
                title = "Distribución de tiempos de asignación en los escenarios",
                xaxis_title = "Escenario",
                yaxis_title = "Tiempo (minutos)",
            ),
        ),
        joinpath(path, "time_distribution_scenarios.png"),
    )

    open(joinpath(path, "info.json"), "w") do io
        return JSON.print(io, result.info)
    end

    return nothing
end

end # module BenchmarkResults