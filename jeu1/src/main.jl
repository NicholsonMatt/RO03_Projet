# N'oublie pas d'importer le paquet !
using Plots 

include("io.jl")
include("resolution.jl")

"""
Génère et ouvre une fenêtre graphique contenant la grille résolue.
"""
function afficher_picross_fenetre(donnees, grille)
    if grille === nothing
        println("Aucune solution à afficher.")
        return
    end

    # Préparation des étiquettes (les indices du jeu)
    # On utilise \n pour que les indices des colonnes s'écrivent à la verticale
    labels_colonnes = [join(donnees[j+15], "\n") for j in 1:15]
    labels_lignes = [join(donnees[i], "   ") for i in 1:15]

    # Création du graphique avec une "heatmap" (carte de chaleur)
    fenetre = heatmap(
        1:15, 1:15, grille,
        color = cgrad([:white, :black]),  # 0 = Blanc, 1 = Noir
        yflip = true,                     # Pour mettre la ligne 1 en haut (comme une matrice)
        xticks = (1:15, labels_colonnes), # Ajout des indices en haut
        yticks = (1:15, labels_lignes),   # Ajout des indices sur le côté
        xrotation = 0,
        tick_direction = :none,
        framestyle = :box,
        aspect_ratio = :equal,            # Pour forcer des cases parfaitement carrées
        legend = :none,
        title = "Solution du Nonogramme (CPLEX)",
        size = (700, 700)                 # Taille de la fenêtre en pixels
    )
    
    # On affiche la fenêtre
    display(fenetre)
end

function main()
    chemin_fichier = joinpath(@__DIR__, "..", "data", "instanceText.txt")
    donnees = readInputFile(chemin_fichier)
    
    println("🔍 Lancement de CPLEX... Veuillez patienter.")
    statut, temps, X = cplexSolve(donnees)

    if statut
        println("✅ Succès ! Problème résolu en ", round(temps, digits=4), " secondes.")
        println("🖼️  Génération de la fenêtre graphique en cours...")
        
        # Appel de la nouvelle fonction d'affichage
        afficher_picross_fenetre(donnees, X)
        
        # Très important : met le script en pause pour éviter que 
        # la fenêtre graphique ne se ferme instantanément.
        println("\n👉 Appuyez sur la touche 'Entrée' dans ce terminal pour fermer la fenêtre et quitter.")
        readline()
    else
        println("❌ CPLEX n'a pas trouvé de solution réalisable.")
    end
end

main()