module dut (

    input clk  ,
    input rst_n,
    
    // add your modport here
    // example : 
    duttb_intf_src.DUTconnect sch,
    duttb_intf_dst.DUTconnect dch

);

    i2c_eeprom_sim i2c_eeprom_sim (
    
        .i2c_clk     (clk  ),
        .i2c_rstn   (rst_n),
        
        .apb_addr    (sch.apb_addr),  
        .apb_wdata   (sch.apb_wdata),
        .apb_write   (sch.apb_write),
        .apb_sel     (sch.apb_sel),
        .apb_enable  (sch.apb_enable),
        .apb_rdata   (sch.apb_rdata),
        .apb_ready   (sch.apb_ready),
        .apb_slverr  (sch.apb_slverr),
        .sda         (dch.sda),
        .scl         (dch.scl)
    );

endmodule