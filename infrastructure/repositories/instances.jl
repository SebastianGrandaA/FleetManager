module Instances

using CSV
using DataFrames: DataFrame

export gather

function gather(path::String, saturation::Float64; kwargs...)::Union{DataFrame, Tuple{DataFrame, DataFrame}}
    couriers_file = get(kwargs, :couriers_file, missing)
    !ismissing(couriers_file) && return CSV.read(joinpath(path, "$(couriers_file).csv"), DataFrame)

    orders = CSV.read(joinpath(path, "orders.csv"), DataFrame)
    couriers = CSV.read(joinpath(path, "couriers_sat$(saturation).csv"), DataFrame)

    return orders, couriers
end

end # module Instances