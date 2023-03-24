package i2c_agent_main;
    class i2c_agent ;
        virtual duttb_intf_dst.TBconnect dch;
        function void set_interface(
            virtual duttb_intf_dst.TBconnect dch
        );
            this.dch = dch;
        endfunction 
    endclass 

endpackage