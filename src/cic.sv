module cic #(
    parameter int signed        register_width   = 10,
    parameter int signed        decimation_factor  = 10

) (
    // Clock and Reset
    input  logic        clk_i,
    input  logic        rstn_i,
    
    input logic modulator_data_i,

    output logic [register_width-1:0] cic_o,
    output logic [register_width:0] integrator_o,
    output logic [register_width:0] comb_o,
    output logic [decimation_factor-1:0] decimation_counter_o,
    output logic cic_clk_o
);

    logic signed [register_width:0] integrator_reg;
    logic signed [register_width:0] comb_reg;
    logic [decimation_factor-1:0] decimation_counter_reg;
    logic signed [register_width:0] cic_reg;

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            integrator_reg <= '0;
            decimation_counter_reg <= '0;
            cic_reg <= '0;
            comb_reg <= '0;
        end else begin
            integrator_reg <= integrator_reg + (modulator_data_i? 1 : 0);
            if (decimation_counter_reg == 0) begin
                cic_reg <= integrator_reg - comb_reg;
                comb_reg <= integrator_reg;
            end
            decimation_counter_reg <= decimation_counter_reg + 1;
        end
    end

    assign cic_o = cic_reg[register_width]? {register_width{1'b1}} : cic_reg[register_width-1:0];
    assign integrator_o = integrator_reg;
    assign comb_o = comb_reg;
    assign cic_clk_o = decimation_counter_reg[decimation_factor-1];
    assign decimation_counter_o = decimation_counter_reg;

endmodule



    