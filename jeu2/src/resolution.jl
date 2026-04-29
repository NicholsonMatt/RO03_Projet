# This file contains methods to solve an instance (heuristically or with CPLEX)
using CPLEX
using MathOptInterface
using JuMP

include("generation.jl")

TOL = 0.00001


"""
Solve an instance with CPLEX
"""
#=
function cplexSolve(V::Matrix{Int}, n::Int64)

    # Create the model
    m = Model(CPLEX.Optimizer)

    # TODO
    println("In file resolution.jl, in method cplexSolve(), TODO: fix input and output, define the model")

    lignes, colonnes = size(V)
    nb_regions = div(lignes * colonnes, n)

    @variable(m, X[1:lignes, 1:colonnes, 1:nb_regions], Bin)

    for i in 1:lignes
        for j in 1:colonnes
            @constraint(m, sum(X[i,j,k] for k in 1:nb_regions) == 1)
        end
    end

    for k in 1:nb_regions
        @constraint(m, sum(X[i,j,k] for i in 1:lignes, j in 1:colonnes) == n)
    end

    for k in 1:nb_regions
        for i in 1:lignes
            for j in 1:colonnes
            
                voisins = VariableRef[]
                
                if i > 1
                    push!(voisins, X[i-1, j, k])
                end
                
                if i < lignes
                    push!(voisins, X[i+1, j, k])
                end
                
                if j > 1
                    push!(voisins, X[i, j-1, k])
                end
                
                if j < colonnes
                    push!(voisins, X[i, j+1, k])
                end

                if V[i,j] >= 0
                    @constraint(m, sum(voisins) - (4 - V[i,j]) <= 4 * (1 - X[i,j,k]))
                    @constraint(m, sum(voisins) - (4 - V[i,j]) >= -4 * (1 - X[i,j,k]))
                end
                
                @constraint(m, sum(voisins) >= X[i,j,k])
                
            end
        end
    end

    # Start a chronometer
    start = time()

    # Solve the model
    optimize!(m)

    # Return:
    # 1 - true if an optimum is found
    # 2 - the resolution time

    statut = (primal_status(m) == MathOptInterface.FEASIBLE_POINT)
    temps_total = time() - start
    
    if statut
        grille_finale = round.(Int, value.(X))
    else
        grille_finale = []
    end

    return statut, temps_total, grille_finale
    
end

=#



function cplexSolve(V::Matrix{Int}, n::Int64)
    m = Model(CPLEX.Optimizer)
    lignes, colonnes = size(V)
    nb_regions = div(lignes * colonnes, n)

    @variable(m, X[1:lignes, 1:colonnes, 1:nb_regions], Bin)
    
    # Variables de flot pour la connectivité
    @variable(m, R[1:lignes, 1:colonnes, 1:nb_regions], Bin) # 1 si c'est la racine
    @variable(m, F_h[1:lignes, 1:colonnes, 1:nb_regions] >= 0) # Flot vers le haut
    @variable(m, F_b[1:lignes, 1:colonnes, 1:nb_regions] >= 0) # Flot vers le bas
    @variable(m, F_g[1:lignes, 1:colonnes, 1:nb_regions] >= 0) # Flot vers la gauche
    @variable(m, F_d[1:lignes, 1:colonnes, 1:nb_regions] >= 0) # Flot vers la droite

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

                voisins = VariableRef[]
                if i > 1 push!(voisins, X[i-1, j, k]) end
                if i < lignes push!(voisins, X[i+1, j, k]) end
                if j > 1 push!(voisins, X[i, j-1, k]) end
                if j < colonnes push!(voisins, X[i, j+1, k]) end

                if V[i,j] >= 0
                    @constraint(m, sum(voisins) - (4 - V[i,j]) <= 4 * (1 - X[i,j,k]))
                    @constraint(m, sum(voisins) - (4 - V[i,j]) >= -4 * (1 - X[i,j,k]))
                end

                # Gestion des bords pour le flot
                if i == 1 @constraint(m, F_h[i,j,k] == 0) end
                if i == lignes @constraint(m, F_b[i,j,k] == 0) end
                if j == 1 @constraint(m, F_g[i,j,k] == 0) end
                if j == colonnes @constraint(m, F_d[i,j,k] == 0) end

                # Capacités du flot (ne passe que dans la région k)
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

    start = time()
    optimize!(m)
    temps_total = time() - start
    
    statut = (termination_status(m) == MathOptInterface.OPTIMAL)
    grille_finale = statut ? round.(Int, value.(X)) : zeros(Int, lignes, colonnes, nb_regions)

    return statut, temps_total, grille_finale
end


"""
Heuristically solve an instance
"""
function heuristicSolve()

    # TODO
    println("In file resolution.jl, in method heuristicSolve(), TODO: fix input and output, define the model")
    
end 

"""
Solve all the instances contained in "../data" through CPLEX and heuristics

The results are written in "../res/cplex" and "../res/heuristic"

Remark: If an instance has previously been solved (either by cplex or the heuristic) it will not be solved again
"""
function solveDataSet()

    dataFolder = "../data/"
    resFolder = "../res/"

    # Array which contains the name of the resolution methods
    resolutionMethod = ["cplex"]
    #resolutionMethod = ["cplex", "heuristique"]

    # Array which contains the result folder of each resolution method
    resolutionFolder = resFolder .* resolutionMethod

    # Create each result folder if it does not exist
    for folder in resolutionFolder
        if !isdir(folder)
            mkdir(folder)
        end
    end
            
    global isOptimal = false
    global solveTime = -1

    # For each instance
    # (for each file in folder dataFolder which ends by ".txt")
    for file in filter(x->occursin(".txt", x), readdir(dataFolder))  
        
        println("-- Resolution of ", file)
        readInputFile(dataFolder * file)

        # TODO
        println("In file resolution.jl, in method solveDataSet(), TODO: read value returned by readInputFile()")
        
        # For each resolution method
        for methodId in 1:size(resolutionMethod, 1)
            
            outputFile = resolutionFolder[methodId] * "/" * file

            # If the instance has not already been solved by this method
            if !isfile(outputFile)
                
                fout = open(outputFile, "w")  

                resolutionTime = -1
                isOptimal = false
                
                # If the method is cplex
                if resolutionMethod[methodId] == "cplex"
                    
                    # TODO 
                    println("In file resolution.jl, in method solveDataSet(), TODO: fix cplexSolve() arguments and returned values")
                    
                    # Solve it and get the results
                    isOptimal, resolutionTime = cplexSolve()
                    
                    # If a solution is found, write it
                    if isOptimal
                        # TODO
                        println("In file resolution.jl, in method solveDataSet(), TODO: write cplex solution in fout") 
                    end

                # If the method is one of the heuristics
                else
                    
                    isSolved = false

                    # Start a chronometer 
                    startingTime = time()
                    
                    # While the grid is not solved and less than 100 seconds are elapsed
                    while !isOptimal && resolutionTime < 100
                        
                        # TODO 
                        println("In file resolution.jl, in method solveDataSet(), TODO: fix heuristicSolve() arguments and returned values")
                        
                        # Solve it and get the results
                        isOptimal, resolutionTime = heuristicSolve()

                        # Stop the chronometer
                        resolutionTime = time() - startingTime
                        
                    end

                    # Write the solution (if any)
                    if isOptimal

                        # TODO
                        println("In file resolution.jl, in method solveDataSet(), TODO: write the heuristic solution in fout")
                        
                    end 
                end

                println(fout, "solveTime = ", resolutionTime) 
                println(fout, "isOptimal = ", isOptimal)
                
                # TODO
                println("In file resolution.jl, in method solveDataSet(), TODO: write the solution in fout") 
                close(fout)
            end


            # Display the results obtained with the method on the current instance
            include(outputFile)
            println(resolutionMethod[methodId], " optimal: ", isOptimal)
            println(resolutionMethod[methodId], " time: " * string(round(solveTime, sigdigits=2)) * "s\n")
        end         
    end 
end
