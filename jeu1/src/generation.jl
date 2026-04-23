# This file contains methods to generate a data set of instances (i.e., sudoku grids)
include("io.jl")

"""
Generate an n*n grid with a given density

Argument
- n: size of the grid
- density: percentage in [0, 1] of initial values in the grid
"""
function generer_instance(nom_fichier::String)
    grille = rand(0:1, 15, 15)
    grille_lisse = copy(grille)
    
    for i in 2:14
        for j in 2:14
            somme_voisins = grille[i-1, j] + grille[i+1, j] + grille[i, j-1] + grille[i, j+1]
            if somme_voisins >= 3
                grille_lisse[i, j] = 1
            elseif somme_voisins <= 1
                grille_lisse[i, j] = 0
            end
        end
    end

    chemin_fichier = joinpath(@__DIR__, "..", "data", nom_fichier)
    
    open(chemin_fichier, "w") do f
        for i in 1:15
            blocs = Int[]
            c = 0
            for j in 1:15
                if grille_lisse[i, j] == 1
                    c += 1
                elseif c > 0
                    push!(blocs, c)
                    c = 0
                end
            end
            if c > 0 push!(blocs, c) end
            if isempty(blocs) push!(blocs, 0) end
            println(f, join(blocs, ","))
        end
        
        for j in 1:15
            blocs = Int[]
            c = 0
            for i in 1:15
                if grille_lisse[i, j] == 1
                    c += 1
                elseif c > 0
                    push!(blocs, c)
                    c = 0
                end
            end
            if c > 0 push!(blocs, c) end
            if isempty(blocs) push!(blocs, 0) end
            println(f, join(blocs, ","))
        end
    end

    return chemin_fichier
end
"""
Generate all the instances

Remark: a grid is generated only if the corresponding output file does not already exist
"""
function generateDataSet(n::Int)
    for i in 1:n
        nom_fichier = "instance_no$i.txt"
        generer_instance(nom_fichier)
    end
end



