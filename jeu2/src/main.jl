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
    solution2d = zeros(Int, l, c)
    for i in 1:l
        for j in 1:c
            for k in 1:r
                if grille_3d[i, j, k] >= 1
                    solution2d[i, j] = k
                    break
                end
            end
        end
    end

    p = plot(aspect_ratio=:equal, showaxis=false, ticks=nothing, xlim=(0, c), ylim=(0, l), legend=false)
    plot!([0, c, c, 0, 0], [0, 0, l, l, 0], color=:black, linewidth=4)

    for i in 1:(l-1)
        for j in 1:c
            if solution2d[i, j] != solution2d[i+1, j]
                plot!([j-1, j], [l-i, l-i], color=:black, linewidth=4)
            end
        end
    end

    for i in 1:l
        for j in 1:(c-1)
            if solution2d[i,j] != solution2d[i, j+1]
                plot!([j, j], [l-i, l-i+1], color=:black, linewidth=4)
            end
        end
    end

    display(p)
end

function main()
    chemin_fichier = joinpath(@__DIR__, "..", "data", "instanceTest_plus_dur.txt")
    V, n = readInputFile(chemin_fichier)
    is_optimal, time_taken, solution = cplexSolve(V, n)
    
    if is_optimal
        afficherSolution(solution)
    else
        println("Aucune solution trouvée.")
    end
    
    return is_optimal, time_taken
end

main()
