`timescale 1ns/1ps

import cds_rnm_pkg::*;
import EE_pkg::*;

module dsm (vdd, vss, bit_line, chrg_trim, comp_vref, clk, en, out);

    inout EEnet vdd, vss;
    input EEnet bit_line;
    input logic [7:0] chrg_trim;
    input logic clk;
    input logic en;
    input wreal1driver comp_vref;
    output logic [8:0] out;

    parameter real Cchrg = 200e-15;     // Capacitor value to charge Cbit
    parameter real Cbit = 500e-15;      // Capacitor value Cbit
    parameter real vthp = 0.5;          // Source folower PMOS threshold voltage
    parameter real clkFreq = 100e6;     // Comparator clock frequency
    parameter real ts = 1/(2*clkFreq);  // sample time
    parameter real vddMin = 1.6;        // Minimum supply voltage
    parameter real vddMax = 2.0;        // Maximum supply voltage
    parameter real vssMax = 0.1;        // Maximum ground voltgae
    parameter real vrefLsb = 2.0e-3;    // LSB vref controlling Cchrg charge

    logic vddGood; logic vddGoodFilt;   // Signals for checking supply range
    logic vssGood; logic vssGoodFilt;   // Signals for checking ground range
    logic supplyOK;                     // Signal for checking all supplies range
    logic [8:0] count;                  // Count the number of Cchrg charge injections
    logic enInt;                        // Internal integer to represent enable input signal

    real ichrg;                         // Cchrg current value
    real icap;                          // The current inject to Cbit from Cchrg
    real vref;                          // The reference voltage that controlled Cchrg charge

    // Current source charging Cbit capacitor
    CapGeq #(.c(Cbit)) cBit(.P(bit_line));
    Isrc_ideal iCup(.P(bit_line),.N(vss),.ival(ichrg));

    // Check supply range
    always begin
        vddGood = ((vdd.V >= vddMin) && (vdd.V <= vddMax));
        @ (vdd.V);
    end
    assign #(0.5e-9) vddGoodFilt = vddGood;

    // Check ground range
    always begin
        vssGood = ((vss.V <= vssMax) && (vss.V >= -vssMax));
        @ (vss.V);
    end
    assign #(0.5e-9) vssGoodFilt = vssGood;

    // Check if both supplies are in range
    assign supplyOK = vssGoodFilt && vddGoodFilt;

    // Enable pin
    always begin
        if (en === 1'b1) enInt = 1;
        else enInt = 0;
        @ (en);
    end

    // Vref value as a function of chrg_trim input
    always begin
        if ((supplyOK === 1'b1) && (^chrg_trim !== 1'bx) && (^chrg_trim !== 1'bz))
            vref = vrefLsb * chrg_trim;
        @ ((supplyOK===1'b1) or chrg_trim);
    end

    // Calculate charge / current inject to Cbit
    always begin
        icap = Cchrg * (vdd.V - vref - vthp) / (ts);
        @(vdd.V,vref);
    end

    // Inject charge to Cbit as a function ov comparator output
    // Counts the number of charge injection to cbit
    always @ (posedge clk)
        if ((enInt === 1'b1) && (supplyOK === 1'b1)) begin
            if (bit_line.V > comp_vref) begin
                ichrg = 0.0;
            end else begin
                ichrg = -1.0 * icap;
                count++;
            end
        end else begin
            ichrg = 0.0;
            count = 0;
        end
    
        // Charge is injected for half cycle only
    always @ (negedge clk)
        ichrg = 0.0;

    assign out = count;

endmodule
