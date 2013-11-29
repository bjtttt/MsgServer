EBIN := ../ebin

%.beam: %.erl
        erlc +debug_info -W -o $(EBIN) $<
        
MODS = $(shell ls *.erl)

compile: ${MODS:%.erl=%.beam}
        @echo "make clean - clean up"
        
all: compile

clean:
        rm -rf  $(EBIN)/*.beam 