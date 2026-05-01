# Script de test global pour le projet Pearl.
#
# À lancer depuis le dossier ./src :
#     julia main_test.jl
#
# ou, depuis une session Julia déjà ouverte :
#     include("main_test.jl")
#
# NB : `resolution.jl`, `resolutionWithCallback.jl` et `generation.jl`
# font chacun leur propre `include("io.jl")` ; Julia émettra quelques
# avertissements de redéfinition de méthodes lors des inclusions
# suivantes — c'est inoffensif.

include("io.jl")
include("resolution.jl")
include("resolutionWithCallback.jl")
include("generation.jl")

using JuMP


"""
Lance les deux tests demandés :
    1. Résolution de l'instance manuelle 4×4 (../data/instanceTest.txt)
    2. Génération + résolution d'une instance 8×8
Toutes deux passent par cplexSolveWithCallback (lazy constraints).
"""
function run_tests()

    # ==================================================================
    # TEST 1 — Instance manuelle 4×4
    # ==================================================================
    println("\n--- TEST 1 : Résolution de la grille 4x4 manuelle ---\n")

    t1 = readInputFile("../data/instanceTest.txt")
    println("Instance lue :")
    displayGrid(t1)

    println("\nRésolution avec cplexSolveWithCallback...\n")
    isFeas1, m1, time1 = cplexSolveWithCallback(t1)

    println("\n  Réalisable : ", isFeas1)
    println("  Temps      : ", round(time1, digits=3), " s\n")

    if isFeas1
        y_val  = JuMP.value.(m1[:y])
        xH_val = JuMP.value.(m1[:xH])
        xV_val = JuMP.value.(m1[:xV])

        println("Solution :")
        displaySolution(t1, y_val, xH_val, xV_val)
    else
        println("Aucune solution réalisable trouvée.")
    end


    # ==================================================================
    # TEST 2 — Génération + résolution d'une instance 8×8
    # ==================================================================
    println("\n\n--- TEST 2 : Génération et résolution d'une grille 8x8 ---\n")

    t2 = generateInstance(8)
    println("Instance générée :")
    displayGrid(t2)

    println("\nRésolution avec cplexSolveWithCallback...\n")
    isFeas2, m2, time2 = cplexSolveWithCallback(t2)

    println("\n  Réalisable : ", isFeas2)
    println("  Temps      : ", round(time2, digits=3), " s\n")

    if isFeas2
        y_val2  = JuMP.value.(m2[:y])
        xH_val2 = JuMP.value.(m2[:xH])
        xV_val2 = JuMP.value.(m2[:xV])

        println("Solution :")
        displaySolution(t2, y_val2, xH_val2, xV_val2)
    else
        println("Aucune solution réalisable trouvée.")
    end
end


run_tests()
