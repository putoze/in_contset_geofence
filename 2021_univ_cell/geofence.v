module geofence (clk,reset,X,Y,valid,is_inside);
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

  parameter IDLE = 3'd0;
  parameter RD_DATA = 3'd1;
  parameter POSITION_CAL= 3'd2;
  parameter DET_INSIDE = 3'd3;
  parameter DONE = 3'd4;

  reg [2:0] counter_reg;
  reg [2:0] pointer_reg;
  reg [19:0] position_reg[0:5];
  reg [19:0] test_point_reg;

  wire [2:0] counter_wire;

  wire rd_data_done_flag;
  wire position_cal_done_flag;
  wire det_inside_done_flag;
  wire iteration_clear;

  wire rd_data;
  wire position_cal;
  wire det_inside;

  assign counter_wire = iteration_clear ? 3'd0 : counter_reg + 3'd1;

  assign rd_data_done_flag = (counter_reg == 3'd6);
  assign position_cal_done_flag = (counter_reg == 3'd5 && position_cal);
  assign rd_data = (current_state == RD_DATA);
  assign iteration_clear = (pointer_reg == 3'd5);

  assign det_inside_done_flag = (counter_reg == 3'd5 && det_inside);
  assign position_cal = (current_state == POSITION_CAL);
  assign det_inside = (current_state == DET_INSIDE);

  //counter_reg
  always @(posedge clk or posedge reset)
  begin
    if(reset)
      counter_reg <= 3'd0;
    else if(det_inside)
      counter_reg <= det_inside_done_flag ? 3'd0 : counter_reg + 3'd1;
    else if(iteration_clear)
      counter_reg <= position_cal_done_flag ? 3'd0 : counter_wire;
    else if(rd_data)
      counter_reg <= rd_data_done_flag ? 3'd1 : counter_reg + 3'd1;
  end

  //pointer_reg
  always @(posedge clk or posedge reset)
  begin
    if(reset)
      pointer_reg <= 3'd0;
    else if(position_cal)
      pointer_reg <= (iteration_clear) ? counter_wire : pointer_reg + 3'd1;
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
    if(reset) begin
        for(i=0;i<6;i=i+1) begin
            position_reg[i] <= 20'd0;
        end
    end
    else if(rd_data)
      position_reg [counter_reg] <= {X,Y};
    else if(current_state == IDLE)
      test_point_reg <= {X,Y};
  end



endmodule

