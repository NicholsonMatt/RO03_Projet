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
    change = true
    it_max = 10
    it = 0
    while change && (it < it_max)
        it = it + 1
        change = false
        for i in 1:15
            for j in 1:15
                somme_voisins = 0
                
                if i > 1
                    somme_voisins += grille[i-1, j]
                end
                if i < 15
                    somme_voisins += grille[i+1, j]
                end
                if j > 1
                    somme_voisins += grille[i, j-1]
                end
                if j < 15
                    somme_voisins += grille[i, j+1]
                end
                if i > 1 && j > 1
                    somme_voisins += grille[i-1, j-1]
                end
                if i < 15 && j < 15
                    somme_voisins += grille[i+1, j+1]
                end
                if i > 1 && j < 15
                    somme_voisins += grille[i-1, j+1]
                end
                if i < 15 && j > 1
                    somme_voisins += grille[i+1, j-1]
                end
                
                if somme_voisins >= 5
                    grille_lisse[i, j] = 1
                    change = true
                elseif somme_voisins <= 3
                    grille_lisse[i, j] = 0
                    change = true
                end
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



