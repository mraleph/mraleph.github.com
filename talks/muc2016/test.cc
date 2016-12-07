
#include <stdint.h>
#include <stdarg.h>
#include <stdio.h>

intptr_t bar(const intptr_t* names, intptr_t argc, ...) {
  static const intptr_t kArgC = 6;
  static const intptr_t EXPECTED[kArgC] = {1, 2, 3, 4, 5, 6};
  static const intptr_t DEFAULT[kArgC] = {1, 2, 3, 4, 5, 6};

  intptr_t args[kArgC];

  const intptr_t *arg = names;
  const intptr_t *last = names + argc;

  va_list vl;
  va_start(vl, argc);
  for (intptr_t i = 0; i < kArgC && arg != last; i++) {
    if (*arg == EXPECTED[i]) {
      args[i] = va_arg(vl, intptr_t);
      arg++;
    } else {
      args[i] = DEFAULT[i];
    }
  }
  va_end(vl);

  return args[0] + args[5];
}

int main(int argc, char* argv[]) {
  static const intptr_t NAMES[] = {1, 6};
  printf("%ld\n", bar(NAMES, 2, (intptr_t)1, (intptr_t)-6));
  return 0;
}