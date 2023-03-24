package monitor_scoreboard;
`include "defines.sv"

    class golden_model;
        virtual duttb_intf_dst.TBconnect dst;

        function void set_interface(
            virtual duttb_intf_dst.TBconnect dst
        );   

            this.dst = dst;
        endfunction  

        task pre_sda (input logic sda,output logic sda_pre);
            sda_pre = dst.sda;
            @(posedge dst.clk);
        endtask

        task detect_i2c_start(output logic i2c_start);
            logic sda_pre;
            pre_sda(dst.sda,sda_pre);
            i2c_start = sda_pre & (!dst.sda) & dst.scl;
        endtask

        task detect_i2c_end(output logic i2c_end);
            logic sda_pre;
            pre_sda(dst.sda,sda_pre);
            i2c_end = !sda_pre & dst.sda & dst.scl;
        endtask

        task i2c_trans_write(
                output logic [7:0] i2c_8bit[4] 
                            );
            logic [8:0] i2c_9bit [4];
            logic i2c_start,i2c_end;
            int i ,j ;
            do begin
                detect_i2c_start(i2c_start);
            end while(!i2c_start);
            assert(i2c_start)$display("COMUNICATION START(WRITE),the time is %t",$time);
            //start i2c communication
            for(i=0;i<4;i++)
            begin
                $display("COMUNICATION (WRITE),the byte start time is %t",$time);
                for(j=8;j>=0;j--)
                begin
                    @(posedge dst.scl);
                    i2c_9bit [i][j]=dst.sda;
                    $display("[%d]the bit is %b,the time is %t",j,i2c_9bit [i][j],$time);
                end
                i2c_8bit[i] = i2c_9bit[i][8:1];
                $display("i2c_write receeive a data is 8'h%h,the acl is %b,the time is %t",i2c_8bit[i],dst.sda,$time);
            end
            do begin
                detect_i2c_end(i2c_end);
            end while(!i2c_end);
            assert(i2c_end)$display("COMUNICATION END(WRITE),the time is %t",$time);     

        endtask

        task i2c_trans_read(
                output logic [7:0] i2c_8bit [5]
                            );
            logic [8:0] i2c_9bit [5];
            logic i2c_start,i2c_end;
            int i ,j ;
            do begin
                detect_i2c_start(i2c_start);
            end while(!i2c_start);
            assert(i2c_start)$display("COMUNICATION START(READ),the time is %t",$time);
            //start i2c communication
            for(i=0;i<3;i++)
            begin
                for(j=8;j>=0;j--)
                begin
                    @(posedge dst.scl);
                    i2c_9bit [i][j]=dst.sda;
                    $display("[%d]the bit is %b,the time is %t",j,i2c_9bit [i][j],$time);
                end
                i2c_8bit[i] = i2c_9bit[i][8:1];
                $display("i2c_trans_read the data is 8'h%h,the acl is %b,the time is %t",i2c_8bit[i],dst.sda,$time);
            end
            do begin
                detect_i2c_start(i2c_start);
            end while(!i2c_start);
            $display("COMUNICATION RESTART(READ),the time is %t",$time);
            for(i=3;i<5;i++)
            begin
                for(j=8;j>=0;j--)
                begin
                    @(posedge dst.scl);
                    i2c_9bit [i][j]=dst.sda;
                    $display("[%d]the bit is %b,the time is %t",j,i2c_9bit [3][j],$time);
                end
                i2c_8bit[i] = i2c_9bit[i][8:1];
                $display("i2c_trans_read the data is 8'h%h,the acl is %b,the time is %t",i2c_8bit[i],dst.sda,$time);
            end
            do begin 
                detect_i2c_end(i2c_end);
            end while(!i2c_end);
            assert(i2c_end)$display("COMUNICATION END(READ),the time is %t",$time);     
        endtask



    endclass

    class monitor;
        virtual duttb_intf_src.TBconnect src;
        virtual duttb_intf_dst.TBconnect dst;
        logic [7:0] data_dst,wdata_8bit;
        logic event_src_valid,event_dst_valid;
        mailbox #(logic [7:0]) mailbox_data_src;
        mailbox #(logic [7:0]) mailbox_data_dst;
        mailbox #(logic [7:0]) mailbox_temp;
        golden_model golden_model;

        function new(
            mailbox #(logic [7:0]) mailbox_data_src,
            mailbox #(logic [7:0]) mailbox_data_dst,
            mailbox #(logic [7:0]) mailbox_temp
        );
            this.mailbox_data_src = mailbox_data_src;
            this.mailbox_data_dst = mailbox_data_dst;
            this.mailbox_temp = mailbox_temp;
            this.data_dst = data_dst;
            this.golden_model = new();
        endfunction

        function void set_interface(
            virtual duttb_intf_src.TBconnect src,
            virtual duttb_intf_dst.TBconnect dst
        );   

            this.src = src;
            this.dst = dst;
            this.golden_model.set_interface(dst);
        endfunction  

        task src_get_signal(output logic event_src_valid);
            @(posedge src.clk);
                event_src_valid = ((src.apb_addr == ADD_REG_TX)&&src.apb_write&&src.apb_enable);
        endtask

        task src_read_signal(output logic event_src_read_valid);
            @(posedge src.clk);
                event_src_read_valid = ((src.apb_addr == ADDR_REG_RX)&&!src.apb_write&&src.apb_enable);
        endtask


        task get_src_write_data(
            );
            //mailbox #(logic [7:0]) mailbox_temp;
            int get_cnt = 0;
            logic get_signal;
            logic [7:0] wdata;
            logic [7:0] data2check;
            do begin
            src_get_signal(get_signal);
            if(get_signal)
            begin
                
                $display("[APB src write monitor] get a data is 8'h%h,the time is %t",src.apb_wdata[7:0],$time);
                mailbox_data_src.put(src.apb_wdata[7:0]);
                $display("[mailbox_src] put : %h",src.apb_wdata[7:0]);
                if(get_cnt == 3) wdata = src.apb_wdata[7:0];
                get_cnt++;
            end
            end while(get_cnt<8);
            mailbox_temp.put(wdata);

            $display("-----------src write data collect over--------------");

        endtask

        task get_src_read_data();
            logic [7:0] wdata;
            logic read_signal;
            do begin
            src_read_signal(read_signal);
            if(read_signal)
            begin
                $display("[APB src read monitor] get a data is 8'h%h,the time is %t",src.apb_rdata[7:0],$time);
                mailbox_data_src.put(src.apb_rdata[7:0]);
                $display("[mailbox_src] put : %h",src.apb_rdata[7:0]);
            end
            end while(!read_signal);

            $display("-----------src read data collect get--------------");
            mailbox_temp.get(wdata);
            $display("the APB_I2C src read the written data is 8'h%h",wdata);
            mailbox_data_src.put(wdata);


        endtask
        
        task get_dst_data();
            logic [7:0] i2c_write[4] ;
            logic [7:0] i2c_read [5];
            logic [7:0] rdata;

            golden_model.i2c_trans_write(i2c_write);
            golden_model.i2c_trans_read(i2c_read);
            for(int i =0 ;i <4 ;i++)
            begin
                mailbox_data_dst.put(i2c_write[i]);
                $display("[mailbox_dst] put : %h",i2c_write[i]);
            end
            for(int i =0 ;i <5 ;i++)
            begin
                mailbox_data_dst.put(i2c_read[i]);
                $display("[mailbox_dst] put : %h",i2c_read[i]);
                if(i == 4) rdata = i2c_read[i];
            end
            $display("the APB_I2C dst read the written data is 8'h%h",rdata);
            mailbox_data_dst.put(rdata);
        endtask

        task monitor_run();
            logic [7:0] wdata;
            fork
                get_src_write_data();
                get_src_read_data();
                get_dst_data();
            join
        endtask

    endclass

    class comparator;
        int cor_cnt;
        int err_cnt;
        logic [7:0] data_src,data_dst;
        mailbox #(logic [7:0]) mailbox_src,mailbox_dst;
        bit flag;
        function new(
            mailbox mailbox_src,
            mailbox mailbox_dst
            );
            cor_cnt = 0;
            err_cnt = 0;
            this.mailbox_src = mailbox_src;
            this.mailbox_dst = mailbox_dst;
        endfunction
        
        task compare_run();
            do begin
                mailbox_src.get(this.data_src);
                mailbox_dst.get(this.data_dst);
                $display("the src num is 8'h%h,the dst num is 8'h%h",data_src,data_dst);
                if(data_src == data_dst)begin
                    cor_cnt ++;
                    flag = 1;
                    $display("PASS");
                end
                else begin
                    err_cnt ++;
                    flag = 0;
                    $display("FAIL");
                end
                //$display("the mailbox_src num is %d",mailbox_src.num());
            end while(mailbox_src.num()!=1);
            mailbox_src.get(this.data_src);
            mailbox_dst.get(this.data_dst);
            $display("the src written num is 8'h%h,the dst read num is 8'h%h",data_src,data_dst);
            if(data_src == data_dst)begin
                cor_cnt ++;
                flag = 1;
                $display("PASS");
            end
            else begin
                err_cnt ++;
                flag = 0;
                $display("FAIL");
            end
            $display("[COMPARETOR]compare is over");
            if(err_cnt == 0) $display("[COMPARETOR]-------------------Congratulations ! all num is right!< total %d PASS, %d FAIL>-------------------",cor_cnt,err_cnt);
            else $display("[COMPARETOR]-------------------THERE ARE %d PASS, %d FAIL-------------------",cor_cnt,err_cnt);
        endtask



    endclass

endpackage