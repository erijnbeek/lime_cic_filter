/*
 * Copyright (c) 2025 Emil Rijnbeek
 * SPDX-License-Identifier: Apache-2.0
 */

module tt_um_lime_cic_filter (

    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset

);

    // =============================================================================
    // INPUT SIGNAL ASSIGNMENTS
    // =============================================================================
    // ui_in[0]     : Modulator data input (sigma-delta bitstream)
    // ui_in[1]     : CIC filter select (0=First order CIC, 1=Second order CIC)
    // ui_in[2]     : uio as input for testing
    // ui_in[3]     : Reserved
    // ui_in[7:4]   : Debug select (4-bit selector for debugging options)
    //
    // =============================================================================
    // SPLIT DEBUG SYSTEM OVERVIEW
    // =============================================================================
    // The debug system is split based on ui_in[1]:
    // - When ui_in[1] = 0: Debug signals relate only to the First Order CIC
    // - When ui_in[1] = 1: Debug signals relate only to the Second Order CIC
    // Debug selector uses ui_in[7:4] (4-bit selector for 16 debug modes per filter)
    // This provides dedicated debugging for each filter independently.
    // =============================================================================

    // First Order CIC
    localparam int REGISTER_WIDTH1 = 10;
    localparam int DECIMATION_FACTOR = 10;

    // Internal signals for CIC
    logic [REGISTER_WIDTH1-1:0] cic_output_data;
    logic [REGISTER_WIDTH1:0] cic_integrator;
    logic [REGISTER_WIDTH1:0] cic_comb;
    logic [DECIMATION_FACTOR-1:0] cic_decimation_counter;
    logic cic_output_clk;

    // Instantiate first order CIC module
    cic #(
        .register_width(REGISTER_WIDTH1)
        , .decimation_factor(DECIMATION_FACTOR)
    ) u_cic_first_order (
        .clk_i(clk)
        , .rstn_i(rst_n)
        , .modulator_data_i(ui_in[0])  // Use LSB of ui_in as modulator data
        , .cic_o(cic_output_data)
        , .integrator_o(cic_integrator)  // Not connected for now
        , .comb_o(cic_comb)  // Not connected for now
        , .decimation_counter_o(cic_decimation_counter)  // Not connected for now
        , .cic_clk_o(cic_output_clk)   // Not connected for now
    );


    // Second Order CIC Instance
    localparam int REGISTER_WIDTH2 = 20;

    // Internal signals for CIC
    logic [REGISTER_WIDTH2-1:0] cic2_output_data;
    logic cic2_output_clk;

    // Internal signals for CIC2 debug outputs
    logic [REGISTER_WIDTH2:0] cic2_integrator1;
    logic [REGISTER_WIDTH2:0] cic2_integrator2;
    logic [REGISTER_WIDTH2:0] cic2_comb1;
    logic [REGISTER_WIDTH2:0] cic2_comb2;
    logic [DECIMATION_FACTOR-1:0] cic2_decimation_counter;

    // Instantiate second order CIC module
    cic2 #(
        .register_width(REGISTER_WIDTH2)
        , .decimation_factor(DECIMATION_FACTOR)
    ) u_cic_second_order (
        .clk_i(clk)
        , .rstn_i(rst_n)
        , .modulator_data_i(ui_in[0])  // Use LSB of ui_in as modulator data
        , .cic_data_o(cic2_output_data)
        , .cic_clk_o(cic2_output_clk)
        // Debug outputs
        , .integrator1_o(cic2_integrator1)
        , .integrator2_o(cic2_integrator2)
        , .comb1_o(cic2_comb1)
        , .comb2_o(cic2_comb2)
        , .decimation_counter_o(cic2_decimation_counter)
    );

    // =============================================================================
    // OUTPUT ASSIGNMENTS
    // =============================================================================
    // Debug select signal: ui_in[7:4] (4-bit selector for 16 debug modes)
    // CIC filter select: ui_in[1] (0=First order CIC, 1=Second order CIC)
    //
    // FIRST ORDER CIC DEBUG MODES (ui_in[1] = 0):
    // 0x0: CIC1 output data (top 8 bits on uo_out, LSB bits + clk on uio_out)
    // 0x1: CIC1 integrator output (top 8 bits on uo_out, LSB bits + clk on uio_out)
    // 0x2: CIC1 comb output (top 8 bits on uo_out, LSB bits + clk on uio_out)
    // 0x3: Input monitoring (ui_in on both uo_out and uio_out)
    // 0x4: IO monitoring (uio_in on uo_out, constant 0 on uio_out)
    // 0x5: Status and control signals (rst_n, clk, ena, cic_output_clk on both outputs)
    // 0x6-0x7: Reserved for CIC1 future debug options
    // 0x8: CIC1 output data LSB (LSB bits + clk on uo_out, reserved on uio_out)
    // 0x9: CIC1 integrator LSB (LSB bits + clk on uo_out, reserved on uio_out)
    // 0xA: CIC1 comb LSB (LSB bits + clk on uo_out, reserved on uio_out)
    // 0xB: CIC1 decimation counter (MSBs on uo_out, LSBs + clk on uio_out)
    // 0xC-0xE: Reserved for CIC1 future debug options
    // 0xF: Reserved (0x4B on uo_out, 0x00 on uio_out)
    //
    // SECOND ORDER CIC DEBUG MODES (ui_in[1] = 1):
    // 0x0: CIC2 output data MSB (top 8 bits on uo_out, mid bits + clk on uio_out)
    // 0x1: CIC2 output data LSB (bits [14:7] on uo_out, bits [6:0] + clk on uio_out)
    // 0x2: CIC2 integrator1 register MSB (top 8 bits on uo_out, mid bits + clk on uio_out)
    // 0x3: CIC2 integrator1 register LSB (bits [14:7] on uo_out, bits [6:0] + clk on uio_out)
    // 0x4: CIC2 integrator2 register MSB (top 8 bits on uo_out, mid bits + clk on uio_out)
    // 0x5: CIC2 integrator2 register LSB (bits [14:7] on uo_out, bits [6:0] + clk on uio_out)
    // 0x6: CIC2 comb1 register MSB (top 8 bits on uo_out, mid bits + clk on uio_out)
    // 0x7: CIC2 comb1 register LSB (bits [14:7] on uo_out, bits [6:0] + clk on uio_out)
    // 0x8: CIC2 comb2 register MSB (top 8 bits on uo_out, mid bits + clk on uio_out)
    // 0x9: CIC2 comb2 register LSB (bits [14:7] on uo_out, bits [6:0] + clk on uio_out)
    // 0xA: Reserved for CIC2 future debug options
    // 0xB: CIC2 decimation counter (MSBs on uo_out, LSBs + clk on uio_out)
    // 0xC: Reserved (0x4C on uo_out, 0x00 on uio_out)
    // 0xD: Reserved (0x69 on uo_out, 0x00 on uio_out)
    // 0xE: Reserved (0x6D on uo_out, 0x00 on uio_out)
    // 0xF: Reserved (0x65 on uo_out, 0x00 on uio_out)
    // =============================================================================

    logic [3:0] debug_select;
    assign debug_select = ui_in[7:4];
    logic [7:0] debug_uo_out;
    logic [7:0] debug_uio_out;

    // Debug signal multiplexer for uo_out
    always_comb
        case ({ui_in[1], debug_select})
            // First Order CIC Debug Modes (ui_in[1] = 0)
            {1'b0, 4'h0}: debug_uo_out = cic_output_data[REGISTER_WIDTH1-1:REGISTER_WIDTH1-8];          // CIC1 output data MSB
            {1'b0, 4'h1}: debug_uo_out = cic_integrator[REGISTER_WIDTH1:REGISTER_WIDTH1-7];    // CIC1 integrator MSB
            {1'b0, 4'h2}: debug_uo_out = cic_comb[REGISTER_WIDTH1:REGISTER_WIDTH1-7];          // CIC1 comb MSB
            {1'b0, 4'h3}: debug_uo_out = {ui_in};                                                       // Input bits monitoring
            {1'b0, 4'h4}: debug_uo_out = {uio_in};                                                      // Input IO monitoring
            {1'b0, 4'h5}: debug_uo_out = {rst_n, clk, ena, 4'b0, cic_output_clk};                       // Status and control signals
            {1'b0, 4'h6}: debug_uo_out = 8'b0;                                                          // Reserved
            {1'b0, 4'h7}: debug_uo_out = 8'b0;                                                          // Reserved
            {1'b0, 4'h8}: debug_uo_out = {cic_output_data[REGISTER_WIDTH1-9:REGISTER_WIDTH1-10], 5'b0, cic_output_clk};   // CIC1 output data LSB
            {1'b0, 4'h9}: debug_uo_out = {cic_integrator[REGISTER_WIDTH1-8:REGISTER_WIDTH1-10], 4'b0, cic_output_clk};  // CIC1 integrator LSB
            {1'b0, 4'hA}: debug_uo_out = {cic_comb[REGISTER_WIDTH1-8:REGISTER_WIDTH1-10], 4'b0, cic_output_clk};  // CIC1 comb LSB
            {1'b0, 4'hB}: debug_uo_out = cic_decimation_counter[DECIMATION_FACTOR-1:2];                 // Decimation Counter MSBs
            {1'b0, 4'hC}: debug_uo_out = 8'b0;                                                          // Reserved
            {1'b0, 4'hD}: debug_uo_out = 8'b0;                                                          // Reserved
            {1'b0, 4'hE}: debug_uo_out = 8'b0;                                                          // Reserved
            {1'b0, 4'hF}: debug_uo_out = 8'h4B;                                                          // Reserved

            // Second Order CIC Debug Modes (ui_in[1] = 1)
            {1'b1, 4'h0}: debug_uo_out = cic2_output_data[REGISTER_WIDTH2-1:REGISTER_WIDTH2-8];      // CIC2 output data MSB
            {1'b1, 4'h1}: debug_uo_out = cic2_output_data[14:7];                                     // CIC2 output data LSB
            {1'b1, 4'h2}: debug_uo_out = cic2_integrator1[REGISTER_WIDTH2:REGISTER_WIDTH2-7];  // CIC2 integrator1 MSB
            {1'b1, 4'h3}: debug_uo_out = cic2_integrator1[14:7];                                 // CIC2 integrator1 LSB    
            {1'b1, 4'h4}: debug_uo_out = cic2_integrator2[REGISTER_WIDTH2:REGISTER_WIDTH2-7];  // CIC2 integrator2 MSB
            {1'b1, 4'h5}: debug_uo_out = cic2_integrator2[14:7];                                 // CIC2 integrator2 LSB
            {1'b1, 4'h6}: debug_uo_out = cic2_comb1[REGISTER_WIDTH2:REGISTER_WIDTH2-7];        // CIC2 comb1 MSB
            {1'b1, 4'h7}: debug_uo_out = cic2_comb1[14:7];                                       // CIC2 comb1 LSB 
            {1'b1, 4'h8}: debug_uo_out = cic2_comb2[REGISTER_WIDTH2:REGISTER_WIDTH2-7];        // CIC2 comb2 MSB
            {1'b1, 4'h9}: debug_uo_out = cic2_comb2[14:7];                                       // CIC2 comb2 LSB
            {1'b1, 4'hA}: debug_uo_out = 8'b0;                                                          // Reserved
            {1'b1, 4'hB}: debug_uo_out = cic2_decimation_counter[DECIMATION_FACTOR-1:2];                 // Decimation Counter MSBs
            {1'b1, 4'hC}: debug_uo_out = 8'h4c;                                                          // Reserved
            {1'b1, 4'hD}: debug_uo_out = 8'h69;                                                          // Reserved
            {1'b1, 4'hE}: debug_uo_out = 8'h6d;                                                          // Reserved
            {1'b1, 4'hF}: debug_uo_out = 8'h65;                                                          // Reserved
            // Invalid selections
            default: debug_uo_out = ui_in[1] ? 8'h0F : 8'hF0;                                         // Invalid selection indicators
        endcase

    // Debug signal multiplexer for uio_out  
    always_comb
        case ({ui_in[1], debug_select})
            // First Order CIC Debug Modes (ui_in[1] = 0)
            {1'b0, 4'h0}: debug_uio_out = {cic_output_data[REGISTER_WIDTH1-9:REGISTER_WIDTH1-10], 5'b0, cic_output_clk};   // CIC1 output data LSB + clk
            {1'b0, 4'h1}: debug_uio_out = {cic_integrator[REGISTER_WIDTH1-8:REGISTER_WIDTH1-10], 4'b0, cic_output_clk};  // CIC1 integrator LSB + clk
            {1'b0, 4'h2}: debug_uio_out = {cic_comb[REGISTER_WIDTH1-8:REGISTER_WIDTH1-10], 4'b0, cic_output_clk};  // CIC1 comb LSB + clk
            {1'b0, 4'h3}: debug_uio_out = {ui_in};                                        // Input monitoring
            {1'b0, 4'h4}: debug_uio_out = 8'h00;                                                                       // Reserved (IO input mode)
            {1'b0, 4'h5}: debug_uio_out = {rst_n, clk, ena, 4'b0, cic_output_clk};                                       // Status and control signals
            {1'b0, 4'h6}: debug_uio_out = 8'h00;                                                                              // Reserved
            {1'b0, 4'h7}: debug_uio_out = 8'h00;                                                                              // Reserved
            {1'b0, 4'h8}: debug_uio_out = 8'h00;                                                                              // Reserved
            {1'b0, 4'h9}: debug_uio_out = 8'h00;                                                                              // Reserved
            {1'b0, 4'hA}: debug_uio_out = 8'h00;                                                                              // Reserved
            {1'b0, 4'hB}: debug_uio_out = {cic_decimation_counter[1:0], 5'b0, cic_output_clk};                                // Decimation Counter LSBs
            {1'b0, 4'hC}: debug_uio_out = 8'h00;                                                                              // Reserved
            {1'b0, 4'hD}: debug_uio_out = 8'h00;                                                                              // Reserved
            {1'b0, 4'hE}: debug_uio_out = 8'h00;                                                                              // Reserved
            {1'b0, 4'hF}: debug_uio_out = 8'h00;                                                                              // Reserved

            // Second Order CIC Debug Modes (ui_in[1] = 1)
            {1'b1, 4'h0}: debug_uio_out = {cic2_output_data[REGISTER_WIDTH2-9:REGISTER_WIDTH2-15], cic2_output_clk};     // CIC2 output data mid bits + clk
            {1'b1, 4'h1}: debug_uio_out = {cic2_output_data[6:0], cic2_output_clk};                                      // CIC2 output data LSB + clk
            {1'b1, 4'h2}: debug_uio_out = {cic2_integrator1[REGISTER_WIDTH2-8:REGISTER_WIDTH2-14], cic2_output_clk}; // CIC2 integrator1 mid bits + clk
            {1'b1, 4'h3}: debug_uio_out = {cic2_integrator1[6:0], cic2_output_clk};                                  // CIC2 integrator1 LSB + clk
            {1'b1, 4'h4}: debug_uio_out = {cic2_integrator2[REGISTER_WIDTH2-8:REGISTER_WIDTH2-14], cic2_output_clk}; // CIC2 integrator2 mid bits + clk
            {1'b1, 4'h5}: debug_uio_out = {cic2_integrator2[6:0], cic2_output_clk};                                  // CIC2 integrator2 LSB + clk
            {1'b1, 4'h6}: debug_uio_out = {cic2_comb1[REGISTER_WIDTH2-8:REGISTER_WIDTH2-14], cic2_output_clk};       // CIC2 comb1 mid bits + clk
            {1'b1, 4'h7}: debug_uio_out = {cic2_comb1[6:0], cic2_output_clk};                                        // CIC2 comb1 LSB + clk
            {1'b1, 4'h8}: debug_uio_out = {cic2_comb2[REGISTER_WIDTH2-8:REGISTER_WIDTH2-14], cic2_output_clk};       // CIC2 comb2 mid bits + clk
            {1'b1, 4'h9}: debug_uio_out = {cic2_comb2[6:0], cic2_output_clk};                                        // CIC2 comb2 LSB + clk
            {1'b1, 4'hA}: debug_uio_out = 8'h00;                                                                              // Reserved
            {1'b1, 4'hB}: debug_uio_out = {cic2_decimation_counter[1:0], 5'b0, cic2_output_clk};                              // Decimation Counter LSBs
            {1'b1, 4'hC}: debug_uio_out = 8'h00;                                                                              // Reserved
            {1'b1, 4'hD}: debug_uio_out = 8'h00;                                                                              // Reserved
            {1'b1, 4'hE}: debug_uio_out = 8'h00;                                                                              // Reserved
            {1'b1, 4'hF}: debug_uio_out = 8'h00;                                                                              // Reserved
            // Invalid selections
            default: debug_uio_out = ui_in[1] ? 8'h0F : 8'hF0;                                         // Invalid selection indicators
        endcase

    
    // Output assignments
    assign uio_oe = ((debug_select==4'h4) & ui_in[2]) ? 8'b00 : 8'hFF;  // All bidirectional pins as outputs (unless testing input)
    assign uo_out = debug_uo_out;
    assign uio_out = debug_uio_out;

endmodule