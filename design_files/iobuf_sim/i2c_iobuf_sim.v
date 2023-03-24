module i2c_iobuf_sim (
    // i2c_scl
    input  wire scl_e,
    output wire scl_i,
    inout  wire scl  ,
    // i2c_sda
    input  wire sda_e,
    output wire sda_i,
    inout  wire sda    
);
// -----------------------------------------------------
// scl
// -----------------------------------------------------

    // actually scl singal donnot need to be used as 
    // inout type, thus just consider it as output
    assign scl_i = scl;
    assign scl = !scl_e;

// -----------------------------------------------------
// sda
// -----------------------------------------------------

    // to sim iobuf within only 0 & 1 type;
    assign sda_i = sda;
    not (weak1,weak0) inv (sda,sda_e);

endmodule