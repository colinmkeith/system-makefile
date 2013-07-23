# system-makefile

A makefile that takes care of most of the mundane steps of building from a source bundle, configuring, building and installng.

It includes code to determine the archive to be used, validate against the PGP key, and checksum file and even adding user accounts leaving you free to focus on the options to be used by `./configure`.

<hr/>


## What It Is

This is a Makefile which can be installed system-wide (say /etc/system.mk). It has pre-defined targets for building, installing, etc. which are used in your Makefile, but which are configurable.

## How to Use It


The best way to use this tool is to create a Makefile with the same basename as the application. For example for Apache you get the installation bundle of:

```
httpd-2.2.25.tar.bz2
httpd-2.2.25.tar.bz2.sha1
httpd-2.2.25.tar.bz2.asc
```

and so you would create a Makefile with the name:

`httpd-2.2.25.mak`

Then you can run:

`% make -f *.mak`

And it will handle un-compressing the tar-ball, running ./configure and "make". You then run

`% make -f *.mak install`

To install.


## Example

Your Makefile could be as simple as:

`include /etc/system.mk`

However that installs your application with the standard options, and often you want to use a source installation to add custom configuration options. Accordingly you will probably want to define some options for configure. You can do this by defining the Makefile variable CONFIG_OPTS. For example:

```
CONFIG_OPTS ?= --prefix=$(INST) \
  --with-included-apr \
  --with-layout=Apache \
  --with-berkeley-db=/lib64 \
  --with-dbm=db43 \
  --disable-v4-mapped \
  --disable-ipv6 \
  --disable-userdir \
  --disable-status \
  --disable-asis \
  --disable-ext-filter \
  --enable-filter=no \
  --enable-so \
  --enable-cgi \
  --enable-suexec \
  --enable-rewrite \
  --enable-mods-shared="expires deflate headers cache mem-cache unique-id usertrack ssl" \
  --enable-static-support \
  --with-suexec-logfile=$(INST)/logs/suexec.log \
  --with-suexec-caller=web \
  --with-suexec-docroot=/usr \
  --with-suexec-uidmin=999 \
  --with-suexec-gidmin=999 \
  --with-suexec-safepath=/bin:/usr/bin:/usr/local/bin \
  --without-ldap \
  --without-pgsql \
  --without-sqlite3 \
  --without-sqlite2 \
  --without-oracle \
  --without-odbc
```


There are lots of different options to configure, including applying patches, creating user accounts and adding SysV init files.


## Makefile Targets

* *all*: untars the archive, runs patch (if defined), then make, make install and make post-install
* *$(ARCHIVEDIR)*:  untar the archive
* *build*:          'make' in the app dir
* *install*:        'make install' in the app dir
* *post-install*:   tries to do a post config
* *useradd*:        adds the user USERNAME
* *migrate*:        use make -f oldver.mak to migrate to new version


## Makefile Variables

* *ARCHIVE*
  * make will use this archive file, otherwise it will guess based on the name of the make file
* *CONFIGURE*
  * It will use this program instead of ./configure
* *CONFIG_OPTS*
  * It will pass these variables to CONFIG
* *SKIP_CS*
  * Will cause checksum searches/checks to be ignored use "SKIP_CS=1 $(MAKE) target" when calling own targets
* *SKIP_PGP*
  * Will cause PGP sig checks to be ignored see SKIP_CS
* *CFLAGS, LDFLAGS*
  * As normal
* *USE_PATCH*
  * make all will call "make patch" when running "make all" It is suggested that you define the patch target as:  "patch: $(ARCHIVEDIR)" to ensure that the source code is unarchived before patching.
* *MYCONFIGURE*
  * If defined this is the target that will be called instead of built in configure: target. See USE_PATCH Define as 0 to disable configure: target
* *MYBUILD*
  * If defined, used instead of build: target.
* *MYINSTALL*
  * If defined, used instead of install: target.
* *MYPOSTINSTALL*
  * If defined, used instead of post-install: target.  Define as 0 to disable configure: target
* *MYPOSTINSTALL_EXTRA*
  * If defined called after post-install: target
* *MYCLEAN*
  * If defined called after cleanup of logfile and archivedir to allow you to remove other files.
* *RC3S*
  * If defined symlink from this to $(INIT)
* *RC3K*
  * If defined symlink from this to $(INIT)


To add users you need to define:

* *USERNAME*
* *GROUPNAME*
* *UID*
  * _(optional)_ The UID you want to user
* *GID*
  * _(optional)_ The GID you want to use for the group if it needs creating

*Users are created with the shell /bin/false and no password for security purposes*
