`ifdef VERILATOR
module cjtag_bridge_tb (
    input clk_gen,
    input rstn_gen
);
`else
module cjtag_bridge_tb();
`endif // VERILATOR

`ifndef VERILATOR
    // generators
    reg  clk_gen;
    reg  rstn_gen;
`endif

    wire cjtag_tmsc_rd;
    reg  cjtag_tckc;
    reg  cjtag_tmsc;

    //  Device-under-Test
    cjtag_bridge cjtag_bridge_inst (
        // global control
        .clk_i(clk_gen),
        .rstn_i(rstn_gen),

        // cJTAG
        .tckc_i(cjtag_tckc),
        .tmsc_i(cjtag_tmsc),
        .tmsc_o(cjtag_tmsc_rd),
        .tmsc_oe_o( ),

        // JTAG
        .tck_o( ),
        .tdi_o( ),
        .tdo_i(1'b0),
        .tms_o( ),

        // Debugging (for testing only)
        .db_tck_falling_o( ),
        .db_tck_rising_o( )
    );

`ifndef VERILATOR
// Generators
initial begin
    clk_gen  = 1'b0;
    rstn_gen = 1'b0;

    #60 rstn_gen = 1'b1;
end

always #10 clk_gen = ~clk_gen;
`endif

// dump VCD
initial begin
    `ifdef VERILATOR
    $dumpfile("wave.fst");
    `else
    $dumpfile("wave.vcd");
    `endif
    $dumpvars(0, cjtag_bridge_tb);
end

/////////////////////////////////////////////////////////////////
// Stimulus
/////////////////////////////////////////////////////////////////
always begin: stimulus
    integer i;
    cjtag_tckc <= 1'b0; cjtag_tmsc <= 1'b0;
    #200 ;

    // protocol reset: 10 TMSC edges while TCKC is kept high
    cjtag_tckc <= 1'b1; cjtag_tmsc <= 1'b0;
    #100 ;

    for ( i = 0 ; i <= 9 ; i = i + 1 ) begin 
        cjtag_tmsc <= ~cjtag_tmsc;
        #100 ;
    end

    // send >= 22 dummy clocks to reset 4-wire JTAG
    cjtag_tmsc <= 1'b1;
    #100 ;
    for ( i = 0 ; i <= 44 ; i = i + 1 ) begin 
        cjtag_tckc <= ~cjtag_tckc;
        #100 ;
    end

    // WriteTMS(0x00, 1)
    // TAP reset
    cjtag_tckc <= 1'b0; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b1; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b0; cjtag_tmsc <= 1'b0;
    #100 ;

    // escape sequence selection 
    cjtag_tckc <= 1'b1; cjtag_tmsc <= 1'b0;
    #100 ;

    for ( i = 0 ; i <= 6 ; i = i + 1 ) begin 
        cjtag_tmsc <= ~( cjtag_tmsc);
        #100 ;
    end

    // WriteTMS(0x0C, 4)
    // write 4-bit OAC
    cjtag_tckc <= 1'b0; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b1; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b0; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b1; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b0; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b1; cjtag_tmsc <= 1'b1;
    #100 ;
    cjtag_tckc <= 1'b0; cjtag_tmsc <= 1'b1;
    #100 ;
    cjtag_tckc <= 1'b1; cjtag_tmsc <= 1'b1;
    #100 ;
    cjtag_tckc <= 1'b0; cjtag_tmsc <= 1'b1;
    #100 ;

    // WriteTMS(0x08, 4)
    // write 4-bit EC
    cjtag_tckc <= 1'b0; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b1; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b0; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b1; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b0; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b1; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b0; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b1; cjtag_tmsc <= 1'b1;
    #100 ;
    cjtag_tckc <= 1'b0; cjtag_tmsc <= 1'b1;
    #100 ;

    // WriteTMS(0x00, 4)
    // write 4-bit CP
    cjtag_tckc <= 1'b0; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b1; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b0; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b1; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b0; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b1; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b0; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b1; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b0; cjtag_tmsc <= 1'b0;
    #100 ;

    #200 ;

    // JTAG transmission
    //  TDI=1, TMS=1
    cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b1;
    #100 ;
    cjtag_tckc <= 1'b0; cjtag_tmsc <= 1'b1;
    #100 ;
    cjtag_tckc <= 1'b1;
    #100 ;
    cjtag_tckc <= 1'b0; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b1;
    #100 ;
    cjtag_tckc <= 1'b0;
    #100 ;

    // JTAG transmission
    //  TDI=0, TMS=0
    cjtag_tmsc <= 1'b1;
    #100 ;
    cjtag_tckc <= 1'b1;
    #100 ;
    cjtag_tckc <= 1'b0; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b1;
    #100 ;
    cjtag_tckc <= 1'b0; cjtag_tmsc <= 1'b0;
    #100 ;
    cjtag_tckc <= 1'b1;
    #100 ;
    cjtag_tckc <= 1'b0;
    #100 ;

    $display("simulation done.");
    $finish(1);
end

endmodule

