/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   fizzbuzz.rexx                                      :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: Maurice809 <maurice809@hotmail.com>        +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2024/05/05 16:34:24 by Maurice809        #+#    #+#             */
/*   Updated: 2024/05/05 16:34:31 by Maurice809       ###   Lausanne.ch       */
/*                                                                            */
/* ************************************************************************** */

/*  Écrivez un programme qui imprime les nombres de 1 à 100.
    Mais pour les multiples de trois, imprimez « Fizz » au lieu du nombre
    et pour les multiples de cinq, imprimez « Buzz ». 
    Pour les nombres multiples de trois et de cinq, inscrivez « FizzBuzz » 
*/

/* Main Program */
do i = 1 to 100
     say check(i)
end
exit

::routine check
    parse arg z
    if (z//3)+(z//5) == 0 then 
        z = "FizzBuzz"
    else if (z//5) == 0 then
        z = "Buzz"
    else if (z//3) == 0 then
        z = "Fizz"
return z
