module geofence (clk,
                 reset,
                 X,
                 Y,
                 valid,
                 is_inside);
    input clk;
    input reset;
    input [9:0] X;
    input [9:0] Y;
    output valid;
    output is_inside;
    //reg valid;
    //reg is_inside;
    reg [2:0] next_state ;
    reg [2:0] current_state ;

    /*-----------CROSS_PRODUCT_DECLARE-------*/
    reg cross_product_in_ref_point[19:0] ;
    reg cross_product_in_input_point_1[19:0];
    reg cross_product_in_input_point_2[19:0];
    wire signed cross_result[19:0];
    wire cross_out;

    wire cross_product_in_ref_point_x[9:0];
    wire cross_product_in_ref_point_y[9:0];

    wire cross_product_in_input_point_1_x[9:0];
    wire cross_product_in_input_point_1_y[9:0];

    wire cross_product_in_input_point_2_x[9:0];
    wire cross_product_in_input_point_2_y[9:0];


    parameter IDLE         = 3'd0;
    parameter RD_DATA      = 3'd1;
    parameter POSITION_CAL = 3'd2;
    parameter DET_INSIDE   = 3'd3;
    parameter DONE         = 3'd4;

    reg [2:0] counter_reg;
    reg [19:0] postion_reg;

    wire rd_data_done_flag;
    wire rd_data;
    assign rd_data_done_flag = (counter_reg == 3'd7);
    assign rd_data           = (current_state == RD_DATA);


    always @(posedge clk or posedge reset)
    begin
        if (reset)
            counter_reg <= 3'd0;
        else if (!reset)
            counter_reg <= rd_data_done_flag ? 3'd0 : counter_reg + 3'd1;
            end

        /*----------FSM-----------*/
        always @(posedge clk or posedge reset)
        begin
            current_state <= (reset) ? IDLE : next_state;
        end

        always @(*)
        begin
            case (current_state)
                IDLE:
                next_state = (!reset) ? RD_data : IDLE;
                RD_DATA:
                next_state = (rd_data_done_flag) ? POSITION_CAL : RD_DATA;
                POSITION_CAL:
                next_state = ;
                DET_INSIDE:
                DONE:
                default:
            endcase
        end

        /*----------RD_DATA----------*/
        always @(posedge clk or posedge reset)
        begin
            if (reset)
                postion_reg <= 20'd0;
            else if (!reset)
                postion_reg [counter_reg] <= {X,Y};
                end

            /*--------CROSS_PRODUCT INPUTS---------*/
            always @(*)
            begin
                case(current_state)
                    POSITION_CAL:
                    begin
                        cross_product_in_input_point_1 = postion_reg[counter_reg];
                        cross_product_in_input_point_2 = postion_reg[pointer_reg];
                        cross_product_in_ref_point     = postion_reg[0];
                    end
                    DET_INSIDE:
                    begin
                        cross_product_in_input_point_1 = test_point_reg;
                        cross_product_in_input_point_2 = position_reg[counter_reg];
                        cross_product_in_ref_point     = postion_reg[0];
                    end

                    default:
                    begin
                        cross_product_in_input_point_1 = 0;
                        cross_product_in_input_point_2 = 0;
                        cross_product_in_ref_point     = 0;
                    end
                endcase
            end

            /*------------CROSS PRODUCT----------*/
            assign {cross_product_in_input_point_1_x,cross_product_in_input_point_1_y} = cross_product_in_input_point_1;
            assign {cross_product_in_input_point_2_x,cross_product_in_input_point_2_y} = cross_product_in_input_point_2;
            assign {cross_product_in_ref_point_x,cross_product_in_ref_point_y}         = cross_product_in_ref_point;


            assign cross_result = (cross_product_in_input_point_1_x - cross_product_in_ref_point_x)
            *(cross_product_in_input_point_2_y-cross_product_in_ref_point_y)
            - (cross_product_in_input_point_2_x-cross_product_in_ref_point_x)
            *(cross_product_in_input_point_1_y - cross_product_in_ref_point_y);

            assign cross_out = cross_result > 0;


            endmodule
