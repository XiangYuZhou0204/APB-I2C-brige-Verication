package apb_agent_main;
    //`include "defines.sv"
    import apb_agent_objects::*;
    class src_agent;
        src_generator                    src_generator;
        mailbox #(apb_random_datapkg)  mailbox_gen2drv;
        src_driver                          src_driver;
        logic [31:0] data_w,data_r;
        function new();
            this.mailbox_gen2drv = new(1);
            this.src_generator   = new(mailbox_gen2drv);
            this.src_driver     =  new(mailbox_gen2drv);
            
        endfunction

        function void set_interface(
            virtual duttb_intf_src.TBconnect sch   
        );   
            // connect to src_driver
            this.src_driver.set_interface(sch);
        endfunction 

        task src_config(output read_data);
            apb_random_datapkg random_data;
            logic [7:0] device_id_8bit;
            src_generator.data_gen();
            mailbox_gen2drv.get(random_data);
            device_id_8bit = {4'ha,random_data.device_id,1'b0};
            $display("the random_data is %p",random_data);
            src_driver.src_config(random_data.clk,device_id_8bit,random_data.addr,random_data.data,read_data);
        endtask


        
    endclass

endpackage



package apb_agent_objects;
    `include "defines.sv"

    class apb_random_datapkg;
        rand logic [2:0]device_id;
        rand logic [12:0] addr;
        rand logic [7:0] data;
        rand logic [7:0] clk;
    endclass 


    class src_generator;

        mailbox #(apb_random_datapkg) gen2drv;

        function new(
            mailbox #(apb_random_datapkg) gen2drv
            );
            this. gen2drv = gen2drv;
        endfunction

        // FUN : generate a random data for transport
        // ---------------------------------------------------   
        task data_gen();
                
            apb_random_datapkg tran_data;
            tran_data   = new();
            assert (tran_data.randomize())
            else $display("data_gen:randomize failed");

            gen2drv.put(tran_data); 
            $display("gen2drv is put");

        endtask   
    endclass

    class src_driver;

        mailbox #(apb_random_datapkg) gen2drv;   

        function new(
            mailbox #(apb_random_datapkg) gen2drv
        );
            this. gen2drv = gen2drv;
        endfunction

        // CONNECT
        // ---------------------------------------------------
        local virtual duttb_intf_src.TBconnect active_channel; 
        
        function void set_interface(
            virtual duttb_intf_src.TBconnect sch
        );   

            this.active_channel = sch;
            this.active_channel.apb_sel       = 0;
            this.active_channel.apb_enable    = 0;
        endfunction   

        function void init_en();
            this.active_channel.apb_sel = 0;
            this.active_channel.apb_enable =0;
            this.active_channel.apb_wdata = 0;
            this.active_channel.apb_write = 0;
            this.active_channel.apb_addr = 0;
        endfunction

        task  write(input address_t address,input data_t data_w);
            @(posedge active_channel.clk);
            this.active_channel.apb_sel = 1;
            this.active_channel.apb_wdata = data_w;
            this.active_channel.apb_write = 1;
            this.active_channel.apb_addr = address;
            @(posedge active_channel.clk)
            this.active_channel.apb_enable =1;
            @(posedge active_channel.clk);
            this.active_channel.apb_sel = 0;
            this.active_channel.apb_enable =0;
            this.active_channel.apb_wdata = 0;
            this.active_channel.apb_write = 0;
            this.active_channel.apb_addr = 0;
        endtask 

        task read(input address_t address,output data_t data_r);
            @(posedge active_channel.clk);
            this.active_channel.apb_sel = 1;
            this.active_channel.apb_write = 0;
            this.active_channel.apb_addr = address;
            @(posedge active_channel.clk)
            this.active_channel.apb_enable =1;
            @(posedge active_channel.clk);
            data_r = this.active_channel.apb_rdata;
            this.active_channel.apb_sel = 0;
            this.active_channel.apb_enable =0;
            this.active_channel.apb_wdata = 0;
            this.active_channel.apb_write = 0;
            this.active_channel.apb_addr = 0;      
        endtask

        task i2c_reg_config(input logic [31:0] clk_scale,
                            input logic [31:0] reg_ctrl
        );
            write(ADDR_REG_CLK,clk_scale);
            delay();
            write(ADDR_REG_CTR,reg_ctrl);
        endtask

        task i2c_cmd_write(input logic [31:0] cmd);
            write(ADD_REG_CMD,cmd);
        endtask

        task i2c_cmd_read(output logic [31:0] cmd);
            write(ADD_REG_CMD,cmd);
        endtask

        task i2c_status_config(output logic [31:0] status);
            read(ADD_REG_STA,status);
        endtask

        task i2c_data_write(input logic [31:0] data_w);
            write(ADD_REG_TX,data_w);
        endtask 

        task i2c_data_read(output logic [31:0] data_r);
            read(ADDR_REG_RX,data_r);
        endtask 

        task src_config(
                input logic [7:0] clk_scale,
                input logic [7:0] device_id,
                input logic [12:0] mem_addr,
                input logic [7:0] data_in,
                output logic [7:0] data_read);
            //write
            logic [31:0] status,data_r;
            logic [31:0] CLK_SCALE,DEVICE_32,MEM_ADDRH_32,MEM_ADDRL_32,DATA_W_32;
            CLK_SCALE ={24'h0,clk_scale};
            DEVICE_32 = {24'h0,device_id};
            MEM_ADDRH_32 = {27'h0,mem_addr[12:8]};
            MEM_ADDRL_32 = {24'h0,mem_addr[7:0]};
            DATA_W_32 = {24'h0,data_in};

            
            i2c_reg_config(CLK_SCALE,32'h00000080);//clk ctr
            $display("I2C write config starts!");
            i2c_data_write(DEVICE_32);              //device
            i2c_cmd_write(32'h00000090);
            do begin
                i2c_status_config(status);
            end while(status[1] == 1);
            $display("sending control over");

            i2c_data_write(MEM_ADDRH_32);
            i2c_cmd_write(32'h00000010);
            do begin
                i2c_status_config(status);
            end while(status[1] == 1);
            $display("sending addrh over");

            i2c_data_write(MEM_ADDRL_32);
            i2c_cmd_write(32'h00000010);
            do begin
                i2c_status_config(status);
            end while(status[1] == 1);
            $display("sending addrl over");

            i2c_data_write(DATA_W_32);
            i2c_cmd_write(32'h00000010);
            do begin
                i2c_status_config(status);
            end while(status[1] == 1);
            $display("sending data over");

            i2c_cmd_write(32'h00000040);//stop
            do begin
                i2c_status_config(status);
            end while(status[6] == 1);
            $display("write is over");

            repeat(10000) delay();


            //read
            $display("I2C read config starts!");
            i2c_data_write(DEVICE_32);       //control
            i2c_cmd_write(32'h00000090);
            do begin
                i2c_status_config(status);
            end while(status[1] == 1);
            $display("sending control over");

            i2c_data_write(MEM_ADDRH_32);        //addrH
            i2c_cmd_write(32'h00000010);
            do begin
                i2c_status_config(status);
            end while(status[1] == 1);
            $display("sending addrh over");

            i2c_data_write(MEM_ADDRL_32);       //addrL
            i2c_cmd_write(32'h00000010);
            do begin
                i2c_status_config(status);
            end while(status[1] == 1);
            $display("sending addrl over");

            i2c_data_write(DEVICE_32+1);       //read control a1
            i2c_cmd_write(32'h00000090);
            do begin
                i2c_status_config(status);
            end while(status[1] == 1);
            $display("sending cmd over");

            i2c_cmd_write(32'h00000060);
            $display("try to get the data_r");        
            repeat(10000) delay();
            i2c_data_read(data_r);
            data_read = data_r[7:0];
            $display("read data over,data_r is 32'h%h,data_read is 8'h%h,the input data_write is 8'h%h ",data_r,data_read,data_in);

        endtask

        task delay();
            @(posedge active_channel.clk);
        endtask


    endclass
    
   

endpackage