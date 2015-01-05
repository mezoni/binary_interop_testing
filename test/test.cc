#include <stdio.h>
#include <stdint.h>
#include <stdarg.h>

#ifdef _WIN32
#include "windows.h"
#else
#include <unistd.h>
#endif

typedef struct _S0 {
  char* cp1;  
} S0, *PS0;

typedef struct _S1 {
  char c1;
  int i1;
  S0 s1;
} S1, *PS1;

#if defined _MSC_VER
#define EXTERN_C extern "C" __declspec( dllexport )
#else
#define EXTERN_C extern "C"
#endif

EXTERN_C int sizeof_S1() {  
  return sizeof(S1);
}

EXTERN_C S1 test_S1_S1(S1 s) {
  s.c1++;
  s.i1++;
  return s;
}

EXTERN_C void test_void_pS1(PS1 s, char* cp) {
  s->c1++;
  s->i1++;
  s->s1.cp1 = cp;
}

EXTERN_C void test_void_void() {  
}

int main() {  
}
