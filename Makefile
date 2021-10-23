WORKDIR=work
STD=08
sim?=none

define compile_and_simulate
	ghdl -a --workdir=$(WORKDIR) --std=$(STD) $(1)
	$(if $(filter $(sim), $(2)),
		ghdl -a --workdir=$(WORKDIR) --std=$(STD) packages/testbench.vhd
		ghdl -a --workdir=$(WORKDIR) --std=$(STD) testbenches/clock_gen.vhd
		ghdl -a --workdir=$(WORKDIR) --std=$(STD) testbenches/$(2)_tb.vhd
		ghdl -e --workdir=$(WORKDIR) --std=$(STD) $(2)_tb
		ghdl -r --workdir=$(WORKDIR) --std=$(STD) $(2)_tb --read-wave-opt=waveforms/$(2)_tb.opt --fst=waveforms/$(2)_tb.fst
		gtkwave waveforms/$(folder)/$(2)_tb$(ext).fst
	)
endef

.PHONY: all lzss tx_acc matcher match_finder match_finder_single match_finder_iter match_finder_piped tx_acc_top rx_acc rx_acc_top

all: lzss tx_acc rx_acc

tx_acc: matcher comparator match_finder match_finder_single match_finder_iter match_finder_piped tx_acc_top
rx_acc: rx_acc_top

# LZSS package
%.vhd: lzss
	@:
lzss:
	ghdl -a --workdir=$(WORKDIR) --std=$(STD) packages/lzss.vhd

# tx_acc folder
matcher: tx_acc/matcher.vhd
	$(call compile_and_simulate,$^,$@)

comparator: tx_acc/comparator.vhd
	$(call compile_and_simulate,$^,$@)

match_finder: tx_acc/match_finder.vhd
	$(call compile_and_simulate,$^,$@)

match_finder_single: tx_acc/match_finder_single.vhd
	$(call compile_and_simulate,$^,$@)

match_finder_iter: tx_acc/match_finder_iter.vhd
	$(call compile_and_simulate,$^,$@)

match_finder_piped: tx_acc/match_finder_piped.vhd
	$(call compile_and_simulate,$^,$@)

tx_acc_top: tx_acc/tx_acc_top.vhd
	$(call compile_and_simulate,$^,$@)

# rx_acc folder
rx_acc_top: rx_acc/rx_acc_top.vhd
	$(call compile_and_simulate,$^,$@)
