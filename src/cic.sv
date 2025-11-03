module cic #(
    parameter int signed        register_width   = 10,
    parameter int signed        decimation_factor  = 10

) (
    // Clock and Reset
    input  logic        clk_i,
    input  logic        rstn_i,
    
    input logic modulator_data_i,

    output logic [register_width-1:0] cic_output_o,
    output logic [register_width:0] integrator_output_o,
    output logic [register_width:0] comb_output_o,
    output logic cic_output_clk_o
);

    logic signed [register_width:0] integrator_reg;
    logic signed [register_width:0] comb_reg;
    logic [decimation_factor-1:0] decimation_counter;
    logic signed [register_width:0] cic_output_int;

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            integrator_reg <= '0;
            decimation_counter <= '0;
            cic_output_int <= '0;
            comb_reg <= '0;
        end else begin
            integrator_reg <= integrator_reg + (modulator_data_i? 1 : 0);
            if (decimation_counter == 0) begin
                cic_output_int <= integrator_reg - comb_reg;
                comb_reg <= integrator_reg;
            end
            decimation_counter <= decimation_counter + 1;
        end
    end

    assign cic_output_o = cic_output_int[register_width]? {register_width{1'b1}} : cic_output_int[register_width-1:0];
    assign integrator_output_o = integrator_reg;
    assign comb_output_o = comb_reg;
    assign cic_output_clk_o = decimation_counter[decimation_factor-1];

endmodule



    