uis := $(wildcard *.ui)
qrcs := $(wildcard *.qrc)

all: t1 t2 compress
t1: $(uis)
	@for name in $^; do rbuic4 $$name > `echo $$name | awk -F '\.ui' '{ print $$1 }' 2> /dev/null`.rb; echo "Running rbuic on $$name"; done
	
t2: $(qrcs)
	@for name in $^; do rbrcc $$name > `echo $$name | awk -F '\.qrc' '{ print $$1 }' 2> /dev/null`.rb; echo "Running rbrcc on $$name"; done

compress:
	@ruby ./compress-resource.rb

clean: c1 c2
c1: $(uis)
	@for name in $^; do rm -f `echo $$name | awk -F '\.ui' '{ print $$1 }' 2> /dev/null`.rb; done
c2: $(qrcs)
	@for name in $^; do rm -f `echo $$name | awk -F '\.qrc' '{ print $$1 }' 2> /dev/null`.rb; done
