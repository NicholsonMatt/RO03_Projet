# This file contains methods to solve a Pearl instance (heuristically or with CPLEX)
using JuMP
using CPLEX

include("io.jl")

TOL = 0.00001


"""
Solve a Pearl instance with CPLEX.

Modélisation
============
Variables de décision (toutes binaires) :
    y[i, j]   : 1 si la boucle passe par la case (i, j)
    xH[i, j]  : 1 si l'arête horizontale entre (i, j) et (i, j+1) est utilisée   (j ∈ 1..n-1)
    xV[i, j]  : 1 si l'arête verticale   entre (i, j) et (i+1, j) est utilisée   (i ∈ 1..n-1)

Helpers (closures) :
    get_H(i, j) : xH[i, j] si dans les bornes, sinon 0 (AffExpr)
    get_V(i, j) : xV[i, j] si dans les bornes, sinon 0 (AffExpr)

Contraintes
-----------
1) Continuité  : ∀(i, j),  H(i,j-1) + H(i,j) + V(i-1,j) + V(i,j) == 2 * y[i,j]
2) Perles      : si t[i,j] != 0,  y[i,j] == 1
3) Perle Blanche (t[i,j] == 2)
        Passage tout droit  : H(i,j-1) == H(i,j) ;  V(i-1,j) == V(i,j)
        Tourner avant/après : H(i,j-2) + H(i,j+1) + H(i,j) <= 2
                              V(i-2,j) + V(i+1,j) + V(i,j) <= 2
4) Perle Noire (t[i,j] == 1)
        Angle obligatoire   : H(i,j-1) + H(i,j) <= 1 ;  V(i-1,j) + V(i,j) <= 1
        Tout droit après    : H(i,j)   <= H(i,j+1)
                              H(i,j-1) <= H(i,j-2)
                              V(i,j)   <= V(i+1,j)
                              V(i-1,j) <= V(i-2,j)

Pearl est un problème de faisabilité ; on garde un objectif factice
@objective(m, Max, 0).

Argument
- t : Matrix{Int} de taille n*n, valeurs ∈ {EMPTY=0, BLACK=1, WHITE=2}

Return
- isFeasible : Bool, true si CPLEX trouve une solution réalisable
- m          : Model JuMP/CPLEX (variables accessibles via m[:y], m[:xH], m[:xV])
- solveTime  : Float64, durée totale de résolution en secondes
"""
function cplexSolve(t::Matrix{Int})

    n = size(t, 1)

    # Création du modèle
    m = Model(CPLEX.Optimizer)

    # ------------------------------------------------------------------
    # 1) VARIABLES DE DÉCISION
    # ------------------------------------------------------------------
    @variable(m, y[1:n, 1:n], Bin)
    @variable(m, xH[1:n, 1:n-1], Bin)   # arêtes horizontales
    @variable(m, xV[1:n-1, 1:n], Bin)   # arêtes verticales

    # Helpers : renvoient la variable d'arête si elle existe, sinon 0
    get_H(i, j) = (1 <= i <= n && 1 <= j <= n - 1) ? xH[i, j] : zero(AffExpr)
    get_V(i, j) = (1 <= i <= n - 1 && 1 <= j <= n) ? xV[i, j] : zero(AffExpr)

    # ------------------------------------------------------------------
    # 2) CONTINUITÉ : sum(arêtes incidentes en (i,j)) == 2 * y[i,j]
    # ------------------------------------------------------------------
    for i in 1:n, j in 1:n
        @constraint(m,
            get_H(i, j - 1) + get_H(i, j) + get_V(i - 1, j) + get_V(i, j)
            == 2 * y[i, j]
        )
    end

    # ------------------------------------------------------------------
    # 3) PERLES : toute case avec une perle est sur la boucle
    # ------------------------------------------------------------------
    for i in 1:n, j in 1:n
        if t[i, j] != 0
            @constraint(m, y[i, j] == 1)
        end
    end

    # ------------------------------------------------------------------
    # 4) PERLES BLANCHES (t[i,j] == 2) : passage tout droit + tourner avant/après
    # ------------------------------------------------------------------
    for i in 1:n, j in 1:n
        if t[i, j] == 2
            # Passage tout droit
            @constraint(m, get_H(i, j - 1) == get_H(i, j))
            @constraint(m, get_V(i - 1, j) == get_V(i, j))

            # Si la traversée est horizontale (H(i,j) = 1), il faut tourner
            # en (i, j-1) ou en (i, j+1) :
            @constraint(m, get_H(i, j - 2) + get_H(i, j + 1) + get_H(i, j) <= 2)

            # Idem pour la traversée verticale (V(i,j) = 1) :
            @constraint(m, get_V(i - 2, j) + get_V(i + 1, j) + get_V(i, j) <= 2)
        end
    end

    # ------------------------------------------------------------------
    # 5) PERLES NOIRES (t[i,j] == 1) : angle obligatoire + tout droit après
    # ------------------------------------------------------------------
    for i in 1:n, j in 1:n
        if t[i, j] == 1
            # Angle obligatoire (interdit d'aller tout droit)
            @constraint(m, get_H(i, j - 1) + get_H(i, j) <= 1)
            @constraint(m, get_V(i - 1, j) + get_V(i, j) <= 1)

            # Tout droit juste après la perle, dans chaque direction
            @constraint(m, get_H(i, j)     <= get_H(i, j + 1))   # sortie droite
            @constraint(m, get_H(i, j - 1) <= get_H(i, j - 2))   # sortie gauche
            @constraint(m, get_V(i, j)     <= get_V(i + 1, j))   # sortie bas
            @constraint(m, get_V(i - 1, j) <= get_V(i - 2, j))   # sortie haut
        end
    end

    # ------------------------------------------------------------------
    # 6) OBJECTIF — Pearl est un problème de faisabilité
    # ------------------------------------------------------------------
    @objective(m, Max, 0)

    # ------------------------------------------------------------------
    # 7) RÉSOLUTION
    # ------------------------------------------------------------------
    start = time()
    optimize!(m)

    isFeasible = primal_status(m) == MOI.FEASIBLE_POINT

    return isFeasible, m, time() - start
end


"""
Heuristically solve a Pearl instance.

Coquille vide : la stratégie heuristique sera décrite par l'architecte.
"""
function heuristicSolve(t::Matrix{Int})

    # TODO (architecte) : définir une heuristique (constructive, locale,
    # gloutonne, ...) pour Pearl.
    println("In file resolution.jl, in method heuristicSolve(), TODO: define the heuristic")

    return false, t
end


"""
Solve all the instances contained in "../data" through CPLEX (and possibly heuristics).

The results are written in "../res/cplex" (and "../res/heuristique" once enabled).

Remark: If an instance has previously been solved by a method,
        it will not be solved again by that method.
"""
function solveDataSet()

    dataFolder = "../data/"
    resFolder  = "../res/"

    # Pour l'instant, seul CPLEX est branché.
    resolutionMethod = ["cplex"]
    # resolutionMethod = ["cplex", "heuristique"]

    resolutionFolder = resFolder .* resolutionMethod

    # Création des sous-dossiers de résultats si absents
    for folder in resolutionFolder
        if !isdir(folder)
            mkpath(folder)
        end
    end

    global isOptimal = false
    global solveTime = -1

    # Pour chaque instance
    for file in filter(x->occursin(".txt", x) && !occursin("~", x), readdir(dataFolder))

        println("-- Resolution of ", file)
        t = readInputFile(dataFolder * file)
        displayGrid(t)

        for methodId in 1:size(resolutionMethod, 1)

            outputFile = resolutionFolder[methodId] * "/" * file

            if !isfile(outputFile)

                fout = open(outputFile, "w")

                resolutionTime = -1
                isOptimal = false

                if resolutionMethod[methodId] == "cplex"

                    isOptimal, _, resolutionTime = cplexSolve(t)

                    if isOptimal
                        writeSolution(fout, t)
                    end

                else
                    # Branche heuristique : à activer plus tard
                    startingTime = time()
                    while !isOptimal && resolutionTime < 100
                        isOptimal, _ = heuristicSolve(t)
                        resolutionTime = time() - startingTime
                    end

                    if isOptimal
                        writeSolution(fout, t)
                    end
                end

                println(fout, "solveTime = ", resolutionTime)
                println(fout, "isOptimal = ", isOptimal)
                close(fout)
            end

            # Affichage des résultats
            include(outputFile)
            println(resolutionMethod[methodId], " optimal: ", isOptimal)
            println(resolutionMethod[methodId], " time: " * string(round(solveTime, sigdigits=2)) * "s\n")
        end
    end
end
