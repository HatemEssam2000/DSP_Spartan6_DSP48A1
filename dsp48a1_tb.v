`timescale 1ns / 1ps

module DSP48A1_tb;

    // ------------------------------------------------------------------------
    // Testbench Parameters & Signals
    // ------------------------------------------------------------------------
    reg  [17:0] A, B, D, BCIN;
    reg  [47:0] C, PCIN;
    reg  [7:0]  OPMODE;
    reg         CLK, CARRYIN;

    reg         RSTA, RSTB, RSTM, RSTP, RSTC, RSTD, RSTCARRYIN, RSTOPMODE;
    reg         CEA, CEB, CEM, CEP, CEC, CED, CECARRYIN, CEOPMODE;

    wire [17:0] BCOUT;
    wire [47:0] PCOUT, P;
    wire [35:0] M;
    wire        CARRYOUT, CARRYOUTF;

    integer     error_count = 0;
    reg  [47:0] past_P;
    reg         past_CARRYOUT;

    // ------------------------------------------------------------------------
    // DUT Instantiation (Default Parameter Configuration)
    // ------------------------------------------------------------------------
    DSP48A1 #(
        .A0REG(0),
        .A1REG(1),
        .B0REG(0),
        .B1REG(1),
        .CREG(1),
        .DREG(1),
        .MREG(1),
        .PREG(1),
        .CARRYINREG(1),
        .CARRYOUTREG(1),
        .OPMODEREG(1),
        .CARRYINSEL("OPMODE5"),
        .B_INPUT("DIRECT"),
        .RSTTYPE("SYNC")
    ) DUT (
        .A(A), .B(B), .D(D), .C(C),
        .CLK(CLK), .CARRYIN(CARRYIN), .OPMODE(OPMODE),
        .BCIN(BCIN), .PCIN(PCIN),
        .RSTA(RSTA), .RSTB(RSTB), .RSTM(RSTM), .RSTP(RSTP),
        .RSTC(RSTC), .RSTD(RSTD), .RSTCARRYIN(RSTCARRYIN), .RSTOPMODE(RSTOPMODE),
        .CEA(CEA), .CEB(CEB), .CEM(CEM), .CEP(CEP),
        .CEC(CEC), .CED(CED), .CECARRYIN(CECARRYIN), .CEOPMODE(CEOPMODE),
        .BCOUT(BCOUT), .PCOUT(PCOUT), .P(P), .M(M),
        .CARRYOUT(CARRYOUT), .CARRYOUTF(CARRYOUTF)
    );

    // ------------------------------------------------------------------------
    // Clock Generation (10ns Period)
    // ------------------------------------------------------------------------
    initial begin
        CLK = 0;
        forever #5 CLK = ~CLK;
    end

    // ------------------------------------------------------------------------
    // Self-Checking Helper Task
    // ------------------------------------------------------------------------
    task check_outputs;
        input [17:0] exp_BCOUT;
        input [35:0] exp_M;
        input [47:0] exp_P;
        input        exp_CARRYOUT;
        input [8*20:1] test_name;
        begin
            if (BCOUT === exp_BCOUT && M === exp_M && P === exp_P && 
                PCOUT === exp_P && CARRYOUT === exp_CARRYOUT && CARRYOUTF === exp_CARRYOUT) begin
                $display("[PASS] %s: BCOUT='h%h, M='h%h, P=PCOUT='h%h, CARRYOUT='h%b", 
                          test_name, BCOUT, M, P, CARRYOUT);
            end else begin
                $display("[FAIL] %s:", test_name);
                if (BCOUT !== exp_BCOUT)     $display("   -> BCOUT: Expected 'h%h, Got 'h%h", exp_BCOUT, BCOUT);
                if (M !== exp_M)             $display("   -> M    : Expected 'h%h, Got 'h%h", exp_M, M);
                if (P !== exp_P)             $display("   -> P    : Expected 'h%h, Got 'h%h", exp_P, P);
                if (PCOUT !== exp_P)         $display("   -> PCOUT: Expected 'h%h, Got 'h%h", exp_P, PCOUT);
                if (CARRYOUT !== exp_CARRYOUT)$display("   -> CYOUT: Expected 'h%b, Got 'h%b", exp_CARRYOUT, CARRYOUT);
                error_count = error_count + 1;
            end
        end
    endtask

    // ------------------------------------------------------------------------
    // Stimulus & Verification Sequence
    // ------------------------------------------------------------------------
    initial begin
        $display("==================================================");
        $display("        Starting DSP48A1 Verification             ");
        $display("==================================================");

        // --------------------------------------------------------------------
        // Step 2.1: Verify Reset Operation
        // --------------------------------------------------------------------
        RSTA = 1; RSTB = 1; RSTM = 1; RSTP = 1;
        RSTC = 1; RSTD = 1; RSTCARRYIN = 1; RSTOPMODE = 1;
        
        CEA = 0; CEB = 0; CEM = 0; CEP = 0;
        CEC = 0; CED = 0; CECARRYIN = 0; CEOPMODE = 0;

        // Drive remaining inputs with random values
        A = $urandom; B = $urandom; D = $urandom; C = {$urandom, $urandom};
        BCIN = $urandom; PCIN = {$urandom, $urandom};
        OPMODE = $urandom; CARRYIN = $urandom % 2;

        @(negedge CLK);
        check_outputs(18'h0, 36'h0, 48'h0, 1'b0, "2.1 Reset Test");

        // Deassert resets & enable clock enables
        RSTA = 0; RSTB = 0; RSTM = 0; RSTP = 0;
        RSTC = 0; RSTD = 0; RSTCARRYIN = 0; RSTOPMODE = 0;

        CEA = 1; CEB = 1; CEM = 1; CEP = 1;
        CEC = 1; CED = 1; CECARRYIN = 1; CEOPMODE = 1;

        // --------------------------------------------------------------------
        // Step 2.2: Verify DSP Path 1
        // --------------------------------------------------------------------
        OPMODE  = 8'b11011101;
        A       = 20;
        B       = 10;
        C       = 350;
        D       = 25;
        BCIN    = $urandom;
        PCIN    = {$urandom, $urandom};
        CARRYIN = $urandom % 2;

        repeat(4) @(negedge CLK);
        check_outputs(18'hF, 36'h12C, 48'h32, 1'b0, "2.2 DSP Path 1");

        // --------------------------------------------------------------------
        // Step 2.3: Verify DSP Path 2
        // --------------------------------------------------------------------
        OPMODE  = 8'b00010000;
        A       = 20;
        B       = 10;
        C       = 350;
        D       = 25;
        BCIN    = $urandom;
        PCIN    = {$urandom, $urandom};
        CARRYIN = $urandom % 2;

        repeat(3) @(negedge CLK);
        check_outputs(18'h23, 36'h2BC, 48'h0, 1'b0, "2.3 DSP Path 2");

        // --------------------------------------------------------------------
        // Step 2.4: Verify DSP Path 3
        // --------------------------------------------------------------------
        // Capture prior P and CARRYOUT values for self-checking dynamic comparison
        past_P        = P;
        past_CARRYOUT = CARRYOUT;

        OPMODE  = 8'b00001010;
        A       = 20;
        B       = 10;
        C       = 350;
        D       = 25;
        BCIN    = $urandom;
        PCIN    = {$urandom, $urandom};
        CARRYIN = $urandom % 2;

        repeat(3) @(negedge CLK);
        check_outputs(18'hA, 36'hC8, past_P, past_CARRYOUT, "2.4 DSP Path 3");

        // --------------------------------------------------------------------
        // Step 2.5: Verify DSP Path 4
        // --------------------------------------------------------------------
        OPMODE  = 8'b10100111;
        A       = 5;
        B       = 6;
        C       = 350;
        D       = 25;
        PCIN    = 3000;
        BCIN    = $urandom;
        CARRYIN = $urandom % 2;

        repeat(3) @(negedge CLK);
        check_outputs(18'h6, 36'h1E, 48'hFE6FFFEC0BB1, 1'b1, "2.5 DSP Path 4");

        // --------------------------------------------------------------------
        // End of Simulation Summary
        // --------------------------------------------------------------------
        $display("==================================================");
        if (error_count == 0)
            $display("   TESTBENCH SUCCESSFUL: All tests passed!");
        else
            $display("   TESTBENCH FAILED: %0d error(s) detected.", error_count);
        $display("==================================================");

        $finish;
    end

endmodule

/* `timescale 1ns/1ps

module DSP48A1_tb;

    reg  [17:0] A, B, D;
    reg  [47:0] C;
    reg         CLK;
    reg         CARRYIN;
    reg  [7:0]  OPMODE;
    reg  [17:0] BCIN;
    reg  [47:0] PCIN;

    reg RSTA, RSTB, RSTM, RSTP, RSTC, RSTD, RSTCARRYIN, RSTOPMODE;
    reg CEA,  CEB,  CEM,  CEP,  CEC,  CED,  CECARRYIN,  CEOPMODE;

    wire [17:0] BCOUT;
    wire [47:0] PCOUT;
    wire [47:0] P;
    wire [35:0] M;
    wire        CARRYOUT;
    wire        CARRYOUTF;

    integer errors;

    DSP48A1 dut (
        .A(A), .B(B), .D(D), .C(C), .CLK(CLK), .CARRYIN(CARRYIN),
        .OPMODE(OPMODE), .BCIN(BCIN), .PCIN(PCIN),
        .RSTA(RSTA), .RSTB(RSTB), .RSTM(RSTM), .RSTP(RSTP),
        .RSTC(RSTC), .RSTD(RSTD), .RSTCARRYIN(RSTCARRYIN), .RSTOPMODE(RSTOPMODE),
        .CEA(CEA), .CEB(CEB), .CEM(CEM), .CEP(CEP),
        .CEC(CEC), .CED(CED), .CECARRYIN(CECARRYIN), .CEOPMODE(CEOPMODE),
        .BCOUT(BCOUT), .PCOUT(PCOUT), .P(P), .M(M),
        .CARRYOUT(CARRYOUT), .CARRYOUTF(CARRYOUTF)
    );

    // 100 MHz clock
    initial CLK = 1'b0;
    always #5 CLK = ~CLK;

    task check48(input [47:0] actual, input [47:0] expected, input [23*8-1:0] name);
        begin
            if (actual !== expected) begin
                errors = errors + 1;
                $display("ERROR: %0s => got 0x%h expected 0x%h at time %0t", name, actual, expected, $time);
            end else begin
                $display("PASS : %0s => 0x%h at time %0t", name, actual, $time);
            end
        end
    endtask

    initial begin
        errors = 0;

        //================= Reset check =================
        RSTA = 1; RSTB = 1; RSTM = 1; RSTP = 1;
        RSTC = 1; RSTD = 1; RSTCARRYIN = 1; RSTOPMODE = 1;
        CEA = 0; CEB = 0; CEM = 0; CEP = 0;
        CEC = 0; CED = 0; CECARRYIN = 0; CEOPMODE = 0;

        A = $random; B = $random; D = $random; C = $random;
        OPMODE = $random; BCIN = $random; PCIN = $random; CARRYIN = $random;

        @(negedge CLK);
        check48({30'd0, BCOUT},    48'd0, "RESET_BCOUT");
        check48({12'd0, M},        48'd0, "RESET_M");
        check48(P,                 48'd0, "RESET_P");
        check48(PCOUT,             48'd0, "RESET_PCOUT");
        check48({47'd0, CARRYOUT}, 48'd0, "RESET_CARRYOUT");
        check48({47'd0, CARRYOUTF},48'd0, "RESET_CARRYOUTF");

        RSTA = 0; RSTB = 0; RSTM = 0; RSTP = 0;
        RSTC = 0; RSTD = 0; RSTCARRYIN = 0; RSTOPMODE = 0;
        CEA = 1; CEB = 1; CEM = 1; CEP = 1;
        CEC = 1; CED = 1; CECARRYIN = 1; CEOPMODE = 1;

        //================= Path 1 =================
        A = 20; B = 10; C = 350; D = 25;
        OPMODE = 8'b11011101;
        BCIN = $random; PCIN = $random; CARRYIN = $random;
        repeat (4) @(negedge CLK);
        check48({30'd0, BCOUT},     48'hf,   "PATH1_BCOUT");
        check48({12'd0, M},         48'h12c, "PATH1_M");
        check48(P,                  48'h32,  "PATH1_P");
        check48(PCOUT,              48'h32,  "PATH1_PCOUT");
        check48({47'd0, CARRYOUT},  48'd0,   "PATH1_CARRYOUT");
        check48({47'd0, CARRYOUTF}, 48'd0,   "PATH1_CARRYOUTF");

        //================= Path 2 =================
        A = 20; B = 10; C = 350; D = 25;
        OPMODE = 8'b00010000;
        BCIN = $random; PCIN = $random; CARRYIN = $random;
        repeat (3) @(negedge CLK);
        check48({30'd0, BCOUT},     48'h23,  "PATH2_BCOUT");
        check48({12'd0, M},         48'h2bc, "PATH2_M");
        check48(P,                  48'd0,   "PATH2_P");
        check48(PCOUT,              48'd0,   "PATH2_PCOUT");
        check48({47'd0, CARRYOUT},  48'd0,   "PATH2_CARRYOUT");
        check48({47'd0, CARRYOUTF}, 48'd0,   "PATH2_CARRYOUTF");

        //================= Path 3 =================
        A = 20; B = 10; C = 350; D = 25;
        OPMODE = 8'b00001010;
        BCIN = $random; PCIN = $random; CARRYIN = $random;
        begin : path3_blk
            reg [47:0] p_prev;
            reg        c_prev;
            p_prev = P;
            c_prev = CARRYOUT;
            repeat (3) @(negedge CLK);
            check48({30'd0, BCOUT},     48'ha,  "PATH3_BCOUT");
            check48({12'd0, M},         48'hc8, "PATH3_M");
            check48(P,                  p_prev, "PATH3_P");
            check48(PCOUT,              p_prev, "PATH3_PCOUT");
            check48({47'd0, CARRYOUT},  {47'd0, c_prev}, "PATH3_CARRYOUT");
            check48({47'd0, CARRYOUTF}, {47'd0, c_prev}, "PATH3_CARRYOUTF");
        end

        //================= Path 4 =================
        A = 5; B = 6; C = 350; D = 25; PCIN = 3000;
        OPMODE = 8'b10100111;
        BCIN = $random; CARRYIN = $random;
        repeat (3) @(negedge CLK);
        check48({30'd0, BCOUT},     48'h6,           "PATH4_BCOUT");
        check48({12'd0, M},         48'h1e,          "PATH4_M");
        check48(P,                  48'hfe6fffec0bb1,"PATH4_P");
        check48(PCOUT,              48'hfe6fffec0bb1,"PATH4_PCOUT");
        check48({47'd0, CARRYOUT},  48'd1,           "PATH4_CARRYOUT");
        check48({47'd0, CARRYOUTF}, 48'd1,           "PATH4_CARRYOUTF");

        if (errors == 0)
            $display("\n===== ALL TESTS PASSED =====\n");
        else
            $display("\n===== TESTS FAILED: %0d error(s) =====\n", errors);

        $stop;
    end

endmodule
 */