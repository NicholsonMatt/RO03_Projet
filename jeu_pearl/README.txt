Projet Pearl — résolution par CPLEX
====================================

Pour utiliser ce programme, se placer dans le répertoire ./src

I - Génération d'un jeu de données (à brancher)
    julia
    include("generation.jl")
    generateDataSet()

II - Résolution du jeu de données par CPLEX
    julia
    include("resolution.jl")
    solveDataSet()

III - Résolution avec callback (lazy constraints)
    julia
    include("resolutionWithCallback.jl")
    solveDataSetWithCallback()

IV - Présentation des résultats sous forme de tableau LaTeX
    julia
    include("io.jl")
    resultsArray("../res/array.tex")


Format des fichiers d'instance
------------------------------
Une instance Pearl est un fichier texte stocké dans ./data/.
Chaque ligne du fichier correspond à une ligne de la grille,
les cases sont séparées par des virgules. Le contenu d'une case est :

    ' '  (un espace) : case vide
    'N'              : perle Noire
    'B'              : perle Blanche

Exemple d'instance 4x4 (./data/instanceTest.txt) :

    N, ,B,
     , , ,
     , , ,
     , , ,N

La taille n de la grille est déduite du nombre de cases sur la
première ligne. La grille est carrée.
