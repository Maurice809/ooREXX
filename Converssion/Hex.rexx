/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   Hex.rexx                                           :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: Maurice809 <maurice809@hotmail.com>        +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2024/05/06 22:23:09 by Maurice809        #+#    #+#             */
/*   Updated: 2024/05/06 22:23:19 by Maurice809       ###   Lausanne.ch       */
/*                                                                            */
/* ************************************************************************** */

/*
    Creation d'un convertiseur decimal en hexdeciaml
*/

/* Main program */
say "Entre un nombre decimal ?"
pull deci_nombre

say "votre nombre en hexa-decimal :"
say hexa(deci_nombre)
exit

::routine hexa
    parse arg nombre
    resultat_hexadecimal = ''

    /* Vérification des entrées */
    if nombre < 0 then do
        say "Erreur : Nombre invalide. Veuillez saisir un nombre positif ou nul."
        return resultat_hexadecimal
    end

    if nombre >= 16 then
        do while nombre >= 16
            reste = nombre//16
           nombre = nombre%16
            say "debug reste" reste
        
           if reste < 10 then
                resultat_hexadecimal = translate(d2c(reste + 48)) || resultat_hexadecimal
         else
                resultat_hexadecimal = translate(d2c(reste + 55)) || resultat_hexadecimal

         if nombre < 16 then
                do
                    reste = nombre
                    say "debug reste" reste

                    if reste < 10 then
                        resultat_hexadecimal = translate(d2c(reste + 48)) || resultat_hexadecimal
                    else
                        resultat_hexadecimal = translate(d2c(reste + 55)) || resultat_hexadecimal
                end  
        end
    else
        do
            if nombre < 10 then
                resultat_hexadecimal = translate(d2c(nombre + 48)) || resultat_hexadecimal
            else
                resultat_hexadecimal = translate(d2c(nombre + 55)) || resultat_hexadecimal
        end


        say "debug" resultat_hexadecimal
return resultat_hexadecimal