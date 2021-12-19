# :electric_plug: Compact-JTAG to 4-Wire JTAG Bridge

[![license](https://img.shields.io/github/license/stnolting/cjtag_bridge)](https://github.com/stnolting/cjtag_bridge/blob/main/LICENSE)

* [Top Entity](#Top-Entity)
* [Simulation](#Simulation)
* [Hardware Utilization](#Hardware-Utilization)
* [Resources](#Resources)

This bridge implements a simple converter to use _compact JTAG_ ("cJTAG") probes with IEEE 1149.1 4-wire JTAG device.
cJTAG only uses two wires: a uni-directional clock generated by the probe and a bi-directional data signal.

:information_source: This bridge only supports the **OScan1** cJTAG format yet.

:warning: This project is still _work-in-progress_.


## Top Entity

The top entity is [`rtl/cjtag_bridge.vhd`](https://github.com/stnolting/cjtag_bridge/blob/main/rtl/cjtag_bridge.vhd):

```vhdl
entity cjtag_bridge is
  port (
    -- global control --
    clk_i     : in  std_ulogic; -- main clock
    rstn_i    : in  std_ulogic; -- main reset, async, low-active
    -- cJTAG (from debug probe) --
    tckc_i    : in  std_ulogic; -- tap clock
    tmsc_i    : in  std_ulogic; -- tap data input
    tmsc_o    : out std_ulogic; -- tap data output
    tmsc_oe_o : out std_ulogic; -- tap data output enable (tri-state driver)
    -- JTAG (to device) --
    tck_o     : out std_ulogic; -- tap clock
    tdi_o     : out std_ulogic; -- tap data input
    tdo_i     : in  std_ulogic; -- tap data output
    tms_o     : out std_ulogic  -- tap mode select
  );
end cjtag_bridge;
```

:information_source: The cJTAG clock frequency (TCKS signal) must not exceed 1/5 of the main clock (`clk_i` signal) frequency.

:information_source: All 4-wire JTAG signals are expected to be sync to `clk_i` (same clock domain).

### Hardware Requirements

The bridge requires a module-external tri-state driver for the off-chip TMSC signal (`tmsc`), which handles the module's
`tmsc_i`, `tmsc_o` and `tmsc_oe_o` signals:

```vhdl
-- TMSC tri-state driver --
tmsc   <= tmsc_o when (tmsc_oe_o = '1') else 'Z';
tmsc_i <= tmsc;
```

:warning: Better add a "panic resistor" into the bi-directional TMSC line - just to be safe.


## Simulation

The projects provides a very simple testbench to test the basic IO functions
([`sim/cjtag_bridge_tb.vhd`](https://github.com/stnolting/cjtag_bridge/blob/main/sim/cjtag_bridge_tb.vhd)).
It can be simulated by GHDL via the provides script:

```
cjtag_bridge/sim$ sh ghdl.sh
```

The simulation will run for 1ms using a 100MHz clock. The waveform data is stored to `sim/cjtag_bridge.ghw`
so it can be viewed using _gtkwave_:

```
cjtag_bridge/sim$ gtkwave cjtag_bridge.ghw
```


## Hardware Utilization

:construction: TODO :construction:


## Resources

* [MIPS® cJTAG Adapter User’s Manual](https://s3-eu-west-1.amazonaws.com/downloads-mips/mips-documentation/login-required/mips_cjtag_adapter_users_manual.pdf)
* [https://sudonull.com/post/106128-We-disassemble-the-2-wire-JTAG-protocol](https://sudonull.com/post/106128-We-disassemble-the-2-wire-JTAG-protocol)
* [https://wiki.segger.com/J-Link_cJTAG_specifics](https://wiki.segger.com/J-Link_cJTAG_specifics)
