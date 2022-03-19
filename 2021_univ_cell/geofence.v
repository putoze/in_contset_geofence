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

    integer i              = 0;
    parameter IDLE         = 3'd0;
    parameter RD_DATA      = 3'd1;
    parameter POSITION_CAL = 3'd2;
    parameter DET_INSIDE   = 3'd3;
    parameter DONE         = 3'd4;
    /*-----------CROSS_PRODUCT_DECLARE-------*/
    reg [19:0]cross_product_in_ref_point ;
    reg [19:0]cross_product_in_input_point_1;
    reg [19:0]cross_product_in_input_point_2;
    wire signed [19:0]cross_result;
    wire cross_out;

    reg [2:0] counter_reg;
    reg [2:0] pointer_reg;
    reg [19:0] position_reg[0:5];
    reg [19:0] test_point_reg;

    wire [2:0] counter_wire;

    wire rd_data_done_flag;
    wire position_cal_done_flag;
    wire det_inside_done_flag;
    wire iteration_clear;

    wire idle;
    wire rd_data;
    wire position_cal;
    wire det_inside;
    wire done;

    assign counter_wire = !position_cal ? 3'd0 : iteration_clear ? counter_reg + 3'd1 : counter_reg;

    assign rd_data_done_flag      = (counter_reg == 3'd5);
    assign position_cal_done_flag = (counter_reg == 3'd4 && position_cal);
    assign iteration_clear        = (pointer_reg == 3'd5);
    assign det_inside_done_flag   = (counter_reg == 3'd5 && det_inside);

    wire [9:0]cross_product_in_ref_point_x;
    wire [9:0]cross_product_in_ref_point_y;

    wire [9:0]cross_product_in_input_point_1_x;
    wire [9:0]cross_product_in_input_point_1_y;

    wire[9:0] cross_product_in_input_point_2_x;
    wire[9:0] cross_product_in_input_point_2_y;

    assign idle         = (current_state == IDLE)  ;
    assign rd_data      = (current_state == RD_DATA);
    assign position_cal = (current_state == POSITION_CAL);
    assign det_inside   = (current_state == DET_INSIDE);
    assign done         = (current_state == DONE);
    //counter_reg
    always @(posedge clk or posedge reset)
    begin
        if (reset)
            counter_reg <= 3'd0;
        else if (det_inside)
            counter_reg <= det_inside_done_flag ? 3'd0 : counter_reg + 3'd1;
        else if (iteration_clear)
            counter_reg <= position_cal_done_flag ? 3'd0 : counter_wire;
        else if (rd_data)
            counter_reg <= rd_data_done_flag ? 3'd1 : counter_reg + 3'd1;
        else
            counter_reg <= counter_reg;
    end

    //pointer_reg
    always @(posedge clk or posedge reset)
    begin
        if (reset)
            pointer_reg <= 3'd2;
        else if (position_cal)
            pointer_reg <= (iteration_clear) ? counter_wire + 3'd1 : pointer_reg + 3'd1;
        else
            pointer_reg <= 3'd2;
    end

    always @(posedge clk or posedge reset)
    begin
        current_state <= (reset) ? IDLE : next_state ;
    end

    always @(*)
    begin
        case (current_state)
            IDLE:
            next_state = (!reset) ? RD_DATA : IDLE;
            RD_DATA:
            next_state = (rd_data_done_flag) ? POSITION_CAL : RD_DATA;
            POSITION_CAL:
            next_state = (counter_reg == 3'd4) ? DET_INSIDE : POSITION_CAL;
            DET_INSIDE:
            next_state = cross_out & det_inside ? DONE: (counter_reg == 'd5) ? DONE : DET_INSIDE;
            DONE:
            next_state = IDLE;
            default:
            next_state = IDLE;
        endcase
    end

    /*----------RD_DATA----------*/

    always @(posedge clk or posedge reset)
    begin
        if (reset)
        begin
            for(i = 0;i<6;i = i+1)
            begin
                position_reg[i] <= 20'd0;
            end
            test_point_reg <= 20'd0;
        end
        else if (rd_data)
            position_reg [counter_reg] <= {X,Y};
        else if (idle)
            test_point_reg <= {X,Y};
        else
            test_point_reg <= test_point_reg;
    end

    //position_reg
    always @(posedge clk)
    begin
        if (reset)
        begin
            for(i = 0;i<6;i = i+1)
            begin
                position_reg[i] <= 20'd0;
            end
        end
        else
        begin
            if (position_cal)
            begin
                position_reg[counter_reg] <= cross_out ? position_reg[pointer_reg] : position_reg[counter_reg];
                position_reg[pointer_reg] <= cross_out ? position_reg[counter_reg] : position_reg[pointer_reg];
            end
            else
            begin
                for(i = 0;i<6;i = i+1)
                begin
                    position_reg[i] <= position_reg[i];
                end
            end
        end
    end

    //test_point_reg
    always @(posedge clk or posedge reset)
    begin
        test_point_reg <= reset ? 20'd0 : idle ? {X,Y} : test_point_reg;
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

    /*------------DONE----------------*/
    assign valid     = (done) ? 1 : 0;
    assign is_inside = (done) ? (cross_out ? 1 : 0) : 0;

endmodule
