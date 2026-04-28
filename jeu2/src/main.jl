using Plots 
include("io.jl")
include("resolution.jl")
include("generation.jl")

function afficherSolution(grille_3d)
    l, c, r = size(grille_3d)
    for i in 1:l
        for j in 1:c
            for k in 1:r
                if grille_3d[i, j, k] > 0.5
                    print(lpad(k, 3))
                    break
                end
            end
        end
        println()
    end
end

function main()
    chemin_fichier = joinpath(@__DIR__, "..", "data", "instanceTest.txt")
    V, n = readInputFile(chemin_fichier)
    is_optimal, time_taken, solution = cplexSolve(V, n)
    afficherSolution(solution)
    return is_optimal, time_taken
end

main()
