# This file contains methods to solve a Pearl instance with CPLEX using
# a lazy-constraint callback that eliminates subtours (ghost loops).

using JuMP
using CPLEX

include("io.jl")

TOL = 0.00001


"""
Solve a Pearl instance with CPLEX, augmented with a lazy callback that
forbids subtours (ghost loops).

Modélisation
------------
Identique à `cplexSolve` (resolution.jl) :
    y[i,j], xH[i,j], xV[i,j] ∈ {0, 1}
    + continuité de degré
    + cases avec perle dans la boucle (y == 1)
    + règles perle Noire (angle + tout droit après)
    + règles perle Blanche (tout droit + tourner avant/après)

Élimination des sous-tours via callback
---------------------------------------
À chaque solution entière candidate, on extrait la composante connexe S
contenant le premier sommet actif (BFS sur le graphe induit par les arêtes
actives). Si |S| < (nombre total de cases actives), c'est qu'il existe au
moins une autre composante : on a un sous-tour. On le coupe avec :

    sum( arêtes (u,v) avec u ∈ S et v ∈ S ) <= |S| - 1

Comme une boucle fermée sur S a exactement |S| arêtes internes, cette
contrainte invalide la cycle actuelle de S sans empêcher S de réapparaître
dans une boucle plus grande qui le contiendrait.

Argument
- t : Matrix{Int} (codage : EMPTY=0, BLACK=1, WHITE=2)

Return
- isFeasible : Bool
- m          : Model
- solveTime  : Float64
"""
function cplexSolveWithCallback(t::Matrix{Int})

    n = size(t, 1)

    # Création du modèle
    m = Model(CPLEX.Optimizer)

    # ------------------------------------------------------------------
    # 1) VARIABLES DE DÉCISION
    # ------------------------------------------------------------------
    @variable(m, y[1:n, 1:n], Bin)
    @variable(m, xH[1:n, 1:n-1], Bin)   # arêtes horizontales
    @variable(m, xV[1:n-1, 1:n], Bin)   # arêtes verticales

    get_H(i, j) = (1 <= i <= n && 1 <= j <= n - 1) ? xH[i, j] : zero(AffExpr)
    get_V(i, j) = (1 <= i <= n - 1 && 1 <= j <= n) ? xV[i, j] : zero(AffExpr)

    # ------------------------------------------------------------------
    # 2) CONTINUITÉ
    # ------------------------------------------------------------------
    for i in 1:n, j in 1:n
        @constraint(m,
            get_H(i, j - 1) + get_H(i, j) + get_V(i - 1, j) + get_V(i, j)
            == 2 * y[i, j]
        )
    end

    # ------------------------------------------------------------------
    # 3) PERLES : y[i,j] == 1 si t[i,j] != 0
    # ------------------------------------------------------------------
    for i in 1:n, j in 1:n
        if t[i, j] != 0
            @constraint(m, y[i, j] == 1)
        end
    end

    # ------------------------------------------------------------------
    # 4) PERLES BLANCHES (t[i,j] == 2)
    # ------------------------------------------------------------------
    for i in 1:n, j in 1:n
        if t[i, j] == 2
            @constraint(m, get_H(i, j - 1) == get_H(i, j))
            @constraint(m, get_V(i - 1, j) == get_V(i, j))
            @constraint(m, get_H(i, j - 2) + get_H(i, j + 1) + get_H(i, j) <= 2)
            @constraint(m, get_V(i - 2, j) + get_V(i + 1, j) + get_V(i, j) <= 2)
        end
    end

    # ------------------------------------------------------------------
    # 5) PERLES NOIRES (t[i,j] == 1)
    # ------------------------------------------------------------------
    for i in 1:n, j in 1:n
        if t[i, j] == 1
            @constraint(m, get_H(i, j - 1) + get_H(i, j) <= 1)
            @constraint(m, get_V(i - 1, j) + get_V(i, j) <= 1)
            @constraint(m, get_H(i, j)     <= get_H(i, j + 1))
            @constraint(m, get_H(i, j - 1) <= get_H(i, j - 2))
            @constraint(m, get_V(i, j)     <= get_V(i + 1, j))
            @constraint(m, get_V(i - 1, j) <= get_V(i - 2, j))
        end
    end

    # Pearl est un problème de faisabilité
    @objective(m, Max, 0)


    # ==================================================================
    # CALLBACK : élimination des sous-tours
    # ==================================================================
    function pearl_callback(cb_data::CPLEX.CallbackContext, context_id::Clong)

        # On ne traite que les solutions entières candidates
        if !isIntegerPoint(cb_data, context_id)
            return
        end

        CPLEX.load_callback_variable_primal(cb_data, context_id)

        # ---- A. Récupération des valeurs (seuil 0.5) ----
        y_val  = callback_value.(cb_data, y)
        xH_val = callback_value.(cb_data, xH)
        xV_val = callback_value.(cb_data, xV)

        # ---- B. Cases actives + point de départ ----
        active_cells = Tuple{Int,Int}[]
        for i in 1:n, j in 1:n
            if y_val[i, j] > 0.5
                push!(active_cells, (i, j))
            end
        end
        total_active = length(active_cells)

        if total_active == 0
            return  # rien à faire, modèle vide (ne devrait pas arriver avec des perles)
        end

        start_node = active_cells[1]

        # ---- C. BFS dans le graphe induit par les arêtes actives ----
        S = Set{Tuple{Int,Int}}()
        push!(S, start_node)
        queue = Tuple{Int,Int}[start_node]

        while !isempty(queue)
            (i, j) = popfirst!(queue)

            # Voisin droite (i, j+1) via xH[i, j]
            if j <= n - 1 && xH_val[i, j] > 0.5
                nxt = (i, j + 1)
                if !(nxt in S)
                    push!(S, nxt)
                    push!(queue, nxt)
                end
            end
            # Voisin gauche (i, j-1) via xH[i, j-1]
            if j >= 2 && xH_val[i, j - 1] > 0.5
                nxt = (i, j - 1)
                if !(nxt in S)
                    push!(S, nxt)
                    push!(queue, nxt)
                end
            end
            # Voisin bas (i+1, j) via xV[i, j]
            if i <= n - 1 && xV_val[i, j] > 0.5
                nxt = (i + 1, j)
                if !(nxt in S)
                    push!(S, nxt)
                    push!(queue, nxt)
                end
            end
            # Voisin haut (i-1, j) via xV[i-1, j]
            if i >= 2 && xV_val[i - 1, j] > 0.5
                nxt = (i - 1, j)
                if !(nxt in S)
                    push!(S, nxt)
                    push!(queue, nxt)
                end
            end
        end

        # ---- D. Détection de sous-tour & coupe ----
        if length(S) < total_active

            println("Callback : sous-tour détecté de taille ", length(S),
                    " (sur ", total_active, " cases actives). Ajout d'une lazy constraint.")

            # Construit la somme des arêtes (u,v) avec u, v ∈ S
            expr = AffExpr(0)

            # Arêtes horizontales : xH[i, j] relie (i, j) et (i, j+1)
            for i in 1:n, j in 1:n-1
                if ((i, j) in S) && ((i, j + 1) in S)
                    add_to_expression!(expr, xH[i, j])
                end
            end

            # Arêtes verticales : xV[i, j] relie (i, j) et (i+1, j)
            for i in 1:n-1, j in 1:n
                if ((i, j) in S) && ((i + 1, j) in S)
                    add_to_expression!(expr, xV[i, j])
                end
            end

            cstr = @build_constraint(expr <= length(S) - 1)
            MOI.submit(m, MOI.LazyConstraint(cb_data), cstr)
        end
    end

    # ------------------------------------------------------------------
    # 6) CONFIGURATION DU SOLVEUR
    # ------------------------------------------------------------------
    # Obligatoire : un seul thread quand on utilise les callbacks CPLEX
    MOI.set(m, MOI.NumberOfThreads(), 1)
    MOI.set(m, CPLEX.CallbackFunction(), pearl_callback)

    # Limite de temps : 60 s par instance (anti-explosion combinatoire)
    MOI.set(m, MOI.TimeLimitSec(), 60.0)

    # ------------------------------------------------------------------
    # 7) RÉSOLUTION
    # ------------------------------------------------------------------
    start = time()
    optimize!(m)

    isFeasible = primal_status(m) == MOI.FEASIBLE_POINT
    return isFeasible, m, time() - start
end


"""
Solve all the instances of "../data" with cplexSolveWithCallback.
Results are written in "../res/cplex_callback".
"""
function solveDataSetWithCallback()

    dataFolder = "../data/"
    resFolder  = "../res/"

    resolutionFolder = resFolder * "cplex_callback"

    if !isdir(resolutionFolder)
        mkpath(resolutionFolder)
    end

    global isOptimal = false
    global solveTime = -1

    for file in filter(x->occursin(".txt", x) && !occursin(r"~$", x), readdir(dataFolder))

        println("-- Resolution of ", file)
        t = readInputFile(dataFolder * file)
        displayGrid(t)

        outputFile = resolutionFolder * "/" * file

        fout = open(outputFile, "w")

        resolutionTime = -1
        isOptimal = false

        isOptimal, _, resolutionTime = cplexSolveWithCallback(t)

        if isOptimal
            writeSolution(fout, t)
        end

        println(fout, "solveTime = ", resolutionTime)
        println(fout, "isOptimal = ", isOptimal)
        close(fout)

        include(outputFile)
        println("optimal: ", isOptimal)
        println("time: " * string(round(solveTime, sigdigits=2)) * "s\n")
    end
end


"""
Helper utilisé par les callbacks pour déterminer si CPLEX a appelé le
callback à cause d'une solution entière (et non pas d'une simple
relaxation). Repris de l'exemple sudoku1.0.
"""
function isIntegerPoint(cb_data::CPLEX.CallbackContext, context_id::Clong)

    if context_id != CPX_CALLBACKCONTEXT_CANDIDATE
        return false
    end

    ispoint_p = Ref{Cint}()
    ret = CPXcallbackcandidateispoint(cb_data, ispoint_p)

    if ret != 0 || ispoint_p[] == 0
        return false
    else
        return true
    end
end
