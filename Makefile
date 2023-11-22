# Build Helios as follows:
#
# - make               -- create non-SGX no-debug-log manifest
# - make SGX=1         -- create SGX no-debug-log manifest
# - make SGX=1 DEBUG=1 -- create SGX debug-log manifest
#
# Any of these invocations clones Helios' git repository and builds Helios in
# default configuration.
#
# Use `make clean` to remove Gramine-generated files and `make distclean` to
# additionally remove the cloned Helios git repository.

################################# CONSTANTS ###################################

# directory with arch-specific libraries, used by Helios
# the below path works for Debian/Ubuntu; for CentOS/RHEL/Fedora, you should
# overwrite this default like this: `ARCH_LIBDIR=/lib64 make`
ARCH_LIBDIR ?= /lib/$(shell $(CC) -dumpmachine)

ENCLAVE_SIZE ?= 1G

HELIOS_BRANCH ?= master
HELIOS_REPO ?= https://github.com/a16z/helios

SRCDIR = src/

ifeq ($(DEBUG),1)
GRAMINE_LOG_LEVEL = debug
else
GRAMINE_LOG_LEVEL = error
endif

.PHONY: all
all: helios helios.manifest
ifeq ($(SGX),1)
all: helios.manifest.sgx helios.sig
endif

############################## HELIOS EXECUTABLE ###############################

# Clone Helios
$(SRCDIR)/README.md:
	git clone -b $(HELIOS_BRANCH) $(HELIOS_REPO) $(SRCDIR)

# Build Helios
$(SRCDIR)/target/release/helios: $(SRCDIR)/README.md
	cd $(SRCDIR) && cargo build --release

################################ HELIOS MANIFEST ###############################

# The template file is a Jinja2 template and contains almost all necessary
# information to run Helios under Gramine / Gramine-SGX. We create
# helios.manifest (to be run under non-SGX Gramine) by replacing variables
# in the template file using the "gramine-manifest" script.

RA_TYPE		?= dcap
ISVPRODID	?= 0
ISVSVN		?= 0

helios.manifest: helios.manifest.template helios
	gramine-manifest \
		-Dlog_level=$(GRAMINE_LOG_LEVEL) \
		-Darch_libdir=$(ARCH_LIBDIR) \
		-Dentrypoint="./helios" \
		-Dra_type=$(RA_TYPE) \
		-Disvprodid=$(ISVPRODID) \
		-Disvsvn=$(ISVSVN) \
		-Denclave_size=$(ENCLAVE_SIZE) \
		$< >$@

# Manifest for Gramine-SGX requires special "gramine-sgx-sign" procedure. This
# procedure measures all Helios trusted files, adds the measurement to the
# resulting manifest.sgx file (among other, less important SGX options) and
# creates helios.sig (SIGSTRUCT object).

# Make on Ubuntu <= 20.04 doesn't support "Rules with Grouped Targets" (`&:`),
# see the gramine helloworld example for details on this workaround.
helios.manifest.sgx helios.sig: sgx_sign
	@:

.INTERMEDIATE: sgx_sign
sgx_sign: helios.manifest
	gramine-sgx-sign \
		--manifest $< \
		--output $<.sgx

########################### COPIES OF EXECUTABLES #############################

# Helios build process creates the final executable as build/bin/helios. For
# simplicity, copy it into our root directory.

helios: $(SRCDIR)/target/release/helios
	cp $< $@

############################## RUNNING TESTS ##################################

.PHONY: check
check: all
	./run-tests.sh > TEST_STDOUT 2> TEST_STDERR
	@grep -q "Success 1/4" TEST_STDOUT
	@grep -q "Success 2/4" TEST_STDOUT
	@grep -q "Success 3/4" TEST_STDOUT
	@grep -q "Success 4/4" TEST_STDOUT
ifeq ($(SGX),1)
	@grep -q "Success SGX quote" TEST_STDOUT
endif

################################## CLEANUP ####################################

.PHONY: clean
clean:
	$(RM) helios *.manifest *.manifest.sgx *.sig *.args OUTPUT* *.PID TEST_STDOUT TEST_STDERR

.PHONY: distclean
distclean: clean
	$(RM) -rf $(SRCDIR)
