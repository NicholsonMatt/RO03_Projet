# This file contains methods to generate a data set of Pearl instances.
#
# Stratégie (imposée par le sujet pour garantir la faisabilité) :
#   A. Boucle initiale = périmètre de la grille.
#   B. Mutations aléatoires : on "pousse" un sous-segment droit de la
#      boucle d'une rangée vers l'intérieur (détour en U).
#   C. Placement des perles le long de la boucle obtenue.
#   D. On retourne la matrice t et on "oublie" le tracé.
#
# Représentation interne de la boucle :
#   inLoopY[i, j]        : la case (i, j) est sur la boucle
#   inLoopH[i, j]        : l'arête horizontale entre (i, j) et (i, j+1) est utilisée   (j ∈ 1..n-1)
#   inLoopV[i, j]        : l'arête verticale   entre (i, j) et (i+1, j) est utilisée   (i ∈ 1..n-1)

include("io.jl")

import Random


"""
Initialise la boucle au périmètre de la grille n × n.
Renvoie (inLoopY, inLoopH, inLoopV).
"""
function perimeterLoop(n::Int)
    inLoopY = falses(n, n)
    inLoopH = falses(n, n - 1)
    inLoopV = falses(n - 1, n)

    # Cases du périmètre
    for j in 1:n
        inLoopY[1, j] = true
        inLoopY[n, j] = true
    end
    for i in 1:n
        inLoopY[i, 1] = true
        inLoopY[i, n] = true
    end

    # Arêtes horizontales (haut + bas)
    for j in 1:n-1
        inLoopH[1, j] = true
        inLoopH[n, j] = true
    end

    # Arêtes verticales (gauche + droite)
    for i in 1:n-1
        inLoopV[i, 1] = true
        inLoopV[i, n] = true
    end

    return inLoopY, inLoopH, inLoopV
end


"""
Tente une mutation aléatoire de la boucle ("push" d'un sous-segment droit).

Algorithme :
    1. Tirer une orientation (horizontal / vertical).
    2. Tirer une rangée / colonne et y trouver un run maximal d'arêtes actives.
    3. Tirer un sous-intervalle d'arêtes [e1, e2] dans ce run.
    4. Tirer une direction perpendiculaire (+1 / -1).
    5. Vérifier que toutes les cases visées dans la rangée parallèle voisine
       sont HORS de la boucle courante. Si oui, appliquer la mutation.

Renvoie true si une mutation a été appliquée.

Invariant maintenu : la boucle reste un cycle simple fermé (cf. rapport ci-dessous).
"""
function tryMutate!(inLoopY::BitMatrix,
                    inLoopH::BitMatrix,
                    inLoopV::BitMatrix,
                    n::Int)

    max_attempts = 50
    for _ in 1:max_attempts

        is_horizontal = rand(Bool)

        if is_horizontal
            # ----- Pousser un sous-segment HORIZONTAL verticalement -----
            i = rand(1:n)
            edges_in_row = [j for j in 1:n-1 if inLoopH[i, j]]
            isempty(edges_in_row) && continue

            j_e = rand(edges_in_row)

            # Run maximal contenant j_e
            jS = j_e
            while jS > 1 && inLoopH[i, jS - 1]
                jS -= 1
            end
            jE = j_e
            while jE < n - 1 && inLoopH[i, jE + 1]
                jE += 1
            end

            # Sous-intervalle d'arêtes [e1, e2] dans [jS, jE]
            e1 = rand(jS:jE)
            e2 = rand(e1:jE)

            # Cellules concernées : (i, e1), ..., (i, e2+1)
            cS = e1
            cE = e2 + 1

            # Direction perpendiculaire
            di = rand((-1, 1))
            i_new = i + di
            (i_new < 1 || i_new > n) && continue

            # Toutes les cases (i_new, cS..cE) doivent être hors boucle
            obstructed = false
            for j in cS:cE
                if inLoopY[i_new, j]
                    obstructed = true
                    break
                end
            end
            obstructed && continue

            # ---- Application ----
            i_min = min(i, i_new)

            # Suppression du sous-segment horizontal en ligne i,
            # et ajout du sous-segment horizontal en ligne i_new
            for e in e1:e2
                inLoopH[i, e]     = false
                inLoopH[i_new, e] = true
            end
            # Ajout des deux arêtes verticales aux extrémités
            inLoopV[i_min, cS] = true
            inLoopV[i_min, cE] = true
            # Mise à jour des cases : intermédiaires en ligne i sortent ;
            # toutes les cases en ligne i_new entrent.
            for j in (cS + 1):(cE - 1)
                inLoopY[i, j] = false
            end
            for j in cS:cE
                inLoopY[i_new, j] = true
            end

            return true

        else
            # ----- Pousser un sous-segment VERTICAL horizontalement -----
            j = rand(1:n)
            edges_in_col = [i for i in 1:n-1 if inLoopV[i, j]]
            isempty(edges_in_col) && continue

            i_e = rand(edges_in_col)

            iS = i_e
            while iS > 1 && inLoopV[iS - 1, j]
                iS -= 1
            end
            iE = i_e
            while iE < n - 1 && inLoopV[iE + 1, j]
                iE += 1
            end

            e1 = rand(iS:iE)
            e2 = rand(e1:iE)

            cS = e1
            cE = e2 + 1

            dj = rand((-1, 1))
            j_new = j + dj
            (j_new < 1 || j_new > n) && continue

            obstructed = false
            for i in cS:cE
                if inLoopY[i, j_new]
                    obstructed = true
                    break
                end
            end
            obstructed && continue

            j_min = min(j, j_new)

            for e in e1:e2
                inLoopV[e, j]     = false
                inLoopV[e, j_new] = true
            end
            inLoopH[cS, j_min] = true
            inLoopH[cE, j_min] = true
            for i in (cS + 1):(cE - 1)
                inLoopY[i, j] = false
            end
            for i in cS:cE
                inLoopY[i, j_new] = true
            end

            return true
        end
    end

    return false
end


"""
Parcourt la boucle dans l'ordre cyclique, en partant d'une case quelconque.
Renvoie le tableau ordonné des cases visitées (taille = longueur de la boucle).
"""
function walkLoop(inLoopY::BitMatrix,
                  inLoopH::BitMatrix,
                  inLoopV::BitMatrix,
                  n::Int)

    start = nothing
    for i in 1:n, j in 1:n
        if inLoopY[i, j]
            start = (i, j)
            break
        end
    end
    start === nothing && return Tuple{Int,Int}[]

    cells = Tuple{Int,Int}[start]
    prev  = (-1, -1)
    cur   = start

    while true
        i, j = cur
        nxt = nothing

        if j < n     && inLoopH[i, j]     && (i, j + 1) != prev
            nxt = (i, j + 1)
        elseif j > 1 && inLoopH[i, j - 1] && (i, j - 1) != prev
            nxt = (i, j - 1)
        elseif i < n && inLoopV[i, j]     && (i + 1, j) != prev
            nxt = (i + 1, j)
        elseif i > 1 && inLoopV[i - 1, j] && (i - 1, j) != prev
            nxt = (i - 1, j)
        end

        (nxt === nothing || nxt == start) && break

        push!(cells, nxt)
        prev = cur
        cur  = nxt
    end

    return cells
end


"""
Pour chaque cellule de la boucle (dans l'ordre), indique si c'est un coin.
Un coin est une cellule dont la direction d'entrée diffère de la direction de sortie.
"""
function classifyCorners(cells::Vector{Tuple{Int,Int}})
    L = length(cells)
    isCorner = falses(L)

    for k in 1:L
        prev_c = cells[mod1(k - 1, L)]
        cur_c  = cells[k]
        next_c = cells[mod1(k + 1, L)]

        dIn  = (cur_c[1]  - prev_c[1], cur_c[2]  - prev_c[2])
        dOut = (next_c[1] - cur_c[1],  next_c[2] - cur_c[2])

        isCorner[k] = (dIn != dOut)
    end

    return isCorner
end


"""
Place les perles sur la matrice t (initialement nulle) selon la boucle.

- Perle Noire en un coin si chacun des deux segments adjacents a une longueur
  d'AU MOINS 2 cases au-delà du coin (donc segment total ≥ 3 cases coin compris).
  Cela garantit que la cellule voisine du coin va tout droit (règle Pearl).
- Perle Blanche en une cellule droite voisine d'un coin (avant ou après) sur la
  boucle.

Probabilité `p_pearls` à chaque candidat.
"""
function placePearls!(t::Matrix{Int},
                      cells::Vector{Tuple{Int,Int}},
                      isCorner::BitVector,
                      p_pearls::Float64)

    L = length(cells)

    # ---- Perles Noires ----
    for k in 1:L
        if isCorner[k] && rand() < p_pearls

            # Longueur du segment en avant (cases, coin compris jusqu'au prochain coin)
            fwd = 1
            for d in 1:L
                idx = mod1(k + d, L)
                fwd += 1
                isCorner[idx] && break
            end

            bwd = 1
            for d in 1:L
                idx = mod1(k - d, L)
                bwd += 1
                isCorner[idx] && break
            end

            # On veut au moins une cellule droite intermédiaire de chaque côté
            if fwd >= 3 && bwd >= 3
                ci, cj = cells[k]
                t[ci, cj] = 1   # BLACK / Noire
            end
        end
    end

    # ---- Perles Blanches ----
    for k in 1:L
        if !isCorner[k]
            prev_idx = mod1(k - 1, L)
            next_idx = mod1(k + 1, L)
            if (isCorner[prev_idx] || isCorner[next_idx]) && rand() < p_pearls
                ci, cj = cells[k]
                if t[ci, cj] == 0   # ne pas écraser une perle déjà posée
                    t[ci, cj] = 2   # WHITE / Blanche
                end
            end
        end
    end
end


"""
Génère une instance Pearl n × n résoluble.

Argument
- n        : taille de la grille
- p_pearls : probabilité (par cellule éligible) de placer une perle

Renvoie une `Matrix{Int}` codée selon io.jl (EMPTY=0, BLACK=1, WHITE=2).
"""
function generateInstance(n::Int; p_pearls::Float64 = 0.3)::Matrix{Int}

    @assert n >= 3 "generateInstance : n >= 3 requis pour générer une boucle non triviale"

    # A. Boucle initiale
    inLoopY, inLoopH, inLoopV = perimeterLoop(n)

    # B. Mutations
    n_mutations = max(2 * n, n * n ÷ 3)
    for _ in 1:n_mutations
        tryMutate!(inLoopY, inLoopH, inLoopV, n)
    end

    # C. Placement des perles
    cells    = walkLoop(inLoopY, inLoopH, inLoopV, n)
    isCorner = classifyCorners(cells)

    t = zeros(Int, n, n)
    placePearls!(t, cells, isCorner, p_pearls)

    return t
end


"""
Génère et sauvegarde plusieurs instances dans ./data/.

- n_instances : nombre d'instances par taille
- sizes       : liste des tailles n à générer
"""
function generateDataSet(n_instances::Int, sizes::Vector{Int})

    dataFolder = "../data/"
    if !isdir(dataFolder)
        mkpath(dataFolder)
    end

    for n in sizes
        for k in 1:n_instances
            outfile = dataFolder * "instance_n$(n)_$(k).txt"
            if isfile(outfile)
                continue
            end
            t = generateInstance(n)
            saveInstance(t, outfile)
            println("Generated ", outfile)
        end
    end
end
