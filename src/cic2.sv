module cic2 #(
    parameter int         register_width   = 20,
    parameter int         decimation_factor  = 10

) (
    // Clock and Reset
    input  logic        clk_i,
    input  logic        rstn_i,
    
    input logic modulator_data_i,
    
    output logic [register_width-1:0] cic_data_o,
    output logic cic_clk_o,


    // Debugging
    output logic [register_width:0] integrator1_o,
    output logic [register_width:0] integrator2_o,
    output logic [register_width:0] comb1_o,
    output logic [register_width:0] comb2_o
);

    logic [register_width:0] integrator1_reg;
    logic [register_width:0] integrator2_reg;
    logic [register_width:0] comb1_reg;
    logic [register_width:0] comb2_reg;
    logic [decimation_factor-1:0] decimation_counter_reg;
    logic [register_width:0] cic_reg;

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            integrator1_reg <= '0;
            integrator2_reg <= '0;
            comb1_reg <= '0;
            comb2_reg <= '0;
            decimation_counter_reg <= '0;
            cic_reg <= '0;
        end else begin
            integrator1_reg <= integrator1_reg + (modulator_data_i? 1 : 0);
            integrator2_reg <= integrator2_reg + integrator1_reg;
            if (decimation_counter_reg == 0) begin
                // Decimated part, running on f_clk/decimation_factor
                // Downsampling and comb stages
                comb1_reg <= integrator2_reg;
                comb2_reg <= integrator2_reg - comb1_reg;
                cic_reg <= integrator2_reg - comb1_reg - comb2_reg;
            end
            decimation_counter_reg <= decimation_counter_reg + 1;
        end
    end

    assign cic_data_o = cic_reg[register_width]? {register_width{1'b1}} : cic_reg[register_width-1:0];
    assign cic_clk_o = decimation_counter_reg[decimation_factor-1];

    assign integrator1_o = integrator1_reg;
    assign integrator2_o = integrator2_reg;
    assign comb1_o = comb1_reg;
    assign comb2_o = comb2_reg;

endmodule



    