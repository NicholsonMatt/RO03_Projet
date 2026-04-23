# N'oublie pas d'importer le paquet !
using Plots 

include("io.jl")
include("resolution.jl")
include("generation.jl")

"""
Génère et ouvre une fenêtre graphique contenant la grille résolue.
"""
function afficher_picross_fenetre(donnees, grille)
    if grille === nothing
        println("Aucune solution à afficher.")
        return
    end
    labels_colonnes = [join(donnees[j+15], "\n") for j in 1:15]
    labels_lignes = [join(donnees[i], "   ") for i in 1:15]

    fenetre = heatmap(
        1:15, 1:15, grille,
        color = cgrad([:white, :black]),
        yflip = true,
        xticks = (1:15, labels_colonnes),
        yticks = (1:15, labels_lignes),
        xrotation = 0,
        tick_direction = :none,
        framestyle = :box,
        aspect_ratio = :equal,
        legend = :none,
        title = "Solution du Nonogramme (CPLEX)",
        size = (700, 700)
    )
    
    display(fenetre)
end

function main()
    chemin_fichier = joinpath(@__DIR__, "..", "data", "instanceText.txt")
    donnees = readInputFile(chemin_fichier)
    
    statut, temps, X = cplexSolve(donnees)
    displayGrid(donnees)
    if statut
        println("Problème résolu en ", round(temps, digits=4), " secondes.")
        displaySolution(donnees, X)
        afficher_picross_fenetre(donnees, X)
        
        println("\n'Entrée' pour fermer la fenêtre et quitter.")
        readline()
    else
        println("Pas trouvé de solution réalisable.")
    end
end

#main()


function main2()
    generateDataSet(10)
    resultsArray("testResultat")
end

main2()