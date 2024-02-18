#include "Vcjtag_bridge.h"
#include "verilated.h"

#define RESOLUTION 10

vluint64_t main_time = 0;

double sc_time_stamp(void)
{
    return main_time;
}

int main(int argc, char** argv)
{
    Verilated::commandArgs(argc,argv);
    Verilated::traceEverOn(true);

    Vcjtag_bridge *top = new Vcjtag_bridge;

    top->rstn_gen = 0;
    top->clk_gen  = 0;

    while (!Verilated::gotFinish()) {
        if (main_time > 6*RESOLUTION) {
            top->rstn_gen = 1;
        }
        if ((main_time % RESOLUTION) == 1) {
            top->clk_gen = 1;
        }
        if ((main_time % RESOLUTION) == (RESOLUTION / 2 + 1)) {
            top->clk_gen = 0;
        }
        top->eval();
        main_time++;
    }

    top->final();
    delete top;

    return 0;
}

