`timescale 1ns/1ps

import cds_rnm_pkg::*;
import EE_pkg::*;

module flashCell (vss, bit_line, row_line);

    inout EEnet bit_line;
    inout EEnet vss;
    input wreal1driver row_line;

    parameter bit state = 0;
    parameter real scale_curr = 10e-6;

    real ibit;
    
    // The current source (sink) that remove charge from Cbit
    Isrc flash_dischrg(.P(bit_line),.N(vss),.ival(ibit));

    // Computes the discharge current as a function of gate voltage
    // current is limited to scale current
    always begin
        if (state==0) begin // Erased
            ibit = scale_curr * ($tanh(row_line + 0.5) + 1) * 0.5;
        end else begin     // Programmed
            ibit = scale_curr * ($tanh(row_line - 1.2) + 1) * 0.5;
        end
        @(row_line);
    end

endmodule
