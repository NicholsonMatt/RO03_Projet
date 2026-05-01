# This file contains functions related to reading, writing and displaying a Pearl puzzle grid and experimental results

using JuMP
using Plots
import GR

# Codes utilisés pour représenter le contenu des cases dans la matrice t
const EMPTY = 0   # case vide (pas de perle)
const BLACK = 1   # perle Noire  -> la boucle DOIT tourner ici
const WHITE = 2   # perle Blanche -> la boucle DOIT aller tout droit ici

"""
Read a Pearl instance from an input file.

- Argument:
inputFile: path of the input file

- File format
Chaque ligne du fichier représente une ligne de la grille.
Les cases sont séparées par des virgules.
Le contenu de chaque case peut être :
    ' '  (un espace) : case vide
    'N'              : perle Noire
    'B'              : perle Blanche

Exemple d'instance 4x4 (perle Noire en (1,1) et (4,4), perle Blanche en (1,3)) :

    N, ,B,
     , , ,
     , , ,
     , , ,N

- Prerequisites
La grille doit être carrée. La taille n est déduite du nombre de
cases sur la première ligne valide du fichier.

- Return
t : Matrix{Int} de taille n*n, où chaque case vaut
        EMPTY (=0), BLACK (=1) ou WHITE (=2).
"""
function readInputFile(inputFile::String)

    # Open the input file
    datafile = open(inputFile)
    data = readlines(datafile)
    close(datafile)

    # On filtre les lignes vides éventuelles en fin de fichier
    nonEmptyLines = filter(l -> length(strip(l)) > 0 || occursin(",", l), data)

    n = length(split(nonEmptyLines[1], ","))
    t = zeros(Int, n, n)

    lineNb = 1

    # For each line of the input file
    for line in nonEmptyLines

        lineSplit = split(line, ",")

        if size(lineSplit, 1) == n
            for colNb in 1:n

                cell = strip(lineSplit[colNb])

                if cell == "" || cell == " "
                    t[lineNb, colNb] = EMPTY
                elseif cell == "N" || cell == "n"
                    t[lineNb, colNb] = BLACK
                elseif cell == "B" || cell == "b"
                    t[lineNb, colNb] = WHITE
                else
                    error("readInputFile: caractère inconnu '$(cell)' à la ligne $lineNb, colonne $colNb. Attendu : ' ', 'N' ou 'B'.")
                end
            end

            lineNb += 1
        end
    end

    return t
end


"""
Display a Pearl grid represented by a 2-dimensional array.

Argument:
- t: array of size n*n with values in {EMPTY, BLACK, WHITE}

Convention d'affichage :
    '.'  pour une case vide
    '#'  pour une perle Noire (N)
    'O'  pour une perle Blanche (B)
"""
function displayGrid(t::Matrix{Int})

    n = size(t, 1)

    # Display the upper border of the grid
    println(" ", "-"^(2*n+1))

    for l in 1:n
        print("| ")
        for c in 1:n
            if t[l, c] == BLACK
                print("# ")
            elseif t[l, c] == WHITE
                print("O ")
            else
                print(". ")
            end
        end
        println("|")
    end

    println(" ", "-"^(2*n+1))
end


"""
Display a Pearl solution (grille + boucle) en ASCII.

Arguments
- t      : Matrix{Int} de l'instance (codage EMPTY=0, BLACK=1, WHITE=2)
- y_val  : valeurs de y[i, j]   (Matrix réelle, on seuille à 0.5)
- xH_val : valeurs de xH[i, j]  (Matrix réelle, taille n × (n-1))
- xV_val : valeurs de xV[i, j]  (Matrix réelle, taille (n-1) × n)

Convention d'affichage des cellules :
    'N'  : perle Noire
    'B'  : perle Blanche
    '+'  : case visitée par la boucle (sans perle)
    '.'  : case non visitée

Les arêtes utilisées sont dessinées en `---` (horizontal) et `|` (vertical).
"""
function displaySolution(t::Matrix{Int},
                         y_val::AbstractMatrix,
                         xH_val::AbstractMatrix,
                         xV_val::AbstractMatrix)

    n = size(t, 1)

    for i in 1:n
        # ----- Ligne des cellules + arêtes horizontales -----
        for j in 1:n
            if t[i, j] == BLACK
                print("N")
            elseif t[i, j] == WHITE
                print("B")
            elseif y_val[i, j] > 0.5
                print("+")
            else
                print(".")
            end

            if j < n
                if xH_val[i, j] > 0.5
                    print("---")
                else
                    print("   ")
                end
            end
        end
        println()

        # ----- Ligne des arêtes verticales (entre i et i+1) -----
        if i < n
            for j in 1:n
                if xV_val[i, j] > 0.5
                    print("|")
                else
                    print(" ")
                end
                if j < n
                    print("   ")
                end
            end
            println()
        end
    end
end


"""
Helper one-shot : résout une instance avec callback et affiche le résultat.
Gère proprement le cas infaisable.

Usage :
    solveAndDisplay(t)
"""
function solveAndDisplay(t::Matrix{Int}; useCallback::Bool = true)

    isFeas, m, dt = useCallback ? cplexSolveWithCallback(t) : cplexSolve(t)

    println("\nRéalisable : ", isFeas, "  | Temps : ", round(dt, digits=3), " s\n")

    if isFeas
        displaySolution(t,
                        JuMP.value.(m[:y]),
                        JuMP.value.(m[:xH]),
                        JuMP.value.(m[:xV]))
    else
        println("Aucune solution. L'instance est probablement infaisable",
                " (contraintes Pearl incompatibles).")
    end

    return isFeas, m, dt
end


"""
Save an instance in a text file (format readable by readInputFile).

Argument
- t: 2-dimensional array of size n*n with values in {EMPTY, BLACK, WHITE}
- outputFile: path of the output file
"""
function saveInstance(t::Matrix{Int}, outputFile::String)

    n = size(t, 1)

    writer = open(outputFile, "w")

    for l in 1:n
        for c in 1:n

            if t[l, c] == BLACK
                print(writer, "N")
            elseif t[l, c] == WHITE
                print(writer, "B")
            else
                print(writer, " ")
            end

            if c != n
                print(writer, ",")
            else
                println(writer, "")
            end
        end
    end

    close(writer)
end


"""
Write a solution in an output stream.

Pour le moment cette fonction n'écrit que la grille d'origine.
Quand les variables CPLEX du modèle (arêtes / coins / etc.) seront
fournies par l'architecte, on étendra cette fonction pour également
sérialiser la boucle trouvée.

Arguments
- fout: the output stream (usually an output file)
- t: 2-dimensional array of size n*n
"""
function writeSolution(fout::IOStream, t::Matrix{Int})

    println(fout, "t = [")
    n = size(t, 1)

    for l in 1:n
        print(fout, "[ ")
        for c in 1:n
            print(fout, string(t[l, c]) * " ")
        end

        endLine = "]"
        if l != n
            endLine *= ";"
        end
        println(fout, endLine)
    end

    println(fout, "]")
end


"""
Create a pdf file which contains a performance diagram associated to the results of the ../res folder
Display one curve for each subfolder of the ../res folder.

Arguments
- outputFile: path of the output file

Prerequisites:
- Each subfolder must contain text files
- Each text file correspond to the resolution of one instance
- Each text file contains a variable "solveTime" and a variable "isOptimal"
"""
function performanceDiagram(outputFile::String)

    resultFolder = "../res/"

    # Maximal number of files in a subfolder
    maxSize = 0

    # Number of subfolders
    subfolderCount = 0

    folderName = Array{String, 1}()

    # For each file in the result folder
    for file in readdir(resultFolder)

        path = resultFolder * file

        # If it is a subfolder
        if isdir(path)

            folderName = vcat(folderName, file)

            subfolderCount += 1
            folderSize = size(readdir(path), 1)

            if maxSize < folderSize
                maxSize = folderSize
            end
        end
    end

    # Array that will contain the resolution times (one line for each subfolder)
    results = Array{Float64}(undef, subfolderCount, maxSize)

    for i in 1:subfolderCount
        for j in 1:maxSize
            results[i, j] = Inf
        end
    end

    folderCount = 0
    maxSolveTime = 0

    # For each subfolder
    for file in readdir(resultFolder)

        path = resultFolder * file

        if isdir(path)

            folderCount += 1
            fileCount = 0

            # For each text file in the subfolder
            for resultFile in filter(x->occursin(".txt", x), readdir(path))

                fileCount += 1
                include(path * "/" * resultFile)

                if isOptimal
                    results[folderCount, fileCount] = solveTime

                    if solveTime > maxSolveTime
                        maxSolveTime = solveTime
                    end
                end
            end
        end
    end

    # Sort each row increasingly
    results = sort(results, dims=2)

    println("Max solve time: ", maxSolveTime)

    # For each line to plot
    for dim in 1: size(results, 1)

        x = Array{Float64, 1}()
        y = Array{Float64, 1}()

        # x coordinate of the previous inflexion point
        previousX = 0
        previousY = 0

        append!(x, previousX)
        append!(y, previousY)

        # Current position in the line
        currentId = 1

        # While the end of the line is not reached
        while currentId != size(results, 2) && results[dim, currentId] != Inf

            # Number of elements which have the value previousX
            identicalValues = 1

             # While the value is the same
            while results[dim, currentId] == previousX && currentId <= size(results, 2)
                currentId += 1
                identicalValues += 1
            end

            # Add the proper points
            append!(x, previousX)
            append!(y, currentId - 1)

            if results[dim, currentId] != Inf
                append!(x, results[dim, currentId])
                append!(y, currentId - 1)
            end

            previousX = results[dim, currentId]
            previousY = currentId - 1

        end

        append!(x, maxSolveTime)
        append!(y, currentId - 1)

        # If it is the first subfolder
        if dim == 1

            # Draw a new plot
            plot(x, y, label = folderName[dim], legend = :bottomright, xaxis = "Time (s)", yaxis = "Solved instances",linewidth=3)

        # Otherwise
        else
            # Add the new curve to the created plot
            savefig(plot!(x, y, label = folderName[dim], linewidth=3), outputFile)
        end
    end
end

"""
Create a latex file which contains an array with the results of the ../res folder.
Each subfolder of the ../res folder contains the results of a resolution method.

Arguments
- outputFile: path of the output file

Prerequisites:
- Each subfolder must contain text files
- Each text file correspond to the resolution of one instance
- Each text file contains a variable "solveTime" and a variable "isOptimal"
"""
function resultsArray(outputFile::String)

    resultFolder = "../res/"
    dataFolder = "../data/"

    # Maximal number of files in a subfolder
    maxSize = 0

    # Number of subfolders
    subfolderCount = 0

    # Open the latex output file
    fout = open(outputFile, "w")

    # Print the latex file output
    println(fout, raw"""\documentclass{article}

\usepackage[french]{babel}
\usepackage [utf8] {inputenc} % utf-8 / latin1
\usepackage{multicol}

\setlength{\hoffset}{-18pt}
\setlength{\oddsidemargin}{0pt} % Marge gauche sur pages impaires
\setlength{\evensidemargin}{9pt} % Marge gauche sur pages paires
\setlength{\marginparwidth}{54pt} % Largeur de note dans la marge
\setlength{\textwidth}{481pt} % Largeur de la zone de texte (17cm)
\setlength{\voffset}{-18pt} % Bon pour DOS
\setlength{\marginparsep}{7pt} % Séparation de la marge
\setlength{\topmargin}{0pt} % Pas de marge en haut
\setlength{\headheight}{13pt} % Haut de page
\setlength{\headsep}{10pt} % Entre le haut de page et le texte
\setlength{\footskip}{27pt} % Bas de page + séparation
\setlength{\textheight}{668pt} % Hauteur de la zone de texte (25cm)

\begin{document}""")

    header = raw"""
\begin{center}
\renewcommand{\arraystretch}{1.4}
 \begin{tabular}{l"""

    # Name of the subfolder of the result folder (i.e, the resolution methods used)
    folderName = Array{String, 1}()

    # List of all the instances solved by at least one resolution method
    solvedInstances = Array{String, 1}()

    # For each file in the result folder
    for file in readdir(resultFolder)

        path = resultFolder * file

        # If it is a subfolder
        if isdir(path)

            # Add its name to the folder list
            folderName = vcat(folderName, file)

            subfolderCount += 1
            folderSize = size(readdir(path), 1)

            # Add all its files in the solvedInstances array
            for file2 in filter(x->occursin(".txt", x), readdir(path))
                solvedInstances = vcat(solvedInstances, file2)
            end

            if maxSize < folderSize
                maxSize = folderSize
            end
        end
    end

    # Only keep one string for each instance solved
    unique(solvedInstances)

    # For each resolution method, add two columns in the array
    for folder in folderName
        header *= "rr"
    end

    header *= "}\n\t\\hline\n"

    # Create the header line which contains the methods name
    for folder in folderName
        header *= " & \\multicolumn{2}{c}{\\textbf{" * folder * "}}"
    end

    header *= "\\\\\n\\textbf{Instance} "

    # Create the second header line with the content of the result columns
    for folder in folderName
        header *= " & \\textbf{Temps (s)} & \\textbf{Optimal ?} "
    end

    header *= "\\\\\\hline\n"

    footer = raw"""\hline\end{tabular}
\end{center}

"""
    println(fout, header)

    # On each page an array will contain at most maxInstancePerPage lines with results
    maxInstancePerPage = 30
    id = 1

    # For each solved files
    for solvedInstance in solvedInstances

        # If we do not start a new array on a new page
        if rem(id, maxInstancePerPage) == 0
            println(fout, footer, "\\newpage")
            println(fout, header)
        end

        # Replace the potential underscores '_' in file names
        print(fout, replace(solvedInstance, "_" => "\\_"))

        # For each resolution method
        for method in folderName

            path = resultFolder * method * "/" * solvedInstance

            # If the instance has been solved by this method
            if isfile(path)

                include(path)

                println(fout, " & ", round(solveTime, digits=2), " & ")

                if isOptimal
                    println(fout, "\$\\times\$")
                end

            # If the instance has not been solved by this method
            else
                println(fout, " & - & - ")
            end
        end

        println(fout, "\\\\")

        id += 1
    end

    # Print the end of the latex file
    println(fout, footer)

    println(fout, "\\end{document}")

    close(fout)

end
