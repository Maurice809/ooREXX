/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   coolconv.rexx                                      :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: Maurice809 <maurice809@hotmail.com>        +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2024/05/06 22:57:47 by Maurice809        #+#    #+#             */
/*   Updated: 2024/05/06 22:57:51 by Maurice809       ###   Lausanne.ch       */
/*                                                                            */
/* ************************************************************************** */

/* Main program */
do while nombre \= ''
  say "Entrez un nombre décimal :"
  pull nombre .
  say "Entrez une base :"
  pull base .

  say "Votre nombre en base : "base
  say convert(nombre base)
end
exit

/* Routine pour convertir */
convert: procedure
  parse arg nombre base
  resultat = ''

   /* Vérification des entrées */
  if nombre < 0 then do
    say "Erreur : Nombre invalide. Veuillez saisir un nombre positif ou nul."
    return resultat
  end
  
  /* Calcul de convertion */
  do while nombre > 0
    reste = nombre // base
    nombre = nombre % base
    
    if reste < 10 then
      resultat = translate(d2c(reste + 48)) || resultat
    else
      resultat = translate(d2c(reste + 55)) || resultat
  end
  
  return resultat