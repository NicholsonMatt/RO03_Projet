# This file contains methods to generate a data set of instances (i.e., sudoku grids)
include("io.jl")
using JuMP, CPLEX

"""
Generate an n*n grid with a given density

Argument
- n: size of the regions
- density: percentage in [0, 1] of initial values in the grid
"""

function cplexGenerate(lignes::Int, colonnes::Int, n::Int)
    m = Model(CPLEX.Optimizer)
    nb_regions = div(lignes * colonnes, n)

    @variable(m, X[1:lignes, 1:colonnes, 1:nb_regions], Bin)
    
    @variable(m, R[1:lignes, 1:colonnes, 1:nb_regions], Bin)
    @variable(m, F_h[1:lignes, 1:colonnes, 1:nb_regions] >= 0)
    @variable(m, F_b[1:lignes, 1:colonnes, 1:nb_regions] >= 0)
    @variable(m, F_g[1:lignes, 1:colonnes, 1:nb_regions] >= 0)
    @variable(m, F_d[1:lignes, 1:colonnes, 1:nb_regions] >= 0)

    for i in 1:lignes
        for j in 1:colonnes
            @constraint(m, sum(X[i,j,k] for k in 1:nb_regions) == 1)
        end
    end

    for k in 1:nb_regions
        @constraint(m, sum(X[i,j,k] for i in 1:lignes, j in 1:colonnes) == n)
        @constraint(m, sum(R[i,j,k] for i in 1:lignes, j in 1:colonnes) == 1)
    end

    for k in 1:nb_regions
        for i in 1:lignes
            for j in 1:colonnes
                
                @constraint(m, R[i,j,k] <= X[i,j,k])

                # Gestion des bords pour le flot
                if i == 1 @constraint(m, F_h[i,j,k] == 0) end
                if i == lignes @constraint(m, F_b[i,j,k] == 0) end
                if j == 1 @constraint(m, F_g[i,j,k] == 0) end
                if j == colonnes @constraint(m, F_d[i,j,k] == 0) end

                # Capacités du flot
                @constraint(m, F_h[i,j,k] <= n * X[i,j,k])
                @constraint(m, F_b[i,j,k] <= n * X[i,j,k])
                @constraint(m, F_g[i,j,k] <= n * X[i,j,k])
                @constraint(m, F_d[i,j,k] <= n * X[i,j,k])
                
                if i > 1 @constraint(m, F_h[i,j,k] <= n * X[i-1,j,k]) end
                if i < lignes @constraint(m, F_b[i,j,k] <= n * X[i+1,j,k]) end
                if j > 1 @constraint(m, F_g[i,j,k] <= n * X[i,j-1,k]) end
                if j < colonnes @constraint(m, F_d[i,j,k] <= n * X[i,j+1,k]) end

                # Conservation du flot
                in_flow_arr = VariableRef[]
                if i < lignes push!(in_flow_arr, F_h[i+1, j, k]) end
                if i > 1 push!(in_flow_arr, F_b[i-1, j, k]) end
                if j < colonnes push!(in_flow_arr, F_g[i, j+1, k]) end
                if j > 1 push!(in_flow_arr, F_d[i, j-1, k]) end
                
                out_flow = F_h[i,j,k] + F_b[i,j,k] + F_g[i,j,k] + F_d[i,j,k]

                @constraint(m, sum(in_flow_arr) - out_flow == X[i,j,k] - n * R[i,j,k])
                
            end
        end
    end
    C = rand(lignes, colonnes, nb_regions)
    @objective(m, Max, sum(C[i,j,k] * X[i,j,k] for i in 1:lignes, j in 1:colonnes, k in 1:nb_regions))
    
    optimize!(m)
    
    if termination_status(m) == MOI.OPTIMAL
        sol_X = round.(Int, value.(X))
        sol_2d = zeros(Int, lignes, colonnes)
        for i in 1:lignes
            for j in 1:colonnes
                for k in 1:nb_regions
                    if sol_X[i,j,k] == 1
                        sol_2d[i,j] = k
                        break
                    end
                end
            end
        end
        return sol_2d
    else
        error("CPLEX n'a pas pu générer une grille valide.")
    end
end

function generateInstance(lignes::Int, colonnes::Int, n::Int, densite::Float64, nom_fichier::String)

    if (lignes * colonnes) % n != 0
        error("Erreur : la taille totale de la grille doit être un multiple de la taille de zone.")
    end

    sol_2d = cplexGenerate(lignes, colonnes, n)
    grille_finale = fill(-1, lignes, colonnes)

    for i in 1:lignes
        for j in 1:colonnes
            if rand() <= densite
                palissades = 0
                if i == 1 || sol_2d[i,j] != sol_2d[i-1,j] palissades += 1 end
                if i == lignes || sol_2d[i,j] != sol_2d[i+1,j] palissades += 1 end
                if j == 1 || sol_2d[i,j] != sol_2d[i,j-1] palissades += 1 end
                if j == colonnes || sol_2d[i,j] != sol_2d[i,j+1] palissades += 1 end
                
                grille_finale[i,j] = palissades
            end
        end
    end

    chemin = joinpath(@__DIR__, "..", "data", nom_fichier)
    open(chemin, "w") do f
        println(f, "$lignes,$colonnes,$n")
        for i in 1:lignes
            println(f, join(grille_finale[i, :], ","))
        end
    end

    println("In file generation.jl, in method generateInstance(), TODO: generate an instance")
    
end 

"""
Generate all the instances

Remark: a grid is generated only if the corresponding output file does not already exist
"""
function generateDataSet()

    # TODO
    println("In file generation.jl, in method generateDataSet(), TODO: generate an instance")
    
end



