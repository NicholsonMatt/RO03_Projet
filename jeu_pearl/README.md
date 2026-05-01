# Projet Pearl — Résolution par Programmation Linéaire en Nombres Entiers

Projet académique de **Recherche Opérationnelle (ENSTA)** visant à résoudre le
jeu logique **Pearl** :
- via une formulation **PLNE exacte** résolue par CPLEX, avec un callback de
  *lazy constraints* pour éliminer les sous-tours,
- et via une **heuristique** par pure propagation de contraintes (déduction
  logique, sans solveur).

## Règles du jeu Pearl

Le but est de tracer une **boucle fermée unique** sur la grille telle que :

- chaque case visitée a exactement **deux** arêtes utilisées (loop simple) ;
- la boucle ne se croise pas elle-même ;
- toute case contenant une **perle Noire (●)** : la boucle **tourne** dans la
  case, et va **tout droit** dans les deux cases voisines ;
- toute case contenant une **perle Blanche (○)** : la boucle va **tout droit**
  dans la case, et **tourne** dans au moins une des deux cases voisines.

## Arborescence

```
jeu_pearl/
├── README.md                ← ce fichier
├── data/                    ← instances Pearl au format texte
│   ├── instanceTest.txt
│   └── instance_n{N}_{K}.txt
├── res/                     ← résultats produits par les batches
│   ├── cplex_callback/      ← un .txt par instance résolue
│   ├── array.tex            ← tableau LaTeX des temps
│   └── performance_plot.png ← courbe temps moyen / max par taille
└── src/                     ← code source Julia
    ├── io.jl                ← lecture/écriture/affichage + diagrammes
    ├── generation.jl        ← génération aléatoire d'instances faisables
    ├── resolution.jl        ← cplexSolve : modèle PLNE de base
    ├── resolutionWithCallback.jl ← cplexSolveWithCallback : + lazy subtour
    ├── heuristic.jl         ← heuristicSolve : propagation pure
    ├── main_test.jl         ← test smoke (4×4 + 8×8 généré)
    ├── run_final_batch.jl   ← pipeline complet (génération → résolution → graphes)
    └── make_graphs.jl       ← génération des graphiques et du tableau LaTeX
```

---

## 1. Pré-requis

| Composant | Version conseillée | Requis |
|-----------|-------------------|--------|
| **Julia** | ≥ 1.10 (testé sur 1.12.6) | oui |
| **IBM CPLEX** | 22.1.x (Community Edition acceptée) | oui |
| Paquets Julia | `JuMP`, `CPLEX`, `Plots`, `GR` | oui |
| OS | Linux/macOS (testé sur Ubuntu) | recommandé |

> **Note Community Edition** : CPLEX gratuit plafonne à 1000 variables /
> 1000 contraintes. Cela suffit pour `N ≤ ~12`. Au-delà, il faut une licence
> académique (gratuite via *IBM Academic Initiative*).

---

## 2. Installation rapide (Linux / WSL)

### a. Installer Julia (via juliaup, recommandé)

```bash
curl -fsSL https://install.julialang.org | sh -s -- -y
# Recharge le shell
source ~/.bashrc
julia --version   # doit afficher 1.10+ (au moment de l'écriture: 1.12.6)
```

### b. Installer IBM CPLEX

1. Télécharger l'installateur Linux depuis le portail IBM :
   - **Community Edition** (gratuite, sans inscription) : 1000 vars max
   - **Academic Edition** (gratuite avec compte universitaire) : illimitée
2. Exécuter l'installateur :
   ```bash
   chmod +x cplex_studio*.bin
   sudo ./cplex_studio*.bin
   ```
   Installation par défaut : `/opt/ibm/ILOG/CPLEX_Studio*/`.

### c. Configurer les variables d'environnement

Ajouter à la fin de `~/.bashrc` (en adaptant le chemin) :
```bash
export CPLEX_STUDIO_BINARIES="/opt/ibm/ILOG/CPLEX_Studio_Community2212/cplex/bin/x86-64_linux"
export LD_LIBRARY_PATH="$CPLEX_STUDIO_BINARIES${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
```

Puis recharger : `source ~/.bashrc`.

### d. Installer les paquets Julia

```bash
julia -e 'using Pkg; Pkg.add(["JuMP", "CPLEX", "Plots", "GR"])'
```

Si `CPLEX.jl` rate la précompilation, lancer manuellement :
```bash
julia -e 'using Pkg; Pkg.build("CPLEX"; verbose=true)'
```

### e. Smoke test (vérification finale)

```bash
julia -e 'using JuMP, CPLEX
m = Model(CPLEX.Optimizer); set_silent(m)
@variable(m, x>=0); @objective(m, Min, x); optimize!(m)
println("OK : value(x)=", value(x))'
```

Doit afficher `OK : value(x)=0.0`.

---

## 3. Test rapide — "ça marche ?" en 30 secondes

```bash
cd src/
julia main_test.jl
```

Lance deux tests :
- **TEST 1** : résolution de `data/instanceTest.txt` (4×4 manuelle)
- **TEST 2** : génération d'une instance 8×8 + résolution avec callback

Sortie attendue : grilles affichées en ASCII + temps de résolution + boucle
solution dessinée. Si les deux tests affichent `Réalisable : true`,
l'installation est validée.

---

## 4. Reproduire le batch complet (livrables du rapport)

```bash
cd src/
julia run_final_batch.jl
```

Ce pipeline en 3 étapes :
1. **Génère** 5 instances pour chaque taille `N ∈ {4, 6, 8, 10, 12}`
   (ne régénère pas les fichiers existants).
2. **Résout** toutes les instances de `../data/` avec
   `cplexSolveWithCallback` (timeout 60 s par instance).
3. **Produit** les livrables dans `../res/` :
   - `array.tex` — tableau LaTeX des résultats
   - `performance_plot.png` — courbe temps moyen / max par taille `N`
   - `cplex_callback/` — un fichier par instance avec `solveTime` et `isOptimal`

Pour repartir de zéro : supprimer `data/instance_n*_*.txt` et
`res/cplex_callback/` avant de lancer.

---

## 5. Utilisation interactive (REPL Julia)

```bash
cd src/
julia
```

Dans la REPL :

```julia
# Charger tout
include("io.jl")
include("resolution.jl")
include("resolutionWithCallback.jl")
include("generation.jl")
include("heuristic.jl")
using JuMP

# A) Lire et afficher une instance
t = readInputFile("../data/instance_n8_3.txt")
displayGrid(t)

# B) Résoudre avec CPLEX (avec ou sans callback)
isFeas, m, dt = cplexSolveWithCallback(t)
solveAndDisplay(t)               # raccourci : résout + affiche

# C) Résoudre avec l'heuristique
heuristicSolveAndDisplay(t)      # affiche la boucle si succès, sinon la déduction partielle

# D) Générer une nouvelle instance
t = generateInstance(10; p_pearls = 0.25)
saveInstance(t, "../data/maGrille.txt")

# E) Lancer un batch et tracer les graphes
generateDataSet(5, [4, 6, 8])    # 15 nouvelles instances
solveDataSetWithCallback()       # résout tout
include("make_graphs.jl")        # produit array.tex + performance_plot.png
```

---

## 6. Format des instances Pearl

Chaque ligne du fichier représente une ligne de la grille. Les cases sont
séparées par des virgules. Le contenu d'une case est :

| Caractère | Signification     |
|-----------|-------------------|
| ` ` (espace) | case vide      |
| `N`       | perle **N**oire   |
| `B`       | perle **B**lanche |

Exemple `data/instanceTest.txt` (4×4) — perle Noire en (1,1) et (4,4),
perle Blanche en (1,3) :

```
N, ,B,
 , , ,
 , , ,
 , , ,N
```

La taille `n` est déduite du nombre de cases sur la première ligne. La grille
est carrée.

En interne, la matrice `t :: Matrix{Int}` utilise les codes :
`0` = vide, `1` = Noire, `2` = Blanche.

---

## 7. Modèle PLNE (`resolution.jl`, `resolutionWithCallback.jl`)

### Variables (toutes binaires)

- `y[i, j]` : 1 si la boucle passe par la case `(i, j)`
- `xH[i, j]` : 1 si l'arête horizontale entre `(i, j)` et `(i, j+1)` est utilisée
- `xV[i, j]` : 1 si l'arête verticale entre `(i, j)` et `(i+1, j)` est utilisée

### Contraintes

1. **Continuité** : ∀(i, j), somme des arêtes incidentes = `2 · y[i, j]`
2. **Perles présentes** : si `t[i, j] ≠ 0`, alors `y[i, j] = 1`
3. **Perle Blanche** : passage tout droit + tourner avant ou après
4. **Perle Noire** : angle obligatoire + tout droit dans les cases adjacentes
5. **Élimination des sous-tours** : ajoutée *paresseusement* via callback CPLEX
   (`resolutionWithCallback.jl`). À chaque solution candidate entière, on
   détecte par BFS si la boucle est fragmentée ; si oui, on coupe le sous-tour
   par `Σ arêtes internes ≤ |S| - 1`.

### Objectif

Pearl est un problème de **faisabilité** : on garde un objectif factice
`@objective(m, Max, 0)`.

---

## 8. Heuristique par propagation (`heuristic.jl`)

Algorithme de **déduction logique pure**, sans backtracking ni solveur.
État de chaque arête : `0` (inconnu), `1` (tracé), `-1` (interdit).

### Pré-traitement (coups forcés)

- Perle Noire en coin → 2 directions intérieures à 1 + extensions
- Perle Blanche sur bord → ligne droite parallèle au bord à 1

### Boucle de propagation

Tant qu'une déduction est possible, pour chaque case :

| Règle | Condition | Action |
|-------|-----------|--------|
| **Noire — Tourner** | une arête tracée | l'arête opposée (même axe) → -1 |
| **Noire — Extension** | une arête tracée | la deuxième case dans cette direction → 1 |
| **Blanche — Cas 1** | une arête tracée | les 2 perpendiculaires → -1, le passage forcé → 1 |
| **Blanche — Cas 2** | un mur (-1) sur un axe | le passage perpendiculaire → 1 |
| **A — Fermeture** | 2 tracées | les 0-edges → -1 |
| **B — Survie** | 1 tracée + 2 interdites | la dernière → 1 (sauf sous-tour invalide → -1) |
| **C — Impasse** | 0 tracée + 3 interdites | la dernière → -1 |

La règle **B** appelle `cree_sous_tour_invalide` qui simule l'ajout, fait un
BFS, et vérifie si la boucle se referme prématurément sans contenir toutes
les perles.

### Limites

L'heuristique **ne résout que ~4 %** des instances générées par
`generateInstance`. Sa valeur académique est de montrer que la propagation
locale ne suffit pas pour Pearl, et de motiver le recours à la PLNE.

---

## 9. Visualisation et graphiques

`displaySolution(t, y_val, xH_val, xV_val)` dessine la solution en ASCII :
- `N` perle Noire, `B` perle Blanche
- `+` case visitée par la boucle
- `.` case non visitée
- `---` arête horizontale active, `|` arête verticale active

`make_graphs.jl` produit deux livrables dans `../res/` :
- **`array.tex`** : tableau LaTeX (fonction des profs `resultsArray`)
- **`performance_plot.png`** : courbe temps moyen / max en fonction de `N`
  (fonction sur-mesure `plot_pearl_performance`, échelle log)

