// #################################################################################################
// # <<cjtag_bridge>> cJTAG to 4-Wire JTAG Bridge                                                  #
// # ********************************************************************************************* #
// # Converts a debugger probe's compact JTAG (cJTAG) port into a 4-wire IEEE 1149.1 JTAG port.    #
// # This bridge only supports "OScan1" cJTAG format.                                              #
// #                                                                                               #
// # IMPORTANT                                                                                     #
// # * TCKC (tckc_i) input frequency must not exceed 1/5 of clk_i frequency                        #
// # * all 4-wire JTAG signals are expected to be sync to clk_i                                    #
// # ********************************************************************************************* #
// # BSD 3-Clause License                                                                          #
// #                                                                                               #
// # Copyright (c) 2021, Stephan Nolting. All rights reserved.                                     #
// #                                                                                               #
// # Redistribution and use in source and binary forms, with or without modification, are          #
// # permitted provided that the following conditions are met:                                     #
// #                                                                                               #
// # 1. Redistributions of source code must retain the above copyright notice, this list of        #
// #    conditions and the following disclaimer.                                                   #
// #                                                                                               #
// # 2. Redistributions in binary form must reproduce the above copyright notice, this list of     #
// #    conditions and the following disclaimer in the documentation and/or other materials        #
// #    provided with the distribution.                                                            #
// #                                                                                               #
// # 3. Neither the name of the copyright holder nor the names of its contributors may be used to  #
// #    endorse or promote products derived from this software without specific prior written      #
// #    permission.                                                                                #
// #                                                                                               #
// # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS   #
// # OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF               #
// # MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE    #
// # COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,     #
// # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE #
// # GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED    #
// # AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING     #
// # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED  #
// # OF THE POSSIBILITY OF SUCH DAMAGE.                                                            #
// # ********************************************************************************************* #
// # https://github.com/stnolting/cjtag_bridge                                 (c) Stephan Nolting #
// # Convert VHDL to Verilog by Kuoping Hsu                                                        #
// #################################################################################################

module cjtag_bridge (
    // global control
    input       clk_i,       // main clock
    input       rstn_i,      // main reset, async, low-active

    // cJTAG (from debug probe)
    input       tckc_i,      // tap clock
    input       tmsc_i,      // tap data input
    output      tmsc_o,      // tap data output
    output      tmsc_oe_o,   // tap data output enable (tri-state driver)

    // JTAG (to device)
    output      tck_o,       // tap clock
    output      tdi_o,       // tap data input
    input       tdo_i,       // tap data input
    output      tms_o,       // tap mode select

    // Debugging (for testing only)
    output      db_tck_rising_o,
    output      db_tck_falling_o
);

    // activation sequence commands
    // NOTE: these are bit-reversed as the LSB is sent first!!
    localparam CMD_OAC_C  = 4'b0011;        // online activation code
    localparam CMD_EC_C   = 4'b0001;        // extension code
    localparam CMD_CP_C   = 4'b0000;        // check packet

    // I/O synchronization
    reg [2:0]   io_sync_tckc_ff;
    reg [2:0]   io_sync_tmsc_ff;
    wire        io_sync_tckc_rising;
    wire        io_sync_tckc_falling;
    wire        io_sync_tmsc_rising;
    wire        io_sync_tmsc_falling;

    // reset
    reg [2:0]   reset_cnt;
    reg [1:0]   reset_sreg;
    wire        reset_fire;

    // status
    reg         status_online;
    reg [11:0]  status_sreg;

    // control FSM
    localparam  S_NTDI  = 2'b00;
    localparam  S_TMS   = 2'b01;
    localparam  S_TDO   = 2'b10;

    reg [1:0]   ctrl_state;
    reg         ctrl_tck;
    reg         ctrl_tdi;
    reg         ctrl_tms;

    // debugging signals
    reg [1:0]debug_tck_sync;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// cJTAG Input Signal Synchronizer
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
always @(posedge clk_i)
begin: input_synchronizer
    if ( clk_i ) begin
        io_sync_tckc_ff <= { io_sync_tckc_ff[1:0], tckc_i };
        io_sync_tmsc_ff <= { io_sync_tmsc_ff[1:0], tmsc_i };
    end
end

// clock
assign io_sync_tckc_rising  = (io_sync_tckc_ff[2:1] == 2'b01);
assign io_sync_tckc_falling = (io_sync_tckc_ff[2:1] == 2'b10);

// data
assign io_sync_tmsc_rising  = (io_sync_tmsc_ff[2:1] == 2'b01);
assign io_sync_tmsc_falling = (io_sync_tmsc_ff[2:1] == 2'b10);

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Reset Controller
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
always @( negedge rstn_i or posedge clk_i)
begin: bridge_reset
    if ( !rstn_i ) begin
        reset_cnt  <= 'd0;
        reset_sreg <= 2'b01;    // internal reset after bitstream upload
    end else begin 
        if ( clk_i ) begin
            // edge counter
            if ( ( io_sync_tckc_rising == 1'b1 ) || ( io_sync_tckc_falling == 1'b1 ) )  begin // reset on any TCKC edge
                reset_cnt <= 'd0;
            end else begin 
                if ( ( reset_cnt != 3'b111 ) && // saturate
                     ( ( io_sync_tmsc_rising == 1'b1 ) || ( io_sync_tmsc_falling == 1'b1 ) ) ) begin // increment on any TMSC edge
                    reset_cnt <= reset_cnt + 1'b1;
                end
            end

            // reset edge detector
            reset_sreg[1] <= reset_sreg[0];

            if ( reset_cnt == 3'b111 ) begin
                reset_sreg[0] <= 1'b1;
            end else begin 
                reset_sreg[0] <= 1'b0;
            end
        end
    end
end

// fire reset *once*
assign reset_fire = (reset_sreg == 2'b01);

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Bridge Activation Control
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
always @(negedge rstn_i or posedge clk_i)
begin : bridge_status
    if ( !rstn_i ) begin
        status_online <= 1'b0;
        status_sreg   <= 'd0;
    end else begin 
        if ( clk_i ) begin
            if ( reset_fire ) begin // sync reset
                status_online <= 1'b0;
                status_sreg   <= 'd0;
            end else begin 
                if ( !status_online ) begin
                    if ( io_sync_tckc_rising ) begin
                        status_sreg <= { status_sreg[10:0], io_sync_tmsc_ff[1] }; // data is transmitted LSB-first
                    end

                    if ( ( status_sreg[11:8] == CMD_OAC_C ) && // check activation code
                         ( status_sreg[ 7:4] == CMD_EC_C  ) &&
                         ( status_sreg[ 3:0] == CMD_CP_C  ) &&
                         ( io_sync_tckc_falling == 1'b1 ) ) begin
                        status_online <= 1'b1;
                    end
                end
            end
        end
    end
end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Bridge Transmission Control
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
always @(negedge rstn_i or posedge clk_i)
begin: bridge_control
    if ( !rstn_i) begin
        ctrl_state <= S_NTDI;
        ctrl_tck   <= 1'b0;
        ctrl_tdi   <= 1'b0;
        ctrl_tms   <= 1'b0;
    end else begin 
        if ( clk_i ) begin
            if ( !status_online ) begin // reset while offline
                ctrl_state <= S_NTDI;
                ctrl_tck   <= 1'b0;
                ctrl_tdi   <= 1'b0;
                ctrl_tms   <= 1'b0;
            end else begin 
                // FSM
                case ( ctrl_state ) 
                    S_NTDI: begin // sample inverse TDI and clear clock
                        if ( io_sync_tckc_rising ) begin
                            ctrl_tdi <=  ~io_sync_tmsc_ff[1];
                        end
                        if ( io_sync_tckc_falling ) begin
                            ctrl_state <= S_TMS;
                        end
                    end

                    S_TMS: begin // sample TMS
                        if ( io_sync_tckc_rising ) begin
                            ctrl_tms <= io_sync_tmsc_ff[1];
                        end
                        if ( io_sync_tckc_falling ) begin
                            ctrl_state <= S_TDO;
                        end
                    end

                    S_TDO: begin // output TDO and set clock
                        if ( io_sync_tckc_falling ) begin
                            ctrl_state <= S_NTDI;
                        end
                    end

                    default : begin
                        ctrl_state <= S_NTDI;
                    end
                endcase

                // JTAG clock control
                if ( ctrl_state == S_TDO ) begin
                    if ( io_sync_tckc_rising ) begin
                        ctrl_tck <= 1'b1;
                    end else begin 
                        if ( io_sync_tckc_falling ) begin
                            ctrl_tck <= 1'b0;
                        end
                    end
                end

            end
        end
    end
end

// IO control
assign tck_o = !status_online ? io_sync_tckc_ff[1] : ctrl_tck;
assign tms_o = !status_online ? io_sync_tmsc_ff[1] : ctrl_tms;
assign tdi_o = !status_online ? 1'b0               : ctrl_tdi;

// tri-state control
assign tmsc_o = tdo_i; // FIXME: synchronize tdo_i?
assign tmsc_oe_o = (ctrl_state == S_TDO);

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Debugging Stuff
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
always @(negedge rstn_i or posedge clk_i)
begin: debug_control
    if ( !rstn_i ) begin
        debug_tck_sync <= 2'b00;
    end else begin 
        if ( clk_i ) begin
            debug_tck_sync[1] <= debug_tck_sync[0];

            if ( !status_online ) begin
                debug_tck_sync[0] <= io_sync_tckc_ff[1];
            end else begin 
                debug_tck_sync[0] <= ctrl_tck;
            end
        end
    end
end

// edge detector
assign db_tck_rising_o  = (debug_tck_sync[1:0] == 2'b01);
assign db_tck_falling_o = (debug_tck_sync[1:0] == 2'b10);

endmodule
