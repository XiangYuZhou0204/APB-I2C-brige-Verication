`timescale 1ns/1ps
//-----------------------------------------------------
// INTF.sv
// this a file that define your interfaces which connect
// your dut and testbench.
//-----------------------------------------------------
interface duttb_intf_src (
    input clk,
    input rst_n
);

//-----------------------------------------------------
// parameters
//-----------------------------------------------------

    localparam ADDR_W = 32;
    // data width of source channel
    localparam WDATA_W = 32;
    // priority width of source channel
    localparam RDATA_W = 32;
//-----------------------------------------------------
// ios
//-----------------------------------------------------

    logic                  apb_write       ;
    logic                  apb_sel         ;
    logic                  apb_enable      ;
    logic [ADDR_W-1   :0]  apb_addr        ;
    logic [WDATA_W-1   :0] apb_wdata       ;


    logic [RDATA_W-1   :0] apb_rdata       ;
    logic                  apb_ready       ;
    logic                  apb_slverr      ;
//-----------------------------------------------------
// modports
//-----------------------------------------------------

    modport DUTconnect (
        input  apb_write, apb_sel,apb_enable,apb_addr,apb_wdata,
        output apb_rdata,apb_ready,apb_slverr
    );

//    modport TBconnect (
//        clocking cb_tb
//    );
    modport TBconnect (     
        input clk,   
        input apb_rdata,apb_ready,apb_slverr,
        output  apb_write, apb_sel,apb_enable,apb_addr,apb_wdata
    );    

endinterface

interface duttb_intf_dst (
    input clk,
    input rst_n
);
    logic sda;
    logic scl;
    modport DUTconnect (
        output sda,scl
    );

    modport TBconnect (     
        input clk,   
        input sda,scl
    );    
endinterface