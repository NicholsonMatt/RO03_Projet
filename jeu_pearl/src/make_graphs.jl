# Script d'analyse des résultats : tableau LaTeX + 2 graphiques.
#
# À lancer depuis le dossier ./src après avoir résolu un dataset :
#     julia make_graphs.jl
#
# Pré-requis :
#   - ../data/  contient les instances (typiquement instance_n{N}_{K}.txt)
#   - ../res/cplex_callback/  contient les résultats produits par
#     solveDataSetWithCallback() (ou ../res/cplex/ pour cplexSolve()).

include("io.jl")

using Plots
using Statistics
using Printf


"""
Lit un fichier résultat produit par solveDataSet* et renvoie
(solveTime::Float64, isOptimal::Bool).

Format attendu : deux lignes "solveTime = ..." et "isOptimal = ..."
(éventuellement précédées d'une matrice t = [...]).
"""
function readResultFile(path::String)
    solveTime = -1.0
    isOptimal = false

    for line in eachline(path)
        s = strip(line)
        if startswith(s, "solveTime")
            solveTime = parse(Float64, strip(split(s, "=")[2]))
        elseif startswith(s, "isOptimal")
            val = strip(split(s, "=")[2])
            isOptimal = (val == "true")
        end
    end

    return solveTime, isOptimal
end


"""
Trace une courbe "temps de résolution en fonction de la taille n".

Pour chaque taille n présente dans les noms de fichier
(`instance_n{N}_{K}.txt`), on agrège les temps des instances OPTIMALES
résolues et on trace la moyenne et le maximum.

Fonction sur-mesure : les profs n'en fournissent pas pour cet axe.

Arguments
- folder      : dossier de résultats (ex. "../res/cplex_callback")
- outputFile  : chemin de sortie de l'image (PNG, PDF, ...)
"""
function plot_pearl_performance(folder::String, outputFile::String)

    if !isdir(folder)
        println("Dossier inexistant : $folder")
        return
    end

    by_n = Dict{Int, Vector{Float64}}()

    for file in readdir(folder)
        (!occursin(".txt", file) || occursin("~", file)) && continue

        m = match(r"instance_n(\d+)_(\d+)\.txt", file)
        m === nothing && continue

        n = parse(Int, m.captures[1])
        path = joinpath(folder, file)

        solveTime, isOptimal = readResultFile(path)
        if isOptimal && solveTime >= 0
            arr = get!(by_n, n, Float64[])
            push!(arr, solveTime)
        end
    end

    if isempty(by_n)
        println("Aucun résultat optimal exploitable dans $folder")
        return
    end

    sizes = sort(collect(keys(by_n)))
    means = [mean(by_n[n])     for n in sizes]
    maxs  = [maximum(by_n[n])  for n in sizes]

    plt = plot(sizes, means;
               label      = "Temps moyen",
               marker     = :circle,
               linewidth  = 2,
               xlabel     = "Taille n de la grille",
               ylabel     = "Temps CPLEX (s)",
               title      = "Pearl — temps de résolution par taille",
               legend     = :topleft,
               yscale     = :log10)

    plot!(plt, sizes, maxs;
          label     = "Temps maximum",
          marker    = :square,
          linewidth = 2)

    savefig(plt, outputFile)
    println("Graphique sauvegardé : $outputFile")

    # Récap texte dans la console
    println("\nRécap (méthode = $(basename(folder))) :")
    println("   n  | nb opt | temps moyen | temps max")
    println("  ----+--------+-------------+----------")
    for n in sizes
        @printf("  %3d | %6d | %9.3f s | %7.3f s\n",
                n, length(by_n[n]), mean(by_n[n]), maximum(by_n[n]))
    end
end


"""
Génère le tableau LaTeX et les deux graphiques de performance.

Sorties dans ../res/ :
    - array.tex                   (tableau LaTeX, fonction des profs)
    - performance_diagram.png     (cumulative, fonction des profs)
    - performance_plot.png        (temps moyen/max par taille, sur-mesure)
"""
function make_all_graphs()
    resFolder = "../res/"

    if !isdir(resFolder)
        println("Dossier $resFolder inexistant. Lance d'abord solveDataSetWithCallback().")
        return
    end

    # 1) Tableau LaTeX récapitulatif (fonction des profs)
    println("\n=== 1. Tableau LaTeX (resultsArray) ===")
    try
        resultsArray(resFolder * "array.tex")
        println("Tableau écrit : ", resFolder, "array.tex")
    catch e
        println("Échec resultsArray : ", e)
    end

    # 2) Diagramme de performance cumulatif (fonction des profs)
    println("\n=== 2. Diagramme de performance cumulatif (performanceDiagram) ===")
    try
        performanceDiagram(resFolder * "performance_diagram.png")
        println("Diagramme écrit : ", resFolder, "performance_diagram.png")
    catch e
        println("Échec performanceDiagram : ", e)
    end

    # 3) Courbe temps vs taille n (fonction sur-mesure)
    println("\n=== 3. Temps de résolution par taille (plot_pearl_performance) ===")
    plot_pearl_performance(resFolder * "cplex_callback",
                           resFolder * "performance_plot.png")
end


make_all_graphs()
