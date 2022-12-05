clc
clear all
close all
% Plan_A 裂解气先预热甲醇后增压                  省煤器尾气和裂解气预热
%%  CAES模块节点压力
% 环境温度和压力
P_0 = 101000;         % Pa
T_0 = 273.15+20;      % K

% 储气室温度和压力
P_store_IN = 7.2e6;       % Pa
T_store = 273.15+20;      % K
P_store_OUT = 4.2e6;      % Pa

% 设备
np = 0.9;     % 水泵效率
nc = 0.85;    % 压气机效率
ncc = 0.85;    % 压气机效率
nt = 0.85;    % 透平效率
ntt = 0.85;    % 透平效率
%  GTCC参数
T_ranshao = 1430;      % 燃烧后温度 K
epsilon = 15;          % GTCC压比
T_r_zhengfa_out = 540; % 蒸发器出口烟气温度 K 
P_t_IN = 4000000;      % 蒸汽透平进口压力 Pa
T_t_IN = 765;          % 蒸汽透平进口温度 K
P_t_OUT = 5000;        % 蒸汽透平出口压力 Pa

%  CRR参数
T_liejie = 273.15+250; % 裂解温度 K
P_liejie = 300000;     % 裂解压力 Pa

% 考虑换热器压损后两级压缩机的压比
[yabi,P_yabi] = yabi_yasun(P_0,P_store_IN);

% 考虑换热器压损后两级透平的膨胀比
[pengzhangbi,P_pengzhangbi] = pengzhangbi_yasun(P_0,P_store_OUT);

% 保存CAES部分的压力值
for i = 1:10
    if i<6
        P(i,1) = P_yabi(end,i);
    else
        P(i,1) = P_pengzhangbi(end,i-5);
    end
end


%% （三层迭代） 裂解气混合温度~由最小空气流量控制后无需迭代
T_liejie_mix = T_liejie;
%% （二层迭代） 裂解气进燃烧室温度
T_liejie_CC = 500;
T_zengya_OUT_max = 650;
T_liejie_CC_ini = T_zengya_OUT_max;
j = 0;
while    (abs(T_liejie_CC-T_liejie_CC_ini)>1e-3)
clear M RK



%% （一层迭代） 调节燃空比和甲醇流量
rankong_a = 10;
rankong_b = 30;

i=1;

m_mmethanol = 13;
mmethanol = 0; 
while(abs((m_mmethanol-mmethanol)/(m_mmethanol))>0.000001) 

% GTCC
[ng_a,mr_a,QH_a,p2_IN_a,Tr_shengmeiOUTa,xN2a,xAra,xO2a,xCO2a,xH20a,T2_OUTa,p2_OUTa,Q_parta,W_GTCCa,W_Ra,T1_OUTa,Tw1_OUTa,Tw3_INa,Tw3_OUTa,mqa,PowerWTa,PowerWQa,PowerWPa,PowerWCa,PowerHRSGa] = GTCC(...
                    m_mmethanol,rankong_a ,...    % 甲醇质量流量，空燃比
                    P_0,T_0,epsilon,nc,...        % 环境压力，环境温度，压缩压比，压缩机效率
                    T_ranshao,nt,...              % 燃机入口温度，透平效率
                    T_r_zhengfa_out,...           % 蒸发器出口烟气温度
                    P_t_IN,T_t_IN,nt,P_t_OUT,...  % 汽机入口压力，汽机入口温度，汽机效率，汽机出口压力，
                    np);                          % 水泵效率
                
[ng_b,mr_b,QH_b,p2_IN_b,Tr_shengmeiOUTb,xN2b,xArb,xO2b,xCO2b,xH20b,T2_OUTb,p2_OUTb,Q_partb,W_GTCCb,W_Rb,T1_OUTb,Tw1_OUTb,Tw3_INb,Tw3_OUTb,mqb,PowerWTb,PowerWQb,PowerWPb,PowerWCb,PowerHRSGb] = GTCC(...
                    m_mmethanol,rankong_b ,...    % 甲醇质量流量，空燃比
                    P_0,T_0,epsilon,nc,...        % 环境压力，环境温度，压缩压比，压缩机效率
                    T_ranshao,nt,...              % 燃机入口温度，透平效率
                    T_r_zhengfa_out,...           % 蒸发器出口烟气温度
                    P_t_IN,T_t_IN,nt,P_t_OUT,...  % 汽机入口压力，汽机入口温度，汽机效率，汽机出口压力，
                    np);                          % 水泵效率
                
% 燃烧
[Hm_a] = Q_ranshao(...
                   T_ranshao,p2_IN_a,...     % 燃机入口温度，入口压力
                   T_liejie_CC);             % 裂解气增压后温度
                      
[Hm_b] = Q_ranshao(...
                   T_ranshao,p2_IN_b,...     % 燃机入口温度，入口压力
                   T_liejie_CC);             % 裂解气增压后温度
                                           
% 配比                  
[mr1_a,mmethanol_a] = peibi(...
                        mr_a,...    % 烟气质量流量
                        Hm_a,...    % 燃烧反应单位质量放热量
                        QH_a);      % 燃烧室中过量空气单位质量吸热量
                    
[mr1_b,mmethanol_b] = peibi(...
                        mr_b,...    % 烟气质量流量
                        Hm_b,...    % 燃烧反应单位质量放热量
                        QH_b);      % 燃烧室中过量空气单位质量吸热量
                    
% 判断空燃比区间是否合适                   
    if mmethanol_a < m_mmethanol & mmethanol_b > m_mmethanol
        rankong_c = (rankong_a+rankong_b)/2;
        [ng_c,mr_c,QH_c,p2_IN_c,Tr_shengmeiOUTc,xN2c,xArc,xO2c,xCO2c,xH20c,T2_OUTc,p2_OUTc,Q_partc,W_GTCCc,W_Rc,T1_OUTc,Tw1_OUTc,Tw3_INc,Tw3_OUTc,mqc,PowerWTc,PowerWQc,PowerWPc,PowerWCc,PowerHRSGc] = GTCC(...
                                        m_mmethanol,rankong_c ,...    % 甲醇质量流量，空燃比
                                        P_0,T_0,epsilon,nc,...        % 环境压力，环境温度，压缩压比，压缩机效率
                                        T_ranshao,nt,...              % 燃机入口温度，透平效率
                                        T_r_zhengfa_out,...           % 蒸发器出口烟气温度
                                        P_t_IN,T_t_IN,nt,P_t_OUT,...  % 汽机入口压力，汽机入口温度，汽机效率，汽机出口压力，
                                        np);                          % 水泵效率
        [Hm_c] = Q_ranshao(...
                           T_ranshao,p2_IN_c,...     % 燃机入口温度，入口压力
                           T_liejie_CC);             % 裂解气增压后温度
        [mr1_c,mmethanol_c] = peibi(...
                                    mr_c,...    % 烟气质量流量
                                    Hm_c,...    % 燃烧反应单位质量放热量
                                    QH_c);      % 燃烧室中过量空气单位质量吸热量
    else
        fprintf('ERROR\n')
    end
%
M (i,1) = mmethanol_a;
M (i,2) = mmethanol_b;
M (i,3) = mmethanol_c;
RK (i,1) = rankong_a;
RK (i,2) = rankong_b;
RK (i,3) = rankong_c;
% 迭代数据替换             
                    if mmethanol_c > m_mmethanol
                        rankong_a = rankong_a;
                        rankong_b = rankong_c;
                    elseif mmethanol_c < m_mmethanol
                        rankong_a = rankong_c;
                        rankong_b = rankong_b;
                    else
                        fprintf('ERROR\n')
                    end
                    
mmethanol =  mmethanol_c;  

i=i+1;
end
                    
%% 裂解反应                          
[H1] = Q_liejie(...
                T_liejie,P_liejie);   % 裂解温度，裂解压力

% 甲醇泵入           
[P_CHO_OUT,T_CHO_OUT,w_PUM_CHO] = PUMP_CHO(...
                        P_0,T_0,...                % 环境压力，环境温度
                        P_liejie,...               % 裂解压力
                        np);     
                    
% CAES一级压缩           
[P_COM1_OUT,T_COM1_OUT,w_COM_1] = COM(ncc,yabi,P(1,1),T_0);

%% 省煤器预热段 4  （烟气余热）
% 省煤器预热段 4  （烟气预热 考虑蒸发过程）
h_HX14_cold_xiangbian = refpropm('H','P',P_CHO_OUT/1000,'Q',0,'METHANOL');
T_HX14_cold_xiangbian = refpropm('T','P',P_CHO_OUT/1000,'Q',0,'METHANOL');
fprintf('——烟气预热判断——\n');
     if (Tr_shengmeiOUTc-10)>T_HX14_cold_xiangbian                                     
        fprintf('     烟气预热温度大于相变温度\n');
     else 
        fprintf('     ERROR!!!烟气预热温度小于相变温度\n');
     end

h_HX14_cold_IN = refpropm('H','T',T_CHO_OUT,'P',P_CHO_OUT/1000,'METHANOL');  % 第一裂解气预热段甲醇入口焓/J/kg
h_HX14_hot_IN = refpropm('H','T',Tr_shengmeiOUTc,'P',P(1,1)/1000,'NITROGEN','ARGON','OXYGEN','CO2','WATER',[xN2c xArc xO2c xCO2c xH20c]);
m_HX4_yanqi = mr_c;
m_HX4_cold = m_mmethanol;
h_HX14_hot_zhengfa_OUT = refpropm('H','T',T_HX14_cold_xiangbian+10,'P',P(1,1)/1000,'NITROGEN','ARGON','OXYGEN','CO2','WATER',[xN2c xArc xO2c xCO2c xH20c]);
h_HX14_cold_OUT = (h_HX14_hot_IN-h_HX14_hot_zhengfa_OUT)*m_HX4_yanqi/m_HX4_cold+h_HX14_cold_xiangbian;
T_HX14_cold_OUT = refpropm('T','H',h_HX14_cold_OUT,'P',P_CHO_OUT/1000,'METHANOL');
Q_HX14_cold_OUT = refpropm('Q','H',h_HX14_cold_OUT,'P',P_CHO_OUT/1000,'METHANOL');
h_HX14_hot_OUT = h_HX14_hot_zhengfa_OUT-(h_HX14_cold_xiangbian-h_HX14_cold_IN)*m_HX4_cold/m_HX4_yanqi;
T_HX14_hot_OUT = refpropm('T','H',h_HX14_hot_OUT,'P',P(1,1)/1000,'NITROGEN','ARGON','OXYGEN','CO2','WATER',[xN2c xArc xO2c xCO2c xH20c]);
fprintf('——烟气预热计算——\n');
     if (Tr_shengmeiOUTc-10)>T_HX14_cold_OUT                                     
        fprintf('     烟气预热冷流体出口正常\n');
     else 
        fprintf('     ERROR!!!烟气预热冷流体出口不匹配\n');
     end
     
     if Q_HX14_cold_OUT<1 & Q_HX14_cold_OUT>0                                     
        fprintf('     烟气预热(蒸发)冷流体出口为  两相\n');
     else 
        fprintf('     烟气预热(蒸发)冷流体出口为  非两相\n');
     end
     
     if (T_HX14_hot_OUT-10)>T_CHO_OUT                                      
        fprintf('     烟气预热热流体出口正常\n');
     else 
        fprintf('      ERROR!!!烟气预热热流体出口温度不匹配\n');
     end     

%% 裂解气预热段 3 （裂解气热量）
% Plan_A （1/4）
h_HX13_cold_IN = h_HX14_cold_OUT;
T_HX13_cold_IN = T_HX14_cold_OUT;
Q_HX13_cold_IN = Q_HX14_cold_OUT;
m_HX3_cold = m_HX4_cold;
m_HX3_hot = m_HX3_cold;

T_HX13_hot_IN = T_liejie_mix; 
h_HX13_hot_IN = refpropm('H','T',T_HX13_hot_IN,'P',P_liejie/1000,'HYDROGEN','CO',[0.125 0.875]);

T_HX13_hot_OUT = T_HX13_cold_IN+10;
h_HX13_hot_OUT = refpropm('H','T',T_HX13_hot_OUT,'P',P_liejie/1000,'HYDROGEN','CO',[0.125 0.875]);
h_HX13_cold_OUT = h_HX13_cold_IN+(h_HX13_hot_IN-h_HX13_hot_OUT)/m_HX3_cold*m_HX3_hot;
T_HX13_cold_OUT = refpropm('T','H',h_HX13_cold_OUT,'P',P_CHO_OUT/1000,'METHANOL');
fprintf('——裂解气预热计算——\n');
     if (T_HX13_cold_OUT+10)<T_HX13_hot_IN                                      
        fprintf('     裂解气预热冷流体出口正常\n');
     else 
        fprintf('     ERROR!!!裂解气预热冷流体出口不匹配\n');
     end
     
     if T_HX13_hot_IN>(T_HX13_cold_IN+10)                                    
        fprintf('     裂解气预热热流体进口正常\n');
     else 
        fprintf('     ERROR!!!裂解气预热热流体进口不匹配\n');
     end

%% 第一裂解段 1 （压缩热）（空气压损）         
h_HX11_hot_IN = refpropm('H','T',T_COM1_OUT,'P',P_COM1_OUT/1000,'AIR.MIX');     % 第一裂解气裂解段空气入口焓J/kg 
h_HX11_hot_OUT = refpropm('H','T',T_liejie+10,'P',P(3,1)/1000,'AIR.MIX');       % 第一裂解气裂解段空气出口焓J/kg 
m_HX1_cold = m_mmethanol/2;      % 第一裂解器中甲醇流量

% 最小CAES空气流量 
% 保证了T_liejie_mix=T_liejie
m_HX_AIR = H1*m_HX1_cold/(h_HX11_hot_IN-h_HX11_hot_OUT);  


%% 第一级AIR预热段 2 （压缩热）  （甲醇压损）
% Plan_A  （2/4）
h_HX12_hot_IN = h_HX11_hot_OUT;     % 第一裂解气预热段空气入口焓J/kg 
h_HX12_cold_OUT = refpropm('H','T',T_liejie,'P',P_liejie/1000,'METHANOL');
h_HX12_cold_IN = h_HX13_cold_OUT;
T_HX12_cold_IN = T_HX13_cold_OUT;
h_HX12_hot_OUT = h_HX12_hot_IN-(h_HX12_cold_OUT-h_HX12_cold_IN) * m_HX1_cold /m_HX_AIR;    % 第一裂解气预热段空气出口焓/J/kg
T_HX12_hot_OUT = refpropm('T','H',h_HX12_hot_OUT,'P',P(3,1)/1000,'AIR.MIX');               % 第一裂解气预热段空气出口温度K
fprintf('——第一级压缩热预热计算——\n');
     if (T_HX12_hot_OUT-10)<T_HX12_cold_IN                                     
        fprintf('     ERROR!!!第一级压缩热预热不匹配\n');
     else 
        fprintf('     第一级压缩热预热匹配\n');
     end

% % % % Plan_B （1/3）
% % % h_HX12_hot_IN = h_HX11_hot_OUT;     % 第一裂解气预热段空气入口焓J/kg 
% % % h_HX12_cold_OUT = refpropm('H','T',T_liejie,'P',P_liejie/1000,'METHANOL');
% % % h_HX12_cold_IN = h_HX14_cold_OUT;
% % % T_HX12_cold_IN = T_HX14_cold_OUT;
% % % h_HX12_hot_OUT = h_HX12_hot_IN-(h_HX12_cold_OUT-h_HX12_cold_IN) * m_HX1_cold /m_HX_AIR;    % 第一裂解气预热段空气出口焓/J/kg
% % % T_HX12_hot_OUT = refpropm('T','H',h_HX12_hot_OUT,'P',P(3,1)/1000,'AIR.MIX');               % 第一裂解气预热段空气出口温度K
% % % fprintf('——第一级压缩热预热计算——\n');
% % %      if (T_HX12_hot_OUT-10)<T_HX12_cold_IN                                     
% % %         fprintf('     ERROR!!!第一级压缩热预热不匹配\n');
% % %      else 
% % %         fprintf('     第一级压缩热预热匹配\n');
% % %      end


% COM1 冷却
P_COM2_IN = P(3,1);
T_COM2_IN = T_0+15;

% CAES二级压缩           
[P_COM2_OUT,T_COM2_OUT,w_COM_2] = COM(ncc,yabi,P_COM2_IN,T_COM2_IN);


%% 第二裂解段 1 （压缩热）（空气压损）         
h_HX21_hot_IN = refpropm('H','T',T_COM2_OUT,'P',P_COM2_OUT/1000,'AIR.MIX');     % 第二裂解气裂解段空气入口焓J/kg 
m_HX2_cold = m_mmethanol/2;
h_HX21_hot_OUT = h_HX21_hot_IN-H1*m_HX2_cold/m_HX_AIR; 
T_HX21_hot_OUT = refpropm('T','H',h_HX21_hot_OUT,'P',P(5,1)/1000,'AIR.MIX'); 
fprintf('——第二级压缩热裂解计算——\n');
     if (T_HX21_hot_OUT-10)<T_liejie                                     
        fprintf('     ERROR!!!第二级压缩热裂解不匹配\n');
     else 
        fprintf('     第二级压缩热裂解匹配\n');
     end
 
%% 第二级AIR预热段 2 （压缩热）  （甲醇压损）
% Plan_A  （3/4）
h_HX22_hot_IN = h_HX21_hot_OUT;     
h_HX22_cold_OUT = refpropm('H','T',T_liejie,'P',P_liejie/1000,'METHANOL');
h_HX22_cold_IN = h_HX13_cold_OUT;
T_HX22_cold_IN = T_HX13_cold_OUT;
h_HX22_hot_OUT = h_HX22_hot_IN-(h_HX22_cold_OUT-h_HX22_cold_IN) * m_HX2_cold /m_HX_AIR;    
T_HX22_hot_OUT = refpropm('T','H',h_HX22_hot_OUT,'P',P(5,1)/1000,'AIR.MIX');               
fprintf('——第二级压缩热预热计算——\n');
     if (T_HX22_hot_OUT-10)<T_HX22_cold_IN                                     
        fprintf('     ERROR!!!第二级压缩热预热不匹配\n');
     else 
        fprintf('     第二级压缩热预热匹配\n');
     end

% % % % Plan_B （2/3）
% % % h_HX22_hot_IN = h_HX21_hot_OUT;     
% % % h_HX22_cold_OUT = refpropm('H','T',T_liejie,'P',P_liejie/1000,'METHANOL');
% % % h_HX22_cold_IN = h_HX14_cold_OUT;
% % % T_HX22_cold_IN = T_HX14_cold_OUT;
% % % h_HX22_hot_OUT = h_HX22_hot_IN-(h_HX22_cold_OUT-h_HX22_cold_IN) * m_HX2_cold /m_HX_AIR;   
% % % T_HX22_hot_OUT = refpropm('T','H',h_HX22_hot_OUT,'P',P(5,1)/1000,'AIR.MIX');               
% % % fprintf('——第二级压缩热预热计算——\n');
% % %      if (T_HX22_hot_OUT-10)<T_HX22_cold_IN                                     
% % %         fprintf('     ERROR!!!第二级压缩热预热不匹配\n');
% % %      else 
% % %         fprintf('     第二级压缩热预热匹配\n');
% % %      end
     
% COM2 冷却

%% 裂解气增压
% Plan_A (4/4)
T_zengya_IN = T_HX13_hot_OUT;

% % % % Plan_B (3/3)
% % % T_zengya_IN = T_liejie;


P_zengya_IN = P_liejie;
h_zengya_IN = refpropm('H','T',T_zengya_IN,'P',P_zengya_IN/1000,'HYDROGEN','CO',[0.125 0.875]);
s_zengya_IN = refpropm('S','T',T_zengya_IN,'P',P_zengya_IN/1000,'HYDROGEN','CO',[0.125 0.875]);
P_zengya_OUT = p2_IN_c/(1-0.03);
h_zengya_OUT_rev = refpropm('H','P',P_zengya_OUT/1000,'S',s_zengya_IN,'HYDROGEN','CO',[0.125 0.875]);
h_zengya_OUT = (h_zengya_OUT_rev-h_zengya_IN)/nc+h_zengya_IN;
T_zengya_OUT = refpropm('T','H',h_zengya_OUT,'P',P_zengya_OUT/1000,'HYDROGEN','CO',[0.125 0.875]);
fprintf('——裂解气增压后温度计算——\n');
     if (T_zengya_OUT)<T_ranshao                                     
        fprintf('     裂解气增压后温度小于燃烧温度\n');
     else 
        fprintf('     裂解气增压后温度大于燃烧温度\n');
     end
     
%% 第二层迭代
fprintf('——第二层循环迭代——\n');
        if T_zengya_OUT<T_zengya_OUT_max
            T_liejie_CC_ini = T_liejie_CC; 
            T_liejie_CC = T_zengya_OUT;    
            j = j+1;
        else
            fprintf('     ERROR!!!第二层循环初值不合适\n');
            pause;
        end

end


%% 释能
m_21 = mr_c;
T_21 = T2_OUTc;
P_21 = p2_OUTc;
m_6 = m_HX_AIR;

m_25 = 0.40*m_21;    % 0~0.4
m_23 = 0.5*m_25;
m_24 = m_25-m_23;
m_22 = m_21-m_25;

% 省煤器预热
T_22 = Tr_shengmeiOUTc;
P_22 = P_0;
h_22_HOT_IN = refpropm('H','T',T_22,'P',P_22/1000,'NITROGEN','ARGON','OXYGEN','CO2','WATER',[xN2c xArc xO2c xCO2c xH20c]);
h_6_COLD_IN = refpropm('H','T',T_store,'P',P(6,1)/1000,'AIR.MIX');
h_22_HOT_OUT = refpropm('H','T',(T_store+10),'P',P_22/1000,'NITROGEN','ARGON','OXYGEN','CO2','WATER',[xN2c xArc xO2c xCO2c xH20c]);
h_6_COLD_OUT = (h_22_HOT_IN-h_22_HOT_OUT)*m_22/m_6+h_6_COLD_IN;
T_6_COLD_OUT = refpropm('T','H',h_6_COLD_OUT,'P',P(6,1)/1000,'AIR.MIX');
fprintf('——释能阶段 省煤器预热温度计算——\n');
     if (T_6_COLD_OUT+10)<T_22                                     
        fprintf('     释能阶段 省煤器预热正常\n');
     else 
        fprintf('     ERROR!!!释能阶段 省煤器预热\n');
     end
      
% 回热or不回热
T_24_HOT_IN = T_21;
P_24_HOT_IN = P_21;
h_24_HOT_IN = refpropm('H','T',T_24_HOT_IN,'P',P_24_HOT_IN/1000,'NITROGEN','ARGON','OXYGEN','CO2','WATER',[xN2c xArc xO2c xCO2c xH20c]);
T_62_COLD_IN = T_6_COLD_OUT;
P_62_COLD_IN = P(6,1);
h_62_COLD_IN = h_6_COLD_OUT;
h_24_HOT_OUT = refpropm('H','T',(T_62_COLD_IN+10),'P',P_0/1000,'NITROGEN','ARGON','OXYGEN','CO2','WATER',[xN2c xArc xO2c xCO2c xH20c]);
h_7 = (h_24_HOT_IN-h_24_HOT_OUT)*m_24/m_6+h_62_COLD_IN;
T_7 = refpropm('T','H',h_7,'P',P(7,1)/1000,'AIR.MIX');
fprintf('——释能阶段 高压段加热计算——\n');
     if (T_7+10)<T_24_HOT_IN                                     
        fprintf('     释能阶段 高压段加热正常\n');
     else 
        fprintf('     ERROR!!!释能阶段 高压段加热\n');
     end

     
     
[P_TUR1_OUT,T_TUR1_OUT,w_TUR_1] = TUR(ntt,pengzhangbi,P(7,1),T_7);     

     
T_23_HOT_IN = T_21;
P_23_HOT_IN = P_21;
h_23_HOT_IN = refpropm('H','T',T_23_HOT_IN,'P',P_23_HOT_IN/1000,'NITROGEN','ARGON','OXYGEN','CO2','WATER',[xN2c xArc xO2c xCO2c xH20c]);
T_8 = T_TUR1_OUT;
P_8 = P(8,1);
h_8 = refpropm('H','T',T_8,'P',P_8/1000,'AIR.MIX');
h_23_HOT_OUT = refpropm('H','T',(T_8+10),'P',P_0/1000,'NITROGEN','ARGON','OXYGEN','CO2','WATER',[xN2c xArc xO2c xCO2c xH20c]);
h_9 = (h_23_HOT_IN-h_23_HOT_OUT)*m_23/m_6+h_8;
T_9 = refpropm('T','H',h_9,'P',P(9,1)/1000,'AIR.MIX');
fprintf('——释能阶段 低压段加热计算——\n');
     if (T_9+10)<T_23_HOT_IN                                     
        fprintf('     释能阶段 低压段加热正常\n');
     else 
        fprintf('     ERROR!!!释能阶段 低压段加热\n');
     end
     
[P_TUR2_OUT,T_TUR2_OUT,w_TUR_2] = TUR(ntt,pengzhangbi,P(9,1),T_9);

h_25 = (h_23_HOT_OUT*m_23+h_24_HOT_OUT*m_24)/m_25;
T_25 = refpropm('T','H',h_25,'P',P_0/1000,'NITROGEN','ARGON','OXYGEN','CO2','WATER',[xN2c xArc xO2c xCO2c xH20c]);

fprintf('——释能阶段 回热温度计算——\n');
     if T_25<T_6_COLD_OUT                                     
        fprintf('     释能阶段 不需要回热\n');
     else 
        fprintf('     ERROR!!!释能阶段 可以考虑回热\n');
     end
     
     
%%
fprintf('——蒸汽部分——\n');
fprintf('蒸汽部分效率为%2.2f\n',ng_c);

Q_GTCC = Q_partc-h_zengya_OUT*m_mmethanol;
n_R = W_Rc/Q_GTCC;
n_GTCC = W_GTCCc/Q_GTCC;
fprintf('——燃气部分——\n');
fprintf('燃气部分效率为%2.2f\n',n_R);
fprintf('——联合循环——\n');
fprintf('联合循环效率为%2.2f\n',n_GTCC);


W_shi = (w_TUR_1+w_TUR_2)*m_6-(m_25/m_21)*(W_GTCCc-W_Rc);
W_chu = (w_COM_1+w_COM_2)*m_6+(w_PUM_CHO+h_zengya_OUT-h_zengya_IN)*m_mmethanol;


% h_HX12_hot_OUT;T_HX12_hot_OUT;P(3,1);    m_HX_AIR;
% T_COM2_IN;P_COM2_IN;
h_hot1 = refpropm('H','T',T_COM2_IN,'P',P_COM2_IN/1000,'AIR.MIX'); 
% h_HX22_hot_OUT;T_HX22_hot_OUT;P(5,1);
% T_COM2_IN;P(5,1);
h_hot2 = refpropm('H','T',T_COM2_IN,'P',P(5,1)/1000,'AIR.MIX'); 

Q_hot = m_HX_AIR*((h_HX12_hot_OUT-h_hot1)+(h_HX22_hot_OUT-h_hot2));
Q_zhengqi = (h_24_HOT_IN-h_24_HOT_OUT)*m_24+(h_23_HOT_IN-h_23_HOT_OUT)*m_23;


n_CAES = W_shi/W_chu;


n1 = (w_TUR_1+w_TUR_2)*m_6/W_chu;
n2 = W_shi/W_GTCCc;
n3 = (W_shi+W_GTCCc)/(W_chu+m_mmethanol*19937000);
n4 = (W_shi+W_GTCCc+Q_hot)/(W_chu+m_mmethanol*19937000);

fprintf('——CAES——\n');
fprintf('CAES 净电电效率为%2.2f\n',n_CAES);
fprintf('CAES 电电效率为%2.2f\n',n1);
fprintf('CAES 调峰比例为%2.2f\n',n2);

n_Q =  (W_shi+Q_hot)/(W_chu+Q_zhengqi);
fprintf('CAES 能量效率为%2.2f\n',n_Q);
fprintf('CAES-GTCC 电效率为%2.2f\n',n3);
fprintf('CAES-GTCC 能量效率为%2.2f\n',n4);
fprintf('——制冷温度——\n');
     if T_TUR2_OUT<(293.15-10-5)                                    
        fprintf('     可制冷\n');
        fprintf('透平出口温度为 %2.2f   %2.2f\n',T_TUR1_OUT,T_TUR2_OUT);
     else 
        fprintf('     ERROR!!!不可制冷\n');
     end
fprintf('===================\n');
h_amb = refpropm('H','T',293.15-10,'P',P_0/1000,'AIR.MIX');
h_cool = refpropm('H','T',T_TUR2_OUT,'P',P_TUR2_OUT/1000,'AIR.MIX');
Q_cool = m_HX_AIR*(h_amb-h_cool);    % 10摄氏度，最小温差大于5
fprintf('——CAES-GTCC——\n');
fprintf('CAES 电电效率为%2.2f\n',n1);
n31 = (W_shi+W_GTCCc)/(W_chu+m_mmethanol*19937000*0.4);
n41 = (W_shi+W_GTCCc+Q_hot+Q_cool)/(W_chu+m_mmethanol*19937000);
fprintf('CAES-GTCC 能量折算效率为%2.2f\n',n31);
fprintf('CAES-GTCC 能量效率为%2.2f\n',n41);

%
E_chu = W_chu;
E_shi = W_shi;
E_GTCC = W_GTCCc;

h_0 = refpropm('H','T',T_0,'P',P_0/1000,'WATER');
s_0 = refpropm('S','T',T_0,'P',P_0/1000,'WATER');
h_hot = refpropm('H','T',(273.15+90),'P',P_0/1000,'WATER');
s_hot = refpropm('S','T',(273.15+90),'P',P_0/1000,'WATER');
m_hot = Q_hot/(h_hot-h_0);
E_hot = m_hot*(h_hot-h_0-T_0*(s_hot-s_0));
h_cool = refpropm('H','T',(273.15+10),'P',P_0/1000,'WATER');
s_cool = refpropm('S','T',(273.15+10),'P',P_0/1000,'WATER');
m_cool = Q_cool/(h_0-h_cool);
E_cool = m_cool*(h_cool-h_0-T_0*(s_cool-s_0));
E_CH = m_mmethanol*19937000*(1.0038+0.1365*4/12+0.0308*16/12);
n_E = (E_shi+E_GTCC+E_cool+E_hot)/(E_chu+E_CH);
n_E1 = (E_shi+E_GTCC+E_hot)/(E_chu+E_CH);
fprintf('CAES-GTCC 火用效率为%2.2f\n',n_E);
%

W_E = (W_shi+W_GTCCc)/(1000000);% 电功率 MW
W_HOT = Q_hot/(1000000);        % 热功率 MW
W_COOL = Q_cool/(1000000);      % 冷功率 MW
Power(1,1) = W_E;
Power(2,1) = W_HOT;
Power(3,1) = W_COOL;
Power(4,1) = n1;    % CAES 电电效率
Power(5,1) = n31;   % CAES-GTCC 能量折算效率
Power(6,1) = n41;   % CAES-GTCC 能量效率
Power(7,1) = n_E;   % CAES-GTCC 火用效率
Power(8,1) = n4;    % CAES-GTCC 能量效率——不制冷
Power(9,1) = n_E1;  % CAES-GTCC 火用效率——不制冷
POW = Power';


COP = 3.2;
M_TOT = ((W_shi+W_GTCCc)+Q_cool/COP)/0.33+Q_hot/0.9;
M_CCHP = (W_chu+m_mmethanol*19937000);
n_esr = (M_TOT-M_CCHP)/M_TOT;
%%
P(11,1) = P_0;
P(12,1) = P_CHO_OUT;
P(13,1) = P_liejie;
P(14,1) = P_liejie;
P(15,1) = P_liejie;
P(16,1) = P_zengya_IN;
P(17,1) = P_zengya_OUT;
P(18,1) = P_0;
P(19,1) = p2_IN_c/(1-0.03);
P(20,1) = p2_IN_c;
P(21,1) = P_21;
P(22,1) = P_22;
P(23,1) = P_0;
P(24,1) = P_0;
P(25,1) = P_0;
P(26,1) = P_t_IN/(1-0.03);
P(27,1) = P_t_IN;
P(28,1) = P_t_OUT;
P(29,1) = P_t_OUT*(1-0.03);

T(1,1) = T_0;
T(2,1) = T_COM1_OUT;
T(3,1) = T_COM2_IN;
T(4,1) = T_COM2_OUT;
T(5,1) = T_COM2_IN;
T(6,1) = T_6_COLD_OUT;
T(7,1) = T_7;
T(8,1) = T_TUR1_OUT;
T(9,1) = T_9;
T(10,1) = T_TUR2_OUT;
T(11,1) = T_0;
T(12,1) = T_CHO_OUT;
T(13,1) = T_liejie;
T(14,1) = T_liejie;
T(15,1) = T_liejie_mix;
T(16,1) = T_zengya_IN;
T(17,1) = T_zengya_OUT;
T(18,1) = T_0;
T(19,1) = T1_OUTc;
T(20,1) = T_ranshao;
T(21,1) = T_21;
T(22,1) = (T_store+10);
T(23,1) = (T_8+10);
T(24,1) = (T_62_COLD_IN+10);
T(25,1) = T_25;
T(26,1) = Tw3_OUTc;
T(27,1) = T_t_IN;
T(28,1) = Tw1_OUTc;
T(29,1) = Tw3_INc;

m(1,1) = m_HX_AIR;
m(2,1) = m_HX_AIR;
m(3,1) = m_HX_AIR;
m(4,1) = m_HX_AIR;
m(5,1) = m_HX_AIR;
m(6,1) = m_6;
m(7,1) = m_6;
m(8,1) = m_6;
m(9,1) = m_6;
m(10,1) = m_6;
m(11,1) = mmethanol_c;
m(12,1) = mmethanol_c;
m(13,1) = m_HX2_cold;
m(14,1) = m_HX1_cold;
m(15,1) = mmethanol_c;
m(16,1) = mmethanol_c;
m(17,1) = mmethanol_c;
m(18,1) = mmethanol_c*rankong_c;
m(19,1) = mmethanol_c*rankong_c;
m(20,1) = mr_c;
m(21,1) = mr_c;
m(22,1) = m_22;
m(23,1) = m_23;
m(24,1) = m_24;
m(25,1) = m_25;
m(26,1) = mqc;
m(27,1) = mqc;
m(28,1) = mqc;
m(29,1) = mqc;

% 2-3
P(30,1) = P(3,1);
T(30,1) = T_HX12_hot_OUT;
m(30,1) = m_HX_AIR;
% 4-5
P(31,1) = P(5,1);
T(31,1) = T_HX22_hot_OUT;
m(31,1) = m_HX_AIR;
% 6出口
P(32,1) = P(6,1);
T(32,1) = T_store;
m(32,1) = m_6;
% 12省煤器预热后
P(33,1) = P_CHO_OUT;
T(33,1) = T_HX14_cold_OUT;
m(33,1) = mmethanol_c;
% 12裂解气预热后
P(34,1) = P_CHO_OUT;
T(34,1) = T_HX13_cold_OUT;
m(34,1) = mmethanol_c;
% 22预热前烟气
P(35,1) = P_22; 
T(35,1) = T_22;
m(35,1) = m_22;
%%
% clearvars -except POW
