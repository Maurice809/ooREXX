/* Main program */
pull a
facto(a)
exit

/* Recursive internal function execution... */
facto:
    arg x
    say x'! =' factorial(x)
    exit

factorial: procedure   /* Calculate factorial by    */
  arg n                /*   recursive invocation.   */
  if n=0 then return 1
  return  factorial(n-1) * n