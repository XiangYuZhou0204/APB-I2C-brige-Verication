`timescale 1ns/100ps

module testbench_top ();

//-----------------------------------------------------
// parameters
//-----------------------------------------------------

    parameter CLK_PERIOD = 10;

//-----------------------------------------------------
// signals define
//-----------------------------------------------------

    // uninterface signals 
    logic clk  ;
    logic rst_n;
    
    // interface signals 
    duttb_intf_src if_schannel(.*);
    duttb_intf_dst if_dchannel(.*);


//-----------------------------------------------------
// signals' fun
//-----------------------------------------------------
       
	initial begin 
		clk    = 0 ;
		forever #(CLK_PERIOD /2) clk = ~clk;
	end

	initial begin
		rst_n   = 0;
		repeat(10) @(posedge clk) ;
		rst_n   = 1;
	end 

//-----------------------------------------------------
// connections
//-----------------------------------------------------

    testbench testbench(
        .clk   (clk       ),
        .rst_n (rst_n     ),

        // source channel connections
        .sch (if_schannel),
        .dch (if_dchannel)
    ); 

    dut dut(
        .clk   (clk          ),
        .rst_n (rst_n        ),

        // source channel connections
        .sch (if_schannel),
        .dch (if_dchannel)
    );
    
endmodule

program testbench(

    input clk  ,
    input rst_n,
    
    // your modport connection
    duttb_intf_src.TBconnect sch,
    duttb_intf_dst.TBconnect dch
);
    
    import env ::*;   // import your ENV object
    env_ctrl envctrl; // first declare it

    initial begin
        
        $display("[TB-SYS] welcome to sv testbench plateform !");

        // BUILD
        // ---------------------------------------------------        
        // the first step in testbench is build your env object 
        // as your command manager, after that you can call it
        // also with its subordinates
        $display("[TB-SYS] building");
        envctrl = new();                //create envctrl

        // CONNECT
        // ---------------------------------------------------
        // let your manager connected to your dut by interface
        $display("[TB-SYS] connecting");
        envctrl.set_interface(
            sch,
            dch
        );

        // RUN
        // ---------------------------------------------------
        // give command to your env object
        $display("[TB-SYS] running");

        // (1) waiting for rst done in dut
        repeat(11) @(posedge clk);
        
            // (2) add your command here 

            fork
                envctrl.run("Start_Source_Agent");
                envctrl.run("Monitor");       
                //envctrl.run("Time_Run");     
                envctrl.run_sample();              
            join_any
            disable fork;
            $display("-------starting scoreboard---");
            #1000
            envctrl.run("Comparator");    

        // END
        // ---------------------------------------------------        
        $display("[TB-SYS] testbench system has done all the work, exit !");

    end

endprogram
// vlog * .vp
//vlog -mfcu -sv eeprom_sim.v apb_i2c.sv i2c_master_bit_ctrl.sv i2c_master_byte_ctrl.sv i2c_master_define.v i2c_iobuf_sim.v i2c_eeprom_sim.sv INTF.sv APB_AGENT.sv I2C_AGENT.sv DUT.sv coverage.sv MONITOR_AGENT.sv ENV.sv TESTBENCH.sv
//vsim -coverage -novopt work.testbench_top