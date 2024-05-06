/*
    Quatre lettres :
    Le programme identifie tous les quatre lettres du mot inséré
    et les place dans l'output liste
*/

/* Main program */

quatre_lettre_mot = '' /* initialise  la varible */

say "Tapez un mot :" 
parse pull motin .
do while motin \= ''
    if length(motin) = 4 then
        quatre_lettre_mot = quatre_lettre_mot motin
    
    say "Tapez un mot :"
    parse pull motin .
end

say 'quatre lettre du mot:' quatre_lettre_mot