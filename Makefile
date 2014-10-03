
ARCH = $(shell uname -m)

ifeq ($(ARCH), x86_64)
  HEAP = 100000
else
  HEAP = 6000
endif

test: test/c-stats.so
	mit-scheme --compiler --heap $(HEAP) --stack 2000 --batch-mode --no-init-file \
	  --eval '(set! load/suppress-loading-message? #t)' \
	  --eval '(begin (load "load") (load "test/load") (run-tests-and-exit))'

test/c-stats.so: test/c-stats.c Makefile
	gcc -I/home/axch/mit-scheme-9.2/src/microcode/ \
	  -I/home/axch/mit-scheme-9.1.1/src/microcode/ \
	  `gsl-config --cflags` -shared \
	  -o test/c-stats.so test/c-stats.c \
	   `gsl-config --libs` -Wall -Wextra -Werror -O2 -fPIC -DCOMPILE_AS_MODULE

.PHONY: test
