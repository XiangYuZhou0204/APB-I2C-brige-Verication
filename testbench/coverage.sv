package coverage;
    
    class reg_coverage;

        local virtual duttb_intf_src.TBconnect src;

        logic [7:0] clk_reg;
        logic [7:0] ctr_reg;
        logic [7:0] sta_reg;
        logic [7:0] cmd_reg;
        logic [7:0] tx_reg;
        logic [7:0] rx_reg;

        covergroup I2C_REG ;
            COVER_CLK_SCALE:coverpoint clk_reg{
                illegal_bins clk_0 = {8'h0};
                wildcard bins clk = {8'h??};
            }
            COVER_CTR:coverpoint ctr_reg{
                wildcard bins no_EN = {8'h0?};
                wildcard bins EN = {8'h8?};
            }

            COVER_STA:coverpoint sta_reg{
                bins TIP = {8'b01000010,8'b00000010};
                bins FIN = {8'b01000001};
                wildcard bins NACK = {8'b11000000};
                wildcard bins AL = {8'b??1000??};
            }

            COVER_CMD:coverpoint cmd_reg{
                bins start = {8'h90,8'ha0};
                bins write = {8'h10,8'h50};
                bins stop_write = {8'h50};
                bins read = {8'h64,8'h60};
                bins stop_read = {8'h60,8'h64};
            }

            COVER_RX:coverpoint rx_reg{
                wildcard bins data_send={8'h??};
            }

            COVER_TX:coverpoint tx_reg{
                wildcard bins data_rcv={8'h??};
            }

        endgroup
        function new();
            I2C_REG = new();
            $display("new cg!");
        endfunction

        function void set_interface(virtual duttb_intf_src.TBconnect src);
            this.src = src;
        endfunction

// coverage sample
        task sample();
            forever begin
                @(posedge src.clk)
            // wait the rising edge of the clock 
                case(src.apb_addr)
                    32'h10025000://CLK
                    begin
                        this.clk_reg = src.apb_wdata;
                    end
                    32'h10025004://CTR
                    begin
                        this.ctr_reg = src.apb_wdata;
                    end
                    32'h10025008://RX
                    begin
                        this.rx_reg = src.apb_rdata;
                    end

                    32'h1002500C://STA
                    begin
                        this.sta_reg = src.apb_rdata;
                    end
                    32'h10025010://TX
                    begin
                        this.tx_reg = src.apb_wdata;
                    end
                    32'h10025014://CMD
                    begin
                        this.cmd_reg = src.apb_wdata;
                    end
                endcase
                I2C_REG.sample();
            end
        endtask
                
    endclass

    

endpackage