module GraphMatching
using Graphs: SimpleGraph, Edge, add_edge!
using GraphsMatching: minimum_weight_perfect_matching
# en desuso: actualmente se utuliza Jonker.
function match()
    add_dummies!(receivers, providers)

    @assert length(receivers) == length(providers)

    N = length(receivers)
    graph = build_bipartite_graph(N)
    arcs = build_arcs(receivers, providers, max_hexagon_travel, bigM)
    assignment = minimum_weight_perfect_matching(graph, arcs, bigM)

    return assignment
end
function build_arcs(
    receivers::Vector{String},
    providers::Vector{String},
    max_hexagon_travel::Int64,
    bigM::Real,
)::Union{Matrix{Float64}, Dict{Edge, Float64}}
    N = length(receivers)
    arcs = Dict{Edge, Float64}()

    for i in 1:N
        for j in (N + 1):(N * 2)
            @assert receivers[i] != providers[j - N]

            if receivers[i] == "Dummy" || providers[j - N] == "Dummy"
                arcs[Edge(i, j)] = bigM

            else
                distance =
                    h3Distance(stringToH3(receivers[i]), stringToH3(providers[j - N]))

                is_feasible = distance < max_hexagon_travel
                arcs[Edge(i, j)] = is_feasible ? distance : bigM
            end
        end
    end

    return arcs
end


function add_dummies!(receivers::Vector{String}, providers::Vector{String})::Nothing
    dummy = "Dummy"
    Δ = length(receivers) - length(providers)

    for _ in 1:abs(Δ)
        Δ > 0 ? push!(providers, dummy) : push!(receivers, dummy)
    end

    return nothing
end

function build_bipartite_graph(cardinality::Int64)::SimpleGraph{Int64}
    graph = SimpleGraph{Int64}(cardinality * 2)

    for i in 1:cardinality
        for j in (cardinality + 1):(cardinality * 2)
            add_edge!(graph, i, j)
        end
    end

    return graph
end

end

