/* Chaîne à lire caractère par caractère */
chaine = "Exemple"

/* Longueur de la chaîne */
longueur = length(chaine)

/* Parcours de la chaîne caractère par caractère */
do i = 1 to longueur
    car = substr(chaine, i, 2)
    say "Caractère à la position" i ":" car
end