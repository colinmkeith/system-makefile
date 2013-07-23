# /etc/system.mk defines the following targets by default:
#
# all: untars the archive, runs patch (if defined), then make, make install
#      and make post-install
# $(ARCHIVEDIR):  untar the archive
# build:          'make' in the app dir
# install:        'make install' in the app dir
# post-install:   tries to do a post config
# useradd:        adds the user USERNAME
# migrate:        use make -f oldver.mk to migrate to new version

# If you define the variable:
#  ARCHIVE               * make will use this archive file, otherwise it will
#                        guess based on the name of the make file
#  CONFIGURE             * It will use this program instead of ./configure
#  CONFIG_OPTS           * It will pass these variables to CONFIG
#  SKIP_CS               * Will cause checksum searches/checks to be ignored
#                        use "SKIPCS=1 $(MAKE) target" when calling own targets
#  SKIP_PGP              * Will cause PGP sig checks to be ignored see SKIP_CS
#  CFLAGS, LDFLAGS       * As normal
#  USE_PATCH             * make all will call "make patch" when running
#                        "make all" It is suggested that you define the patch
#                        target as:  "patch: $(ARCHIVEDIR)" to ensure that the
#                        source code is unarchived before patching.
#  MYCONFIGURE           * If defined this is the target that will be called
#                        instead of built in configure: target. See USE_PATCH
#                        Define as 0 to disable configure: target
#  MYBUILD               * If defined, used instead of build: target.
#  MYINSTALL             * If defined, used instead of install: target.
#  MYPOSTINSTALL         * If defined, used instead of post-install: target.
#                        Define as 0 to disable configure: target
#  MYPOSTINSTALL_EXTRA   * If defined called after post-install: target
#  MYCLEAN               * If defined called after cleanup of logfile and
#                        archivedir to allow you to remove other files.
#  RC3S                  * If defined symlink from this to $(INIT)
#  RC3K                  * If defined symlink from this to $(INIT)

# To add users you need to define:
#  USERNAME  - duh
#  GROUPNAME - duh
#
# You can also specify:
#  UID      - The UID you want to user
#  GID      - The GID you want to use for the group if it needs creating
#
# Users are created with the shell /bin/false and no password to prevent
# security problems.


# 
# #  Examples:
# ARCHIVE    ?=The archive file
# INST       ?=Install dir
# CONFIGURE   = ./configure
# CONFIG_OPTS = -q
# LDCFG      ?=$(LDCONFD)/#XXX.conf
# RC3K       ?=$(RC3D)/K#XXX
# RC3S       ?=$(RC3D)/S#XXX
# INIT       ?=$(INITD)/#XXX


#-------- Do not alter values defined below -----

INITD      =/etc/init.d
RC3D       =/etc/rc3.d
LDCONFD    =/etc/ld.so.conf.d
FILE_EXISTS=$(shell test -f $(1);echo $$?)
ADD_MAN_PAGES=$(shell $(QGREP) '^MANPATH_MAP.*$(1)' /etc/man.config; [ "$$?" == 0 ] || echo "MANPATH_MAP	$(1)		$(2)" >> /etc/man.config)

ifndef NOTARGETS


# {{{ Files to use:
CC        ?=gcc
CPP       ?=$(CC)
CP         =/bin/cp -rpf
ID        ?=/usr/bin/id
LN         =/bin/ln -s
LS         =/bin/ls
MV         =/bin/mv -f
RM         =/bin/rm -rf
GPG        =/usr/bin/gpg
SED       ?=/bin/sed
CAT       ?=/bin/cat
TAR       ?=/bin/tar
GREP      ?=/bin/grep
HEAD      ?=/usr/bin/head
SORT      ?=/bin/sort
TAIL      ?=/usr/bin/tail
CHCON     ?=/usr/bin/chcon -Rh
CHMOD     ?=/bin/chmod -R
CHOWN     ?=/bin/chown -Rh
MKDIR     ?=/bin/mkdir -p
PATCH     ?=/usr/bin/patch -p0 -N
QGREP     ?=/bin/grep -q
STRIP     ?=/usr/bin/strip
TOUCH     ?=/bin/touch
ifdef UID
  USERADD   ?=/usr/sbin/useradd  $(USERNAME)  -g $(GROUPNAME) -u $(UID) -r -s /bin/false
else
  USERADD   ?=/usr/sbin/useradd  $(USERNAME)  -g $(GROUPNAME) -r -s /bin/false
endif
ifdef GID
  GROUPADD  ?=/usr/sbin/groupadd $(GROUPNAME) -f -g $(GID) -r
else
  GROUPADD  ?=/usr/sbin/groupadd $(GROUPNAME) -f -g $(GID) -r
endif
INSTALL   ?=/usr/bin/install
LIBTOOL   ?=/usr/bin/libtool
LDCONFIG  ?=/sbin/ldconfig
CONFIGURE ?=./configure
CONTAINS  :=$(shell echo $(1) | $(QGREP) -e '$(2)'; test '$$?' '=' '0'; echo $$? )

# {{{ Some files that might not exist:
ifndef RESTORECON
  ifeq ($(call FILE_EXISTS,/sbin/restorecon),0)
    RESTORECON:=/sbin/restorecon -R
    SELINUX_FCL=/etc/selinux/targeted/contexts/files/file_contexts.local
  else
    RESTORECON:=echo "restorecon -R "
    SELINUX_FCL=/dev/null
  endif
endif

ifndef PRELINK
  ifeq ($(call FILE_EXISTS,/usr/sbin/prelink),0)
    PRELINK:=/usr/sbin/prelink
  else
    PRELINK:=echo "prelink "
  endif
endif

ifndef EXECSTACK
  ifeq ($(call FILE_EXISTS,/usr/bin/execstack),0)
    EXECSTACK:=/usr/bin/execstack
  else
    EXECSTACK:=echo "execstack "
  endif
endif

# }}}
# }}}

# {{{ Try to determine Archive if not defined:
ifeq "$(MAKECMDGOALS)" "migrate"
  $(warning "migrating. Skipping check for archive")
  MAKEFILE_NAME=$(word 1,$(MAKEFILE_LIST))
else
ifdef ARCHIVE
  ifneq ($(shell test -f $(ARCHIVE); echo $$?),0)
    ifneq ($(shell test -f $(ARCHIVE).c; echo $$?),0)
      $(error "Error using archive $(ARCHIVE)")
    endif
    $(warning "Archive found as $(ARCHIVE).c")
  endif
else
  # {{{ Check for a .tar.gz version of makefile filename
  MAKEFILE_NAME=$(word 1,$(MAKEFILE_LIST))
  TESTFILE    :=$(MAKEFILE_NAME:.mk=.tar.gz)
  ifeq ($(shell test -f $(TESTFILE); echo $$?),0)
    ARCHIVE :=$(TESTFILE)
    UNTAROPTS =-xzf
    ARCHIVEDIR :=$(MAKEFILE_NAME:.mk=)
  else
  # }}}
    # {{{ Otherwise, try .tar.bz2
    TESTFILE  :=$(MAKEFILE_NAME:.mk=.tar.bz2)
    ifeq ($(shell test -f $(TESTFILE); echo $$?),0)
      ARCHIVE :=$(TESTFILE)
      UNTAROPTS =-xjf
      ARCHIVEDIR :=$(MAKEFILE_NAME:.mk=)
    else

      # {{{ Last ditch attempt to use something, anything!
      ARCHIVE:=$(shell $(LS) -d1 *.tar.{bz2,gz} 2>/dev/null |$(SORT) |$(TAIL) -1 |xargs)
      ifeq ($(ARCHIVE),)
        $(error "Error finding archive for $(MAKEFILE_NAME)")
      endif

      ifeq ($(ARCHIVE:.tar.bz2=),$(ARCHIVE))
        UNTAROPTS ="-xzf"
        ARCHIVEDIR :=$(ARCHIVE:.tar.gz=)
      else
        UNTAROPTS ="-xjf"
        ARCHIVEDIR :=$(ARCHIVE:.tar.bz2=)
      endif
      # }}}
    endif
    # }}}
  endif

  $(warn "Using archive file: $(ARCHIVE)")
endif
endif
# }}}


# {{{ Now test if the archive is valid or not:
ifndef SKIP_CS
  ifeq ($(call FILE_EXISTS,$(ARCHIVE).md5),0)
    ARCHIVE_CS :=$(ARCHIVE).md5
    ARCHIVE_CSCMD := md5sum
  else
    ifeq ($(call FILE_EXISTS,$(ARCHIVE).sha1),0)
      TEST_SHA1SUM:=$(shell which sha1sum)
      ifneq ($(TEST_SHA1SUM),)
        ARCHIVE_CS :=$(ARCHIVE).sha1
        ARCHIVE_CSCMD := sha1sum
      endif
    endif
  endif

  ifdef ARCHIVE_CS
    _cscmd_out :=$(shell $(ARCHIVE_CSCMD) -c $(ARCHIVE_CS) | sed 's/^.*: *//')
    ifneq ($(_cscmd_out), OK)
      _current_cs := $(shell $(ARCHIVE_CSCMD) -b $(ARCHIVE))
      _file_cs :=    $(shell cat $(ARCHIVE_CS))
      $(error Archive checksum invalid. Aborting. Got:  $(_current_cs) Need: $(_file_cs)))
    endif
  else
    $(warning No checksum available for $(ARCHIVE))
  endif
endif # }}}


# {{{ Check GPG signature if present:
ifndef SKIP_PGP
  ifeq ($(call FILE_EXISTS,$(ARCHIVE).asc),0)
    ARCHIVE_SIG :=$(ARCHIVE).asc
  else
    ifeq ($(call FILE_EXISTS,$(ARCHIVE).sig),0)
      ARCHIVE_SIG :=$(ARCHIVE).sig
    else
      ifeq ($(call FILE_EXISTS,$(ARCHIVE).gpg),0)
        ARCHIVE_SIG :=$(ARCHIVE).gpg
      endif
    endif
  endif

  ifdef ARCHIVE_SIG
    _cscmd_ret :=$(shell $(GPG) --verify $(ARCHIVE_SIG) 2>/dev/null; echo $$?)

    ifneq ($(_cscmd_ret),0)
      _cscmd_out :=$(shell $(GPG) --verify $(ARCHIVE_SIG) 2>&1)
      ifeq ($(call CONTAINS,$(_cscmd_out),'public key not found'),1)
        _key :=$(shell $(ECHO) "$(_cscmd_out)" | $(SED) 's/^.*using [RD]SA key ID \([^ ]*\) .*/\1/')
        $(error Need to load PGP key $(_key): $(_cscmd_out))
      endif
      $(error GPG signature for $(ARCHIVE) failed: $(_cscmd_out))
    endif

    # $(warning GPG signature validated:)
    # $(warning $(_cscmd_out))
  else
    $(warning No GPG signature available for $(ARCHIVE))
  endif
endif
# }}}

LIB_OR_64 :=$(shell if [ -d '/usr/lib64' ]; then   echo 'lib64'; else   echo 'lib'; fi)
MACH      :=$(shell uname -m)

BERKELEYDB_DIR :=$(shell if [ -f '/usr/local/BerkeleyDB/include/db.h' ]; then   echo '/usr/local/BerkeleyDB'; elif [ -f '/usr/include/db.h' ]; then echo '/usr/include'; else echo ''; fi)
BERKELEYDB_INCDIR :=$(shell if [ -f '/usr/local/BerkeleyDB/include/db.h' ]; then   echo '/usr/local/BerkeleyDB/include'; elif [ -f '/usr/include/db.h' ]; then echo '/usr/include'; else echo ''; fi)
BERKELEYDB_LIBDIR :=$(shell if [ -f '/usr/local/BerkeleyDB/lib/libdb.so' ]; then   echo '/usr/local/BerkeleyDB/lib'; elif [ -f '/usr/lib64/libdb.so' ]; then echo '/usr/lib64/'; elif [ -f '/usr/lib/libdb.so' ]; then echo '/usr/lib'; else echo ''; fi)


ifndef LOGFILE
  LOGFILE   :=$(shell pwd)/$(ARCHIVEDIR).log
endif
LDFLAGS   ?= -L/lib64 -L/usr/lib64 -L/usr/local/lib64 -L/usr/local/lib -L/usr/local/openssl/lib -L/usr/local/BerkeleyDB/lib -L/usr/local/mysql/lib
CPPFLAGS  ?= -I/usr/local/openssl/include -I/usr/local/BerkeleyDB/include -I/usr/local/mysql/include
CFLAGS    ?= $(CPPFLAGS)
BUILDDIR  ?= $(ARCHIVEDIR)

ISUNTARRED=$(shell test -d $(ARCHIVEDIR) || echo $(ARCHIVE))


ifdef USE_PATCH
all: patch configure build
else
all: configure build
endif

.PHONY: all patch configure build install post-install useradd groupadd clean migrate

# {{{ Untar archive:
$(ARCHIVEDIR): $(ISUNTARRED)
	@$(RM) $(LOGFILE)
	@echo "=============================================="  >> $(LOGFILE)
	@echo "Unarchiving with $(TAR) $(UNTAROPTS) $(ARCHIVE)" >> $(LOGFILE)
	@echo "=============================================="  >> $(LOGFILE)
	@$(TAR) $(UNTAROPTS) $(ARCHIVE) 2>&1 >> $(LOGFILE)
	@$(TOUCH) $(ARCHIVEDIR)
# }}}


# {{{ configure - configure app
configure: $(ARCHIVEDIR)
ifdef MYCONFIGURE
  ifneq ($(MYCONFIGURE),0)
	@echo "=============================================="  >> $(LOGFILE)
	@echo "Using User defined configure routine"            >> $(LOGFILE)
	@echo "Building with \"make $(MYCONFIGURE)\""           >> $(LOGFILE)
	@echo "=============================================="  >> $(LOGFILE)
	@CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" CPPFLAGS="$(CPPFLAGS)" \
	         SKIP_CS=1 SKIP_PGP=1 \
	         PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/local/apache2/lib/pkgconfig:/usr/local/openssl/lib/pkgconfig" \
	         $(MAKE) -f $(MAKEFILE_NAME) $(MYCONFIGURE) 2>&1>> $(LOGFILE)
  endif
else
	@echo "=============================================="  >> $(LOGFILE)
	@echo "Configuring with $(CONFIGURE) $(CONFIG_OPTS)"    >> $(LOGFILE)
	@echo "=============================================="  >> $(LOGFILE)
	@cd $(BUILDDIR) && \
	         CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" CPPFLAGS="$(CPPFLAGS)" \
	         PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/local/apache2/lib/pkgconfig:/usr/local/openssl/lib/pkgconfig" \
	         $(CONFIGURE) $(CONFIG_OPTS) 2>&1               >> $(LOGFILE)
endif
# }}}


# {{{ build: - General 'make'
build: $(ARCHIVEDIR)
ifdef MYBUILD
	@echo "=============================================="  >> $(LOGFILE)
	@echo "Using User defined build routine"                >> $(LOGFILE)
	@echo "Building with \"make $(MYBUILD)\""               >> $(LOGFILE)
	@echo "=============================================="  >> $(LOGFILE)
	@CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" CPPFLAGS="$(CPPFLAGS)" \
	         SKIP_CS=1 SKIP_PGP=1 \
	         PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/local/apache2/lib/pkgconfig:/usr/local/openssl/lib/pkgconfig" \
	         $(MAKE) -f $(MAKEFILE_NAME) $(MYBUILD) 2>&1    >> $(LOGFILE)
else
	@echo "=============================================="  >> $(LOGFILE)
	@echo "Building with \"make -C $(ARCHIVEDIR)\""         >> $(LOGFILE)
	@echo "=============================================="  >> $(LOGFILE)
	@CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" CPPFLAGS="$(CPPFLAGS)" \
	         PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/local/apache2/lib/pkgconfig:/usr/local/openssl/lib/pkgconfig" \
	         $(MAKE) -C $(BUILDDIR) 2>&1                    >> $(LOGFILE)
endif
# }}}


# {{{ test: - General 'make'
test: $(ARCHIVEDIR)
ifdef MYTEST
	@echo "=============================================="  >> $(LOGFILE)
	@echo "Using User defined test routine"                 >> $(LOGFILE)
	@echo "Testing with \"make $(MYTEST)\""                 >> $(LOGFILE)
	@echo "=============================================="  >> $(LOGFILE)
	@CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" CPPFLAGS="$(CPPFLAGS)" \
	         SKIP_CS=1 SKIP_PGP=1 \
	         PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/local/apache2/lib/pkgconfig:/usr/local/openssl/lib/pkgconfig" \
	         $(MAKE) -f $(MAKEFILE_NAME) $(MYTEST) 2>&1     >> $(LOGFILE)
else
	@echo "=============================================="  >> $(LOGFILE)
	@echo "Testing with \"make -C $(ARCHIVEDIR)\""          >> $(LOGFILE)
	@echo "=============================================="  >> $(LOGFILE)
	@CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" CPPFLAGS="$(CPPFLAGS)" \
	         PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/local/apache2/lib/pkgconfig:/usr/local/openssl/lib/pkgconfig" \
	         $(MAKE) -C $(BUILDDIR) test 2>&1               >> $(LOGFILE)
endif
# }}}


# {{{ install - Install app
install: $(ARCHIVEDIR)
ifdef MYINSTALL
	@echo "=============================================="  >> $(LOGFILE)
	@echo "Using User defined install routine"              >> $(LOGFILE)
	@echo "Building with \"make $(MYINSTALL)\""             >> $(LOGFILE)
	@echo "=============================================="  >> $(LOGFILE)
	@CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" CPPFLAGS="$(CPPFLAGS)" \
	         SKIP_CS=1 SKIP_PGP=1 \
	         PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/local/apache2/lib/pkgconfig:/usr/local/openssl/lib/pkgconfig" \
	         $(MAKE) -f $(MAKEFILE_NAME) $(MYINSTALL) 2>&1  >> $(LOGFILE)
else
	@echo "=============================================="  >> $(LOGFILE)
	@echo "Building with \"make -C $(ARCHIVEDIR) install\"" >> $(LOGFILE)
	@echo "=============================================="  >> $(LOGFILE)
	@CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" CPPFLAGS="$(CPPFLAGS)" \
	         SKIP_CS=1 SKIP_PGP=1 \
	         PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/local/apache2/lib/pkgconfig:/usr/local/openssl/lib/pkgconfig" \
	         $(MAKE) -C $(BUILDDIR) install 2>&1            >> $(LOGFILE)
endif
	@CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" CPPFLAGS="$(CPPFLAGS)" \
	         SKIP_CS=1 SKIP_PGP=1 \
	         PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/local/apache2/lib/pkgconfig:/usr/local/openssl/lib/pkgconfig" \
	         $(MAKE) -f $(MAKEFILE_NAME) post-install 2>&1  >> $(LOGFILE)
# }}}


# {{{ post-install
post-install: $(ARCHIVEDIR)
ifdef MYPOSTINSTALL
	@echo "=============================================="  >> $(LOGFILE)
	@echo "Using User defined post-install routine"         >> $(LOGFILE)
	@echo "Building with \"make $(MYPOSTINSTALL)\""         >> $(LOGFILE)
	@echo "=============================================="  >> $(LOGFILE)
	@CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" CPPFLAGS="$(CPPFLAGS)" \
	         SKIP_CS=1 SKIP_PGP=1 \
	         PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/local/apache2/lib/pkgconfig:/usr/local/openssl/lib/pkgconfig" \
	         $(MAKE) -f $(MAKEFILE_NAME) $(MYPOSTINSTALL) 2>&1 >> $(LOGFILE)
else
	@echo "=============================================="  >> $(LOGFILE)
	@echo "Commencing post-install"                         >> $(LOGFILE)
	@echo "=============================================="  >> $(LOGFILE)
  ifdef RC3S
	@-[ -f $(RC3S) ]    || (cd $(RC3D);  $(LN) $(INIT) $(RC3S));
  endif
  ifdef RC3K
	@-[ -f $(RC3K) ]    || (cd $(RC3D);  $(LN) $(INIT) $(RC3K));
  endif
  ifdef MYPOSTINSTALL_EXTRA
	@CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" CPPFLAGS="$(CPPFLAGS)" \
	         SKIP_CS=1 SKIP_PGP=1 \
	         PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/local/apache2/lib/pkgconfig:/usr/local/openssl/lib/pkgconfig" \
	 $(MAKE) -f $(MAKEFILE_NAME) $(MYPOSTINSTALL_EXTRA) 2>&1 >> $(LOGFILE)
  endif
endif
# }}}


# {{{ useradd - Add a user to the DB
useradd:
ifdef USERNAME
	@echo "=============================================="  >> $(LOGFILE)
	@echo "Creating user account $(USERNAME)"               >> $(LOGFILE)
	@echo "=============================================="  >> $(LOGFILE)
  ifneq ($(shell $(QGREP) ^$(USERNAME): /etc/passwd 2>&1>/dev/null; echo $$?),0)
    ifneq ($(shell $(QGREP) $(GROUPNAME) /etc/group 2>&1>/dev/null; echo $$?),0)
		@echo "Need to create group $(GROUPNAME) first ... ">> $(LOGFILE)
		@$(GROUPADD) 2>&1                                   >> $(LOGFILE)
    endif
	@$(USERADD) 2>&1                                        >> $(LOGFILE)
  else
	@echo "Username $(USERNAME) exists"                     >> $(LOGFILE)
  endif
else
	$(error useradd called but no USERNAME defined)
endif
# }}}


# {{{ clean:
clean:
	@$(RM) $(ARCHIVEDIR)
	@$(RM) $(LOGFILE)
ifdef MYCLEAN
	@CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" CPPFLAGS="$(CPPFLAGS)" \
	 SKIP_CS=1 SKIP_PGP=1 \
	 $(MAKE) -f $(MAKEFILE_NAME) $(MYCLEAN) 2>&1            >> $(LOGFILE)
endif
# }}}


# {{{ migrate:
migrate:
	@-read -e -p "Enter new program + version (E.g. $(MAKEFILE_NAME:.mk=)): " newprog; \
	for file in $(MAKEFILE_NAME:.mk=).*; \
	do \
	 new=`echo $$file | sed "s/^$(MAKEFILE_NAME:.mk=)/$$newprog/"`; \
	 [ -f $$new ] && continue; \
     if [ -d .svn ]; then \
        svn rename $$file $$new || mv $$file $$new; \
     else \
        mv $$file $$new; \
     fi; \
	done
# }}}

add_local_selinux_context:
	@-echo "$(SELINUX_FC)" >> $(SELINUX_FCL)
	@-$(SORT) -u $(SELINUX_FCL) > $(SELINUX_FCL).tmp
	@-$(MV) $(SELINUX_FCL).tmp $(SELINUX_FCL)

endif
