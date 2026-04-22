# This file contains methods to solve an instance (heuristically or with CPLEX)
using CPLEX
using MathOptInterface
using JuMP

include("generation.jl")

TOL = 0.00001

"""
Solve an instance with CPLEX
"""
function cplexSolve(data)

    # Create the model
    m = Model(CPLEX.Optimizer)

    # TODO
    println("In file resolution.jl, in method cplexSolve(), TODO: fix input and output, define the model")

    @variable(m, X[1:15, 1:15], Bin)

    Y_lignes = Vector{Vector{Vector{VariableRef}}}(undef, 15)

    for i in 1:15
        nb_blocs = length(data[i])
        Y_lignes[i] = Vector{Vector{VariableRef}}(undef, nb_blocs)
        
        for k in 1:nb_blocs
            Y_lignes[i][k] = @variable(m, [1:15], Bin)
            
            @constraint(m, sum(Y_lignes[i][k][p] for p in 1:(15 - data[i][k] + 1)) == 1)
            
            for p in (15 - data[i][k] + 2):15
                @constraint(m, Y_lignes[i][k][p] == 0)
            end
        end
        
        if nb_blocs > 1
            for k in 1:(nb_blocs - 1)
                @constraint(m, sum(p * Y_lignes[i][k+1][p] for p in 1:15) >= sum((p + data[i][k] + 1) * Y_lignes[i][k][p] for p in 1:15))
            end
        end
    end

    Y_colonnes = Vector{Vector{Vector{VariableRef}}}(undef, 15)

    for j in 1:15
        nb_blocs = length(data[j+15])
        Y_colonnes[j] = Vector{Vector{VariableRef}}(undef, nb_blocs)
        
        for k in 1:nb_blocs
            Y_colonnes[j][k] = @variable(m, [1:15], Bin)
            
            @constraint(m, sum(Y_colonnes[j][k][p] for p in 1:(15 - data[j+15][k] + 1)) == 1)
            
            for p in (15 - data[j+15][k] + 2):15
                @constraint(m, Y_colonnes[j][k][p] == 0)
            end
        end
        
        if nb_blocs > 1
            for k in 1:(nb_blocs - 1)
                @constraint(m, sum(p * Y_colonnes[j][k+1][p] for p in 1:15) >= sum((p + data[j+15][k] + 1) * Y_colonnes[j][k][p] for p in 1:15))
            end
        end
    end

    for i in 1:15
        for j in 1:15
            @constraint(m, X[i, j] == sum(Y_lignes[i][k][p] for k in 1:length(data[i]) for p in max(1, j - data[i][k] + 1):j))
            @constraint(m, X[i, j] == sum(Y_colonnes[j][k][p] for k in 1:length(data[j+15]) for p in max(1, i - data[j+15][k] + 1):i))
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