/*  Le jeu du nombre mystère est le suivant - L'ordinateur choisi un nombre entre 1 et 10.
    L'utilisateur devine et tape un nombre entre 1 - 10.
    Si les deux nombres sont identiques, l'utilisateur gagne.
    Dans tous les autres cas, il perd.
*/

/* Main program */

le_nombre = random(1,10)

say "j'ai choisi, a vous de le deviner, il est entre 1 et 10 :"
pull le_choix

if le_nombre = le_choix then
    say 'Vous avez gagne !'
else
    say 'Perdu, le nombre etait ' le_nombre

say 'Au revoir !'
exit