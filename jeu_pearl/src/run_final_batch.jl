# Script d'orchestration FINAL pour produire les livrables du rapport.
#
# Pipeline complet, exécuté à partir de zéro :
#   1. Génère 5 instances pour chaque taille n ∈ {4, 6, 8, 10, 12}.
#   2. Résout toutes les instances avec cplexSolveWithCallback (lazy
#      constraints + limite de temps 60 s).
#   3. Produit le tableau LaTeX, le diagramme cumulatif et la courbe
#      "temps par taille" dans ../res/.
#
# À lancer depuis ./src :
#     julia run_final_batch.jl
#
# Pré-requis : env vars CPLEX déjà positionnées (~/.bashrc) et paquets
# Julia déjà installés.

println("=== Pipeline final Pearl ===")
println("Étape 0 : chargement des dépendances\n")

using JuMP
using CPLEX
using Plots
using Statistics
using Printf


# ----------------------------------------------------------------------
# Étape 1 : génération du jeu de données
# ----------------------------------------------------------------------
println("=== Étape 1 : génération du dataset ===\n")

include("generation.jl")

generateDataSet(5, [4, 6, 8, 10, 12])

println()


# ----------------------------------------------------------------------
# Étape 2 : résolution avec callback (lazy constraints + 60 s timeout)
# ----------------------------------------------------------------------
println("=== Étape 2 : résolution CPLEX (avec callback + TimeLimit 60 s) ===\n")

include("resolutionWithCallback.jl")

solveDataSetWithCallback()

println()


# ----------------------------------------------------------------------
# Étape 3 : tableau LaTeX + graphiques de performance
# ----------------------------------------------------------------------
println("=== Étape 3 : génération des graphiques et du tableau LaTeX ===\n")

include("make_graphs.jl")

println("\n=== Pipeline terminé ===")
println("Livrables disponibles dans ../res/ :")
println("  - array.tex                  (tableau LaTeX)")
println("  - performance_diagram.png    (diagramme cumulatif)")
println("  - performance_plot.png       (temps par taille n)")
