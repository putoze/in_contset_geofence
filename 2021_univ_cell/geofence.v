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

    parameter IDLE         = 3'd0;
    parameter RD_DATA      = 3'd1;
    parameter POSITION_CAL = 3'd2;
    parameter DET_INSIDE   = 3'd3;
    parameter DONE         = 3'd4;
    /*-----------CROSS_PRODUCT_DECLARE-------*/
    reg [19:0]cross_product_in_ref_point ;
    reg [19:0]cross_product_in_input_point_1;
    reg [19:0]cross_product_in_input_point_2;
    wire [9:0]cross_product_in_ref_point_x;
    wire [9:0]cross_product_in_ref_point_y;

    wire [9:0]cross_product_in_input_point_1_x;
    wire [9:0]cross_product_in_input_point_1_y;

    wire[9:0] cross_product_in_input_point_2_x;
    wire[9:0] cross_product_in_input_point_2_y;

    wire signed [19:0]cross_result;
    wire cross_out;

    /*-------------Counter_pointer_declare-------*/
    reg [2:0] counter_reg;
    reg [2:0] pointer_reg;
    reg [19:0] position_reg[0:5];
    reg [19:0] test_point_reg;

    /*-----------------Flags--------------------*/
    wire [2:0] counter_wire;
    wire rd_data_done_flag;
    wire position_cal_done_flag;
    wire det_inside_done_flag;
    wire iteration_clear;

    wire rd_data;
    wire state_position_cal;
    wire state_det_inside;

    assign counter_wire = iteration_clear ? 3'd0 : counter_reg + 3'd1;

    assign rd_data_done_flag      = (counter_reg == 3'd6);
    assign position_cal_done_flag = (counter_reg == 3'd5 && state_position_cal);
    assign rd_data                = (current_state == RD_DATA);
    assign iteration_clear        = (pointer_reg == 3'd5);

    assign det_inside_done_flag = (counter_reg == 3'd5 && state_det_inside);
    assign state_position_cal         = (current_state == POSITION_CAL);
    assign state_det_inside           = (current_state == DET_INSIDE);

    //counter_reg
    always @(posedge clk or posedge reset)
    begin
        if (reset)
        begin
            counter_reg <= 3'd0;
        end
        else if (state_det_inside)
        begin
            counter_reg <= det_inside_done_flag ? 3'd0 : counter_reg + 3'd1;
        end
            else if (iteration_clear)
            begin
            counter_reg <= position_cal_done_flag ? 3'd0 : counter_wire;
            end
            else if (rd_data)
            begin
            counter_reg <= rd_data_done_flag ? 3'd1 : counter_reg + 3'd1;
            end
        else
        begin
            counter_reg <= counter_reg;
        end
    end

    //pointer_reg
    always @(posedge clk or posedge reset)
    begin
        if (reset)
            pointer_reg <= 3'd0;
        else if (state_position_cal)
            pointer_reg <= (iteration_clear) ? counter_wire : pointer_reg + 3'd1;
        else
        begin
            pointer_reg <= pointer_reg;
        end
    end

    always @(*)
    begin
        case (current_state)
            IDLE:
            next_state = (!reset) ? RD_DATA : IDLE;
            RD_DATA:
            next_state = (rd_data_done_flag) ? POSITION_CAL : RD_DATA;
            POSITION_CAL:
            next_state = (counter_reg == 3'd5) ? DET_INSIDE : POSITION_CAL;
            DET_INSIDE:
            next_state = (counter_reg == 3'd5) ? DET_INSIDE : DONE;
            DONE:
            next_state = IDLE;
            default:
            next_state = IDLE;
        endcase
    end

    /*----------RD_DATA----------*/
    integer i;
    always @(posedge clk or posedge reset)
    begin
        if (reset)
        begin
            for(i = 0;i<6;i = i+1)
            begin
                position_reg[i] <= 20'd0;
            end
        end
        else if (rd_data)
        begin
            position_reg [counter_reg] <= {X,Y};
        end
            else if (current_state == IDLE)
            begin
            test_point_reg <= {X,Y};
            end
        else
        begin
            position_reg[counter_reg] <= position_reg[counter_reg];
        end
    end


    /*--------CROSS_PRODUCT INPUTS---------*/
    always @(*)
    begin
        case(current_state)
            POSITION_CAL:
            begin
                cross_product_in_input_point_1 = position_reg[counter_reg];
                cross_product_in_input_point_2 = position_reg[pointer_reg];
                cross_product_in_ref_point     = position_reg[0];
            end
            DET_INSIDE:
            begin
                cross_product_in_input_point_1 = test_point_reg;
                cross_product_in_input_point_2 = position_reg[counter_reg];
                cross_product_in_ref_point     = position_reg[0];
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
