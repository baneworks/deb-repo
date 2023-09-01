#!/usr/bin/env make

img = debian:bullseye
cnt = debian
user = mtain
group = users

name = sh-dpkg
version = "0.0.1~alpha"

dc_running := $(shell docker ps -q -f ancestor=$(img) -f name=$(cnt) | wc -l)
ifeq ($(dc_running),1)
docker_start:
	@echo ""
docker_stop:
	@echo ""
else
docker_start:
	@echo "starting docker"
	docker start "$(cnt)"
docker_stop:
	@echo "stopping docker"
	docker stop "$(cnt)"
endif

home = /home/$(user)/$(name)
dirs = bin share debian doc
bin = sh-dpkg
libs = bkend.sh breq.sh bspec.sh debver.sh docker.sh globals.sh lcrun.sh log.sh stage.sh tag.sh task.sh test.sh
debian = 'rules' 'control' 'changelog'
docs = '../README.md'

dt_fmt = '%a, %d %b %Y %H:%M:%S %z'
gl_fmt ="$(name) ($(version)) bullseye; urgency=low%n%n  * %s%n%n -- %an <%ae>  %ad"

changelog:
	LC_ALL=C git log --date=format:$(dt_fmt) --format=$(gl_fmt) -1 > ../debian/changelog

clean: docker_start clean_body docker_stop
clean_body:
	docker exec -u $(user):$(group) -w "/home/$(user)" $(cnt) sh -c "rm -rf $(name)"
	rm -f ../tmp/$(bin)
	docker exec -u $(user):$(group) -w "/home/$(user)" $(cnt) sh -c "rm -f /home/$(user)/$(name)_$(version)_amd64.*"

configure:
	cat ../bin/$(bin) | \
	sed 's/LIBS="$$SHDPKG_LIBS"/LIBS="\/usr\/share\/$(name)"/' | \
	sed 's/SHDPKG_USEDOCKER=1; SHDPKG_LCRUN=""/SHDPKG_USEDOCKER=""; SHDPKG_LCRUN=1/' \
	> ../tmp/$(bin)

lib_docs = $(filter-out test.sh tag.sh, $(libs))

clear_doc: $(lib_docs:.sh=.md)
	rm ../docs/$<

build_doc: $(lib_docs:.sh=.md)

$(lib_docs:.sh=.md): %.md: %.sh
	shdoc < ../lib/$< > ../docs/$@

copy: docker_start copy_body docker_stop
copy_body: clean_body configure $(home) $(dirs) $(bin) $(libs) $(debian) $(docs)
$(home):
	docker exec -u $(user):$(group) -w "/home/$(user)" $(cnt) mkdir $@
$(dirs):
	docker exec -u $(user):$(group) -w "$(home)" "$(cnt)" mkdir -p $@
$(bin):
	docker cp ../tmp/$@ $(cnt):"$(home)/bin/"
$(libs):
	docker cp ../lib/$@ $(cnt):"$(home)/share/"
$(debian):
	docker cp ../debian/$@ $(cnt):"$(home)/debian/"
$(docs):
	docker cp $@ $(cnt):"$(home)/doc/"

deb: docker_start copy_body docker_stop
	docker exec -u $(user):$(group) -w "$(home)/debian" "$(cnt)" chmod u+x rules
	docker exec -u $(user):$(group) -w "$(home)" "$(cnt)" dpkg-buildpackage -us -uc
	docker cp $(cnt):"/home/$(user)/$(name)_$(version)_amd64.deb" ../

default: deb