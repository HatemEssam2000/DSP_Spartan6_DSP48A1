// ============================================================================
// Generic Parametric Pipeline Register Module
// ============================================================================
module Pipeline_Module #(
    parameter INPUT_SIZE = 8,
    parameter RSTTYPE    = "SYNC", // "SYNC" or "ASYNC"
    parameter PIPELINE   = 1       // 1 = Registered, 0 = Direct Bypass
)(
    input  wire [INPUT_SIZE-1:0] in_port,
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  ce,
    output wire [INPUT_SIZE-1:0] out_Port
);

    reg [INPUT_SIZE-1:0] reg_out;

    generate 
        if (RSTTYPE == "ASYNC") begin : g_async
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    reg_out <= {INPUT_SIZE{1'b0}};
                end else if (ce) begin
                    reg_out <= in_port;
                end
            end
        end else begin : g_sync
            always @(posedge clk) begin
                if (rst) begin
                    reg_out <= {INPUT_SIZE{1'b0}};
                end else if (ce) begin
                    reg_out <= in_port;
                end
            end
        end
    endgenerate

    // Selection mux: output registered value if PIPELINE is enabled, else bypass
    assign out_Port = (PIPELINE) ? reg_out : in_port;

endmodule


// ============================================================================
// Top-Level DSP48A1 Module
// ============================================================================
module DSP48A1 #(
    parameter A0REG       = 0,
    parameter A1REG       = 1,
    parameter B0REG       = 0,
    parameter B1REG       = 1,
    parameter CREG        = 1,
    parameter DREG        = 1,
    parameter MREG        = 1,
    parameter PREG        = 1,
    parameter CARRYINREG  = 1,
    parameter CARRYOUTREG = 1,
    parameter OPMODEREG   = 1,
    parameter CARRYINSEL  = "OPMODE5",   // "OPMODE5" or "CARRYIN"
    parameter B_INPUT     = "DIRECT",    // "DIRECT" or "CASCADE"
    parameter RSTTYPE     = "SYNC"       // "SYNC" or "ASYNC"
)(
    input  wire [17:0] A,
    input  wire [17:0] B,
    input  wire [17:0] D,
    input  wire [47:0] C,
    input  wire        CLK,
    input  wire        CARRYIN,
    input  wire [7:0]  OPMODE,
    input  wire [17:0] BCIN,
    input  wire [47:0] PCIN,

    input  wire RSTA, RSTB, RSTM, RSTP, RSTC, RSTD, RSTCARRYIN, RSTOPMODE,
    input  wire CEA,  CEB,  CEM,  CEP,  CEC,  CED,  CECARRYIN,  CEOPMODE,

    output wire [17:0] BCOUT,
    output wire [47:0] PCOUT,
    output wire [47:0] P,
    output wire [35:0] M,
    output wire        CARRYOUT,
    output wire        CARRYOUTF
);

    // ------------------------------------------------------------------------
    // Stage 1 Pipeline Registers: D, B0, A0, C, OPMODE, CARRYIN
    // ------------------------------------------------------------------------
    wire [17:0] b_src = (B_INPUT == "CASCADE") ? BCIN : B;

    wire [17:0] d0;
    wire [17:0] b0;
    wire [17:0] a0;
    wire [47:0] c0;
    wire [7:0]  opmode0;
    wire        cyi0;

    Pipeline_Module #(.INPUT_SIZE(18), .RSTTYPE(RSTTYPE), .PIPELINE(DREG)) 
        D_REG (.in_port(D), .out_Port(d0), .clk(CLK), .rst(RSTD), .ce(CED));

    Pipeline_Module #(.INPUT_SIZE(18), .RSTTYPE(RSTTYPE), .PIPELINE(B0REG)) 
        B0_REG (.in_port(b_src), .out_Port(b0), .clk(CLK), .rst(RSTB), .ce(CEB));

    Pipeline_Module #(.INPUT_SIZE(18), .RSTTYPE(RSTTYPE), .PIPELINE(A0REG)) 
        A0_REG (.in_port(A), .out_Port(a0), .clk(CLK), .rst(RSTA), .ce(CEA));

    Pipeline_Module #(.INPUT_SIZE(48), .RSTTYPE(RSTTYPE), .PIPELINE(CREG)) 
        C_REG (.in_port(C), .out_Port(c0), .clk(CLK), .rst(RSTC), .ce(CEC));

    Pipeline_Module #(.INPUT_SIZE(8), .RSTTYPE(RSTTYPE), .PIPELINE(OPMODEREG)) 
        OPMODE_REG (.in_port(OPMODE), .out_Port(opmode0), .clk(CLK), .rst(RSTOPMODE), .ce(CEOPMODE));

    Pipeline_Module #(.INPUT_SIZE(1), .RSTTYPE(RSTTYPE), .PIPELINE(CARRYINREG)) 
        CYI_REG (.in_port(CARRYIN), .out_Port(cyi0), .clk(CLK), .rst(RSTCARRYIN), .ce(CECARRYIN));

    // ------------------------------------------------------------------------
    // Pre-adder / Pre-subtracter Stage (D +/- B)
    // ------------------------------------------------------------------------
    wire [17:0] preadder_out = opmode0[6] ? (d0 - b0) : (d0 + b0);
    wire [17:0] b1_in        = opmode0[4] ? preadder_out : b0;

    // ------------------------------------------------------------------------
    // Stage 2 Pipeline Registers: A1, B1
    // ------------------------------------------------------------------------
    wire [17:0] a1;
    wire [17:0] b1;

    Pipeline_Module #(.INPUT_SIZE(18), .RSTTYPE(RSTTYPE), .PIPELINE(A1REG)) 
        A1_REG (.in_port(a0), .out_Port(a1), .clk(CLK), .rst(RSTA), .ce(CEA));

    Pipeline_Module #(.INPUT_SIZE(18), .RSTTYPE(RSTTYPE), .PIPELINE(B1REG)) 
        B1_REG (.in_port(b1_in), .out_Port(b1), .clk(CLK), .rst(RSTB), .ce(CEB));

    assign BCOUT = b1;

    // ------------------------------------------------------------------------
    // Multiplier & Concatenation (D:A:B) Stage
    // ------------------------------------------------------------------------
    wire signed [35:0] mult_comb = $signed(a1) * $signed(b1);
    wire        [47:0] dab_comb  = {d0[11:0], a1, b1};

    wire [35:0] m_val;
    wire [47:0] dab_val;

    Pipeline_Module #(.INPUT_SIZE(36), .RSTTYPE(RSTTYPE), .PIPELINE(MREG)) 
        M_REG (.in_port(mult_comb), .out_Port(m_val), .clk(CLK), .rst(RSTM), .ce(CEM));

    Pipeline_Module #(.INPUT_SIZE(48), .RSTTYPE(RSTTYPE), .PIPELINE(MREG)) 
        DAB_REG (.in_port(dab_comb), .out_Port(dab_val), .clk(CLK), .rst(RSTM), .ce(CEM));

    assign M = m_val;
    wire [47:0] mult_ext = {{12{m_val[35]}}, m_val};

    // ------------------------------------------------------------------------
    // Carry-In Mux & Post-Adder Operand Multiplexers (X and Z)
    // ------------------------------------------------------------------------
    wire cin_final = (CARRYINSEL == "CARRYIN") ? cyi0 : opmode0[5];

    wire [47:0] p_val; // Feedback from final P register output

    wire [47:0] x_mux = (opmode0[1:0] == 2'b00) ? 48'd0    :
                        (opmode0[1:0] == 2'b01) ? mult_ext :
                        (opmode0[1:0] == 2'b10) ? p_val    :dab_val;

    wire [47:0] z_mux = (opmode0[3:2] == 2'b00) ? 48'd0 :
                        (opmode0[3:2] == 2'b01) ? PCIN  :
                        (opmode0[3:2] == 2'b10) ? p_val :c0;

    wire x_is_zero    = (opmode0[1:0] == 2'b00);
    wire z_is_zero    = (opmode0[3:2] == 2'b00);
    wire bypass_adder = x_is_zero || z_is_zero;

    // ------------------------------------------------------------------------
    // Post-Adder / Subtracter Execution Logic
    // ------------------------------------------------------------------------
    wire [48:0] add_ext = {1'b0, x_mux} + {1'b0, z_mux} + cin_final;
    wire [48:0] sub_ext = {1'b0, z_mux} - {1'b0, x_mux} - cin_final;

    wire [47:0] p_comb = bypass_adder ? (z_is_zero ? x_mux : z_mux)
                                      : (opmode0[7] ? sub_ext[47:0] : add_ext[47:0]);

    wire carry_comb = opmode0[7] ? sub_ext[48] : add_ext[48];

    // ------------------------------------------------------------------------
    // Output Registers: Carry Out & P
    // ------------------------------------------------------------------------
    wire carryout_val;

    // Feed carry_comb or freeze current carryout_val based on bypass status
    wire carry_in_sel = bypass_adder ? carryout_val : carry_comb;

    Pipeline_Module #(.INPUT_SIZE(1), .RSTTYPE(RSTTYPE), .PIPELINE(CARRYOUTREG)) 
        CYO_REG (.in_port(carry_in_sel), .out_Port(carryout_val), .clk(CLK), .rst(RSTCARRYIN), .ce(CECARRYIN));

    Pipeline_Module #(.INPUT_SIZE(48), .RSTTYPE(RSTTYPE), .PIPELINE(PREG)) 
        P_REG (.in_port(p_comb), .out_Port(p_val), .clk(CLK), .rst(RSTP), .ce(CEP));

    // Final Output Assignments
    assign P        = p_val;
    assign PCOUT    = P;
    assign CARRYOUT = carryout_val;
    assign CARRYOUTF= CARRYOUT;

endmodule