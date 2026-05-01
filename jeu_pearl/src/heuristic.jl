# =====================================================================
# Heuristique de résolution Pearl par PROPAGATION DE CONTRAINTES.
# Aucun solveur externe : pure déduction logique sur l'état des arêtes.
#
# Représentation des matrices d'état :
#       0  : inconnu
#       1  : tracé (arête de la boucle)
#      -1  : interdit (arête NE peut PAS faire partie de la boucle)
#
# Conventions sur les directions retournées par get_edges :
#       1 : Haut    (xV[i-1, j])
#       2 : Bas     (xV[i,   j])
#       3 : Gauche  (xH[i, j-1])
#       4 : Droite  (xH[i,   j])
#
# Sortie de heuristicSolve :
#       (success::Bool, xH::Matrix{Int}, xV::Matrix{Int})
# où xH et xV sont déjà convertis en 0/1 (les -1 deviennent 0)
# pour rester compatibles avec displaySolution(t, y, xH, xV).
# =====================================================================

include("io.jl")


# ---------------------------------------------------------------------
# Utilitaires : voisinage et lecture/écriture d'arêtes
# ---------------------------------------------------------------------

"""
Renvoie l'état des 4 arêtes incidentes à la case (i, j) sous la forme
[Haut, Bas, Gauche, Droite]. Une direction hors-grille renvoie -1.
"""
function get_edges(i::Int, j::Int, xH::Matrix{Int}, xV::Matrix{Int}, N::Int)
    haut   = (i > 1) ? xV[i - 1, j] : -1
    bas    = (i < N) ? xV[i,     j] : -1
    gauche = (j > 1) ? xH[i, j - 1] : -1
    droite = (j < N) ? xH[i,     j] : -1
    return [haut, bas, gauche, droite]
end

"""
Voisin de (i, j) dans la direction `dir` (1=Haut, 2=Bas, 3=Gauche, 4=Droite).
Renvoie nothing si la direction sort de la grille.
"""
function neighbor_cell(i::Int, j::Int, dir::Int, N::Int)
    if     dir == 1; return i > 1 ? (i - 1, j) : nothing
    elseif dir == 2; return i < N ? (i + 1, j) : nothing
    elseif dir == 3; return j > 1 ? (i, j - 1) : nothing
    else             return j < N ? (i, j + 1) : nothing
    end
end

"""
Écrit `value` dans l'arête de la case (i, j) située dans la direction `dir`.
"""
function set_edge!(i::Int, j::Int, dir::Int, value::Int,
                   xH::Matrix{Int}, xV::Matrix{Int})
    if     dir == 1; xV[i - 1, j] = value
    elseif dir == 2; xV[i,     j] = value
    elseif dir == 3; xH[i, j - 1] = value
    else             xH[i,     j] = value
    end
end


# ---------------------------------------------------------------------
# Pré-traitement : coups forcés évidents
# ---------------------------------------------------------------------

"""
Applique les coups directement dérivables des règles Pearl :
  - Perle Noire dans un coin : 2 directions intérieures à 1 + extensions
  - Perle Blanche sur un bord : ligne droite parallèle au bord à 1
                                 (et l'arête perpendiculaire à -1).
"""
function apply_forced_moves!(xH::Matrix{Int}, xV::Matrix{Int},
                             t::Matrix{Int}, N::Int)

    for i in 1:N, j in 1:N
        cell = t[i, j]

        # =========================================================
        # PERLE NOIRE — règle dans un coin de la grille
        # =========================================================
        if cell == 1
            if i == 1 && j == 1 && N >= 2
                # Coin haut-gauche : seules les directions Bas + Droite existent
                xV[1, 1] = 1                  # bas
                xH[1, 1] = 1                  # droite
                if N >= 3
                    xV[2, 1] = 1              # extension bas (cellule (2,1) tout droit)
                    xH[1, 2] = 1              # extension droite
                end

            elseif i == 1 && j == N && N >= 2
                # Coin haut-droite
                xV[1, N]     = 1
                xH[1, N - 1] = 1
                if N >= 3
                    xV[2, N]     = 1
                    xH[1, N - 2] = 1
                end

            elseif i == N && j == 1 && N >= 2
                # Coin bas-gauche
                xV[N - 1, 1] = 1
                xH[N, 1]     = 1
                if N >= 3
                    xV[N - 2, 1] = 1
                    xH[N, 2]     = 1
                end

            elseif i == N && j == N && N >= 2
                # Coin bas-droite
                xV[N - 1, N] = 1
                xH[N, N - 1] = 1
                if N >= 3
                    xV[N - 2, N] = 1
                    xH[N, N - 2] = 1
                end
            end

        # =========================================================
        # PERLE BLANCHE — règle sur un bord (hors coin)
        # =========================================================
        elseif cell == 2

            # Bord supérieur : passage horizontal forcé
            if i == 1 && 1 < j < N
                xH[1, j - 1] = 1
                xH[1, j]     = 1
                xV[1, j]     = -1   # pas d'arête vers le bas

            # Bord inférieur
            elseif i == N && 1 < j < N
                xH[N, j - 1] = 1
                xH[N, j]     = 1
                xV[N - 1, j] = -1

            # Bord gauche : passage vertical forcé
            elseif j == 1 && 1 < i < N
                xV[i - 1, 1] = 1
                xV[i, 1]     = 1
                xH[i, 1]     = -1

            # Bord droit
            elseif j == N && 1 < i < N
                xV[i - 1, N] = 1
                xV[i, N]     = 1
                xH[i, N - 1] = -1

            # Cas perle blanche en coin : structurellement infaisable
            # (aucun passage droit possible). Le check final renverra success=false.
            end
        end
    end
end


# ---------------------------------------------------------------------
# Anti-sous-tour : éviter d'enfermer la boucle prématurément
# ---------------------------------------------------------------------

"""
Simule l'ajout (temporaire) de l'arête `dir` de (i, j) à 1, puis fait un BFS
en suivant uniquement les arêtes à 1.

Renvoie true si la composante connexe trouvée forme une boucle fermée
qui NE contient PAS toutes les perles de la grille (c'est-à-dire un
sous-tour invalide), false sinon.

L'arête modifiée est restaurée à sa valeur d'origine avant retour.
"""
function cree_sous_tour_invalide(i::Int, j::Int, dir::Int,
                                 xH::Matrix{Int}, xV::Matrix{Int},
                                 t::Matrix{Int}, N::Int)

    # ----- Sauvegarde et pose temporaire -----
    saved::Int = 0
    if     dir == 1; saved = xV[i - 1, j]; xV[i - 1, j] = 1
    elseif dir == 2; saved = xV[i,     j]; xV[i,     j] = 1
    elseif dir == 3; saved = xH[i, j - 1]; xH[i, j - 1] = 1
    else             saved = xH[i,     j]; xH[i,     j] = 1
    end

    # ----- BFS depuis (i, j) sur les arêtes à 1 -----
    visited = Set{Tuple{Int,Int}}([(i, j)])
    queue   = Tuple{Int,Int}[(i, j)]

    while !isempty(queue)
        (ci, cj) = popfirst!(queue)
        edges = get_edges(ci, cj, xH, xV, N)
        for d in 1:4
            if edges[d] == 1
                nbr = neighbor_cell(ci, cj, d, N)
                if nbr !== nothing && !(nbr in visited)
                    push!(visited, nbr)
                    push!(queue, nbr)
                end
            end
        end
    end

    # ----- La composante visitée est-elle une boucle fermée ? -----
    # Une boucle fermée a tous ses sommets de degré exactement 2 sur les arêtes à 1
    is_closed_loop = (length(visited) >= 3)
    if is_closed_loop
        for (ci, cj) in visited
            edges = get_edges(ci, cj, xH, xV, N)
            if count(==(1), edges) != 2
                is_closed_loop = false
                break
            end
        end
    end

    # ----- Compte les perles dans la composante -----
    pearls_in_component = 0
    for (ci, cj) in visited
        if t[ci, cj] != 0
            pearls_in_component += 1
        end
    end

    # ----- Restauration -----
    if     dir == 1; xV[i - 1, j] = saved
    elseif dir == 2; xV[i,     j] = saved
    elseif dir == 3; xH[i, j - 1] = saved
    else             xH[i,     j] = saved
    end

    total_pearls = count(!=(0), t)
    return is_closed_loop && pearls_in_component < total_pearls
end


# ---------------------------------------------------------------------
# Vérification finale
# ---------------------------------------------------------------------

"""
Renvoie true si la solution courante (xH, xV) est complète et cohérente :
    - aucune arête restée à 0 (tout est décidé)
    - chaque case a un degré ∈ {0, 2}
    - toutes les perles ont un degré 2
    - toutes les cases actives appartiennent à UNE SEULE composante connexe
"""
function check_solution(xH::Matrix{Int}, xV::Matrix{Int},
                        t::Matrix{Int}, N::Int)

    # 1. Tout est décidé
    if any(==(0), xH) || any(==(0), xV)
        return false
    end

    # 2. Chaque case a un degré 0 ou 2
    for i in 1:N, j in 1:N
        deg = count(==(1), get_edges(i, j, xH, xV, N))
        if !(deg == 0 || deg == 2)
            return false
        end
    end

    # 3. Toutes les perles sont sur la boucle (degré 2)
    for i in 1:N, j in 1:N
        if t[i, j] != 0
            if count(==(1), get_edges(i, j, xH, xV, N)) != 2
                return false
            end
        end
    end

    # 4. Une seule composante connexe parmi les cases actives
    start_cell = nothing
    for i in 1:N, j in 1:N
        if any(==(1), get_edges(i, j, xH, xV, N))
            start_cell = (i, j)
            break
        end
    end
    start_cell === nothing && return true   # grille sans aucune arête

    visited = Set{Tuple{Int,Int}}([start_cell])
    queue   = Tuple{Int,Int}[start_cell]
    while !isempty(queue)
        (ci, cj) = popfirst!(queue)
        edges = get_edges(ci, cj, xH, xV, N)
        for d in 1:4
            if edges[d] == 1
                nbr = neighbor_cell(ci, cj, d, N)
                if nbr !== nothing && !(nbr in visited)
                    push!(visited, nbr)
                    push!(queue, nbr)
                end
            end
        end
    end

    for i in 1:N, j in 1:N
        if any(==(1), get_edges(i, j, xH, xV, N)) && !((i, j) in visited)
            return false
        end
    end

    return true
end


# ---------------------------------------------------------------------
# Fonction principale
# ---------------------------------------------------------------------

"""
Heuristique de résolution Pearl par propagation de contraintes pure.

Argument :
    t :: Matrix{Int}  (codage : 0 = vide, 1 = perle Noire, 2 = perle Blanche)

Retour :
    (success::Bool, xH::Matrix{Int}, xV::Matrix{Int})
        - success : true si la déduction a abouti à une solution complète
                    et cohérente (boucle unique passant par toutes les perles).
        - xH, xV  : matrices d'arêtes (valeurs 0 ou 1 uniquement,
                    directement utilisables avec displaySolution).
"""
function heuristicSolve(t::Matrix{Int})

    N  = size(t, 1)
    xH = zeros(Int, N, N - 1)
    xV = zeros(Int, N - 1, N)

    # ----- Étape 1 : pré-traitement des coups forcés -----
    apply_forced_moves!(xH, xV, t, N)

    # ----- Étape 2 : boucle de propagation -----
    changed = true
    while changed
        changed = false

        for i in 1:N, j in 1:N
            edges = get_edges(i, j, xH, xV, N)

            # =============================================================
            # NOUVELLES RÈGLES — Perles à l'intérieur de la grille
            # On modifie xH/xV ET on synchronise `edges` au fur et à mesure
            # pour que les règles A/B/C qui suivent voient l'état à jour.
            # =============================================================

            # ---- Perle Noire : la boucle DOIT tourner ici ----
            if t[i, j] == 1
                # Indices : 1=Haut, 2=Bas, 3=Gauche, 4=Droite

                # ----- Règle "tourner" -----
                # Si une arête verticale est tracée, l'autre verticale est interdite
                if edges[1] == 1 && edges[2] == 0
                    set_edge!(i, j, 2, -1, xH, xV); edges[2] = -1; changed = true
                end
                if edges[2] == 1 && edges[1] == 0
                    set_edge!(i, j, 1, -1, xH, xV); edges[1] = -1; changed = true
                end
                if edges[3] == 1 && edges[4] == 0
                    set_edge!(i, j, 4, -1, xH, xV); edges[4] = -1; changed = true
                end
                if edges[4] == 1 && edges[3] == 0
                    set_edge!(i, j, 3, -1, xH, xV); edges[3] = -1; changed = true
                end

                # ----- Règle "extension" (tout droit après) -----
                # Si un trait sort d'une perle noire dans une direction,
                # le trait suivant dans cette même direction doit aussi être tracé
                # (la case voisine continue tout droit).
                if edges[1] == 1 && i > 2 && xV[i - 2, j] == 0
                    xV[i - 2, j] = 1; changed = true
                end
                if edges[2] == 1 && i < N - 1 && xV[i + 1, j] == 0
                    xV[i + 1, j] = 1; changed = true
                end
                if edges[3] == 1 && j > 2 && xH[i, j - 2] == 0
                    xH[i, j - 2] = 1; changed = true
                end
                if edges[4] == 1 && j < N - 1 && xH[i, j + 1] == 0
                    xH[i, j + 1] = 1; changed = true
                end

            # ---- Perle Blanche : la boucle DOIT aller tout droit ici ----
            elseif t[i, j] == 2

                # ----- Cas 1 : un trait entrant impose la direction -----
                # Vertical (Haut ou Bas tracé) → passage vertical
                if edges[1] == 1 || edges[2] == 1
                    if edges[1] == 0
                        set_edge!(i, j, 1, 1, xH, xV); edges[1] = 1; changed = true
                    end
                    if edges[2] == 0
                        set_edge!(i, j, 2, 1, xH, xV); edges[2] = 1; changed = true
                    end
                    if edges[3] == 0
                        set_edge!(i, j, 3, -1, xH, xV); edges[3] = -1; changed = true
                    end
                    if edges[4] == 0
                        set_edge!(i, j, 4, -1, xH, xV); edges[4] = -1; changed = true
                    end
                # Horizontal (Gauche ou Droite tracé) → passage horizontal
                elseif edges[3] == 1 || edges[4] == 1
                    if edges[3] == 0
                        set_edge!(i, j, 3, 1, xH, xV); edges[3] = 1; changed = true
                    end
                    if edges[4] == 0
                        set_edge!(i, j, 4, 1, xH, xV); edges[4] = 1; changed = true
                    end
                    if edges[1] == 0
                        set_edge!(i, j, 1, -1, xH, xV); edges[1] = -1; changed = true
                    end
                    if edges[2] == 0
                        set_edge!(i, j, 2, -1, xH, xV); edges[2] = -1; changed = true
                    end
                end

                # ----- Cas 2 : un mur impose la direction perpendiculaire -----
                # NB : on ne re-rentre dans Cas 2 que s'il reste des arêtes à 0
                # Si l'une des verticales est interdite, le passage vertical est impossible
                # → passage horizontal forcé
                if edges[1] == -1 || edges[2] == -1
                    if edges[3] == 0
                        set_edge!(i, j, 3, 1, xH, xV); edges[3] = 1; changed = true
                    end
                    if edges[4] == 0
                        set_edge!(i, j, 4, 1, xH, xV); edges[4] = 1; changed = true
                    end
                    if edges[1] == 0
                        set_edge!(i, j, 1, -1, xH, xV); edges[1] = -1; changed = true
                    end
                    if edges[2] == 0
                        set_edge!(i, j, 2, -1, xH, xV); edges[2] = -1; changed = true
                    end
                # Idem côté horizontal
                elseif edges[3] == -1 || edges[4] == -1
                    if edges[1] == 0
                        set_edge!(i, j, 1, 1, xH, xV); edges[1] = 1; changed = true
                    end
                    if edges[2] == 0
                        set_edge!(i, j, 2, 1, xH, xV); edges[2] = 1; changed = true
                    end
                    if edges[3] == 0
                        set_edge!(i, j, 3, -1, xH, xV); edges[3] = -1; changed = true
                    end
                    if edges[4] == 0
                        set_edge!(i, j, 4, -1, xH, xV); edges[4] = -1; changed = true
                    end
                end
            end

            # =============================================================
            # RÈGLES STRUCTURELLES — A, B, C
            # =============================================================
            nb_trace    = count(==(1),  edges)
            nb_interdit = count(==(-1), edges)

            # Règle A — Fermeture
            # déjà 2 arêtes tracées : toutes les autres deviennent interdites
            if nb_trace == 2 && nb_interdit < 2
                for d in 1:4
                    if edges[d] == 0
                        set_edge!(i, j, d, -1, xH, xV)
                        changed = true
                    end
                end

            # Règle B — Survie
            # 1 arête tracée + 2 interdites : la dernière DOIT être tracée
            # (sauf si cela fermerait un sous-tour invalide → on l'interdit)
            elseif nb_trace == 1 && nb_interdit == 2
                d = findfirst(==(0), edges)
                if d !== nothing
                    if cree_sous_tour_invalide(i, j, d, xH, xV, t, N)
                        set_edge!(i, j, d, -1, xH, xV)
                    else
                        set_edge!(i, j, d, 1, xH, xV)
                    end
                    changed = true
                end

            # Règle C — Impasse
            # 0 tracée + 3 interdites : la dernière ne peut être que -1
            # (autrement degré 1, impossible dans un cycle)
            elseif nb_trace == 0 && nb_interdit == 3
                d = findfirst(==(0), edges)
                if d !== nothing
                    set_edge!(i, j, d, -1, xH, xV)
                    changed = true
                end
            end
        end
    end

    # ----- Étape 3 : check final + conversion 0/1 pour displaySolution -----
    success = check_solution(xH, xV, t, N)

    xH_disp = Int.(xH .== 1)
    xV_disp = Int.(xV .== 1)

    return success, xH_disp, xV_disp
end


# ---------------------------------------------------------------------
# Wrapper ergonomique (calcule y et appelle displaySolution)
# ---------------------------------------------------------------------

"""
Résout par heuristique et affiche la solution si elle a été trouvée.
Sinon imprime un message d'échec et affiche la déduction partielle.
"""
function heuristicSolveAndDisplay(t::Matrix{Int})
    N = size(t, 1)
    success, xH, xV = heuristicSolve(t)

    # Construction de y à partir des arêtes (1 si la case a au moins une arête active)
    y = zeros(Int, N, N)
    for i in 1:N, j in 1:N
        haut   = (i > 1) ? xV[i - 1, j] : 0
        bas    = (i < N) ? xV[i,     j] : 0
        gauche = (j > 1) ? xH[i, j - 1] : 0
        droite = (j < N) ? xH[i,     j] : 0
        if (haut + bas + gauche + droite) > 0
            y[i, j] = 1
        end
    end

    if success
        println("Heuristique : solution trouvée par propagation pure ✓")
    else
        println("Heuristique : pas de solution complète déduite ",
                "(la propagation s'est arrêtée). Affichage de la déduction partielle :")
    end

    displaySolution(t, y, xH, xV)

    return success, xH, xV
end
