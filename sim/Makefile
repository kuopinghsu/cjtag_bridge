FLAGS = -O3 -cc --timing -Wall -Wno-STMTDLY -Wno-UNUSED -Wno-PINCONNECTEMPTY \
        --trace-fst --Mdir sim_cc --build --exe sim_main.cpp

FILELIST = ../rtl/cjtag_bridge.v cjtag_bridge_tb.v
TARGET   = sim

all: $(TARGET)

$(TARGET):
	verilator $(FLAGS) -o $(TARGET) $(FILELIST)
	sim_cc/sim

clean:
	@$(RM) -rf sim_cc wave.*

