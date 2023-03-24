`timescale 1ns / 100ps
module i2c_eeprom_sim (
    // general signals
    input  wire        i2c_clk   ,
    input  wire        i2c_rstn  ,
    
    // APB signals
    input  wire [31:0] apb_addr  ,
    input  wire [31:0] apb_wdata ,
    input  wire        apb_write ,
    input  wire        apb_sel   ,
    input  wire        apb_enable,
    output wire [31:0] apb_rdata ,
    output wire        apb_ready ,
    output wire        apb_slverr,
    output wire        sda,
    output wire        scl  
);

// -----------------------------------------------------
// i2c_master module
// -----------------------------------------------------
    
    wire scl_i ; // scl for input
    wire scl_en; // scl for output

    wire sda_i ; // sda for input
    wire sda_en; // sda for output
    sequence SETUP;
        $rose(apb_sel)&&!apb_enable;
    endsequence
    sequence ACCESS;
        $rose(apb_enable)&&apb_sel&&$stable(apb_write)&&$stable(apb_wdata);
    endsequence
    sequence RECEIVE;
        apb_sel&&apb_enable&&apb_ready&&$stable(apb_write)&&$stable(apb_wdata);
    endsequence

    sequence PRECLK;
        (apb_addr==32'h10025000)&&(apb_wdata==32'h0000001f);
    endsequence

    sequence CTR;
        (apb_addr==32'h10025004)&&(apb_wdata==32'h00000080);
    endsequence

    sequence DEVICE_ID;
        (apb_addr==32'h10025010) ##[1:$](apb_addr==32'h10025014)&&(apb_wdata==32'h00000090);
    endsequence

    sequence SEND_START;
        (apb_addr==32'h10025010)&&(apb_sel&&apb_enable&&apb_ready) ##1(apb_addr==32'h10025014)&&(apb_wdata[4]==1);
    endsequence
    
    sequence SEND_FINISH;
        ((apb_addr==32'h1002500C)&&(apb_rdata[1]==1)&&!apb_write)[->0:$] ##1 ((apb_addr==32'h1002500C)&&(apb_rdata[1]==0)&&!apb_write)||((apb_addr==32'h10025014)&&apb_write&&apb_wdata[6]);
    endsequence

    sequence STOP;
        ((apb_addr==32'h1002500C)&&(apb_rdata[6]==1))[=0:$] ##1 ((apb_addr==32'h1002500C)&&(apb_rdata[6]==0))||((apb_addr==32'h10025014)&&apb_write&&apb_wdata[6]);
    endsequence

    sequence READ_DATA_SRC;
        (apb_addr==32'h10025008)&&apb_enable&&!apb_write;
    endsequence

    sequence I2C_start;
        $fell(sda)&&scl;
    endsequence

    sequence I2C_end;
        $rose(sda)&&scl;
    endsequence

    property apb_handshake_check;
        @(posedge i2c_clk)
        SETUP  |-> ##1 ACCESS ##[0:$]RECEIVE;
    endproperty

    property PRECLK2CTR;
        @(posedge i2c_clk)
        PRECLK and RECEIVE |-> ##[0:$] CTR and RECEIVE;
    endproperty

    property DEVICE_ID_SEND;
        @(posedge i2c_clk)
        CTR and RECEIVE |-> ##[0:$] DEVICE_ID and RECEIVE;
    endproperty

    property DATA_ADDRESS_SEND;
        @(negedge apb_enable)
        SEND_START  |->##[0:$] SEND_FINISH;
    endproperty

    property WRITE_STOP;
        @(negedge apb_enable)
        (apb_addr==32'h10025014)&&(apb_wdata[6]==1) and (apb_write&&apb_sel&&apb_enable&&apb_ready) |->##[0:$] STOP;
    endproperty

    property SRC_READ_DATA;
        @(posedge i2c_clk)
        READ_DATA_SRC |->1;
    endproperty

    property I2C_COMUNICATION;
        @(posedge scl)
        I2C_start |-> ##[0:$]I2C_end;
    endproperty




    check_apb_handshake: assert property (apb_handshake_check) 
    else $error($stime,"\t\t FAIL::handshake_check_ch\n");
    check_apb_clk2ctr: assert property (PRECLK2CTR) 
    else $error($stime,"\t\t FAIL::PRECLK2CTR\n");
    check_deviceID: assert property (DEVICE_ID_SEND) 
    else $error($stime,"\t\t FAIL::DEVICE_ID_SEND\n");
    check_send: assert property (DATA_ADDRESS_SEND) 
    else $error($stime,"\t\t FAIL::DATA_ADDRESS_SEND\n");
    check_stop: assert property (WRITE_STOP) 
    else $error($stime,"\t\t FAIL::WRITE_STOP\n");
    check_src_read: assert property (SRC_READ_DATA) 
    else $error($stime,"\t\t FAIL::WRITE_STOP\n");

    




    apb_i2c #(
        .APB_ADDR_WIDTH (32) 
    ) u_perips_apb_i2c0 (
        .HCLK          (i2c_clk   ),
        .HRESETn       (i2c_rstn  ),
    
        .PADDR         (apb_addr  ),
        .PWDATA        (apb_wdata ),
        .PWRITE        (apb_write ),
        .PSEL          (apb_sel   ),
        .PENABLE       (apb_enable),
        .PRDATA        (apb_rdata ),
        .PREADY        (apb_ready ),
        .PSLVERR       (apb_slverr),
    
        .interrupt_o   (/*unused*/),
        .scl_pad_i     (scl_i     ),
        .scl_pad_o     (/*unused*/),
        .scl_padoen_o  (scl_en    ),
        .sda_pad_i     (sda_i     ),
        .sda_pad_o     (/*unused*/),
        .sda_padoen_o  (sda_en    )
    );

// -----------------------------------------------------
// iobuf
// -----------------------------------------------------
    
    //wire scl; // io
    //wire sda; // io

    i2c_iobuf_sim i2c_iobuf_sim (
        .scl_e (!scl_en),
        .scl_i (scl_i  ),
        .scl   (scl    ),
        .sda_e (!sda_en),
        .sda_i (sda_i  ),
        .sda   (sda    )      
    );

// -----------------------------------------------------
// eerprom
// -----------------------------------------------------

    EEPROM_AT24C64 EEPROM_AT24C64 (
      .scl (scl),
      .sda (sda)
    );



endmodule
//vsim -gui -assertdebug -novopt work.testbench_top