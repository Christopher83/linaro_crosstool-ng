#include <stdio.h>

__attribute__((noinline))
float add(float a, float b)
{
  return a * (b + 5);
}

int main()
{
  printf("got %f\n", add(6, 7));

  return 0;
}
