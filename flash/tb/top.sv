`timescale 1ns/1ps

import cds_rnm_pkg::*;
import EE_pkg::*;

`define erased 0
`define programmed 1

module top;

    EEnet bit_line;
    EEnet vss;
    EEnet vdd;

    logic [7:0] chrg_trim;
    logic [8:0] out;

    logic en;
    bit clk;

    real comp_vref;
    real vdd_v, vss_v;
    real ibit;
    real row_line;

    parameter bit state = `programmed;
    parameter real Cchrg = 100e-15;
    parameter real vthp = 0.5;
    parameter real vrefLsb = 2.0e-3;
    parameter real clkFreq = 100e6;
    parameter real ts = 1 / (2*clkFreq);

    assign vss = '{vss_v,0.0,0.01};
    assign vdd = '{vdd_v,0.0,0.01};

    always #(ts*1s) clk = ~clk;

    dsm #(.Cchrg(Cchrg)) dsm (
        .vdd(vdd),
        .vss(vss),
        .bit_line(bit_line),
        .chrg_trim(chrg_trim),
        .comp_vref(comp_vref),
        .clk(clk),
        .en(en),
        .out(out)
    );

    flashCell #(.state(state)) flashCell (
        .bit_line(bit_line),
        .vss(vss),
        .row_line(row_line)
    );

    initial begin
        comp_vref=0.0;
        chrg_trim=0.0;
        vdd_v=0.0;
        vss_v=0.0;
        row_line = 5.0;

        repeat (6) @ (posedge clk);          // Add some delay before startup
        vdd_v = 1.8;                         // Turn on supplies

        repeat (1) @ (posedge clk);
        chrg_trim = 147;                     // Set Cchrg charge value
        comp_vref = 0.6;                     // Set comparator value
        row_line = 0.0;                      // Sense bit_line cell

        repeat (1) @ (posedge clk);
        en=1'b1;                             // Enable circuit (comparison)

        repeat (512) @ (posedge clk);
        ibit = real'(out/(2*512.0));
        ibit *= expected_Chrg_charge();

        $display("\n*******************************************");
        $display("For row_line voltage:       %.3fV\nsensed bit_line current:    %.3fuA\nexpected bit_lined current: %.3fuA\nCchrg cap charge current:   %.3fuA",
            row_line,
            1e6*ibit,
            1e6*expected_flash_current(.state(state),.row_line(row_line)),
            1e6*expected_Chrg_charge);
        $display("*******************************************\n");

        repeat (10) @ (posedge clk);
        $stop;

    end

    function real expected_flash_current (bit state, real row_line);
        if (state==`erased) begin // Erased
            return 10e-6 * ($tanh(row_line + 0.5) + 1) * 0.5;
        end else begin     // Programmed
            return 10e-6 * ($tanh(row_line - 1.2) + 1) * 0.5;
        end
    endfunction

    function real expected_Chrg_charge();
        return Cchrg * (vdd.V - vrefLsb*chrg_trim - vthp) / (ts);
    endfunction

endmodule
