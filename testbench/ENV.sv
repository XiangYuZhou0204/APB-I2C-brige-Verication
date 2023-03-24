package env;
`include "defines.sv"
    import apb_agent_main ::*;
    import monitor_scoreboard ::*;
    import i2c_agent_main ::*;
    import coverage ::*;


    class env_ctrl;

        // BUILD
        // ---------------------------------------------------
        // the new function is to build the class object's subordinates

        // first declare your subordinates
        i2c_agent i2c_agent;
        src_agent src_agent;
        monitor monitor;
        comparator comparator;
        mailbox #(logic [7:0]) mb_data_src,mb_data_dst,mb_temp;
        logic [7:0] data_read;
        reg_coverage reg_coverage;

        // new them
        function new();
            mb_data_src = new();
            mb_data_dst = new();
            mb_temp = new();
            this.src_agent = new();
            this.monitor = new(mb_data_src,mb_data_dst,mb_temp);
            this.comparator = new(mb_data_src,mb_data_dst);
            this.i2c_agent = new();
            this.reg_coverage = new(); 
        endfunction        

        // CONNECT
        // ---------------------------------------------------
        // the set_interface function is to connect the interface to itself
        // and then also connect to its subordinates
        // (only if used)
        function void set_interface(
            virtual duttb_intf_src.TBconnect sch,
            virtual duttb_intf_dst.TBconnect dch
        );

            // connect to src_agent
            this.src_agent.set_interface(
                sch
            );
            this.monitor.set_interface(
                sch,
                dch
            );
            this.i2c_agent.set_interface(
                dch
            );
            this.reg_coverage.set_interface(
                sch
            );
            
        endfunction 

        task run_sample();
            this.reg_coverage.sample();
        endtask

        // RUN
        // ---------------------------------------------------
        // manage your work here : 
        // (1) receive the command from the testbench
        // (2) call its subordinates to work
        task run(string state);
            case(state)
                "Start_Source_Agent": begin
                    $display("[ENV] start work : Start_Source_Agent !The time is %t",$time);
                    //-------------------------------------------------
                    //test every channel data trans
                    //-------------------------------------------------
                    this.src_agent.src_config(data_read);                     
                    $display("[ENV-INFO] Source_Agent:   completed ! The time is %t",$time);
                end
                "Time_Run": begin
                    $display("[ENV] start work : Time_Run !");
                    #100000000
                    $display("[ENV] time out !");
                end
                "Monitor":begin
                    $display("[ENV] start work : Monitor !The time is %t",$time);
                    monitor.monitor_run();
                end
                "Comparator":begin
                    $display("[ENV] start work : Comparator !The time is %t",$time);
                    comparator.compare_run();
                end
                default: begin
                    $display("[ENV] error : command out of range !");
                end
            endcase
        endtask

        

    endclass

endpackage