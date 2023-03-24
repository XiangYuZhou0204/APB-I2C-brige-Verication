typedef logic [31:0] data_t;
typedef enum logic [31:0] { ADDR_REG_CLK = 32'h10025000,
                            ADDR_REG_CTR = 32'h10025004,
                            ADDR_REG_RX  = 32'h10025008,
                            ADD_REG_STA  = 32'h1002500C,
                            ADD_REG_TX   = 32'h10025010,
                            ADD_REG_CMD  = 32'h10025014} address_t;
