`timescale 1ns / 100ps
module EEPROM_AT24C64 #(
    parameter timeslice = 150 
    // the eeprom responce delay after scl's negedge
    // thus the value must smaller than scl_period/2 (ns)
    // because the responce must be setup before next
    // scl posedge
) (
    input wire scl,
    inout wire sda
);

// -----------------------------------------------------
// memory devices and ther ctrl vector
// -----------------------------------------------------
     
    reg [7:0] ctrl_byte;  
    parameter
        r7 = 8'b1010_1111,  w7 = 8'b1010_1110,   // device 7 : [7:1] is addr, [0] is w/r operation ae
        r6 = 8'b1010_1101,  w6 = 8'b1010_1100,   // device 6 : [7:1] is addr, [0] is w/r operation ac
        r5 = 8'b1010_1011,  w5 = 8'b1010_1010,   // device 5 : [7:1] is addr, [0] is w/r operation aa
        r4 = 8'b1010_1001,  w4 = 8'b1010_1000,   // device 4 : [7:1] is addr, [0] is w/r operation a8
        r3 = 8'b1010_0111,  w3 = 8'b1010_0110,   // device 3 : [7:1] is addr, [0] is w/r operation a6
        r2 = 8'b1010_0101,  w2 = 8'b1010_0100,   // device 2 : [7:1] is addr, [0] is w/r operation a4
        r1 = 8'b1010_0011,  w1 = 8'b1010_0010,   // device 1 : [7:1] is addr, [0] is w/r operation a2
        r0 = 8'b1010_0001,  w0 = 8'b1010_0000;   // device 0 : [7:1] is addr, [0] is w/r operation a0

    // shared mem with 1 byte on each 13bit address { h[4:0] , l[7:0] }
    reg [7 :0] memory  [8191:0]; 
    reg [12:0] address         ; 
    reg [7 :0] addr_byte_h     ;     
    reg [7 :0] addr_byte_l     ;

// -----------------------------------------------------
// regs
// -----------------------------------------------------

    reg [1:0] State;                                      
    // eeprom behavior state : 
    // 2'b00 IDLE
    // 2'b01 CRTL   = START + CTRL_BYTE + ACK + ADDRESS + ACK
    // 2'b10 WRITE  = WDATA + ACK + STOP
    // 2'b11 READ   = START + CTRL_BYTE + ACK + RDATA + ACK + STOP     
     
    reg [7:0] shift     ; // buffers     
    reg [7:0] memory_buf; // buffers     
    reg [7:0] sda_buf   ; // buffers  

    reg       out_flag  ; // emable sda driver when ack needed   

// -----------------------------------------------------
// eeprom behavior
// -----------------------------------------------------
    
    integer i;
    
    initial begin
        addr_byte_h  = 0;
        addr_byte_l  = 0;
        ctrl_byte    = 0;
        out_flag     = 0;
        sda_buf      = 0;
        State        = 2'b00;
        memory_buf   = 0;
        address      = 0;
        shift        = 0;
    
        for(i=0;i<=8191;i=i+1) memory[i] = 0;
    end
    
    always@(negedge sda) begin
        if(scl == 1) begin                              // detect START 
            State = State + 1;                          
            if(State == 2'b11) begin                    // if START from WRITE, goto READ
                disable write_to_eeprom;                // else goto WRITE
            end
        end
    end

    always@(posedge sda) begin                          // DETECT sda activity, which is always triggered by CTRL_BYTE's first bit and STOP
        if(scl == 1) begin                              // if STOP                                 
            stop_W_R;                                 
        end else begin                                  // if not STOP
            casex(State)                                // note that CTRL_BYTE[7] is always 1

                2'b01: begin                                                
                    read_in;                            // CTRL : receive ctrl_byte and address
                    if(   ctrl_byte == w7  || ctrl_byte == w6
                       || ctrl_byte == w5  || ctrl_byte == w4
                       || ctrl_byte == w3  || ctrl_byte == w2
                       || ctrl_byte == w1  || ctrl_byte == w0
                    ) begin                             // if op is WRITE
                        State = 2'b10;                  // set WRITE
                        write_to_eeprom;                // receive WDATA and operate mem then back to IDLE (during this task, 
                    end else begin                      // if the i2c operation is READ, the State will changed to 2'b11(by re-START detected)
                        State = 2'b00;
                    end
                end
    
                2'b11:   read_from_eeprom;              // READ operation
    
                default: State = 2'b00;

            endcase
        end
    end

// -----------------------------------------------------
// task : stop_W_R
//        responce i2c STOP
// -----------------------------------------------------

    task stop_W_R;
        begin
            State        = 0;
            addr_byte_h  = 0;
            addr_byte_l  = 0;
            ctrl_byte    = 0;
            out_flag     = 0;
            sda_buf      = 0;
        end
    endtask

// -----------------------------------------------------
// task : read_in
//        read the (1) ctrl_byte (2) address 
//        with ack
// -----------------------------------------------------

    task read_in;
        begin
            shift_in(ctrl_byte);
            shift_in(addr_byte_h);
            shift_in(addr_byte_l);
        end
    endtask

// -----------------------------------------------------
// task : shift_in
//        record the next 8 scl cycles' sda to generate
//        an 1 byte data as shift
// -----------------------------------------------------

    task shift_in;
        output[7:0]shift;
        begin
            // read the 8bit on each scl posedge
            @(posedge scl) shift[7] = sda;
            @(posedge scl) shift[6] = sda;
            @(posedge scl) shift[5] = sda;
            @(posedge scl) shift[4] = sda;
            @(posedge scl) shift[3] = sda;
            @(posedge scl) shift[2] = sda;
            @(posedge scl) shift[1] = sda;
            @(posedge scl) shift[0] = sda;
            
            // generate ack
            @(negedge scl) begin
                #timeslice;
                out_flag = 1;
                sda_buf  = 0;
            end
    
            @(negedge scl) begin
                #timeslice;
                out_flag = 0;
            end
        end
    endtask

// -----------------------------------------------------
// task : eeprom memory operations
// -----------------------------------------------------

    task write_to_eeprom;
        begin
            shift_in(memory_buf);
            address = {addr_byte_h[4:0], addr_byte_l};
            memory[address] = memory_buf;
            State = 2'b00;
        end
    endtask

    task read_from_eeprom;
        begin
            shift_in(ctrl_byte);                      
            if(   ctrl_byte == r7  || ctrl_byte == r6
               || ctrl_byte == r5  || ctrl_byte == r4
               || ctrl_byte == r3  || ctrl_byte == r2
               || ctrl_byte == r1  || ctrl_byte == r0
            ) begin
                address = {addr_byte_h[4:0], addr_byte_l};
                sda_buf = memory[address];
                shift_out;
                State = 2'b00;
            end
        end
    endtask

// -----------------------------------------------------
// task : eeprom memory operations
// -----------------------------------------------------

    task shift_out;
        begin
            out_flag = 1;
            for(i=6; i>=0; i=i-1) begin
                @(negedge scl);
                #timeslice;
                sda_buf = sda_buf << 1;
            end
            // in read mode, hoped that data from eeprom,
            // while ack is from master
            @(negedge scl) #timeslice begin out_flag = 0; sda_buf[7] = 1; end 
            @(negedge scl) #timeslice out_flag = 0;
        end
    endtask

// -----------------------------------------------------
// sda output
// -----------------------------------------------------

    assign sda = (out_flag == 1) ? sda_buf[7] : 1'bz;
    
endmodule