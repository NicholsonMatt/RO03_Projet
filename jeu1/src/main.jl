include("io.jl")

function main()
    chemin_fichier = joinpath(@__DIR__, "..", "data", "instanceText.txt")
    
    donnees = readInputFile(chemin_fichier)
    println("Data read from file : ", donnees)

    

end

main()