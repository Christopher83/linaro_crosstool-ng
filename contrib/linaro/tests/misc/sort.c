/* Sort a list of integers using the libc qsort().  Used to check the
   libc debug symbol support in GDB:

   * Run GDB
   * b comparator
   * c
   * backtrace
   
   Should load the separate debug files and show the backtrace.
*/

#include <stdlib.h>
#include <stdio.h>

static int comparator(const void *pleft, const void *pright)
{
  int left = *(int *)pleft;
  int right = *(int *)pright;

  return left - right;
}

int main()
{
  int v[] = { 5, 3, 2, 4, 11, 32, -5, 66 };
  int n = sizeof(v)/sizeof(v[0]);
  qsort(v, n, sizeof(v[0]), comparator);

  for (int i = 0; i < n; i++)
    {
      printf("%d ", v[i]);
    }

  printf("\n");

  return 0;
}
