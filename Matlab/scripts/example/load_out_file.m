%% Program
clc;clear;close all

%% 测试单个文件读取
file_path = 'D:\OneDrive\LIUYU\003-Document\file_Ansys\project1_1_5_Dipole_3D_NoLLS_Dataset_GravityAnalyse\03_Fluent\out\';
file = 'pressure_signal_test9_1_1.out';
Data = importdata(fullfile(file_path,file));
data = Data.data;
pressure = PressureReorder(Data);
% pressure = data(:,3:end);
time = data(:,2);
fs = 1/time(2);
time_not_use = 4; %秒
pressure = pressure(ceil(time_not_use*fs+1):end,:);
time = time(1:end-floor(time_not_use*fs));
num_sensor = size(pressure,2);

figure()
plot(time, pressure(:,1)-mean(pressure(:,1)))

figure(); hold on
plot(time, pressure(:,1), '*-','LineWidth',2,'Color','r')
plot(time, pressure(:,:))
legend



%% FFT
fft_array = fft_pressure(pressure,fs);
fft_array_front = fft_array(1:11*11);
fft_array_front2 = fft_array([1:11]+11*5);
figure();hold on
plot(fft_array_front)
plot(fft_array_front2)


%% 偶极子压力分布测试
% 偶极子压力分布方程
dip_x = 0;
dip_y = 0.05;
P = SensorPressure(dip_x,dip_y);
P_half = P(ceil(length(P)/2):end);
figure();plot(P,'-*')

% 多偶极子复合流场
% dip_x1 = +0.05;
% dip_y1 = 0.05;
% P1 = SensorPressure(dip_x1,dip_y1);
% 
% dip_x2 = -0.05;
% dip_y2 = 0.05;
% P2 = SensorPressure(dip_x2,dip_y2);
% 
% S = -10:10; ld = 1;
% figure();hold on
% plot(S,P1,'-*','linewidth',ld);
% plot(S,P2,'-*','linewidth',ld);
% plot(S,P1+P2,'-*','linewidth',ld)
% plot(S,abs(P1-P2),'-*','linewidth',ld)
% legend({"P1","P2","P1+P2","abs(P1-P2)"})


figure()
hold on
plot(fft_array_front2,'-*')
plot(P_half,'o')
legend({'仿真','理论'})


%% 对比不同距离
fft_array_front1 = fft_array([1:11]+11*5);
fft_array_front2 = fft_array([1:11]+11*5+121*1);
fft_array_front3 = fft_array([1:11]+11*5+121*2);
fft_array_front4 = fft_array([1:11]+11*5+121*3);
P1 = SensorPressure(0,0.05-0.005); P_half1 = P1(ceil(length(P1)/2):end);
P2 = SensorPressure(0,0.06-0.005); P_half2 = P2(ceil(length(P2)/2):end);
P3 = SensorPressure(0,0.07-0.005); P_half3 = P3(ceil(length(P3)/2):end);
P4 = SensorPressure(0,0.08-0.005); P_half4 = P4(ceil(length(P4)/2):end);
figure(); hold on
plot(fft_array_front1,'r-*'); plot(P_half1,'ro')
plot(fft_array_front2,'b-*'); plot(P_half2,'bo')
plot(fft_array_front3,'k-*'); plot(P_half3,'ko')
plot(fft_array_front4,'g-*'); plot(P_half4,'go')
legend({'仿真-距离5cm','理论-距离5cm', ...
    '仿真-距离6cm','理论-距离6cm', ...
    '仿真-距离7cm','理论-距离7cm', ...
    '仿真-距离8cm','理论-距离8cm'},"FontSize",16)
set(gca,'fontsize',16)


%% 偶极子理论【豆包】
P2 = SensorPressure2();
P_half2 = P2(ceil(length(P2)/2):end);
figure()
hold on
plot(fft_array_front2,'-*')
plot(P_half2,'o')
legend({'仿真','理论'})










%% 函数——压力数据重新排序
% 注意，Fluent生成的out文件，序号并不是1,2,3,4这样子，而是1,10,11
% 因此需要转序。
% 参考：D:\OneDrive\LIUYU\003-Document\file_matlab\文章构思——2021年03(PSO)\Fluent仿真数据处理\DataLoadAndSTFT_FluentData.m
% 压力数据重新排序函数
function data_reordered = PressureReorder(Data)
% 读取通道名称
textdata = Data.textdata;
pointname = textdata{3};
pointname_ = strsplit(pointname);
pointname__ = pointname_(4:end);
pointname__{end} = pointname__{end}(1:end-1);
% 根据通道名称生成数列
for i = 1:length(pointname__)
    bb = pointname__{i}(7:end-1);%
    % bb = pointname__{i}(6:end-1);
    oldname(i) = str2num(bb);
end
% 交换顺序
% time = data(:,2);
data1 = Data.data(:,3:end);
for i = 1:length(oldname)
    data2(:,oldname(i)) = data1(:,i);
end
for i = 1:length(oldname)
    data3(:,oldname(i)) = data2(:,i);
end
data_reordered = data3;
end


%% 函数——FFT
% 参考：
% D:\OneDrive\LIUYU\003-Document\file_matlab\文章构思——66个位置侧线实验（文章构思）\draft_3_fft_prog.m
% D:\OneDrive\LIUYU\003-Document\file_matlab\文章构思——2021年03(PSO)\文章分析——仿真——固定点偶极子不同SNR和Variance随X和Y变化\PSOPredict66PointsFunction_matlabData_SNR.m
function [f_eigen] = fft_pressure(data_set,Fs)
num_data = size(data_set,2);
for i=1:num_data
    a=data_set(:,i);   
    % L=length(a(:,1));
    L=ceil(length(a(:,1)));
    a = a - mean(a);
    Y=fft(a);                    % 快速傅里叶变换
    P2=abs(Y/L);
    P1=P2(2:ceil(L/2+1),:);
    P1(2:end-1,:)=2*P1(2:end-1,:);
    f=Fs*(0:ceil(L/2))/L;            % 频域轴
    % figure(); plot(f(1:end-1),P1); xlim([0 49]); legend        %画频域图
    % xlabel('频率/Hz');ylabel('电压/V');title('频域图');
    % 计算特征值
    % 实验中目标振动频率为7Hz
    % f_low=1; f_high=15;
    % f_start=f_low/Fs*L; f_end=f_high/Fs*L;
    % f_eigen(i,:)=max(P1(f_start:f_end,:));
    f_eigen(i,:) = max(P1);
    % figure(); plot(f_eigen(i,:),'linewidth',2.0);
end
end

%% 偶极子方程
% 参考：D:\OneDrive\LIUYU\003-Document\file_matlab\文章构思——2022年06(不同数目偶极子)\Untitled.m
function P = SensorPressure(dip_x,dip_y)
% Sensor Location
sensor_x = linspace(-10,10,21) * 10^(-2);
sensor_y = zeros(1,length(sensor_x));
% P = zeros(6,1);
f = 5;
rou = 998.2;
w = f*2*pi;
a = 25*10^(-3);
delta = 0.005;
K = 0.5*w^2*rou*a^3*delta;
for i = 1:length(sensor_x)
    delta_x = abs(dip_x-sensor_x(i));
    delta_y = abs(dip_y-sensor_y(i));
    r_square = delta_x^2+delta_y^2;
    r = sqrt(r_square);
    costheta = delta_y/r;
    sintheta = delta_x/r;
    P(i) = K * costheta / r_square;
end
end

%偶极子方程【豆包】
function P_amp = SensorPressure2()
    sensor_x = linspace(-0.1,0.1,21); % ±10cm
    sensor_z = zeros(1,length(sensor_x));
    dip_z0 = 0.05; dip_x0 = 0;
    f = 5; rou = 998.2; c = 1500;
    w = 2*pi*f; a = 0.025; A_vib = 0.005;
    k = w/c;
    for i = 1:length(sensor_x)
        dx = sensor_x(i)-dip_x0;
        dz = sensor_z(i)-dip_z0;
        r = sqrt(dx^2 + dz^2);
        costheta = dz / r; % Z向振动，θ为Z轴夹角
        denom = r^2 * sqrt(1 + (k*r)^2);
        P_amp(i) = (rou * w^2 * a^3 * A_vib * abs(costheta)) / denom * 0.5;
    end
end